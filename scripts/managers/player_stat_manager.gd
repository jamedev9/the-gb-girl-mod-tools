extends GameManager
class_name PlayerStatsManager

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

signal player_damage_exceeds_threshold

#region Mutating game state: Only Main Script can call

static func _drain_player_energy_from_moving_action_(effect_context: EffectContext) -> void:
	var move_energy_cost: int = max(effect_context.energy_delta,0) #Never gain energy from moving actions
	effect_context.game_state.player["current_energy"] -= move_energy_cost
	PlayerStatsManager._increase_player_energy_spend_this_round(effect_context.game_state,move_energy_cost)

static func _increase_player_energy_spend_this_round(game_state:GameState, energy_delta: int) -> void:
	game_state.player["energy_spent_this_round"] += energy_delta

func _restore_player_energy_on_turn_start_(game_state:GameState) ->  void:
	PlayerStatsManager._reset_player_energy_spent_this_round_(game_state)
	var new_energy: int = PlayerStatsManager.get_player_energy_next_round(game_state)
	game_state.player["current_energy"] = new_energy

static func _reset_player_energy_spent_this_round_(game_state:GameState) ->  void:
	game_state.player["energy_spent_this_round"] = 0

func _mutate_player_damage_value_(game_state: GameState, damage_delta: int) -> void:
	if game_state.player["current_damage"] + damage_delta > 0:
		game_state.player["current_damage"] += damage_delta
	elif game_state.player["current_damage"] + damage_delta <= 0:
		game_state.player["current_damage"] = 0
		
	if game_state.player["current_damage"] >= game_state.player["damage_threshold"]:
		emit_signal("player_damage_exceeds_threshold")

func _reduce_player_HP_(game_state: GameState, hp_reduction: int) -> void:
	game_state.player["hp"] -= hp_reduction
func _increase_player_HP_(game_state: GameState, hp_increase: int) -> void:
	game_state.player["hp"] += hp_increase

func _reset_player_damage_taken_(game_state:GameState) -> void:
	game_state.player["current_damage"] = 0

func _drain_player_energy_(game_state:GameState, energy_reduction: int) -> void:
	var new_energy: int = game_state.player["current_energy"] - energy_reduction
	if new_energy < 0:
		game_state.player["current_energy"] = 0
		return
	game_state.player["current_energy"] = new_energy

#endregion

#region Public queries:
static func get_energy_spent_this_round(game_state:GameState) -> int:
	return game_state.player["energy_spent_this_round"]

static func get_player_energy_next_round(game_state:GameState) -> int:
	var energy_used_to_maintain_actions: int = ActionManager.get_current_action_upkeep(game_state)
	#var energy_spent_this_round: int = PlayerStatsManager.get_energy_spent_this_round(game_state)
	var energy_reduction_from_statuses: int = StatusEffectManager.get_energy_reduction_from_statuses(game_state)
	var energy_next_round: int = game_state.player["max_energy"] - energy_used_to_maintain_actions - energy_reduction_from_statuses
	if energy_next_round < 0:
		return 0
	return energy_next_round

func player_has_energy_to_play_event_card(game_state:GameState,_context:EffectContext,event_card_instance:EventCardInstance) -> bool:
	return game_state.player["current_energy"] >= AutoloadDatabase.event_cards_by_id[event_card_instance.card_id].energy_cost

func player_can_pay_energy_cost(player_entity: PlayerEntity,energy_delta: int) -> bool:
	return player_entity.get_player_energy() + energy_delta >= 0

func get_player_damage(game_state: GameState) -> int:
	return int(game_state.player["current_damage"])
	
func get_player_hp(game_state: GameState) -> int:
	return int(game_state.player["hp"])
	
func get_player_current_energy(game_state: GameState) -> int:
	return int(game_state.player["current_energy"])


#endregion
