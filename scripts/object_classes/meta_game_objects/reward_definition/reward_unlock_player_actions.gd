@tool
extends RewardDefinition
class_name Reward_UnlockPlayerActions

@export var action_ids: Array[String]

func get_referenced_content_ids() -> Dictionary:
	return {"actions": action_ids.duplicate()}

func apply_reward(save_game_state: SaveGameState) -> void:
	for action_id in action_ids:
		save_game_state.add_new_player_action(action_id)

func reward_is_hidden_from_player(save_game_state: SaveGameState) -> bool:
	### Owning the actions hides the reward, unless this save unlocked the reward itself: the
	### character that earned it still sees where it came from, one that started with it never does.
	return check_if_player_has_all_actions(save_game_state) and not save_game_state.is_reward_unlocked(reward_id)

func check_if_player_has_all_actions(save_game_state: SaveGameState) -> bool:
	var actions_needed: int = action_ids.size()
	var count: int = 0
	for action in action_ids:
		if action in save_game_state.owned_player_actions:
			count += 1
	if count >= actions_needed:
		return true
	return false
	

func is_reward_disabled_for_player(save_game_state: SaveGameState) -> bool:
	return check_if_player_has_all_actions(save_game_state)
