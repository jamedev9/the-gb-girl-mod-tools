@tool
extends TriggerCondition
class_name TriggerCondition_RandomChance

@export_range(0, 1, 0.01) var trigger_chance: float = 1

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "TriggerCondition_RandomChance"
	d["trigger_chance"] = trigger_chance
	return d

static func from_json_dict(data: Dictionary) -> TriggerCondition_RandomChance:
	var condition := TriggerCondition_RandomChance.new()
	condition.trigger_condition_id = data.get("trigger_condition_id", "")
	condition.trigger_chance = float(data.get("trigger_chance", 1.0))
	return condition

func is_condition_met(
	_input_context: EffectContext,
	_game_state: GameState,
	_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:

		if trigger_chance == 0:

			return false

		var random_nr: float = randf_range(0, 1)

		return random_nr <= trigger_chance
