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

func remove_passive_from_player(passive_id: String) -> void:
	if "passive_effects" in player.keys():
		player["passive_effects"].erase(passive_id)

func give_player_passivegive_player_passive(passive_id: String) -> void:
	if "passive_effects" not in player.keys():
		return
	var player_passives = player["passive_effects"]
	if passive_id not in player_passives:
		player["passive_effects"].append(passive_id)

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
				for action in effect.disabled_action_ids:
					if action in currently_disabled_actions:
						continue
					currently_disabled_actions.append(action)
	
	for passive_id in get_active_player_passives():
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if not passive_def:
			continue
		for modifier in passive_def.modifier_components:
			if modifier is Status_DisablePlayerActions:
				for action in modifier.disabled_action_ids:
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

var reward_cards_from_actions: Dictionary = {} #ActionID, EventCardID
func add_reward_cards_from_actions(save_game_state: SaveGameState) -> void:
	self.reward_cards_from_actions = save_game_state.reward_cards_from_actions

#endregion
#region Opponents
var opponents_in_encounter_reserves: Dictionary = {} # type_id : number

var randomly_spawnable_opponents: Dictionary = {} # type_id : number

var nr_of_scheduled_opponents_spawned: int = 0

func determine_randomly_spawning_opponents(encounter_def: EncounterDefinition) -> void:
	randomly_spawnable_opponents = opponents_in_encounter_reserves.duplicate()
	# Reserve opponents used in the fixed spawn order.
	for opponent_type_id in encounter_def.fixed_spawn_order.values():
		if opponent_type_id not in randomly_spawnable_opponents:
			push_error("Fixed spawn '%s' is not present in the encounter reserves." % opponent_type_id)
			continue
		randomly_spawnable_opponents[opponent_type_id] -= 1
		if randomly_spawnable_opponents[opponent_type_id] < 0:
			push_error("Encounter reserves contain fewer '%s' than are required by fixed spawns." % opponent_type_id)
			randomly_spawnable_opponents[opponent_type_id] = 0
		elif randomly_spawnable_opponents[opponent_type_id] == 0:
			randomly_spawnable_opponents.erase(opponent_type_id)
	# Reserve opponents used in forced turn spawns.
	#for turn in encounter_def.forced_spawns_after_turn.keys():
		#for opponent_type_id in encounter_def.forced_spawns_after_turn[turn]:
			#for opp_type_in_reserves in opponents_in_encounter_reserves.keys():
				#if opp_type_in_reserves == opponent_type_id:
					#randomly_spawnable_opponents[opp_type_in_reserves] -= 1

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
	return opponent_type.opponent_type_name
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
	
	var current_ally_card: String = save_game_state.get_current_ally_card()
	if current_ally_card != "":
		event_cards_starting_hand[current_ally_card] = 1

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
