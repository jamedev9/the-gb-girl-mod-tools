extends StatusModifierComponent
class_name Status_DisablePlayerActions

@export var disabled_action_ids: Array[String]

func modify_context(effect_context: EffectContext) -> void:
	if effect_context.moving_player_action:
		if effect_context.player_action_id in disabled_action_ids:
			effect_context.moving_player_action = false
