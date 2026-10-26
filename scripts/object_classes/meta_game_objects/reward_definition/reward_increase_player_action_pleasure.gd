@tool
extends RewardDefinition
class_name Reward_IncreasePlayerActionPleasure

### Test reward for the per-save player-action progression system (Phase C of the player-action
### rework): permanently adds pleasure_increase to the Pleasure every damage effect of each listed
### action deals, for this save only. See SaveGameState.get_effective_player_action().
### Only DealDamageEffect intents count - same as what the action card shows as its Pleasure number.
### Stacks if granted again (repeatable rewards, or several of these rewards on the same action).

@export var action_ids: Array[String]
@export var pleasure_increase: int = 1

func get_referenced_content_ids() -> Dictionary:
	return {"actions": action_ids.duplicate()}

func apply_reward(save_game_state: SaveGameState) -> void:
	if action_ids.is_empty():
		push_warning("Reward '%s' has no action_ids set, so it increases nothing." % reward_id)
		return
	var progressed_any_action: bool = false
	for action_id in action_ids:
		var intents: Array[EffectAndTargetIntent] = save_game_state.get_effect_intents_copy_for_progression(action_id)
		var increased_any: bool = false
		for intent in intents:
			var damage_effect: DealDamageEffect = intent.effect_intent as DealDamageEffect
			if damage_effect:
				damage_effect.damage += pleasure_increase
				increased_any = true
		if not increased_any:
			push_warning("Reward '%s' found no pleasure effect to increase on action '%s'." % [reward_id, action_id])
			continue
		save_game_state.set_progressed_effect_intents(action_id, intents, false)
		progressed_any_action = true
	### One announcement for the whole reward, however many actions it upgraded.
	if progressed_any_action:
		save_game_state.announce_player_power_changed("action_progression")

func changes_player_action_progress() -> bool:
	return true

### The listed actions are what this reward upgrades, so the player needs to own them first - unlike
### Reward_UnlockPlayerActions, whose action_ids are what it grants (see RewardDefinition's note).
func get_action_ids_required_by_this_reward() -> Array[String]:
	return action_ids
