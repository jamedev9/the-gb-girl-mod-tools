@tool
extends UnlockCondition
class_name Condition_PlayNCardsInOneTurn

### Report: win the encounter after having played at least cards_in_one_turn Event Cards in a single turn.
### required_card_ids optionally names cards that must all be among the ones played in that same turn.

@export var encounter_id: String
@export var cards_in_one_turn: int = 3
@export var required_card_ids: Array[String] = []

func is_judged_on_a_single_run() -> bool:
	return true

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if not encounter_report.player_won:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	return encounter_report.has_turn_with_cards(cards_in_one_turn,required_card_ids)

### Most cards played in one turn in a winning run of this encounter so far - only when no specific cards
### are required (the record does not know which cards they were).
func get_progress_style() -> ProgressStyle:
	if required_card_ids.is_empty():
		return ProgressStyle.COUNT_UP
	return ProgressStyle.NONE

func get_progress_current(save_game_state: SaveGameState) -> int:
	var live_report: EncounterReport = get_in_progress_report(save_game_state,encounter_id)
	if live_report: ### during the encounter: the most cards in one turn so far this run
		return live_report.get_most_cards_played_in_one_turn()
	return save_game_state.get_encounter_record(encounter_id,SaveGameState.RECORD_MOST_CARDS_IN_ONE_TURN,0)

func get_progress_required(_save_game_state: SaveGameState) -> int:
	return cards_in_one_turn

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var segments: Array[DescriptionSegment] = _template("UI_UNLOCK_CONDITION_PLAY_CARDS_IN_ONE_TURN",
		{"count": _number(cards_in_one_turn), "encounter": _encounter_name(encounter_id)}, cards_in_one_turn)
	if not required_card_ids.is_empty():
		segments.append(DescriptionSegment.text_segment(" "))
		segments.append_array(_template("UI_UNLOCK_CONDITION_PLAY_CARDS_IN_ONE_TURN_INCLUDING", {"cards": _term_list("CARD", required_card_ids)}))
	return segments
