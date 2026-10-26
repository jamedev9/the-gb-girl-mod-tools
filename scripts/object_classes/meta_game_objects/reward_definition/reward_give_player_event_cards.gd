@tool
extends RewardDefinition
class_name Reward_GivePlayerEventCards

@export var cards_to_give: Dictionary[String,int] #Event card ID

func get_referenced_content_ids() -> Dictionary:
	return {"cards": cards_to_give.keys()}

func apply_reward(save_game_state: SaveGameState) -> void:
	save_game_state.give_player_cards(cards_to_give)
