extends Resource
class_name TriggerCondition

@export var trigger_condition_id: String

func is_condition_met(
	input_context: EffectContext,
	game_state: GameState
	,save_game_state: SaveGameState,
	owner_of_trigger: TargetEntity) -> bool:
		### Overwritten by child classes.
		return false
