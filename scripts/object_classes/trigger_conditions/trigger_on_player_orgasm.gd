@tool
extends TriggerCondition
class_name TriggerCondition_OnPlayerOrgasm

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "TriggerCondition_OnPlayerOrgasm"
	return d

static func from_json_dict(data: Dictionary) -> TriggerCondition_OnPlayerOrgasm:
	var condition := TriggerCondition_OnPlayerOrgasm.new()
	condition.trigger_condition_id = data.get("trigger_condition_id", "")
	return condition

func is_condition_met(
	input_context: EffectContext,
	_game_state: GameState
	, _save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:

	return input_context.player_orgasmed
