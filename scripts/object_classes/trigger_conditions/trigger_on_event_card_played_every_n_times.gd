@tool
extends TriggerCondition
class_name TriggerCondition_OnEventCardPlayedEveryNTimes

@export var card_ids: Array[String] = []
@export var every_n: int = 1

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "TriggerCondition_OnEventCardPlayedEveryNTimes"
	d["card_ids"] = card_ids
	d["every_n"] = every_n
	return d

static func from_json_dict(data: Dictionary) -> TriggerCondition_OnEventCardPlayedEveryNTimes:
	var condition := TriggerCondition_OnEventCardPlayedEveryNTimes.new()
	condition.trigger_condition_id = data.get("trigger_condition_id", "")
	var ids: Array[String] = []
	for id in data.get("card_ids", []):
		ids.append(str(id))
	condition.card_ids = ids
	condition.every_n = int(data.get("every_n", 1))
	return condition

func is_condition_met(
	input_context: EffectContext, game_state: GameState, _save_game_state: SaveGameState, _owner_of_trigger: TargetEntity) -> bool:

	if every_n <= 0:
		return false
	if not input_context.played_event_card:
		return false

	var event_card_instance: EventCardInstance = input_context.event_card_instance
	var played_card_id: String = event_card_instance.card_id

	if played_card_id not in card_ids:
		return false

	# Pooled across every tracked card, so any of them advances the same shared count.
	var total_play_count: int = DealDamageBasedOnCardPlayCount.get_current_count(game_state, card_ids)
	return total_play_count % every_n == 0
