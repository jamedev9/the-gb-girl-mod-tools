extends Resource
class_name GameState

### First draft: Dictionaries represent stuff to be replaced with classes later.

var player_has_won: bool = false
var player_has_lost: bool = false
var game_ended_succesfully: bool = false
var player_quit_the_game: bool = false
func game_is_over() -> bool:
	return player_has_won or player_has_lost
func set_victory_state_to_loss() -> void:
	player_has_lost = true
	player_has_won = false

var player_input_enabled: bool = false	
func player_can_input() -> bool:
	return player_input_enabled and it_is_players_turn() and not game_is_over()

var player: Dictionary = {
	"hp": 0,
	"damage_threshold": 100,
	"edging_threshold": EdgingRules.DEFAULT_THRESHOLD,
	"current_damage": 0,
	"max_energy":10,
	"current_energy": 0,
	"energy_next_round": 0,
	"energy_spent_this_round": 0,
	"status_effects": {}
}
func get_player_stats() -> Dictionary:
	return player

func add_player_stats(save_game_state: SaveGameState) -> void:
	self.player = save_game_state.player.duplicate(true)
	self.player["current_damage"] = 0
	self.player["current_energy"] =  save_game_state.player["max_energy"]
	self.player["energy_next_round"] = save_game_state.player["max_energy"]
	self.player["energy_spent_this_round"] = 0
	self.player["status_effects"] = {}
	self.player["passive_effects"] = save_game_state.get_active_player_passives()

#region Edging
### The player's BASE edging threshold for THIS encounter, as a share of max pleasure (0..1, see EdgingRules): the save's value,
### moved by effects that edit it for the rest of the encounter (ChangeEdgingThreshold, the debug keys). It leaves out what statuses
### and passives add on top, see get_edging_threshold(). add_player_stats() gives the encounter its own copy of the save's value,
### so changing it here never reaches the save.
func get_base_edging_threshold() -> float:
	return EdgingRules.clamp_threshold(float(player.get("edging_threshold", EdgingRules.DEFAULT_THRESHOLD)))

func set_edging_threshold(new_threshold: float) -> void:
	player["edging_threshold"] = EdgingRules.clamp_threshold(new_threshold)

### The threshold the player is held to right now: the base plus what the player's statuses and passives change
### (Status_ChangeEdgingThreshold, per stack), kept between 0% and 100%. Everything that asks "is the player on the edge" reads this.
func get_edging_threshold() -> float:
	return EdgingRules.clamp_threshold(get_base_edging_threshold() + get_edging_threshold_change_from_effects())

### The sum of every Status_ChangeEdgingThreshold the player's statuses (times their stacks) and passives have, as a share of max pleasure.
func get_edging_threshold_change_from_effects() -> float:
	var total_change: float = 0.0
	var player_statuses: Dictionary = get_player_statuses()
	for status_id in player_statuses.keys():
		var status_def: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(status_id)
		if status_def == null:
			continue
		var stacks: int = int(player_statuses[status_id].get("stacks", 1))
		total_change += _get_edging_threshold_change_of_components(status_def.status_effect_components, stacks)
	for passive_id in get_active_player_passives():
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if passive_def:
			total_change += _get_edging_threshold_change_of_components(passive_def.modifier_components, 1)
	return total_change

func _get_edging_threshold_change_of_components(components: Array, stacks: int) -> float:
	var change: float = 0.0
	for component in components:
		if component is Status_ChangeEdgingThreshold:
			var threshold_component: Status_ChangeEdgingThreshold = component
			change += threshold_component.get_threshold_change(stacks)
	return change

### The lowest whole Pleasure that counts as at or above the threshold right now: the threshold applied to this
### encounter's max pleasure.
func get_edging_threshold_pleasure() -> int:
	return EdgingRules.get_threshold_pleasure(int(player.get("damage_threshold", 100)), get_edging_threshold())
#endregion

func get_active_player_passives() -> Array:
	if "passive_effects" in player.keys():
		return player["passive_effects"]
	return []
func get_player_statuses() -> Dictionary:
	if "status_effects" in player.keys():
		return player["status_effects"]
	return {}

func give_player_passive(passive_id: String) -> void:
	if passive_id not in self.player["passive_effects"]:
		self.player["passive_effects"].append(passive_id)

### Gives the player passives that only last for this encounter (EncounterDefinition.temporary_player_passives).
### add_player_stats() hands this game state the save's own passive list, not a copy - the list is copied
### here first, so these passives can never be written into the save.
func add_temporary_player_passives(passive_ids: Array[String]) -> void:
	if passive_ids.is_empty():
		return
	player["passive_effects"] = get_active_player_passives().duplicate()
	for passive_id in passive_ids:
		if passive_id not in AutoloadDatabase.passive_effect_definitions.keys():
			push_warning("Encounter wants to give the player the temporary passive '%s', which does not exist." % passive_id)
			continue
		give_player_passive(passive_id)

func remove_passive_from_player(passive_id: String) -> void:
	if "passive_effects" in player.keys():
		player["passive_effects"].erase(passive_id)

#func give_player_passivegive_player_passive(passive_id: String) -> void:
	#if "passive_effects" not in player.keys():
		#return
	#var player_passives = player["passive_effects"]
	#if passive_id not in player_passives:
		#player["passive_effects"].append(passive_id)

func get_energy_cost_of_playing_event_card(intent_context: EffectContext) -> int:
	var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(intent_context.event_card_instance.card_id)
	#var base_energy_cost: int = card_def.energy_cost
	#var energy_cost_mod_from_player_effects: int = card_def.get_event_card_energy_mod_from_player_effects(self)
	return card_def.get_energy_cost_of_playing_card(self,intent_context.event_card_instance.card_id)
	
#region Variable Tracking during encounters:
### String: Unique ID of tracker. Dictionary: Optional variables
var encounter_trigger_tracker: Dictionary[String,Dictionary] = {}

func add_to_turn_tracked_value(tracker_id: String, entity: TargetEntity, amount: int) -> void:
	var key: String = "%s:%s" % [tracker_id, entity.get_tracker_key()]
	if key not in encounter_trigger_tracker.keys() or encounter_trigger_tracker[key]["turn"] != current_round:
		encounter_trigger_tracker[key] = {"turn": current_round, "value": amount}
	else:
		encounter_trigger_tracker[key]["value"] += amount

func get_turn_tracked_value(tracker_id: String, entity: TargetEntity) -> int:
	var key: String = "%s:%s" % [tracker_id, entity.get_tracker_key()]
	if key not in encounter_trigger_tracker.keys():
		return 0
	if encounter_trigger_tracker[key]["turn"] != current_round:
		return 0
	return encounter_trigger_tracker[key]["value"]

#endregion

#region Player actions
func add_available_player_actions(save_game_state: SaveGameState) -> void:
	actions_available_in_encounter = save_game_state.currently_used_player_actions
func get_player_actions_in_encounter() -> Array:
	return actions_available_in_encounter
var actions_available_in_encounter: Array
var actions_assigned_to_opponents: Dictionary[String,String] #Action ID, Opponent ID
func get_opponent_with_action(action_id:String) -> String:
	if action_id not in actions_assigned_to_opponents.keys():
		return ""
	return actions_assigned_to_opponents[action_id]
func get_action_assigned_to_opponent(opponent_id: String) -> String:
	for action_id in actions_assigned_to_opponents.keys():
		if actions_assigned_to_opponents[action_id] == opponent_id:
			return action_id
	return ""

func get_disabled_player_actions() -> Array[String]:
	var currently_disabled_actions: Array[String]
	for status_id in get_player_statuses().keys():
		var status_def: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(status_id)
		if not status_def:
			continue
		for effect in status_def.status_effect_components:
			if effect is Status_DisablePlayerActions:
				for action in effect.get_disabled_action_ids():
					if action in currently_disabled_actions:
						continue
					currently_disabled_actions.append(action)

	for passive_id in get_active_player_passives():
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if not passive_def:
			continue
		for modifier in passive_def.modifier_components:
			if modifier is Status_DisablePlayerActions:
				for action in modifier.get_disabled_action_ids():
					if action in currently_disabled_actions:
						continue
					currently_disabled_actions.append(action)
	
	return currently_disabled_actions

func is_action_available(action_id: String) -> bool:
	if action_id not in get_player_actions_in_encounter():
		return false
	if action_id in get_disabled_player_actions():
		return false
	return true

#region Player blindness
### Whether the player can't currently see the given kind of information about the opponents (shown to
### the player as "partners") - true when any status or passive of the player has a Status_BlindPlayer
### component that hides it. The opponent displays ask this one question; to blind the player from other
### code, give them a status or passive with such a component (see Status_BlindPlayer).
func is_opponent_info_hidden(info: Status_BlindPlayer.HiddenInfo) -> bool:
	for component in _get_player_blind_components():
		if component.hides(info):
			return true
	return false

### Whether the encounter background should be dimmed because of a blinding status or passive.
func is_player_background_dimmed() -> bool:
	for component in _get_player_blind_components():
		if component.dim_background:
			return true
	return false

func _get_player_blind_components() -> Array[Status_BlindPlayer]:
	var blind_components: Array[Status_BlindPlayer] = []
	for status_id in get_player_statuses().keys():
		var status_def: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(status_id)
		if not status_def:
			continue
		_add_blind_components(status_def.status_effect_components, blind_components)
	for passive_id in get_active_player_passives():
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if not passive_def:
			continue
		_add_blind_components(passive_def.modifier_components, blind_components)
	return blind_components

func _add_blind_components(components: Array, blind_components: Array[Status_BlindPlayer]) -> void:
	for component in components:
		if component is Status_BlindPlayer:
			blind_components.append(component)
#endregion

#region Preventing orgasms
### Whether any status or passive of the player has a Status_PreventPlayerOrgasm component. While it does, Pleasure past the max
### builds up instead of making the player orgasm (MainCardgame._handle_signal_of_damage_exceeding_threshold()), and an effect that
### forces an orgasm does nothing. To stop the player's orgasms from other code, give them a status or passive with such a component.
func player_cannot_orgasm() -> bool:
	return not get_orgasm_preventing_status_ids().is_empty() or _player_passives_prevent_orgasm()

### The ids of the player's statuses that prevent orgasms (a passive has no status icon, so it is not listed): the icons to flash
### when an orgasm is blocked.
func get_orgasm_preventing_status_ids() -> Array:
	var status_ids: Array = []
	for status_id in get_player_statuses().keys():
		var status_def: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(status_id)
		if status_def and _has_prevent_orgasm_component(status_def.status_effect_components):
			status_ids.append(status_id)
	return status_ids

func _player_passives_prevent_orgasm() -> bool:
	for passive_id in get_active_player_passives():
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if passive_def and _has_prevent_orgasm_component(passive_def.modifier_components):
			return true
	return false

func _has_prevent_orgasm_component(components: Array) -> bool:
	for component in components:
		if component is Status_PreventPlayerOrgasm:
			return true
	return false
#endregion

var reward_cards_from_actions: Dictionary = {} #ActionID, EventCardID
func add_reward_cards_from_actions(save_game_state: SaveGameState) -> void:
	self.reward_cards_from_actions = save_game_state.reward_cards_from_actions

#endregion
#region Opponents
### The order the encounter's opponents will enter in (type ids, front = next). Built once when the
### encounter starts; spawns from the spawn button and the per-turn refill consume it from the front.
### Summoned opponents never touch it.
var spawn_queue: Array[String] = []
### Parallel to spawn_queue: the look each queued opponent will have, rolled when the queue is built so a
### display of the queue (the rework's opponent queue) shows the opponent that actually enters. An entry is
### null when the opponent type has no appearance variations.
var spawn_queue_appearances: Array[OpponentAppearance] = []
### How many entries have left the front of the queue so far. Also the spawn-order index of the current front,
### so a display can tell which of the entries it shows are gone.
var spawn_queue_entries_taken: int = 0

func build_spawn_queue(encounter_def: EncounterDefinition) -> void:
	spawn_queue.clear()
	spawn_queue_appearances.clear()
	spawn_queue_entries_taken = 0
	var remaining_counts: Dictionary[String,int] = {} # type_id : number not yet placed
	var total: int = 0
	for opponent_type_id in encounter_def.opponents_in_encounter_reserves.keys():
		var count: int = encounter_def.opponents_in_encounter_reserves[opponent_type_id]
		if count <= 0:
			continue
		if opponent_type_id not in AutoloadDatabase.opponent_types:
			push_error("Encounter reserves contain unknown opponent type '%s'. Not added to the spawn queue." % opponent_type_id)
			continue
		remaining_counts[opponent_type_id] = count
		total += count

	# Fixed spawns come out of the reserves first. Position is 1-based.
	var fixed_by_position: Dictionary[int,String] = {}
	var out_of_range_fixed: Array[String] = []
	var fixed_positions: Array = encounter_def.fixed_spawn_order.keys()
	fixed_positions.sort()
	for position: int in fixed_positions:
		var fixed_type_id: String = encounter_def.fixed_spawn_order[position]
		if fixed_type_id not in AutoloadDatabase.opponent_types:
			push_error("Fixed spawn %s is unknown opponent type '%s'. Not added to the spawn queue." % [position, fixed_type_id])
			continue
		if remaining_counts.get(fixed_type_id, 0) <= 0:
			push_error("Fixed spawn %s ('%s') is not covered by the encounter reserves. Not added to the spawn queue." % [position, fixed_type_id])
			continue
		remaining_counts[fixed_type_id] -= 1
		if position < 1 or position > total:
			push_error("Fixed spawn position %s is outside the spawn queue (1-%s). '%s' is added at the end." % [position, total, fixed_type_id])
			out_of_range_fixed.append(fixed_type_id)
			continue
		fixed_by_position[position] = fixed_type_id

	# Everything else is shuffled. Equivalent to the old weighted pick without replacement.
	var random_pool: Array[String] = []
	for opponent_type_id in remaining_counts.keys():
		for i in remaining_counts[opponent_type_id]:
			random_pool.append(opponent_type_id)
	random_pool.shuffle()

	for position in range(1, total + 1):
		if position in fixed_by_position:
			spawn_queue.append(fixed_by_position[position])
		elif not random_pool.is_empty():
			spawn_queue.append(random_pool.pop_back())
		else:
			spawn_queue.append(out_of_range_fixed.pop_front())

	for opponent_type_id in spawn_queue:
		spawn_queue_appearances.append(AutoloadDatabase.opponent_types[opponent_type_id].get_random_appearance())

func get_spawn_queue() -> Array[String]:
	return spawn_queue.duplicate()
func get_upcoming_spawns(count: int) -> Array[String]:
	return spawn_queue.slice(0, count)
func get_upcoming_spawn_appearances(count: int) -> Array[OpponentAppearance]:
	return spawn_queue_appearances.slice(0, count)
func peek_next_spawn() -> String:
	if spawn_queue.is_empty():
		return ""
	return spawn_queue[0]
func peek_next_spawn_appearance() -> OpponentAppearance:
	if spawn_queue_appearances.is_empty():
		return null
	return spawn_queue_appearances[0]
func pop_next_spawn() -> String:
	if spawn_queue.is_empty():
		return ""
	if not spawn_queue_appearances.is_empty():
		spawn_queue_appearances.pop_front()
	spawn_queue_entries_taken += 1
	return spawn_queue.pop_front()

### How many opponents are still to be defeated to win: what is left in the spawn queue plus the active opponents that came out of it.
### Summoned opponents don't count. The remaining-guys counter starts from this (RemainingOpponentsCounter).
func get_remaining_queued_opponent_count() -> int:
	var remaining_count: int = spawn_queue.size()
	for opponent_instance: OpponentInstance in currently_active_opponents.values():
		if opponent_instance.spawned_from_spawn_queue:
			remaining_count += 1
	return remaining_count

### Win condition: every opponent that came out of the spawn queue has been defeated. Summoned
### opponents still in the room don't matter.
func all_queued_opponents_defeated() -> bool:
	return get_remaining_queued_opponent_count() == 0

var currently_active_opponents: Dictionary = {} # opponent ID - OpponentInstance
var last_spawned_opponent: OpponentInstance = null

func get_current_count_of_opponents() -> int:
	return currently_active_opponents.keys().size()
func get_missing_opponent_count() -> int:
	return min_simultaneous_opponents - get_current_count_of_opponents()

func get_currently_active_opponents() -> Dictionary:
	return currently_active_opponents
func get_opponent_instance(opponent_id: String) -> OpponentInstance:
	if opponent_id in get_currently_active_opponents().keys():
		return get_currently_active_opponents()[opponent_id]
	return null
func get_active_opponent_type(active_opponent_id: String) -> OpponentType:
	return currently_active_opponents[active_opponent_id].opponent_type
func get_name_of_opponent_type(opponent_type_id: String) -> String:
	var opponent_type: OpponentType = AutoloadDatabase.opponent_types[opponent_type_id]
	return opponent_type.get_opponent_type_name()
func get_count_of_active_opponent_types() -> Dictionary:
	var active_opponent_types: Dictionary[String, int] = {} #opponent type ID, count
	for opponent_id in get_currently_active_opponents().keys():
		var opponent_type_id: String = get_active_opponent_type(opponent_id).opponent_type_id
		if opponent_type_id not in active_opponent_types.keys():
			active_opponent_types[opponent_type_id] = 1
		else:
			active_opponent_types[opponent_type_id] += 1
	
	return active_opponent_types
func get_most_recently_entered_opponent() -> OpponentInstance:
	return last_spawned_opponent


func opponent_was_defeated_by_player_action(opponent_id: String,action_on_opponent: String) -> bool:
	if action_on_opponent != "":
		return true
	var effect_causing_defeat = encounter_report.get_reason_for_defeat(opponent_id)
	if effect_causing_defeat is PlayerAction:
		return true
	return false

func get_action_that_defeated_opponent(opponent_id: String) -> String:
	var action_on_opponent: String = get_action_assigned_to_opponent(opponent_id)
	if action_on_opponent != "":
		return action_on_opponent
	var effect_causing_defeat = encounter_report.get_reason_for_defeat(opponent_id)
	if effect_causing_defeat is PlayerAction:
		return effect_causing_defeat.action_id
	return ""

func get_nr_of_opponents_defeated_this_turn() -> int:
	return encounter_report.get_nr_of_opponents_defeated_on_turn(current_round)

var nr_of_opponents_spawned: int = 0
var min_simultaneous_opponents: int = 3
var max_simultaneous_opponents: int = 12

func change_min_simultaneous_opponents(delta: int) -> void:
	min_simultaneous_opponents += delta
	#print("Added delta %s to min_opponents. New min: %s"%[delta,min_simultaneous_opponents])

var registered_unique_opponents: Dictionary = {}
func register_unique_opponent_instance(opponent_instance: OpponentInstance) -> void:
	registered_unique_opponents[opponent_instance.opponent_id] = opponent_instance
	
func is_opponent_unique(opponent_id: String) -> bool:
	return opponent_id in registered_unique_opponents.keys()

func record_active_player_passives_at_end_of_game() -> void:
	encounter_report.record_active_player_passives_at_end_of_game(self)

func record_active_player_statuses_at_end_of_game() -> void:
	encounter_report.record_active_player_statuses_at_end_of_game(self)
#endregion

#region Event cards:
var opening_hand_size: int = 5
var event_cards_starting_hand: Dictionary #= {"handcuffs":3}

var event_cards_deck: Array[EventCardInstance] = []
var event_cards_hand: Array[EventCardInstance] = []
var event_cards_discard: Array[EventCardInstance] = []

var play_queue: Array[EventCardInstance] = []

func add_card_to_play_queue(card_instance: EventCardInstance) -> bool:
	if card_instance not in event_cards_hand:
		push_error("Trying to play card %s that is not in the players hand!"%card_instance.entity_id)
		return false
	if card_instance.card_state != EventCardInstance.CardState.IN_HAND:
		push_error("Trying to play a card has wrong CardState: %s"%EventCardInstance.CardState.keys()[card_instance.card_state])
		return false
	
	card_instance.previous_hand_index = event_cards_hand.find(card_instance)
	play_queue.append(card_instance)
	event_cards_hand.erase(card_instance)
	card_instance.card_state = EventCardInstance.CardState.RESOLVING
	return true

func remove_card_from_queue_after_resolving(card_instance: EventCardInstance) -> void:
	if card_instance not in play_queue:
		push_error("Trying to resolve card %s that is not in the play queue!"%card_instance.entity_id)
		return
	if card_instance.card_state != EventCardInstance.CardState.RESOLVING:
		push_error("Trying to resolve a card has wrong CardState: %s"%EventCardInstance.CardState.keys()[card_instance.card_state])
		return
	
	#print("Played card with ID: %s. Permancene: %s"%[card_instance.card_id,CardInstance.CardPermanence.keys()[card_instance.permanence]])
	
	if card_instance.permanence == CardInstance.CardPermanence.PERMANENT:
		#print("Adding %s to discard deck."%card_instance.card_id)
		event_cards_discard.append(card_instance)
	#else:
		#print("Not adding card %s to the discard deck, as it is not Permanent."%card_instance.card_id)
	play_queue.erase(card_instance)
	
	card_instance.card_state = EventCardInstance.CardState.IN_DISCARD_PILE
	
	if card_instance.permanence == CardInstance.CardPermanence.ONCE_PER_GAME:
		card_instance.card_state = EventCardInstance.CardState.EXILED
		#print("Remove card after resolving is erasing card %s from the game."%card_instance.card_id)
		event_cards_discard.erase(card_instance)

	
func return_card_to_hand_if_it_fails_resolving(card_instance: EventCardInstance) -> void:
	if card_instance not in play_queue:
		push_error("Trying to return card %s that is not in the play queue!"%card_instance.entity_id)
		return
	if card_instance.card_state != EventCardInstance.CardState.RESOLVING:
		push_error("Trying to play a card has wrong CardState: %s"%EventCardInstance.CardState.keys()[card_instance.card_state])
		return
	
	event_cards_hand.insert(card_instance.previous_hand_index,card_instance)
	play_queue.erase(card_instance)
	card_instance.card_state = EventCardInstance.CardState.IN_HAND

var event_cards_starting_deck: Dictionary = {}
func add_event_cards_from_save_game_deck(save_game_state:SaveGameState) -> void:
	for card_id in save_game_state.get_current_deck().keys():
		if card_id not in event_cards_starting_deck.keys():
			event_cards_starting_deck[card_id] = save_game_state.get_current_deck()[card_id]
		else:
			event_cards_starting_deck[card_id] += save_game_state.get_current_deck()[card_id]
	
	_handle_ally_summon(save_game_state)

func _handle_ally_summon(save_game_state: SaveGameState) -> void:
	if not current_encounter:
		return
	if current_encounter.forbid_all_summons:
		return
	
	var current_ally_card: String = save_game_state.get_current_ally_card()
	if current_ally_card == "":
		return
	var current_ally_type: String = save_game_state.get_current_ally_type()
	if current_ally_type in current_encounter.forbidden_ally_summons:
		return
	
	event_cards_starting_hand[current_ally_card] = 1

func record_event_card_played(event_card_def: EventCardDefinition) -> void:
	encounter_report.record_event_card_played(event_card_def,self)

#region Card instance tracking (debug/validation):
var _all_event_card_instances: Dictionary[String, EventCardInstance] = {} # entity_id -> instance

func register_event_card_instance(card_instance: EventCardInstance) -> void:
	_all_event_card_instances[card_instance.entity_id] = card_instance

func get_all_registered_event_card_instances() -> Array[EventCardInstance]:
	return _all_event_card_instances.values()

var _already_reported_missing: Dictionary[String, bool] = {}

func validate_all_event_card_instances_are_accounted_for() -> void:
	var missing: Array[EventCardInstance] = []
	for entity_id in _all_event_card_instances.keys():
		var card_instance: EventCardInstance = _all_event_card_instances[entity_id]
		if card_instance.permanence != CardInstance.CardPermanence.PERMANENT and card_instance.permanence != CardInstance.CardPermanence.ONCE_PER_GAME:
			continue
		if _already_reported_missing.has(entity_id):
			continue
		if not _event_card_instance_is_accounted_for(card_instance):
			missing.append(card_instance)
			_already_reported_missing[entity_id] = true
	
	if missing.is_empty():
		return
	
	push_error("Found %s missing event card instance(s):" % missing.size())
	for card in missing:
		print("  MISSING: entity_id=%s card_id=%s permanence=%s last_known_state=%s" % [
			card.entity_id,
			card.card_id,
			CardInstance.CardPermanence.keys()[card.permanence],
			EventCardInstance.CardState.keys()[card.card_state]
		])

#func validate_all_event_card_instances_are_accounted_for() -> void:
	#var missing: Array[EventCardInstance] = []
	#for entity_id in _all_event_card_instances.keys():
		#var card_instance: EventCardInstance = _all_event_card_instances[entity_id]
		#if card_instance.permanence != CardInstance.CardPermanence.PERMANENT and card_instance.permanence != CardInstance.CardPermanence.ONCE_PER_GAME:
			#continue
		#if not _event_card_instance_is_accounted_for(card_instance):
			#missing.append(card_instance)
	#
	#if missing.is_empty():
		#return
	#
	#push_error("Found %s missing event card instance(s):" % missing.size())
	#for card in missing:
		#print("  MISSING: entity_id=%s card_id=%s permanence=%s last_known_state=%s" % [
			#card.entity_id,
			#card.card_id,
			#CardInstance.CardPermanence.keys()[card.permanence],
			#EventCardInstance.CardState.keys()[card.card_state]
		#])

func _event_card_instance_is_accounted_for(card_instance: EventCardInstance) -> bool:
	if card_instance in event_cards_deck:
		return true
	if card_instance in event_cards_hand:
		return true
	if card_instance in event_cards_discard:
		return true
	if card_instance in play_queue:
		return true
	if card_instance.card_state == EventCardInstance.CardState.EXILED:
		return true # once-per-game cards are intentionally removed after resolving
	return false
#endregion

#endregion 

### Round and turn structure
var current_round: int = 0
@export_enum("PLAYERTURN","OPPONENTSTURN") var current_game_phase: int = 0
func it_is_players_turn() -> bool:
	return current_game_phase == 0

#region Log:
var game_log: Array[LogFragment] = []
var unresolved_log_fragments: Array[LogFragment] = []

#endregion
#region Options:
@export var opponent_step_delay: float = 0.75 #s

@export var drag_preview_z_index: int = 10000
#endregion
#region Encounter Report
var current_encounter: EncounterDefinition = null
var encounter_report: EncounterReport = EncounterReport.new()

#endregion

#region Orgasms
func get_current_orgasm_count() -> int:
	return encounter_report.get_current_orgasm_count()

#endregion
