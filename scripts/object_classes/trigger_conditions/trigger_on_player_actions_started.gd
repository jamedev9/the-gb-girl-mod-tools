@tool
extends TriggerCondition
class_name TriggerCondition_OnPlayerActionsStarted

@export var action_ids: Array[String]

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "TriggerCondition_OnPlayerActionsStarted"
	d["action_ids"] = action_ids
	return d

static func from_json_dict(data: Dictionary) -> TriggerCondition_OnPlayerActionsStarted:
	var condition := TriggerCondition_OnPlayerActionsStarted.new()
	condition.trigger_condition_id = data.get("trigger_condition_id", "")
	var ids: Array[String] = []
	for id in data.get("action_ids", []):
		ids.append(str(id))
	condition.action_ids = ids
	return condition

func is_condition_met(
	input_context: EffectContext,
	_game_state: GameState
	, _save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:

	if not input_context.moving_player_action:
		return false
	if input_context.player_action_id not in action_ids:
		return false
	if input_context.target_is_immune_to_action:
		return false

	return true
