@tool
extends UnlockCondition
class_name Condition_DefeatNWithSourceInEncounter

### Report: win the encounter after making at least required_count partners cum with the given kind of
### source (Action, Event Card, Status, Passive, other). source_ids optionally narrows it to specific
### Actions/Cards/Statuses/Passives of that kind (ids of that kind; empty = any of the kind).
### What counts as the source is decided when the damage lands (EncounterReport.set_defeat_source()): a
### passive or status that deals the damage counts as that passive/status, even if an Event Card started it;
### "Trigger [Action]" Event Cards count as the Action.

@export var encounter_id: String
@export var source_kind: EncounterReport.DefeatSourceKind = EncounterReport.DefeatSourceKind.EVENT_CARD
@export var source_ids: Array[String] = []
@export var required_count: int = 1

func is_judged_on_a_single_run() -> bool:
	return true

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if not encounter_report.player_won:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	return encounter_report.get_nr_of_defeats_by_source(source_kind,source_ids) >= required_count

### Best result in this encounter so far - only when no specific ids are asked for (the records are per kind).
func get_progress_style() -> ProgressStyle:
	if source_ids.is_empty():
		return ProgressStyle.COUNT_UP
	return ProgressStyle.NONE

func get_progress_current(save_game_state: SaveGameState) -> int:
	var live_report: EncounterReport = get_in_progress_report(save_game_state,encounter_id)
	if live_report: ### during the encounter: this run so far
		return live_report.get_nr_of_defeats_by_source(source_kind)
	return save_game_state.get_encounter_record(
		encounter_id,SaveGameState.get_defeats_by_source_record_key(source_kind),0)

func get_progress_required(_save_game_state: SaveGameState) -> int:
	return required_count

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_DEFEAT_WITH_SOURCE", {
		"count": _number(required_count), "source": _get_source_segments(), "encounter": _encounter_name(encounter_id)}, required_count)

### The category ("Actions", "Event Cards", ...) in bold when no specific source is asked for, otherwise links to the ones asked for.
func _get_source_segments() -> Array[DescriptionSegment]:
	if source_ids.is_empty():
		var category: Array[DescriptionSegment] = [
			DescriptionSegment.emphasis_segment(tr("UI_UNLOCK_DEFEAT_SOURCE_" + EncounterReport.DefeatSourceKind.keys()[source_kind]))]
		return category
	var term_kind: String = ""
	match source_kind:
		EncounterReport.DefeatSourceKind.PLAYER_ACTION:
			term_kind = "ACTION"
		EncounterReport.DefeatSourceKind.EVENT_CARD:
			term_kind = "CARD"
		EncounterReport.DefeatSourceKind.STATUS_EFFECT:
			term_kind = "STATUS"
		EncounterReport.DefeatSourceKind.PASSIVE:
			term_kind = "PASSIVE"
	if term_kind == "":
		var unknown: Array[DescriptionSegment] = [DescriptionSegment.emphasis_segment("?")]
		return unknown
	return _term_list(term_kind, source_ids, true)
