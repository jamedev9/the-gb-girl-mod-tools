extends UnlockCondition
class_name Condition_HasPlayedCardNTimes

@export var event_card_id: String
@export var required_nr_of_plays: int


func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	var cards_played: Dictionary = save_game_state.event_cards_played
	if event_card_id not in cards_played.keys():
		return false
	return cards_played[event_card_id] >= required_nr_of_plays
