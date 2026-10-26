@tool
extends UnlockCondition
class_name Condition_HasPlayedCardNTimes

@export var event_card_id: String
@export var required_nr_of_plays: int


func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	var cards_played: Dictionary = save_game_state.event_cards_played
	if event_card_id not in cards_played.keys():
		return false
	return cards_played[event_card_id] >= required_nr_of_plays

func get_progress_style() -> ProgressStyle:
	return ProgressStyle.COUNT_UP

func get_progress_current(save_game_state: SaveGameState) -> int:
	return int(save_game_state.event_cards_played.get(event_card_id,0))

func get_progress_required(_save_game_state: SaveGameState) -> int:
	return required_nr_of_plays

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_PLAYED_CARD_N_TIMES",
		{"card": _term_link("CARD", event_card_id), "count": _number(required_nr_of_plays)}, required_nr_of_plays)
