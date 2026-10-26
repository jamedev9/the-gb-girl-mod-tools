@tool
extends RewardDefinition
class_name Reward_GiveAndRemovePlayerPassives

@export var passives_to_add: Dictionary[String,bool] # passive ID : Starts active or not
@export var passives_to_remove: Array[String]

func get_referenced_content_ids() -> Dictionary:
	var passive_ids: Array = passives_to_add.keys()
	passive_ids.append_array(passives_to_remove)
	return {"passives": passive_ids}

func apply_reward(save_game_state: SaveGameState) -> void:
	#var passive: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions[passive_id]
	for passive_id in passives_to_add.keys():
		save_game_state.give_player_passive(passive_id,passives_to_add[passive_id])
	
	for passive_id in passives_to_remove:
		save_game_state.remove_passive_from_player(passive_id)
