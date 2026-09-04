@tool
extends TriggerCondition
class_name TriggerCondition_OnOpponentEnters

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "TriggerCondition_OnOpponentEnters"
	return d

static func from_json_dict(data: Dictionary) -> TriggerCondition_OnOpponentEnters:
	var condition := TriggerCondition_OnOpponentEnters.new()
	condition.trigger_condition_id = data.get("trigger_condition_id", "")
	return condition

func is_condition_met(
	input_context: EffectContext, _game_state: GameState, _save_game_state: SaveGameState, owner_of_trigger: TargetEntity) -> bool:

		if input_context.new_opponent_spawned != null:
			return true
		return false
