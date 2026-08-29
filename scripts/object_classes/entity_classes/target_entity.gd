extends Node
class_name TargetEntity

var game_state: GameState

#region Status methods - overwritten by children
func get_data():
	pass
func get_status_effects() -> Dictionary:
	return {}
func get_passive_effects() -> Array:
	return []

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
