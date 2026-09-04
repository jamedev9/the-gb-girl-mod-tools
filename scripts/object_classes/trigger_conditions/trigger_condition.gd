@tool
extends Resource
class_name TriggerCondition

@export var trigger_condition_id: String

func to_json_dict() -> Dictionary:
	return {"type": "TriggerCondition", "trigger_condition_id": trigger_condition_id}

### No concrete TriggerCondition subclasses exist yet - this dispatch is here so any
### subclass added later only needs a case added here, matching the pattern used by
### EffectIntent/TargetingRule/StatusModifierComponent.
static func from_json_dict(data: Dictionary) -> TriggerCondition:
	match data.get("type", ""):
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
