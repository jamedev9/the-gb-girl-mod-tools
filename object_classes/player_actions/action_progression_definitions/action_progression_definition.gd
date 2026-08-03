extends Resource
class_name ActionProgressionDefinition

@export var action_ids: Array[String] ### can be just one or multiple (for HJ's

### int: number required, Reward ID: What is awarded when the number is reached
@export var rewards_per_guy_defeated: Dictionary[String,int] = {}

### Challenges that award stuff related to this action. String: Id of reward.
@export var action_related_rewards: Array[String]

func get_rewards_that_should_be_unlocked(save_game_state: SaveGameState) -> Array[String]:
	var rewards_ids: Array[String]
	var defeat_count: int = 0
	for action in action_ids:
		defeat_count += save_game_state.get_opponents_defeated_by_action(action)
	
	#for defeat_requirement in rewards_per_guy_defeated.keys():
		#if defeat_count >= defeat_requirement:
			#rewards_ids.append(rewards_per_guy_defeated[defeat_requirement])
	for reward_id in rewards_per_guy_defeated.keys():
		if defeat_count >= rewards_per_guy_defeated[reward_id]:
			rewards_ids.append(reward_id)
	
	return rewards_ids

#func get_next_reward_id(save_game_state: SaveGameState) -> String:
	#var defeat_count: int = 0
	#for action in action_ids:
		#defeat_count += save_game_state.get_opponents_defeated_by_action(action)
	#
	#var difference_dict: Dictionary[String,int] = {}
	#
	#for reward_id in rewards_per_guy_defeated.keys():
		#if defeat_count < rewards_per_guy_defeated[reward_id]:
			#difference_dict[reward_id] = rewards_per_guy_defeated[reward_id] - defeat_count
	#
	#if difference_dict.is_empty():
		#print("There were no rewards left to unlock for: %s"%action_ids)
		#return ""
	#var smallest_dif: int
	#var current_smallest: String = ""
	#for reward_id in difference_dict.keys():
		#if not smallest_dif:
			#smallest_dif = difference_dict[reward_id]
		#if difference_dict[reward_id] < smallest_dif:
			#smallest_dif = difference_dict[reward_id]
			#current_smallest = reward_id
	#
	#print("Smallest reward id returned: %s"%current_smallest)
	#return current_smallest

func get_next_reward_id(save_game_state: SaveGameState) -> String:
	var defeat_count: int = 0
	for action in action_ids:
		defeat_count += save_game_state.get_opponents_defeated_by_action(action)
	
	var difference_dict: Dictionary[String,int] = {}
	
	for reward_id in rewards_per_guy_defeated.keys():
		if defeat_count < rewards_per_guy_defeated[reward_id]:
			difference_dict[reward_id] = rewards_per_guy_defeated[reward_id] - defeat_count
	
	if difference_dict.is_empty():
		#print("There were no rewards left to unlock for: %s"%action_ids)
		return ""
	
	var smallest_dif: int = -1
	var current_smallest: String = ""
	for reward_id in difference_dict.keys():
		if smallest_dif == -1 or difference_dict[reward_id] < smallest_dif:
			smallest_dif = difference_dict[reward_id]
			current_smallest = reward_id
	
	#print("Smallest reward id returned: %s"%current_smallest)
	return current_smallest

func get_count_for_reward(reward_id: String) -> int:
	if reward_id not in rewards_per_guy_defeated.keys():
		return 0
	return rewards_per_guy_defeated[reward_id]

func get_count_required_for_next_reward(save_game_state: SaveGameState) -> int:
	var defeat_count: int = 0
	for action in action_ids:
		defeat_count += save_game_state.get_opponents_defeated_by_action(action)
	
	var difference_dict: Dictionary[String,int] = {}
	
	for reward_id in rewards_per_guy_defeated.keys():
		if defeat_count < rewards_per_guy_defeated[reward_id]:
			difference_dict[reward_id] = rewards_per_guy_defeated[reward_id] - defeat_count
	
	if difference_dict.is_empty():
		return 0
	var smallest_dif: int
	#var current_smallest: String = ""
	
	for reward_id in difference_dict.keys():
		if not smallest_dif:
			smallest_dif = difference_dict[reward_id]
		if difference_dict[reward_id] < smallest_dif:
			smallest_dif = difference_dict[reward_id]
			#current_smallest = reward_id
			
	return 0


func get_current_count_for_reward(save_game_state: SaveGameState) -> int:
	var count: int = 0
	for action in action_ids:
		count += save_game_state.get_opponents_defeated_by_action(action)
	return count
