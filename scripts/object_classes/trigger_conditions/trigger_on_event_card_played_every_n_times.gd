@tool
extends TriggerCondition
class_name TriggerCondition_OnEventCardPlayedEveryNTimes

@export var card_ids: Array[String] = []
@export var every_n: int = 1

func is_condition_met(
	input_context: EffectContext,game_state: GameState,_save_game_state: SaveGameState,_owner_of_trigger: TargetEntity) -> bool:

	if every_n <= 0:
		return false
	if not input_context.played_event_card:
		return false

	var event_card_instance: EventCardInstance = input_context.event_card_instance
	var played_card_id: String = event_card_instance.card_id

	if played_card_id not in card_ids:
		return false

	### Pooled across every tracked card, so any of them advances the same shared count.
	var total_play_count: int = game_state.encounter_report.get_times_cards_have_been_played(card_ids)
	return total_play_count % every_n == 0
