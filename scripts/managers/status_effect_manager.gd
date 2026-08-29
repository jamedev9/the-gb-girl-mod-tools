extends GameManager
class_name StatusEffectManager

#signal status_effect_sends_effect_context(effect_context: EffectContext)
signal status_effect_sends_effect_and_target_intent(base_context: EffectContext, effect_and_target_intent)
signal passive_effect_sends_effect_and_target_intent(base_context: EffectContext, effect_and_target_intent)

func _progress_status_effects_on_target_entity_(game_state: GameState,target_entity:TargetEntity) -> void:
	var status_effects_on_target = target_entity.get_status_effects()
	var status_effect_ids: Array = status_effects_on_target.keys()
	for effect_id in status_effect_ids:
		var status_instance: Dictionary = status_effects_on_target[effect_id]
		_send_requests_for_ticking_status_effects(game_state,target_entity,effect_id,status_instance)
		_tick_down_duration_of_status(status_instance)
		_remove_instance_if_duration_is_zero(target_entity,effect_id)

### TODO: The two methods below should really be merged, as they do the same thing for statuses and passives.
func _send_requests_for_ticking_status_effects(game_state: GameState, target_entity: TargetEntity, effect_id: String, _status_instance: Dictionary) -> void:
	var status_def: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[effect_id]
	for component in status_def.ticking_effect_components:
		for effect_and_target_intent in component.effect_intents:
			var base_context: EffectContext = EffectContext.new()
			base_context.source = target_entity
			base_context.id_of_effect_origin = status_def.status_id
			base_context.effect_origin = status_def
			base_context.game_state = game_state
			base_context.context_phase = EffectContext.ContextPhase.INTENT
			base_context.status_sending_context = status_def
			emit_signal("status_effect_sends_effect_and_target_intent", base_context, effect_and_target_intent)

func _send_requests_for_ticking_passive_effects(game_state: GameState, target_entity: TargetEntity, effect_id: String) -> void:
	var passive_def: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions[effect_id]
	for component in passive_def.ticking_effect_components:
		for effect_and_target_intent in component.effect_intents:
			var base_context: EffectContext = EffectContext.new()
			base_context.source = target_entity
			base_context.id_of_effect_origin = passive_def.passive_id
			base_context.effect_origin = passive_def
			base_context.game_state = game_state
			base_context.context_phase = EffectContext.ContextPhase.INTENT
			base_context.passive_sending_context = passive_def
			emit_signal("passive_effect_sends_effect_and_target_intent", base_context, effect_and_target_intent)

func _tick_down_duration_of_status(status_instance: Dictionary)->void:
	status_instance["duration"] -= 1

func _remove_instance_if_duration_is_zero(target_entity: TargetEntity,effect_id: String) -> void:
	var status_effects_on_target: Dictionary = target_entity.get_status_effects()
	var status_instance: Dictionary = status_effects_on_target[effect_id]
	if status_instance["duration"] <= 0:
		status_effects_on_target.erase(effect_id)

static func get_energy_reduction_from_statuses(game_state: GameState) -> int:
	var reduction: int = 0
	var player_entity: PlayerEntity = PlayerEntity.new(game_state)
	var status_effects_on_target: Dictionary = player_entity.get_status_effects()
	var status_effect_ids: Array = status_effects_on_target.keys()
	for effect_id in status_effect_ids:
		var status_def: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[effect_id]
		for effect_component in status_def.status_effect_components:
			if effect_component is Status_ReducePlayerEnergy:
				reduction += effect_component.energy_reduction
	return reduction
