extends GameSystem
class_name StatusSystem

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

#region Damage affecting statuses:

static func get_outgoing_damage_multiplier(context: EffectContext) -> float:
	if context.damage_phase != DamageSystem.DamagePhase.OUTGOING:
		return 1.0
	if not context.damage_amount:
		return 1.0
	if context.source.get_status_effects().size() == 0:
		return 1.0
	var multiplier: float = 1.0
	var modified_context: EffectContext = EffectContext.new()
	modified_context.source = context.source
	modified_context.damage_amount = context.damage_amount
	modified_context.damage_phase = context.damage_phase
	for status_id in context.source.get_status_effects().keys():
		var status_def: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[status_id]
		for effect_component in status_def.status_effect_components:
			effect_component.modify_context(modified_context)
	multiplier = float(modified_context.damage_amount)/float(context.damage_amount)
	return multiplier

static func get_outgoing_healing_multiplier(_context: EffectContext) -> float:
	#TODO
	return 1.0
	
static func get_incoming_healing_multiplier(_context: EffectContext,_target_entity: TargetEntity) -> float:
	#TODO
	return 1.0

static func get_incoming_damage_multiplier(context: EffectContext, target: TargetEntity) -> float:
	if not target:
		return 1.0
	if context.damage_phase != DamageSystem.DamagePhase.INCOMING:
		return 1.0
	if not context.damage_amount:
		return 1.0
	if target.get_status_effects().size() == 0:
		return 1.0
	var multiplier: float = 1.0
	var modified_context: EffectContext = EffectContext.new()
	modified_context.damage_amount = context.damage_amount
	modified_context.damage_phase = context.damage_phase
	modified_context.source = context.source
	modified_context.game_state = context.game_state
	for status_id in target.get_status_effects().keys():
		var status_def: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[status_id]
		for effect_component in status_def.status_effect_components:
			effect_component.modify_context(modified_context)
	multiplier = float(modified_context.damage_amount)/float(context.damage_amount)
	return multiplier

#endregion

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
