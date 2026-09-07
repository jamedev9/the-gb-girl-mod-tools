extends RewardDefinition
class_name Reward_UnlockRewardCardForActions

@export var reward_card_ids: String
@export var action_ids: Array[String]

func apply_reward(save_game_state:SaveGameState) -> void:
	for action_id in action_ids:
		save_game_state.unlock_reward_card_for_action(reward_card_ids,action_id)

func reward_is_hidden_from_player(save_game_state: SaveGameState) -> bool:
	for action in action_ids:
		if action not in save_game_state.owned_player_actions:
			return true

	return false

func get_action_ids_required_by_this_reward() -> Array[String]:
	return action_ids
