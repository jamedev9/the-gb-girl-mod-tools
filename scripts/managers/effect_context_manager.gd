extends GameManager
class_name EffectContextManager

### Handles the effect context pipeline:
#enum ContextPhase {
	#INTENT, #An effect wants to happen
	#MODIFY, # Modifier to to the effect are applied
	#VERIFY, # Check if the modified context is valid
	#RESOLUTION, # Resolve the effects of the context

signal move_player_action(intent_context: EffectContext)
signal deal_damage_to_target(intent_context: EffectContext)
signal apply_statuses_to_target(intent_context: EffectContext)
signal cannot_move_player_action(intent_context: EffectContext,reason: FailureReason)
signal cannot_resolve_event_card(intent_context: EffectContext,reason: FailureReason)
signal resolve_event_card_effects(intent_context: EffectContext)
signal apply_energy_delta(intent_context: EffectContext)
signal resolve_card_flow_effect(intent_context: EffectContext)
signal retract_player_actions(intent_context: EffectContext)
signal resolve_healing_effect(intent_context: EffectContext)
signal remove_statuses_from_target(intent_context: EffectContext)
signal change_opponent_action(intent_context: EffectContext)
signal trigger_player_action(intent_context: EffectContext)
signal restore_orgasms(intent_context: EffectContext)
signal trigger_orgasms(intent_context: EffectContext)
signal change_edging_threshold(intent_context: EffectContext)
signal set_player_pleasure(intent_context: EffectContext)
signal end_player_turn_requested(intent_context: EffectContext)
signal remove_passive_from_target(intent_context: EffectContext)
signal context_requests_spawning_opponent(intent_context: EffectContext)
signal add_passives_to_target(intent_context: EffectContext)
signal triggered_component_triggered(source: TargetEntity,intent_context: EffectContext,trigger_component: StatusTriggeredComponent,effect_def: Resource)
signal request_spawning_multiple_opponents(intent_context: EffectContext)
signal new_opponent_just_spawned(intent_context: EffectContext)
signal request_giving_player_unlock_rewards(intent_context: EffectContext)


enum FailureReason {
	NOT_ENOUGH_ENERGY,
	SINGLE_TARGET_BUT_NOT_DROPPED_ON_OPPONENT,
	NO_OPPONENT_WITH_REQUIRED_ACTION_ACTIVE,
	PLAYER_ACTION_REQUIRED_BY_OPPONENT_ACTION_IS_NOT_IN_ENCOUNTER,
	OPPONENT_IS_IMMUNE_TO_ACTION,
	OPPPONENT_CANT_BE_TARGETED_BY_EVENT_CARDS,
	OPPONENT_IS_NOT_VALID,
	UNIQUE_OPPONENT_ALREADY_PRESENT,
	TARGETING_RULE_BLOCKED,
	ACTION_NOT_AVAILABLE
}

#region Handle Intent:
func handle_intent(
	intent_context: EffectContext,
	is_context_a_trigger: bool = false) -> bool: #Returns true if resolved

	intent_context.context_phase = EffectContext.ContextPhase.MODIFY
	_modify_intent_context_with_passive_and_status_effects(intent_context,is_context_a_trigger)
	
	intent_context.context_phase = EffectContext.ContextPhase.VERIFY
	if not _verify_that_intent_can_resolve(intent_context):
		return false
	
	intent_context.context_phase = EffectContext.ContextPhase.RESOLUTION
	_resolve_intent_context(intent_context)
	
	_handle_observer_triggers(intent_context)
	
	return true ### Return true if the effect/intent was resolved.
#endregion
#region Claude Rewrite 15.07.26: Merging passives and status modifcation and triggers

func _modify_effect_context_based_on_effect(intent_context: EffectContext, effect_def: EffectDefinition) -> void:
	for effect_component in effect_def.get_modifier_components():
		effect_component.modify_context(intent_context)

func _trigger_effects(
	intent_context: EffectContext, 
	effect_def: EffectDefinition, 
	source: TargetEntity,
	is_context_a_trigger: bool) -> void:
	if intent_context is TriggeredEffectContext:
		return ### Made by a bookkeeping intent (give/remove passive, unlock rewards, trigger counter): never sets off reactions

	if is_context_a_trigger:
		#print("_trigger_effects was told that effect %s is triggered - quitting out."%effect_def.get_effect_id())
		return ### Unused: nothing passes true, so reactions DO chain (see _handle_triggering_of_trigger_component())

	for trigger_component in effect_def.get_triggered_components():
		#print("Checking for trigger on component: %s"%trigger_component.trigger_component_id)
		if not trigger_component.should_component_trigger(
			intent_context,main_game.game_state,main_game.meta_game.save_game_state,source):
			#print("Component does not trigger, continuing.")
			continue
		#print("Component DOES trigger!")
		_handle_triggering_of_trigger_component(source,intent_context,trigger_component,effect_def)


### effect_def is the PassiveEffectDefinition/StatusEffectDefinition that OWNS trigger_component -
### threaded through so main_cardgame.gd can stamp the resulting effect context with
### passive_sending_context/status_sending_context (see _on_triggered_component_triggered),
### since _make_effect_intent_context_without_target() otherwise overwrites effect_origin/
### id_of_effect_origin to the triggered EffectIntent's own identity, losing which passive/status
### it came from - see Modifier_MultiplyDamageFromPassives for why that distinction matters.
### A PlayerAction can own a component too (see _trigger_active_player_actions()), hence Resource:
### nothing is stamped for it.
### Emitted ONCE per trigger, not once per effect intent: _on_triggered_component_triggered() already loops
### over all of trigger_component.effect_intents, so emitting per intent resolved every intent N times
### (and recorded the trigger N times) for a component with N intents.
###
### Reactions chain on purpose: the contexts a reaction makes go through the observers again, so e.g. pleasure
### from an opponent's retaliation can set off Zoned Out. What must not happen is a reaction setting itself off
### again from inside its own resolution (an action that triggers itself whenever it is triggered), which would
### loop forever. So the reactions currently being resolved are kept on a stack, keyed by owner + component
### object (trigger_component_id is empty on a lot of content), and a reaction already on it is skipped.
### Resolution is synchronous, so the stack is exactly "the reactions we are currently inside". The size
### limit catches a chain that never repeats the same reaction but still never ends.
var _reactions_being_resolved: Array[String] = []
const MAX_NESTED_REACTIONS: int = 10

func _handle_triggering_of_trigger_component(
	source: TargetEntity,
	intent_context: EffectContext,
	trigger_component: StatusTriggeredComponent,
	effect_def: Resource) -> void:
	var reaction_label: String = "'%s' (owner: %s)" % [trigger_component.trigger_component_id, source.get_tracker_key()]
	var reaction_key: String = "%s:%d" % [source.get_tracker_key(), trigger_component.get_instance_id()]
	if reaction_key in _reactions_being_resolved:
		push_warning("Reaction %s tried to set itself off while it was resolving - skipped." % reaction_label)
		return
	if _reactions_being_resolved.size() >= MAX_NESTED_REACTIONS:
		push_error("More than %d reactions nested inside each other (at %s) - skipped." % [MAX_NESTED_REACTIONS, reaction_label])
		return
	_reactions_being_resolved.append(reaction_key)
	#print("Sending signal to main game to handle component: %s"%trigger_component.trigger_component_id)
	emit_signal("triggered_component_triggered",source,intent_context,trigger_component,effect_def)
	_reactions_being_resolved.pop_back()


func _modify_intent_context_with_passive_and_status_effects(intent_context: EffectContext,is_context_a_trigger: bool) -> void:
	if intent_context.context_phase != EffectContext.ContextPhase.MODIFY:
		push_error("Trying to modify intent that has incorrect phase")
		return

	### For a status's own ticking effect, `source` is set to whoever HAS the status (so the tick
	### can target itself - see TargetingSystem.TargetingMode.SOURCE_OF_EFFECT), which is NOT
	### necessarily who's "giving" the effect. status_placed_by, when present, names whoever
	### actually placed the status - it's their OUTGOING modifiers that should apply here, not the
	### holder's own (see EffectContext.status_placed_by for the bug this fixes). Everything else
	### (immediate card/action effects, passive ticks) has no status_placed_by and falls back to
	### the existing behavior of attributing OUTGOING to `source` itself.
	var outgoing_attribution_source: TargetEntity = intent_context.status_placed_by if intent_context.status_placed_by else intent_context.source
	_modify_context_with_entity_effects(intent_context, outgoing_attribution_source, DamageSystem.DamagePhase.OUTGOING,is_context_a_trigger)

	var target: TargetEntity = intent_context.target
	if target:
		_modify_context_with_entity_effects(intent_context, target, DamageSystem.DamagePhase.INCOMING,is_context_a_trigger)


func _modify_context_with_entity_effects(
	intent_context: EffectContext, entity: TargetEntity, status_damage_phase: DamageSystem.DamagePhase,is_context_a_trigger) -> void:
	var effect_defs: Array[EffectDefinition] = _get_all_effect_definitions_for_entity(entity)
	for effect_def in effect_defs:
		### damage_phase must be set for every effect def, not just Statuses - a Passive's own
		### modifier_components (e.g. Double Pleasure's MultiplyDamage) are just as damage_phase-
		### sensitive as a Status's. Leaving it unset here meant it kept whatever value the
		### previous pass left behind (usually OUTGOING, since every context starts that way),
		### so an "outgoing-only" passive matched during the INCOMING pass too - see
		### Passive_DoublePleasure.tres, which doubled Pleasure both given and received.
		if effect_def.get_script() != StatusEffectDefinition and effect_def.get_script() != PassiveEffectDefinition:
			push_error("Unknown effect definition type: %s" % effect_def)
		intent_context.damage_phase = status_damage_phase
		intent_context.modifier_effect_stacks = _get_stacks_of_effect_on_entity(entity, effect_def)

		_modify_effect_context_based_on_effect(intent_context, effect_def)
		#_trigger_effects(intent_context, effect_def, entity,is_context_a_trigger)
	intent_context.modifier_effect_stacks = 1 ### Scratch value: only meaningful while a status's own modifiers run.

### Passives don't stack, so they always count as 1.
func _get_stacks_of_effect_on_entity(entity: TargetEntity, effect_def: EffectDefinition) -> int:
	if effect_def is StatusEffectDefinition:
		return maxi(entity.get_status_stacks(effect_def.status_id), 1)
	return 1

func _get_all_effect_definitions_for_entity(entity: TargetEntity) -> Array[EffectDefinition]:
	if not entity:
		return []
	var effect_defs: Array[EffectDefinition] = []
	for passive_id in entity.get_passive_effects():
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if passive_def == null: ### Not in the game (e.g. a disabled mod's passive); the id stays on the entity.
			continue
		effect_defs.append(passive_def)
	for status_id in entity.get_status_effects().keys():
		effect_defs.append(AutoloadDatabase.status_effects_by_id[status_id])
	return effect_defs

func _handle_observer_triggers(reactive_context: EffectContext) -> void:
	### Pass the intent context through the triggered effects on player and opponents.
	#print("Checking reactive triggers")
	if reactive_context is TriggeredEffectContext:
		return ### Made by a bookkeeping intent (give/remove passive, unlock rewards, trigger counter): never sets off reactions
	var targets_to_check: Array[TargetEntity] = []
	targets_to_check.append(PlayerEntity.new(main_game.game_state))
	for opponent_id in main_game.game_state.get_currently_active_opponents():
		var opponent_entity: OpponentEntity = OpponentEntity.new(main_game.game_state,opponent_id)
		targets_to_check.append(opponent_entity)
	
	for entity in targets_to_check:
		var effect_defs: Array[EffectDefinition] = _get_all_effect_definitions_for_entity(entity)
		for effect_def in effect_defs:
			_trigger_effects(reactive_context,effect_def,entity,false)

	_trigger_active_player_actions(reactive_context)

### Player Actions react like passives/statuses do (their triggered_components), but only while they are
### active, i.e. assigned to an opponent. The owner of the trigger is the player: it is the player's
### Action, and ApplyEffectOfPlayerAction (how an action triggers itself) puts the player as source anyway.
func _trigger_active_player_actions(reactive_context: EffectContext) -> void:
	var game_state: GameState = main_game.game_state
	if game_state.actions_assigned_to_opponents.is_empty():
		return
	var save_game_state: SaveGameState = main_game.meta_game.save_game_state
	var player_entity: PlayerEntity = PlayerEntity.new(game_state)
	### keys() is a copy: a reaction can defeat an opponent and clear its action while this loop runs.
	for action_id in game_state.actions_assigned_to_opponents.keys():
		### The save's version of the action, like MainCardgame._resolve_effects_of_player_action().
		var action: PlayerAction = save_game_state.get_effective_player_action(action_id) if save_game_state \
			else AutoloadDatabase.get_player_action_by_id(action_id)
		if not action:
			continue
		for trigger_component in action.triggered_components:
			if game_state.get_opponent_with_action(action_id) == "":
				break ### An earlier reaction cleared this action.
			if not trigger_component.should_component_trigger(reactive_context,game_state,save_game_state,player_entity):
				continue
			_handle_triggering_of_trigger_component(player_entity,reactive_context,trigger_component,action)


#endregion

#region Verification:
func _verify_that_intent_can_resolve(intent_context:EffectContext) -> bool:
	if intent_context.effect_origin is ApplyEffectOfPlayerAction:
		if not intent_context.target:
			return false
			
	if not intent_context.statuses_to_apply.is_empty():
		if intent_context.target_is_immune_to_status_effects:
			return false
	if intent_context.spawn_opponent:
		if intent_context.spawned_opponent_is_unique:
			if intent_context.spawn_opponent_type in main_game.game_state.get_count_of_active_opponent_types().keys():
				return false


	if intent_context.moving_player_action:
		if not main_game.game_state.is_action_available(intent_context.player_action_id):
			emit_signal("cannot_move_player_action",intent_context,FailureReason.ACTION_NOT_AVAILABLE)
			return false
		if not main_game.player_stat_manager.player_can_pay_energy_cost(PlayerEntity.new(intent_context.game_state),-intent_context.energy_delta):
			emit_signal("cannot_move_player_action",intent_context,FailureReason.NOT_ENOUGH_ENERGY)
			return false
		if intent_context.target_is_immune_to_action:
			emit_signal("cannot_move_player_action",intent_context,FailureReason.OPPONENT_IS_IMMUNE_TO_ACTION)
			return false
		if not intent_context.target:
			emit_signal("cannot_move_player_action",intent_context,FailureReason.OPPONENT_IS_NOT_VALID)
			return false
		if intent_context.target is not OpponentEntity:
			emit_signal("cannot_move_player_action",intent_context,FailureReason.OPPONENT_IS_NOT_VALID)
			return false
		var opponent_instance: OpponentInstance = main_game.game_state.get_opponent_instance(intent_context.target.opponent_id)
		if not opponent_instance:
			emit_signal("cannot_move_player_action",intent_context,FailureReason.OPPONENT_IS_NOT_VALID)
			return false
			
	if not required_player_action_is_in_encounter(intent_context):
		return false
		
	if intent_context.played_event_card:
		#if not main_game.player_stat_manager.player_can_pay_energy_cost(PlayerEntity.new(intent_context.game_state),-intent_context.energy_delta):
		if not main_game.player_stat_manager.player_can_pay_energy_cost(PlayerEntity.new(
			intent_context.game_state),-intent_context.energy_delta):
			emit_signal("cannot_resolve_event_card",intent_context,FailureReason.NOT_ENOUGH_ENERGY)
			return false
		if intent_context.target_is_immune_to_event_card_targeting:
			emit_signal("cannot_resolve_event_card",intent_context,FailureReason.OPPPONENT_CANT_BE_TARGETED_BY_EVENT_CARDS)
			return false
		### This if-statement should fire and stop targeting. 
		if intent_context.event_card_instance.card_requires_targeted_opponent():
			if intent_context.dropped_on_opponent not in intent_context.game_state.currently_active_opponents:
				emit_signal("cannot_resolve_event_card",intent_context,FailureReason.SINGLE_TARGET_BUT_NOT_DROPPED_ON_OPPONENT)
				return false
		if intent_context.event_card_instance.card_targets_opponent_with_action():
			var opponents_with_required_actions: Array[String] = intent_context.event_card_instance.get_opponents_with_one_of_required_actions(main_game.game_state)
			if opponents_with_required_actions.is_empty():
				emit_signal("cannot_resolve_event_card",intent_context,FailureReason.NO_OPPONENT_WITH_REQUIRED_ACTION_ACTIVE)
				return false
		var card_id: String = intent_context.event_card_causing_effect.card_id
		var event_card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
		if event_card_def.are_all_relevant_player_actions_disabled(intent_context.game_state):
			return false

		var required_player_actions: Array[String] = get_player_actions_required_for_opponent_action(intent_context)
		var missing_player_actions: Array[String] = [] 
		if not required_player_actions.is_empty():
			for player_action_id in required_player_actions:
				if player_action_id not in main_game.game_state.get_player_actions_in_encounter():
					missing_player_actions.append(player_action_id)
			if not missing_player_actions.is_empty():
				intent_context.failed_to_resolve_info["missing_player_actions"] = missing_player_actions
				emit_signal("cannot_resolve_event_card",intent_context,FailureReason.PLAYER_ACTION_REQUIRED_BY_OPPONENT_ACTION_IS_NOT_IN_ENCOUNTER)
				return false
		
		### Running checks based on the effect intents in the event card definition:
		for effect_and_intent in event_card_def.effect_intents:
			if effect_and_intent.effect_intent is Intent_SummonOpponent:
				if effect_and_intent.effect_intent.opponent_is_unique:
					if effect_and_intent.effect_intent.opponent_type_id in main_game.game_state.get_count_of_active_opponent_types().keys():
						emit_signal("cannot_resolve_event_card",intent_context,FailureReason.UNIQUE_OPPONENT_ALREADY_PRESENT)
						return false
			if effect_and_intent.targeting_intent == TargetingSystem.TargetingMode.SINGLE_OPPONENT:
				for rule in effect_and_intent.targeting_rules:
					if rule is TargetCannotHaveTheseActionsAssigned:
						if not rule.is_target_valid(main_game.game_state,intent_context.target.opponent_id):
							emit_signal("cannot_resolve_event_card",intent_context,FailureReason.TARGETING_RULE_BLOCKED)
							return false

	#print("Returning that intent %s can resolve"%intent_context.id_of_effect_origin)
	return true

func get_player_actions_required_for_opponent_action(intent_context: EffectContext) -> Array[String]:
	var effect_intents: Array[EffectAndTargetIntent] = intent_context.event_card_instance.get_effect_intents()
	var player_actions_required: Array[String] = []
	for intent in effect_intents:
		if intent.effect_intent is Intent_ChangeOpponentAction:
			var opponent_action_id: String = intent.effect_intent.opponent_action_id
			var opponent_action: OpponentActionDefinition = AutoloadDatabase.get_opponent_action_by_id(opponent_action_id)
			player_actions_required.append_array(opponent_action.get_player_actions_grabbed())
	return player_actions_required

func required_player_action_is_in_encounter(intent_context: EffectContext) -> bool:
	if intent_context.change_opponent_action_to:
		var opponent_action: OpponentActionDefinition = AutoloadDatabase.get_opponent_action_by_id(
			intent_context.change_opponent_action_to)
		if player_actions_required_by_opponent_action_is_not_in_enconter(opponent_action):
			return false
	return true

func player_actions_required_by_opponent_action_is_not_in_enconter(opponent_action: OpponentActionDefinition) -> bool:
	var player_actions_required: Array[String] = opponent_action.get_player_actions_grabbed()
	for player_action_id in player_actions_required:
		if player_action_id not in main_game.game_state.get_player_actions_in_encounter():
			return true ### Fails because action is not in encounter.
	return false

#region Resolution:
func _resolve_intent_context(intent_context:EffectContext) -> void:
	if intent_context.context_phase != EffectContext.ContextPhase.RESOLUTION:
		return
	if intent_context.effect_origin is ApplyEffectOfPlayerAction:
		emit_signal("trigger_player_action",intent_context)
		return ### This return is needed to prevent double triggering of cards that trigger actions
	if intent_context.added_pleasure_to_new_opponents:
		### This is handled in the Opponent Manager
		return
	if intent_context.played_event_card:
		emit_signal("resolve_event_card_effects",intent_context)
	if intent_context.moving_player_action:
		emit_signal("move_player_action",intent_context)
	if intent_context.energy_reason:
		emit_signal("apply_energy_delta",intent_context)
	if intent_context.retract_actions:
		#print("Emitting signal to retract player action")
		emit_signal("retract_player_actions",intent_context)
	if intent_context.damage_amount and intent_context.target:
		emit_signal("deal_damage_to_target",intent_context)
	if not intent_context.statuses_to_apply.is_empty() and intent_context.target:
		emit_signal("apply_statuses_to_target",intent_context)
	if not intent_context.statuses_to_clear.is_empty() and intent_context.target:
		emit_signal("remove_statuses_from_target",intent_context)
	if intent_context.card_flow_effect == true:
		emit_signal("resolve_card_flow_effect",intent_context)
	if intent_context.healing_amount:
		emit_signal("resolve_healing_effect",intent_context)
	if intent_context.change_opponent_action_to:
		emit_signal("change_opponent_action",intent_context)
	if intent_context.restore_orgasms:
		emit_signal("restore_orgasms",intent_context)
	if intent_context.orgasms_to_trigger:
		emit_signal("trigger_orgasms",intent_context)
	if not is_zero_approx(intent_context.edging_threshold_change):
		emit_signal("change_edging_threshold",intent_context)
	if intent_context.set_player_pleasure_to >= 0:
		emit_signal("set_player_pleasure",intent_context)
	if intent_context.end_player_turn:
		emit_signal("end_player_turn_requested",intent_context)
	if intent_context.passive_to_remove_from_target:
		#print("Sending intent to remove passive from target")
		emit_signal("remove_passive_from_target",intent_context)
	if intent_context.spawn_opponent:
		emit_signal("context_requests_spawning_opponent",intent_context)
	if not intent_context.passives_to_add_to_target.is_empty():
		print("Effect context manager sending request to add passives")
		emit_signal("add_passives_to_target",intent_context)
	if intent_context.new_opponent_spawned:
		emit_signal("new_opponent_just_spawned",intent_context)
	if intent_context.spawn_multiple_opponents:
		emit_signal("request_spawning_multiple_opponents",intent_context)
	#if intent_context.player_orgasmed:
		##print("Player orgasmed context has resolved properly.")
		#pass
		##emit_signal("")
	if intent_context.unlock_rewards_to_give_player:
		emit_signal("request_giving_player_unlock_rewards",intent_context)
	
#region Reactions:
