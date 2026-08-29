extends UnlockCondition
class_name Condition_PlayCardsGivenTimeInEncounter

@export var encounter_id: String
@export var cards_to_play: Dictionary[String,int] #card id, nr of plays


func is_condition_met(save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	if not encounter_report.player_won:
		return false
	var cards_played_in_encounter: Dictionary[String,int] = encounter_report.get_played_event_cards()
	for card_id in cards_to_play.keys():
		if card_id not in cards_played_in_encounter.keys():
			return false # A card was not played
		if cards_played_in_encounter[card_id] < cards_to_play[card_id]:
			return false
	
	return true
