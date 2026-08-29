extends GameManager
class_name ActionManager
#Responsability: What actions are avilable, where are they being used.

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

#region Public functions to ask for info
func get_action_base_move_cost(action_id: String) -> int:
	return AutoloadDatabase.player_actions_by_id[action_id].move_energy

## Computes the CURRENT move-energy cost for an action, with all applicable status/
## passive modifiers applied (e.g. the "Lubed" status reducing cost to a specific
## opponent) - without any of the side effects of actually moving the action (no
## verification, no resolution, no signals). Pass opponent_id to preview the cost of
## targeting a specific opponent; leave empty to preview with only the player's own
## modifiers applied. Safe to call every frame - only mutates a throwaway context.
func get_current_move_cost(action_id: String, opponent_id: String = "") -> int:
	var player_action: PlayerAction = AutoloadDatabase.get_player_action_by_id(action_id)
	if not player_action:
		return 0
	var game_state: GameState = main_game.game_state
	### A GameState always exists (main_cardgame.gd's _clear_game_state()), but
	### game_state.player only gets its full field set (including "passive_effects")
	### via GameState.add_player_stats(), called when a real encounter starts.
	### _clear_encounter() (run on exiting an encounter) resets current_encounter to a
	### fresh, non-null placeholder EncounterDefinition without calling
	### add_player_stats() again, so current_encounter alone isn't a reliable signal -
	### check the same way GameState.get_active_player_passives() does.
	if not game_state or not game_state.current_encounter or "passive_effects" not in game_state.player.keys():
		return player_action.move_energy

	var intent_source: PlayerEntity = PlayerEntity.new(game_state)
	var preview_context: EffectContext = EffectContext.new()
	preview_context.game_state = game_state
	preview_context.context_phase = EffectContext.ContextPhase.MODIFY
	preview_context.moving_player_action = true
	preview_context.player_action_id = action_id
	preview_context.effect_origin = intent_source
	preview_context.id_of_effect_origin = "player"
	preview_context.source = intent_source
	preview_context.energy_delta = player_action.move_energy
	preview_context.energy_reason = EffectContext.EnergyReason.MOVED_PLAYER_ACTION
	if opponent_id != "":
		preview_context.target = OpponentEntity.new(game_state, opponent_id)

	main_game.effect_context_manager._modify_intent_context_with_passive_and_status_effects(preview_context, false)
	### Matches PlayerStatsManager._drain_player_energy_from_moving_action_ - never gain
	### energy from moving actions, so cost can't preview as negative either.
	return max(preview_context.energy_delta, 0)

static func get_current_action_upkeep(game_state:GameState) -> int:
	var upkeep_energy: int = 0
	var active_action_ids: Array[String] = get_currently_active_actions(game_state)
	for action_id in active_action_ids:
		upkeep_energy += AutoloadDatabase.player_actions_by_id[action_id].energy_per_round
	return upkeep_energy

static func get_currently_active_actions(game_state: GameState) -> Array[String]:
	var action_ids: Array[String] = []
	for action_id in AutoloadDatabase.player_actions_by_id:
		if action_is_in_use(game_state,action_id):
			action_ids.append(action_id)
	return action_ids

static func get_inactive_actions(game_state: GameState) -> Array[String]:
	var action_ids: Array[String] = []
	for action_id in game_state.get_player_actions_in_encounter():
		if not action_is_in_use(game_state,action_id):
			action_ids.append(action_id)
	return action_ids

static func get_action_assigned_to_opponent(game_state: GameState, opponent_id: String) -> String:
	for action_id in game_state.actions_assigned_to_opponents.keys():
		if game_state.actions_assigned_to_opponents[action_id] == opponent_id:
			return action_id
	return ""
	

static func get_opponent_with_specific_action(game_state: GameState,action_id: String) -> String:
	if action_id in game_state.actions_assigned_to_opponents.keys():
		return game_state.actions_assigned_to_opponents[action_id]
	return ""

#endregion

#region Validate moving action to opponent.
func action_id_is_valid(action_id: String) -> bool:
	return action_id in AutoloadDatabase.player_actions_by_id.keys()

func opponent_already_has_action(game_state: GameState,opponent_id: String) -> bool:
	for action_id in game_state.actions_assigned_to_opponents.keys():
		if game_state.actions_assigned_to_opponents[action_id] == opponent_id:
			return true
	return false
	
func opponent_is_target_of_action(game_state: GameState,opponent_id: String, action_id: String) -> bool:
	return game_state.actions_assigned_to_opponents[action_id] == opponent_id

static func action_is_in_use(game_state: GameState,action_id: String) -> bool:
	if action_id in game_state.actions_assigned_to_opponents:
		return true
	return false

func player_has_energy_to_move_action(effect_context: EffectContext) -> bool:
	var energy_cost_to_move: int = effect_context.energy_delta
	return energy_cost_to_move <= effect_context.game_state.player["current_energy"]

#endregion



#region MUTATE FUNCTIONS - ONLY MAIN SCRIPT CAN CALL
func _assign_action_to_opponent_(game_state: GameState,action_id: String, opponent_id: String) -> void:
	game_state.actions_assigned_to_opponents[action_id] = opponent_id

func _retract_action(game_state:GameState, action_id: String) -> void:
	game_state.actions_assigned_to_opponents.erase(action_id)

func _clear_opponent_from_all_actions_(game_state: GameState,opponent_id: String) -> void:
	for action_id in game_state.actions_assigned_to_opponents.keys():
		if game_state.actions_assigned_to_opponents[action_id] == opponent_id:
			game_state.actions_assigned_to_opponents.erase(action_id)
			main_game.sound_manager.end_soundtrack_for_player_action(action_id)

func _clear_opponent_from_action_(game_state: GameState,opponent_id: String, action_id: String) -> void:
	if game_state.get_opponent_with_action(action_id) != opponent_id:
		return
	game_state.actions_assigned_to_opponents.erase(action_id)


#endregion
