@tool
extends ModExportable
class_name UnlockCondition

@export var unlock_condition_id: String
@export var description: String

func is_condition_met(_save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	return false

### True for a condition that judges the report of ONE encounter run (win by turn 5, play a card 3 times in the encounter, ...)
### instead of the save. Such a condition can only be met at the moment that run ends - any other time it gets no report.
### RewardDefinition therefore remembers, per reward, that a single run met all of its run conditions
### (SaveGameState.has_met_run_conditions()), so the rest of the reward can be met before OR after that run. A new
### condition class that reads the report must override this to return true. Not for conditions that keep their own
### running total in the save (Condition_MakeGuysCumWithActivePassive).
func is_judged_on_a_single_run() -> bool:
	return false

func is_condition_hidden_from_player(_save_game_state: SaveGameState) -> bool:
	### Overwritten by child classes.
	### Specific conditions can be hidden from the player to hide secrets,
	### and to prevent them from being overloaded with information early on.
	return false

#region Progress counter (shown after the condition text in UnlockRequirementPanel)
### What kind of number a condition shows the player. NONE = nothing (yes/no conditions, and the older
### conditions whose text already contains the counter).
### COUNT_UP: "(current/required)" - something that is counted up towards a number.
### BEST_LOWER: "(Best: x)" - a condition where a lower number is better ("win by turn 5"), shows the best
### result so far.
enum ProgressStyle {NONE, COUNT_UP, BEST_LOWER}

func get_progress_style() -> ProgressStyle:
	return ProgressStyle.NONE

### COUNT_UP: how far the player is. BEST_LOWER: the best (lowest) result so far, or -1 if there is none yet.
### Reads only the save: conditions that need an encounter report keep their best results in
### SaveGameState.encounter_records (see SaveGameState.apply_encounter_report()), so this still works
### between encounters.
func get_progress_current(_save_game_state: SaveGameState) -> int:
	return 0

### COUNT_UP only: the number to reach.
func get_progress_required(_save_game_state: SaveGameState) -> int:
	return 0

### BEST_LOWER only: how the best result is written (e.g. "62%").
func format_best_value(best_value: int) -> String:
	return str(best_value)

### The report of the encounter being played right now, if it is the given encounter. Only the in-encounter
### rewards panel has one (it sets SaveGameState.in_progress_encounter_report on its temporary save copy);
### everywhere else this is null. Encounter conditions use it to show the current run's progress ("1/2")
### instead of the best earlier result.
func get_in_progress_report(save_game_state: SaveGameState, for_encounter_id: String) -> EncounterReport:
	var report: EncounterReport = save_game_state.in_progress_encounter_report
	if report and report.encounter_def and report.encounter_def.encounter_id == for_encounter_id:
		return report
	return null
#endregion

#region Text for the player
### The condition as text for the player (UnlockRequirementPanel shows it in a DescriptionLabel and adds the progress counter after it):
### a csv template with {placeholders} whose values are numbers/names picked out with bold(-italic) and the game terms (cards, Actions,
### Passives, Statuses) as hover links. A condition that has no text of its own (_build_description_segments() gives nothing) shows its
### hand-written `description`, which can hold {KEYWORD} / {CARD:id}-style tokens too.
func get_description_segments(save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var segments: Array[DescriptionSegment] = _build_description_segments(save_game_state)
	if segments.is_empty():
		segments = DescriptionBuilder.parse_template(description)
	return segments

### Overwritten by the conditions that write their own text.
func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return []

### Parses a template row of this condition. The csv has no plural forms, so a text that names what is counted has a second row,
### KEY_ONE, with the singular wording; it is used when `count` is exactly 1 (pass -1 for a text with no count). Every KEY_ONE needs
### an English and a Chinese row with the same {placeholders}.
func _template(key: String, substitutions: Dictionary, count: int = -1) -> Array[DescriptionSegment]:
	var final_key: String = key + "_ONE" if count == 1 else key
	return DescriptionBuilder.parse_template(tr(final_key), substitutions)

### A number in bold.
func _number(value: int) -> DescriptionSegment:
	return DescriptionSegment.emphasis_segment(str(value))

### "(3/10)" in bold: how far the player is.
func _progress_text(current: int, required: int) -> DescriptionSegment:
	return DescriptionSegment.emphasis_segment("(%d/%d)" % [current, required])

### A name in bold italic (an encounter, a region, a reward): picked out, not a link.
func _name_emphasis(name_text: String) -> DescriptionSegment:
	return DescriptionSegment.emphasis_segment(name_text, true)

func _encounter_name(encounter_id: String) -> DescriptionSegment:
	var encounter_def: EncounterDefinition = AutoloadDatabase.get_encounter_def_by_id(encounter_id)
	return _name_emphasis(encounter_def.get_encounter_name() if encounter_def else encounter_id)

### A game term as a hover link: kind is STATUS / PASSIVE / ACTION / CARD (see DescriptionTerms.from_token()).
func _term_link(kind: String, term_id: String) -> DescriptionSegment:
	return DescriptionTerms.from_token(kind, term_id)

### "A", "A and B", "A, B, and C" (or "or") of links to the given terms.
func _term_list(kind: String, term_ids: Array[String], use_or: bool = false) -> Array[DescriptionSegment]:
	var segment_lists: Array = []
	for term_id in term_ids:
		var single: Array[DescriptionSegment] = [_term_link(kind, term_id)]
		segment_lists.append(single)
	return _join(segment_lists, use_or)

### Joins already-built segment lists with the translated "and" / "or".
func _join(segment_lists: Array, use_or: bool = false) -> Array[DescriptionSegment]:
	var conjunction: String = TranslationServer.translate(
		"EFFECTANDTARGETINTENT_LIST_OR_JOINER" if use_or else "EFFECTANDTARGETINTENT_LIST_AND_JOINER")
	return DescriptionBuilder.join_segment_lists_with_conjunction(segment_lists, conjunction)

### Joins with plain commas ("A, B, C"), for lists that carry their own counters.
func _join_with_commas(segment_lists: Array) -> Array[DescriptionSegment]:
	var joined: Array[DescriptionSegment] = []
	for index in segment_lists.size():
		if index > 0:
			joined.append(DescriptionSegment.text_segment(", "))
		joined.append_array(segment_lists[index])
	return joined
#endregion
