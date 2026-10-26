@tool
extends RewardDefinition
class_name Reward_UnlockNewCharacterForPlayerProgression

@export var character_id: String

func get_referenced_content_ids() -> Dictionary:
	return {"characters": [character_id]}

func apply_reward(_save_game_state: SaveGameState) -> void:
	SaveSystem.unlock_character(character_id)

func reward_is_hidden_from_player(_save_game_state: SaveGameState) -> bool:
	return SaveSystem.is_character_unlocked(character_id)

func is_reward_disabled_for_player(_save_game_state: SaveGameState) -> bool:
	return SaveSystem.is_character_unlocked(character_id)
