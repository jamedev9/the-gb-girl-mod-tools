@tool
extends RewardDefinition
class_name Reward_UnlockAllyForPlayer

@export var ally_card_id: String #Event card ID

func get_referenced_content_ids() -> Dictionary:
	return {"cards": [ally_card_id]}

func apply_reward(save_game_state: SaveGameState) -> void:
	save_game_state.give_player_new_ally_card(ally_card_id)
