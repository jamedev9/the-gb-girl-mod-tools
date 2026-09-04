@tool
extends TriggerCondition
class_name TriggerCondition_OnlyOnPlayersTurn

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "TriggerCondition_OnlyOnPlayersTurn"
	return d

static func from_json_dict(data: Dictionary) -> TriggerCondition_OnlyOnPlayersTurn:
	var condition := TriggerCondition_OnlyOnPlayersTurn.new()
	condition.trigger_condition_id = data.get("trigger_condition_id", "")
	return condition

func is_condition_met(
	_input_context: EffectContext, game_state: GameState, _save_game_state: SaveGameState, _owner_of_trigger: TargetEntity) -> bool:
	return game_state.it_is_players_turn()
