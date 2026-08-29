extends Resource
class_name StatusTickComponent

@export var tick_component_id: String
@export var effect_intents: Array[EffectAndTargetIntent]

func are_ticking_conditions_met(_game_state: GameState) -> bool:
	return true
