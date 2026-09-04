@tool
extends TriggerCondition
class_name TriggerCondition_OnEventCardPlayed

@export var trigger_on_all_cards: bool = false
@export var card_ids: Array[String] = []

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "TriggerCondition_OnEventCardPlayed"
	d["trigger_on_all_cards"] = trigger_on_all_cards
	d["card_ids"] = card_ids
	return d

static func from_json_dict(data: Dictionary) -> TriggerCondition_OnEventCardPlayed:
	var condition := TriggerCondition_OnEventCardPlayed.new()
	condition.trigger_condition_id = data.get("trigger_condition_id", "")
	condition.trigger_on_all_cards = data.get("trigger_on_all_cards", false)
	var ids: Array[String] = []
	for id in data.get("card_ids", []):
		ids.append(str(id))
	condition.card_ids = ids
	return condition

func is_condition_met(
	input_context: EffectContext, _game_state: GameState, _save_game_state: SaveGameState, owner_of_trigger: TargetEntity) -> bool:

	if not input_context.played_event_card:
		return false

	if trigger_on_all_cards:
		return true

	if input_context.event_card_instance.card_id in card_ids:
		return true

	return false
