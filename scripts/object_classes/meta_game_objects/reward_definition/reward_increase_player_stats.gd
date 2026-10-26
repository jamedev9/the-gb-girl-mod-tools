@tool
extends RewardDefinition
class_name Reward_IncreasePlayerStats

@export var hp_increase: int = 0
@export var damage_threshold_increase: int = 0
@export var max_energy_increase: int = 0

func apply_reward(save_game_state: SaveGameState) -> void:
	var stat_increase_dict: Dictionary[String, int] = {
	"hp_increase": hp_increase,
	"damage_threshold_increase": damage_threshold_increase,
	"max_energy_increase":max_energy_increase,
}
	save_game_state.increase_player_stats(stat_increase_dict)
