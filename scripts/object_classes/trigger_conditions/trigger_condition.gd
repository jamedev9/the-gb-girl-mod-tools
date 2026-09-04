@tool
extends Resource
class_name TriggerCondition

@export var trigger_condition_id: String

func to_json_dict() -> Dictionary:
	return {"type": "TriggerCondition", "trigger_condition_id": trigger_condition_id}

static func from_json_dict(data: Dictionary) -> TriggerCondition:
	match data.get("type", ""):
		"TriggerCondition_OnPlayerOrgasm":
			return TriggerCondition_OnPlayerOrgasm.from_json_dict(data)
		"TriggerCondition_OnOpponentEnters":
			return TriggerCondition_OnOpponentEnters.from_json_dict(data)
		"TriggerCondition_OnlyOnPlayersTurn":
			return TriggerCondition_OnlyOnPlayersTurn.from_json_dict(data)
		"TriggerCondition_OnEventCardPlayed":
			return TriggerCondition_OnEventCardPlayed.from_json_dict(data)
		"TriggerCondition_RandomChance":
			return TriggerCondition_RandomChance.from_json_dict(data)
		"TriggerCondition_OnPlayerActionsStarted":
			return TriggerCondition_OnPlayerActionsStarted.from_json_dict(data)
		"TriggerCondition_OnEventCardPlayedEveryNTimes":
			return TriggerCondition_OnEventCardPlayedEveryNTimes.from_json_dict(data)
		"TriggerCondition_OnPlayerActionsTriggered":
			return TriggerCondition_OnPlayerActionsTriggered.from_json_dict(data)
		_:
			push_warning("Unsupported/unknown trigger_condition type in mod data: %s" % data.get("type", ""))
			return null

func is_condition_met(
	input_context: EffectContext,
	game_state: GameState
	,save_game_state: SaveGameState,
	owner_of_trigger: TargetEntity) -> bool:
		### Overwritten by child classes.
		return false
