@tool
extends UnlockCondition
class_name Condition_DontPlayGivenCardsInEncounter

@export var encounter_id: String
@export var cards_to_not_play: Array[String] #card id, nr of plays


func is_judged_on_a_single_run() -> bool:
	return true

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

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var card_lists: Array = []
	for card_id in cards_to_not_play:
		var card_segments: Array[DescriptionSegment] = [_term_link("CARD", card_id)]
		card_lists.append(card_segments)
	return _template("UI_UNLOCK_CONDITION_DONT_PLAY_CARDS_TEMPLATE",
		{"encounter": _encounter_name(encounter_id), "cards": _join_with_commas(card_lists)})
