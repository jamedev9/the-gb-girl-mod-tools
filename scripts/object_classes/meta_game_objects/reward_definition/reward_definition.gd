extends Resource
class_name RewardDefinition

@export var reward_id: String
@export var reward_name: String
@export var reward_description: String
@export var reward_picture: Texture2D
@export var repeatable: bool = false
@export var unlock_conditions: Array[UnlockCondition]

func get_reward_name() -> String:
	return tr("REWARDDEFINITION_"+reward_id.to_upper()+"_REWARD_NAME")
func get_description() -> String:
	return tr("REWARDDEFINITION_"+reward_id.to_upper()+"_REWARD_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	var prefix: String = "REWARDDEFINITION_"+reward_id.to_upper()
	return [
		{"key": prefix+"_REWARD_NAME", "text": reward_name},
		{"key": prefix+"_REWARD_DESCRIPTION", "text": reward_description},
	]

func are_all_conditions_met(save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	#print("Running are_all_conditions_met for reward: %s"%reward_id)
	if unlock_conditions.is_empty():
		return false
	
	if is_reward_disabled_for_player(save_game_state):
		return false
	
	for condition in unlock_conditions:
		if not condition.is_condition_met(save_game_state,encounter_report):
			#print("Found this condition is not true: %s"%condition.description)
			return false

	return true
	

func apply_reward(_save_game_state:SaveGameState) -> void:
	#Overwritten by children
	pass


func reward_is_hidden_from_player(save_game_state: SaveGameState) -> bool:
	### This is where we check to display the reward to the player or not.
	### Default is false, but return true if conditions are missing
	for condition in unlock_conditions:
		if condition.is_condition_hidden_from_player(save_game_state):
			return true

	return false

func is_reward_disabled_for_player(save_game_state: SaveGameState) -> bool:
	### child classes overwrite
	return false
