@tool
extends RefCounted
class_name ModdableResourceRegistry

### Explicit registration table for every class ModExportable's generic to_json_dict()/
### populate_from_json_dict() (see mod_exportable.gd) can polymorphically reconstruct from a
### "_class"-tagged JSON dict - the EffectAndTargetIntent/EffectIntent/TargetingRule object graph,
### plus StatusModifierComponent/StatusTickComponent/TriggerCondition (nested inside
### PassiveEffectDefinition, which has its own hand-written to_json_dict()/from_json_dict() - see
### passive_effect_definition.gd - since its picture: Texture2D field needs file-reference
### handling the generic serializer can't do). Deliberately a hand-maintained list, not a runtime
### directory scan - see
### CLAUDE.md's "Directory scanning breaks in exported builds" note, and it mirrors how
### AutoloadDatabase._register_resource_types() and ModConfig.export_configs already register
### their own known types the same way.
###
### Add a new EffectIntent/TargetingRule subclass here when it's created - nothing else needs to
### change, the generic serializer picks it up automatically as long as its fields are plain
### data or other ModExportable-derived Resources.
const _REGISTERED_SCRIPTS: Array[Script] = [
	# effect_and_target_intention
	preload("res://scripts/object_classes/effect_and_target_intention/effect_and_target_intent.gd"),
	# event_cards/intent_effects
	preload("res://scripts/object_classes/event_cards/intent_effects/apply_effect_of_player_action.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/apply_energy_delta.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/apply_status_effect.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/card_flow_effect.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/clear_debuffs_from_targets.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/clear_statuses_from_targets.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/deal_damage_based_on_card_play_count.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/deal_damage_based_on_energy.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/deal_damage_based_on_orgasms.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/deal_damage_effect.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/deal_damage_if_source_has_player_action.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/drain_energy.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/draw_cards_based_on_orgasms.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/heal_for_value.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_add_cards_from_list_of_cards_to_hand.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_capture_player_action.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_change_opponent_action.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_draw_cards_based_on_damage_dealt.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_give_passives_to_player.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_give_player_unlock_rewards.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_pleasure_based_on_times_cards_are_played.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_refill_room_with_opponent_types.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_remove_passive_from_player.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_restore_orgasms.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_retract_action_from_target.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_retract_player_actions.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_summon_opponent_type.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_track_number_of_times_triggered.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/intent_trigger_n_orgasm.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/randomly_heal_or_deal_damage.gd"),
	preload("res://scripts/object_classes/event_cards/intent_effects/restore_energy_based_on_orgasms.gd"),
	# event_cards/targeting_rules
	preload("res://scripts/object_classes/event_cards/targeting_rules/opponent_cant_target_self.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/opponent_of_different_type.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/opponent_targets_self.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/opponent_with_most_health_remaining.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/target_cannot_have_these_actions_assigned.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/target_cant_be_ally.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/target_most_recently_entered_opponent.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/target_must_be_different_opponent_type.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/target_must_be_specific_opponent_type.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/target_only_one_opponent.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/target_specific_opponent_id.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/targets_have_less_than_n_health_left.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/targets_have_one_of_several_actions_assigned.gd"),
	preload("res://scripts/object_classes/event_cards/targeting_rules/targets_opponents_with_passive.gd"),
	# event_cards (composition helper, not itself an EffectIntent/TargetingRule)
	preload("res://scripts/object_classes/event_cards/cards_to_add_intent.gd"),
	# status_effects/status_modifier_components
	preload("res://scripts/object_classes/status_effects/status_modifier_components/ChangeMoveCost.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/change_move_cost_of_certain_actions.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/MultiplyDamage.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_multiply_damage_if_under_player_actions.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_draw_cards_from_damage.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_flat_delta_to_player_action_damage.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_multiply_damage_from_all_except_given_ids.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_multiply_damage_from_passives.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_multiply_event_card_damage.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_multiply_player_action_damage.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_prevent_applying_statuses.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_prevent_applying_statuses_from_event_cards.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_prevent_applying_statuses_to_specific_opponent_types.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/modifier_prevent_targeting_by_event_cards.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/prevent_moving_actions_to_target.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/reduce_player_energy.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/status_disable_player_actions.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/statusmod_change_cost_of_cards_using_actions.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/statusmod_change_cost_of_playing_event_cards.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/statusmod_change_cost_of_playing_event_cards_per_play.gd"),
	preload("res://scripts/object_classes/status_effects/status_modifier_components/statusmod_multiply_healing.gd"),
	# status_effects/status_tick_component
	preload("res://scripts/object_classes/status_effects/status_tick_component/damage_over_time/DamageOverTime.gd"),
	preload("res://scripts/object_classes/status_effects/status_tick_component/discard_n_cards_on_end_turn.gd"),
	preload("res://scripts/object_classes/status_effects/status_tick_component/ticking_heal_over_time.gd"),
	preload("res://scripts/object_classes/status_effects/status_tick_component/ticking_heal_target_each_turn.gd"),
	preload("res://scripts/object_classes/status_effects/status_tick_component/ticking_if_guy_with_passive_has_been_defeated.gd"),
	preload("res://scripts/object_classes/status_effects/status_tick_component/ticking_if_no_other_opp_has_passive.gd"),
	# status_effects/status_triggered_components - no concrete subclasses exist yet, so the base
	# class itself is what modders instantiate directly; it must be registered too or its "_class"
	# tag can never resolve on import.
	preload("res://scripts/object_classes/status_effects/status_triggered_components/status_triggered_component.gd"),
	# trigger_conditions
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_event_card_played.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_event_card_played_every_n_times.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_event_card_played_n_times.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_multiple_defeat_in_one_turn.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_nr_of_logged_triggers_exceeded.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_opponent_defeat.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_opponent_defeated_by_player_action.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_opponent_enters.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_player_actions_started.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_player_actions_triggered.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_player_gaining_pleasure.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_player_orgasm.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_source_dealing_pleasure.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_source_taking_n_damage_on_one_turn.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_on_specific_opponent_criteria_defeat.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_only_if_player_does_not_have_effects.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_only_if_player_has_effects.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_only_if_source_has_one_of_listed_player_action.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_only_if_target_has_one_of_listed_player_action.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_only_on_players_turn.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_owner_of_trigger_is_targeted.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_random_chance.gd"),
	preload("res://scripts/object_classes/trigger_conditions/trigger_retaliate_player_action.gd"),
]

static var _by_class_name: Dictionary = {}

static func _ensure_built() -> void:
	if not _by_class_name.is_empty():
		return
	for script in _REGISTERED_SCRIPTS:
		var global_name: String = script.get_global_name()
		if global_name == "":
			push_error("ModdableResourceRegistry: registered script has no class_name: %s" % script.resource_path)
			continue
		_by_class_name[global_name] = script

## Reconstructs a ModExportable instance from a "_class"-tagged dict produced by
## ModExportable.to_json_dict(). Returns null (and logs an error) if the tag is missing or
## unregistered - callers should treat that as a corrupt/unsupported payload, not silently drop
## the field, since a missing intent/rule silently changes what an action/card/status actually
## does.
static func instantiate(data: Dictionary) -> ModExportable:
	_ensure_built()
	var class_name_str: String = data.get("_class", "")
	if class_name_str == "":
		push_error("ModdableResourceRegistry: payload has no '_class' key: %s" % str(data))
		return null
	var script: Script = _by_class_name.get(class_name_str)
	if script == null:
		push_error("ModdableResourceRegistry: no registered class for '%s' - was it added to _REGISTERED_SCRIPTS?" % class_name_str)
		return null
	var instance: ModExportable = script.new()
	instance.populate_from_json_dict(data)
	return instance
