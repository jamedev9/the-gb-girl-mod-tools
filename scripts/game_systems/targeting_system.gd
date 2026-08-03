extends Node
class_name TargetingSystem

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

enum TargetingMode {
	NO_TARGET,
	PLAYER,
	SINGLE_OPPONENT,
	ALL_OPPONENTS,
	RULE_BASED,
	SOURCE_OF_EFFECT,
}


static func get_targets_matching_rules(
	game_state: GameState,
	rules_array: Array[TargetingRule],
	source: TargetEntity = null) -> Array[TargetEntity]:

	#var rule_names: Array = rules_array.map(func(r): return r.get_script().get_global_name())
	#print("Rules passed in (%d): %s" % [rules_array.size(), rule_names])

	var filter_rules: Array[TargetingRule] = []
	var selector_rules: Array[TargetingRule] = []
	for rule in rules_array:
		if _is_selector_rule(rule):
			selector_rules.append(rule)
		else:
			filter_rules.append(rule)

	var valid_opponent_ids: Array = game_state.get_currently_active_opponents().keys()
	for rule in filter_rules:
		valid_opponent_ids = _apply_filter_rule(rule, valid_opponent_ids, game_state, source)
	#print("After filter rules: %s" % [valid_opponent_ids])
	
	valid_opponent_ids = _remove_duplicate_opponent_ids(valid_opponent_ids)	

	for rule in selector_rules:
		valid_opponent_ids = _apply_selector_rule(rule, valid_opponent_ids, game_state, source)
	#print("After selector rules: %s" % [valid_opponent_ids])

	var opp_entities: Array[TargetEntity] = []
	for opponent_id in valid_opponent_ids:
		if not opponent_id:
			continue
		opp_entities.append(OpponentEntity.new(game_state, opponent_id))
	return opp_entities

static func _remove_duplicate_opponent_ids(opponent_ids: Array) -> Array:
	var unique_ids: Array = []
	for opponent_id in opponent_ids:
		if opponent_id not in unique_ids:
			unique_ids.append(opponent_id)
	return unique_ids

static func _is_selector_rule(rule: TargetingRule) -> bool:
	match rule.get_script():
		OpponentWithMostHealthRemaining:
			return true
		OnlyOneOpponent:
			return true
	return false

static func _apply_filter_rule(
	rule: TargetingRule,
	opponent_ids: Array,
	game_state: GameState,
	source: TargetEntity) -> Array:

	var valid: Array = []
	match rule.get_script():
		#TargetSpecificOpponentId:
			#print("Found targeting rule of type TargetSpecificOpponentId")
			#valid.append(rule.unique_opponent_id)
			#print("Valid opponents: %s"%valid)
		TargetCantBeAlly:
			for opponent_id in opponent_ids:
				var opponent_instance: OpponentInstance = game_state.get_opponent_instance(opponent_id)
				if not opponent_instance.opponent_type.summonable_ally:
					valid.append(opponent_id)
				
		OpponentTargetsSelf:
			if source is OpponentEntity and source.opponent_id in opponent_ids:
				valid.append(source.opponent_id)
		OpponentCantTargetSelf:
			var source_opponent_id: String = ""
			if source is OpponentEntity and source.opponent_id in opponent_ids:
				source_opponent_id = source.opponent_id
			
			for opponent_id in opponent_ids:
				if opponent_id != source_opponent_id:
					valid.append(opponent_id)
		TargetMostRecentlyEnteredOpponent:
			#print("Targeting most recent opponent. Opponent id: %s")
			var latest_opponent_spawned: OpponentInstance =  game_state.get_most_recently_entered_opponent()
			valid.append(latest_opponent_spawned.opponent_id)
			#print("Targeting most recent opponent. Opponent id: %s"%latest_opponent_spawned.opponent_id)
		TargetsHaveOneOfSeveralActionsAssigned:
			var active_actions: Array[String] = ActionManager.get_currently_active_actions(game_state)
			for action_id in rule.action_ids:
				if action_id in active_actions:
					var opponent_id: String = game_state.get_opponent_with_action(action_id)
					#print("Checking opponent: %s"%opponent_id)
					if opponent_id in opponent_ids and opponent_id not in valid:
						valid.append(opponent_id)
		TargetMustBeDifferentOpponentType:
			if source is PlayerEntity:
				return opponent_ids
			var source_instance: OpponentInstance = game_state.get_opponent_instance(source.opponent_id)
			var source_type_id: String = source_instance.opponent_type.opponent_type_id
			for opponent_id in opponent_ids:
				var opponent_instance: OpponentInstance = game_state.get_opponent_instance(opponent_id)
				if opponent_instance.opponent_type.opponent_type_id != source_type_id:
					valid.append(opponent_id)
		TargetsHaveLessThanNHealthLeft:
			for opponent_id in opponent_ids:
				var opponent_instance: OpponentInstance = game_state.get_opponent_instance(opponent_id)
				var health_remaining: int = opponent_instance.opponent_type.max_damage - opponent_instance.current_damage
				if health_remaining <= rule.health_left_threshold:
					valid.append(opponent_id)
		TargetsOpponentsWithPassive:
			for opponent_id in opponent_ids:
				var opponent_instance: OpponentInstance = game_state.get_opponent_instance(opponent_id)
				var opponent_type: OpponentType = opponent_instance.opponent_type
				var opponent_passives: Array[String] = opponent_type.passive_effects
				for passive in opponent_passives:
					if passive == rule.passive_id:
						valid.append(opponent_id)
		TargetMustBeSpecificOpponentType:
			for opponent_id in opponent_ids:
				var opponent_instance: OpponentInstance = game_state.get_opponent_instance(opponent_id)
				var opponent_type: OpponentType = opponent_instance.opponent_type
				var opponent_type_id: String = opponent_type.opponent_type_id
				if opponent_type_id == rule.opponent_type_id:
					valid.append(opponent_id)
		TargetCannotHaveTheseActionsAssigned:
			var invalid_opponents: Array = []
			var active_actions: Array[String] = ActionManager.get_currently_active_actions(game_state)
			for action_id in rule.action_ids:
				if action_id in active_actions:
					var opponent_id: String = game_state.get_opponent_with_action(action_id)
					if opponent_id not in invalid_opponents:
						invalid_opponents.append(opponent_id)
			for opponent_id in opponent_ids:
				if opponent_id not in invalid_opponents:
					valid.append(opponent_id)
					
		#TargetCannotHaveTheseActionsAssigned:
			#var all_opponents = game_state.get_currently_active_opponents().keys()
			#var invalid_opponents: Array = []
			#var active_actions: Array[String] = ActionManager.get_currently_active_actions(game_state)
			#for action_id in rule.action_ids:
				#if action_id in active_actions:
					#var opponent_id: String = game_state.get_opponent_with_action(action_id)
					##print("Checking opponent: %s"%opponent_id)
					#if opponent_id in opponent_ids and opponent_id not in valid:
						#invalid_opponents.append(opponent_id)
			#for opponent_id in all_opponents.keys():
				#if opponent_id not in invalid_opponents:
					#valid.append(opponent_id)
		
		_:
			return opponent_ids
	return valid

static func _apply_selector_rule(
	rule: TargetingRule,
	opponent_ids: Array,
	game_state: GameState,
	_source: TargetEntity) -> Array:

	match rule.get_script():
		OpponentWithMostHealthRemaining:
			var highest_health: int = 0
			for opponent_id in opponent_ids:
				var opponent_instance: OpponentInstance = game_state.get_opponent_instance(opponent_id)
				var health_remaining: int = opponent_instance.opponent_type.max_damage - opponent_instance.current_damage
				if health_remaining > highest_health:
					highest_health = health_remaining
			var valid: Array = []
			for opponent_id in opponent_ids:
				var opponent_instance: OpponentInstance = game_state.get_opponent_instance(opponent_id)
				var health_remaining: int = opponent_instance.opponent_type.max_damage - opponent_instance.current_damage
				if health_remaining == highest_health:
					valid.append(opponent_id)
			#print("OpponentWithMostHealthRemaining valid before pick_random: %s" % valid)
			return [valid.pick_random()]
		OnlyOneOpponent:
			return [opponent_ids.pick_random()]

	return opponent_ids
