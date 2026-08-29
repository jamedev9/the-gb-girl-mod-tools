extends GameSystem
class_name StatusSystem

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"


#region Energy affecting statuses:

func _change_energy_cost_from_player_statuses(effect_context: EffectContext) -> void:
	for status_id in effect_context.source.get_status_effects().keys():
		var status_def: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[status_id]
		for effect_component in status_def.status_effect_components:
			### modify_context needs to know which varibles it is allowed to change - potential for error
			effect_component.modify_context(effect_context)
	

func _change_energy_cost_from_opponent_statuses(effect_context: EffectContext) -> void:
	for status_id in effect_context.targets[0].get_status_effects().keys():
		var status_def: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[status_id]
		for effect_component in status_def.status_effect_components:
			effect_component.modify_context(effect_context)


#endregion
