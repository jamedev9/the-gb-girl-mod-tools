@tool
extends UnlockCondition
class_name Condition_PlayCardsGivenTimeInEncounter

@export var encounter_id: String
@export var cards_to_play: Dictionary[String,int] #card id, nr of plays


func is_judged_on_a_single_run() -> bool:
	return true

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

### While the encounter is being played, each card shows how many times it has been played this run ("2/3"), else just the number.
func _build_description_segments(save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var live_report: EncounterReport = get_in_progress_report(save_game_state, encounter_id) if save_game_state else null
	var card_lists: Array = []
	for card_id in cards_to_play.keys():
		var card_count: int = cards_to_play[card_id]
		var counter_text: String = str(card_count)
		if live_report:
			counter_text = "%d/%d" % [mini(live_report.get_times_card_has_been_played(card_id), card_count), card_count]
		var card_segments: Array[DescriptionSegment] = [
			_term_link("CARD", card_id), DescriptionSegment.text_segment(" "), DescriptionSegment.emphasis_segment("(%s)" % counter_text)]
		card_lists.append(card_segments)
	return _template("UI_UNLOCK_CONDITION_PLAY_CARDS_TEMPLATE",
		{"encounter": _encounter_name(encounter_id), "cards": _join_with_commas(card_lists)})
