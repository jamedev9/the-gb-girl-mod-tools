extends RefCounted
class_name TargetEntity

var game_state: GameState

#region Status methods - overwritten by children
func get_data():
	pass
func get_status_effects() -> Dictionary:
	return {}
func get_passive_effects() -> Array:
	return []
func get_tracker_key() -> String:
	return "player"

### An entity reference (e.g. EffectContext.status_placed_by) can outlive what it points to - an
### opponent that placed a status can be defeated and removed from currently_active_opponents
### long before that status finishes ticking. Default true (the Player is never "removed" this
### way); OpponentEntity overrides this to actually check. Callers that poll a stored entity
### reference and can't tell if it's stale should check this rather than assuming any non-null
### TargetEntity is safe to query.
func is_still_in_encounter() -> bool:
	return true

#endregion


# In TargetEntity:
func get_all_modifier_components() -> Array[StatusModifierComponent]:
	var components: Array[StatusModifierComponent] = []
	
	for passive_id in get_passive_effects():
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if not passive_def:
			continue
		components.append_array(passive_def.get_modifier_components())
	
	for status_effect_id in get_status_effects().keys():
		var status_def: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(status_effect_id)
		if not status_def:
			continue
		components.append_array(status_def.get_modifier_components())
	
	return components
