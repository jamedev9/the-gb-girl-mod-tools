extends UnlockCondition
class_name Condition_DontPlayGivenCardsInEncounter

@export var encounter_id: String
@export var cards_to_not_play: Array[String] #card id, nr of plays


func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	if not encounter_report.player_won:
		return false
	var cards_played_in_encounter: Dictionary[String,int] = encounter_report.get_played_event_cards()
	for card_id in cards_to_not_play:
		if card_id in cards_played_in_encounter.keys():
			return false # A card  not played
	
	return true
