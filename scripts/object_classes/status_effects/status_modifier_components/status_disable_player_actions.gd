extends StatusModifierComponent
class_name Status_DisablePlayerActions

@export var disabled_action_ids: Array[String]
### If non-empty, disables every action EXCEPT these instead of enumerating
### disabled_action_ids - for "only X is allowed" statuses that should still
### cover actions added after this resource was authored.
@export var allowed_action_ids: Array[String] = []

func modify_context(effect_context: EffectContext) -> void:
	if not effect_context.moving_player_action:
		return
	if effect_context.player_action_id in get_disabled_action_ids():
		effect_context.moving_player_action = false

### Single source of truth for "which actions does this component disable" -
### used here and by GameState.get_disabled_player_actions() so the two never
### disagree about what an allowed_action_ids-based component actually disables.
func get_disabled_action_ids() -> Array[String]:
	if allowed_action_ids.is_empty():
		return disabled_action_ids
	var result: Array[String] = []
	for action_id in AutoloadDatabase.player_actions_by_id.keys():
		if action_id not in allowed_action_ids:
			result.append(action_id)
	return result
