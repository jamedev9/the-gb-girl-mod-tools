extends RefCounted
class_name EncounterDifficultyModel

### The maths behind the encounter difficulty estimate. Two halves, both static:
###
### OFFLINE (used by tools/encounter_difficulty to fill the EncounterDifficultyTable):
###   1. build_opponent_profile(): an opponent type -> how tough it is (effective HP) and how much it hurts
###      (pleasure-equivalents per turn), read straight from the opponent's Moves and passives. Effects that
###      don't deal pleasure (capturing actions, draining energy, junk cards, healing, summoning, ...) are
###      turned into pleasure-equivalents with the weights in EncounterDifficultyWeights.
###   2. simulate_encounter(): plays the encounter's spawn queue (shuffled / fixed order like the real game)
###      against a player who deals a constant amount of pleasure per turn, and records how much pleasure the
###      player takes before the last opponent falls. Done for a grid of player outputs.
###
### RUNTIME (used by EncounterDifficultyService with the current save):
###   get_player_inputs() -> the save's output per turn and pleasure budget; get_rating_score()/get_stars()
###   -> turn "expected pleasure taken / budget" into the 1-5 rating.
###
### Anything in an opponent's data the model does not understand is reported in the profile's "unmodelled"
### list (shown in the tool's report) instead of being silently dropped.

### The highest difficulty rating (stars); the lowest is 1. The "m" in a displayed "n/m".
const MAX_STARS: int = 5

#region Runtime: the player
### What the save's player brings to an encounter: pleasure dealt per turn (the used actions' pleasure plus
### what the energy left after their upkeep is assumed to buy in cards) and the pleasure budget (the pleasure
### bar times the number of bars: the orgasm bank plus the one you lose on).
static func get_player_inputs(save_game_state: SaveGameState, weights: EncounterDifficultyWeights) -> Dictionary:
	var max_pleasure: int = int(save_game_state.player.get("damage_threshold", 100))
	var orgasm_bank: int = int(save_game_state.player.get("hp", 0))
	var max_energy: int = int(save_game_state.player.get("max_energy", 10))
	var action_pleasure: float = 0.0
	var action_upkeep: float = 0.0
	var action_summaries: Array[String] = []
	for action_id in save_game_state.currently_used_player_actions:
		var action: PlayerAction = save_game_state.get_effective_player_action(String(action_id))
		if action == null:
			continue
		action_pleasure += float(action.get_displayed_damage())
		action_upkeep += float(action.energy_per_round)
		action_summaries.append("%s(%d pleasure, %d upkeep)" % [action.action_id, action.get_displayed_damage(), action.energy_per_round])
	var spare_energy: float = maxf(float(max_energy) - action_upkeep, 0.0)
	var output: float = maxf(action_pleasure + weights.spare_energy_pleasure_per_point * spare_energy, 1.0)
	var budget: float = float(orgasm_bank + 1) * float(max_pleasure)
	return {
		"max_pleasure": max_pleasure,
		"orgasm_bank": orgasm_bank,
		"max_energy": max_energy,
		"actions": ", ".join(action_summaries),
		"action_pleasure": action_pleasure,
		"spare_energy": spare_energy,
		"output": output,
		"budget": maxf(budget, 1.0),
	}

### 1.0 (ratio at or below ratio_for_one_star) to 5.0 (at or above ratio_for_five_stars), log scale between.
static func get_rating_score(ratio: float, weights: EncounterDifficultyWeights) -> float:
	var low: float = maxf(weights.ratio_for_one_star, 0.0001)
	var high: float = maxf(weights.ratio_for_five_stars, low * 1.0001)
	var position: float = (log(maxf(ratio, 0.000001)) - log(low)) / (log(high) - log(low))
	return 1.0 + float(MAX_STARS - 1) * clampf(position, 0.0, 1.0)

static func get_stars(score: float) -> int:
	return clampi(roundi(score), 1, MAX_STARS)
#endregion

#region Offline: opponents
### {"effective_hp", "threat", "usable_moves", "total_moves", "notes", "unmodelled"} for one opponent type,
### facing a player who owns exactly usable_action_ids. Moves that would capture an action the player doesn't
### have are left out - the game re-rolls those (OpponentActionManager.change_opponents_next_action()).
static func build_opponent_profile(
		opponent_type: OpponentType, usable_action_ids: Array, weights: EncounterDifficultyWeights) -> Dictionary:
	var unmodelled: Array[String] = []
	var notes: Array[String] = []
	var moves: Array[OpponentActionDefinition] = _get_usable_moves(opponent_type, usable_action_ids)
	if moves.is_empty() and not opponent_type.available_actions.is_empty():
		notes.append("no Move is usable with the character's actions - counting all of them")
		moves = opponent_type.available_actions.duplicate()

	var move_threat_sum: float = 0.0
	for move in moves:
		move_threat_sum += _get_move_threat(move, weights, unmodelled)
	var mean_move_threat: float = 0.0
	if not moves.is_empty():
		mean_move_threat = move_threat_sum / float(moves.size())

	var passives: Dictionary = _read_passives(opponent_type, weights, unmodelled)
	var threat: float = (mean_move_threat + float(passives["damage_per_turn"])) * float(passives["output_multiplier"])
	var base_hp: float = float(opponent_type.max_damage * maxi(opponent_type.orgasms_before_defeat, 1))
	var effective_hp: float = base_hp * float(passives["hp_multiplier"]) + float(passives["regen_per_turn"]) * weights.regen_lifetime_turns
	return {
		"effective_hp": maxf(effective_hp, 1.0),
		"threat": threat,
		"usable_moves": moves.size(),
		"total_moves": opponent_type.available_actions.size(),
		"notes": notes,
		"unmodelled": unmodelled,
	}

static func _get_usable_moves(opponent_type: OpponentType, usable_action_ids: Array) -> Array[OpponentActionDefinition]:
	var usable: Array[OpponentActionDefinition] = []
	for move in opponent_type.available_actions:
		if move == null:
			continue
		var is_usable: bool = true
		for action_id in move.get_player_actions_grabbed():
			if action_id not in usable_action_ids:
				is_usable = false
		if is_usable:
			usable.append(move)
	return usable

static func _get_move_threat(move: OpponentActionDefinition, weights: EncounterDifficultyWeights, unmodelled: Array[String]) -> float:
	var threat: float = 0.0
	for intent in move.effect_intents:
		threat += _get_intent_threat(intent, weights, unmodelled)
	if not move.trigger_conditions.is_empty():
		threat *= weights.conditional_move_chance
	return threat

static func _get_intent_threat(intent: EffectAndTargetIntent, weights: EncounterDifficultyWeights, unmodelled: Array[String]) -> float:
	if intent == null or intent.effect_intent == null:
		return 0.0
	var effect: EffectIntent = intent.effect_intent
	var targets_player: bool = intent.targeting_intent == TargetingSystem.TargetingMode.PLAYER

	var damage_effect: DealDamageEffect = effect as DealDamageEffect
	if damage_effect:
		if damage_effect.damage > 0:
			return float(damage_effect.damage) if targets_player else 0.0 ### Pleasure an opponent gives himself isn't a threat.
		if damage_effect.damage < 0 and not targets_player:
			return weights.weight_heal_or_cleanse
		return 0.0
	if effect is DealDamageBasedOnOrgasms or effect is DealDamagePerEnergy:
		return weights.weight_damage_scaling_move if targets_player else 0.0
	var apply_status: ApplyStatusEffect = effect as ApplyStatusEffect
	if apply_status:
		return _get_status_application_threat(apply_status, targets_player, weights)
	if effect is Intent_CapturePlayerAction:
		return weights.weight_capture_player_action
	if effect is Intent_RetractPlayerActions:
		return weights.weight_retract_player_actions
	if effect is DrainPlayerEnergy:
		return weights.weight_drain_energy_per_point * 5.0 ### Drains everything the player has left; call it half a bar.
	if effect is CardFlowEffect or effect is Intent_AddCardsFromListOfCardsToHand:
		return weights.weight_add_cards_to_player
	if effect is HealForValueEffect or effect is ClearDebuffsFromTargets or effect is ClearStatusesfromTargets:
		return weights.weight_heal_or_cleanse
	if effect is Intent_SummonOpponent:
		return weights.weight_summon_opponent
	_note_unmodelled(unmodelled, "effect %s" % _get_class_name(effect))
	return 0.0

static func _get_status_application_threat(apply_status: ApplyStatusEffect, targets_player: bool, weights: EncounterDifficultyWeights) -> float:
	var status: StatusEffectDefinition = apply_status.get_status_definition()
	if status == null:
		return 0.0
	if not targets_player:
		if status.status_category == StatusEffectDefinition.StatusCategory.BUFF:
			return weights.weight_buff_other_opponents
		return 0.0
	var turns: float = float(maxi(weights.status_turns_cap, 1)) ### A persistent status (duration 0) counts for the full cap.
	if not StatusEffectManager.is_duration_persistent(apply_status.status_duration):
		turns = float(clampi(apply_status.status_duration, 1, maxi(weights.status_turns_cap, 1)))
	var threat: float = 0.0
	for component in status.get_ticking_components():
		var ticking: StatusTickComponent = component as StatusTickComponent
		if ticking == null:
			continue
		for tick_intent in ticking.effect_intents:
			threat += float(_get_damage_to_status_owner(tick_intent)) * turns
	for component in status.get_modifier_components():
		var reduce_energy: Status_ReducePlayerEnergy = component as Status_ReducePlayerEnergy
		if reduce_energy:
			threat += weights.weight_drain_energy_per_point * float(reduce_energy.energy_reduction) * turns
		elif component is Status_DisablePlayerActions:
			threat += weights.weight_retract_player_actions
	return threat

### Pleasure a passive's trigger / tick gives the player, per turn it fires (and regeneration / immunities on
### the opponent himself).
static func _read_passives(opponent_type: OpponentType, weights: EncounterDifficultyWeights, unmodelled: Array[String]) -> Dictionary:
	var damage_per_turn: float = 0.0
	var regen_per_turn: float = 0.0
	var hp_multiplier: float = 1.0
	var output_multiplier: float = 1.0
	for passive_id in opponent_type.passive_effects:
		var passive: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
		if passive == null:
			_note_unmodelled(unmodelled, "passive '%s' is not registered" % passive_id)
			continue
		for component in passive.get_triggered_components():
			var triggered: StatusTriggeredComponent = component as StatusTriggeredComponent
			if triggered == null:
				continue
			for triggered_intent in triggered.effect_intents:
				damage_per_turn += float(_get_damage_to_player(triggered_intent)) * weights.passive_retaliation_chance
		for component in passive.get_ticking_components():
			var ticking: StatusTickComponent = component as StatusTickComponent
			if ticking == null:
				continue
			for tick_intent in ticking.effect_intents:
				damage_per_turn += float(_get_damage_to_player(tick_intent))
				regen_per_turn += float(_get_self_healing(tick_intent))
		for component in passive.get_modifier_components():
			var multiply_damage: MultiplyDamage = component as MultiplyDamage
			if multiply_damage:
				if multiply_damage.damage_phase == DamageSystem.DamagePhase.INCOMING:
					if multiply_damage.multiplier <= 0.0:
						hp_multiplier *= weights.immune_to_player_actions_hp_multiplier
					else:
						hp_multiplier /= multiply_damage.multiplier
				else:
					output_multiplier *= maxf(multiply_damage.multiplier, 0.0)
				continue
			var prevent_moving: PreventMovingActionsToTarget = component as PreventMovingActionsToTarget
			if prevent_moving and prevent_moving.all_actions:
				hp_multiplier *= weights.immune_to_player_actions_hp_multiplier
				continue
			_note_unmodelled(unmodelled, "passive '%s': %s" % [passive_id, _get_class_name(component)])
	return {
		"damage_per_turn": damage_per_turn,
		"regen_per_turn": regen_per_turn,
		"hp_multiplier": hp_multiplier,
		"output_multiplier": output_multiplier,
	}

### Pleasure the intent gives the player (positive DealDamageEffect aimed at the player).
static func _get_damage_to_player(intent: EffectAndTargetIntent) -> int:
	if intent == null:
		return 0
	var damage_effect: DealDamageEffect = intent.effect_intent as DealDamageEffect
	if damage_effect == null or damage_effect.damage <= 0:
		return 0
	if intent.targeting_intent == TargetingSystem.TargetingMode.PLAYER:
		return damage_effect.damage
	return 0

### Same, for a tick of a status the player carries: those aim at "the owner of the status", not "the player".
static func _get_damage_to_status_owner(intent: EffectAndTargetIntent) -> int:
	if intent == null:
		return 0
	var damage_effect: DealDamageEffect = intent.effect_intent as DealDamageEffect
	if damage_effect == null or damage_effect.damage <= 0:
		return 0
	match intent.targeting_intent:
		TargetingSystem.TargetingMode.PLAYER, TargetingSystem.TargetingMode.SOURCE_OF_EFFECT, TargetingSystem.TargetingMode.NO_TARGET:
			return damage_effect.damage
	return 0

### Pleasure an opponent loses per turn from a tick (negative pleasure, or a heal, aimed at anything but the player).
static func _get_self_healing(intent: EffectAndTargetIntent) -> int:
	if intent == null or intent.targeting_intent == TargetingSystem.TargetingMode.PLAYER:
		return 0
	var damage_effect: DealDamageEffect = intent.effect_intent as DealDamageEffect
	if damage_effect and damage_effect.damage < 0:
		return -damage_effect.damage
	var heal_effect: HealForValueEffect = intent.effect_intent as HealForValueEffect
	if heal_effect and heal_effect.healing > 0:
		return heal_effect.healing
	return 0

static func _note_unmodelled(unmodelled: Array[String], text: String) -> void:
	if text not in unmodelled:
		unmodelled.append(text)

static func _get_class_name(object: Object) -> String:
	if object == null:
		return "<empty entry>"
	var script: Script = object.get_script()
	if script and script.get_global_name() != &"":
		return String(script.get_global_name())
	return object.get_class()
#endregion

#region Offline: simulation
### Geometric grid of player outputs from output_grid_min to output_grid_max.
static func make_output_grid(weights: EncounterDifficultyWeights) -> PackedFloat32Array:
	var grid: PackedFloat32Array = PackedFloat32Array()
	var points: int = maxi(weights.output_grid_points, 2)
	var low: float = maxf(weights.output_grid_min, 0.01)
	var high: float = maxf(weights.output_grid_max, low * 1.01)
	for index in points:
		var position: float = float(index) / float(points - 1)
		grid.append(low * pow(high / low, position))
	return grid

### {"mean", "spread", "turns"} (one PackedFloat32Array each, one value per output_grid point): the pleasure the
### player takes while clearing the encounter (average and standard deviation over the trials) and how many
### turns that took. profiles: opponent type id -> build_opponent_profile() result. Empty when the encounter
### has nobody to fight.
static func simulate_encounter(
		encounter_def: EncounterDefinition, profiles: Dictionary,
		output_grid: PackedFloat32Array, weights: EncounterDifficultyWeights) -> Dictionary:
	var game_state: GameState = GameState.new() ### Only used to build the spawn queue exactly like the real game does.
	var max_active: int = encounter_def.max_simultaneous_opponents
	if max_active <= 0:
		max_active = game_state.max_simultaneous_opponents
	var min_active: int = mini(maxi(encounter_def.min_simultaneous_opponents, 1), max_active)

	var grid_size: int = output_grid.size()
	var pleasure_sums: PackedFloat64Array = PackedFloat64Array()
	var pleasure_square_sums: PackedFloat64Array = PackedFloat64Array()
	var turn_sums: PackedFloat64Array = PackedFloat64Array()
	pleasure_sums.resize(grid_size)
	pleasure_square_sums.resize(grid_size)
	turn_sums.resize(grid_size)

	var trials: int = maxi(weights.simulation_trials, 1)
	for trial in trials:
		seed(weights.simulation_seed + trial) ### build_spawn_queue() shuffles with the global random generator.
		game_state.build_spawn_queue(encounter_def)
		var queue: Array[String] = game_state.get_spawn_queue()
		if queue.is_empty():
			return {}
		for grid_index in grid_size:
			var run: Vector2 = _simulate_run(queue, profiles, output_grid[grid_index], min_active, weights.max_simulated_turns)
			pleasure_sums[grid_index] += run.x
			pleasure_square_sums[grid_index] += run.x * run.x
			turn_sums[grid_index] += run.y

	var mean: PackedFloat32Array = PackedFloat32Array()
	var spread: PackedFloat32Array = PackedFloat32Array()
	var turns: PackedFloat32Array = PackedFloat32Array()
	for grid_index in grid_size:
		var average: float = pleasure_sums[grid_index] / float(trials)
		var variance: float = pleasure_square_sums[grid_index] / float(trials) - average * average
		mean.append(average)
		spread.append(sqrt(maxf(variance, 0.0)))
		turns.append(turn_sums[grid_index] / float(trials))
	return {"mean": mean, "spread": spread, "turns": turns}

### One playthrough of one spawn queue. Each turn: the room is refilled from the queue up to the minimum,
### the player's output kills opponents front to back, then the survivors hurt the player.
### Returns Vector2(pleasure taken, turns).
static func _simulate_run(
		queue: Array[String], profiles: Dictionary, player_output: float,
		min_active: int, max_turns: int) -> Vector2:
	var waiting: Array[String] = queue.duplicate()
	var active_hp: Array[float] = []
	var active_threat: Array[float] = []
	var pleasure_taken: float = 0.0
	var turns: int = 0
	while (not waiting.is_empty() or not active_hp.is_empty()) and turns < max_turns:
		turns += 1
		while not waiting.is_empty() and active_hp.size() < min_active:
			var type_id: String = waiting.pop_front()
			var profile: Dictionary = profiles.get(type_id, {})
			active_hp.append(float(profile.get("effective_hp", 1.0)))
			active_threat.append(float(profile.get("threat", 0.0)))
		var output_left: float = player_output
		var index: int = 0
		while output_left > 0.0 and index < active_hp.size():
			var dealt: float = minf(output_left, active_hp[index])
			active_hp[index] -= dealt
			output_left -= dealt
			index += 1
		for remove_index in range(active_hp.size() - 1, -1, -1):
			if active_hp[remove_index] <= 0.0:
				active_hp.remove_at(remove_index)
				active_threat.remove_at(remove_index)
		for threat in active_threat:
			pleasure_taken += threat
	return Vector2(pleasure_taken, float(turns))
#endregion
