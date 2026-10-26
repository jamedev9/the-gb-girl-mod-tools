@tool
extends RewardDefinition
class_name Reward_GivePlayerPassive

@export var passive_id: String
@export var starts_enabled: bool = true

func get_referenced_content_ids() -> Dictionary:
	return {"passives": [passive_id]}

func apply_reward(save_game_state: SaveGameState) -> void:
	#var passive: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions[passive_id]
	save_game_state.give_player_passive(passive_id,starts_enabled)
