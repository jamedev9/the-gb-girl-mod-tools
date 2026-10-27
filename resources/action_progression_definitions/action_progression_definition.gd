@tool
extends ModExportable
class_name ActionProgressionDefinition

### Registered under each of its Actions (AutoloadDatabase.action_progress_definitions, action id -> this), so an Action
### has at most one progression.
@export var action_ids: Array[String] ### can be just one or multiple (for HJ's

### int: number required, Reward ID: What is awarded when the number is reached
@export var rewards_per_guy_defeated: Dictionary[String,int] = {}

### Challenges that award stuff related to this action. String: Id of reward.
@export var action_related_rewards: Array[String]

### True for a progression loaded from a mod. @export_storage so duplicate() keeps it; never written to JSON.
@export_storage var is_modded: bool = false

func _validate_property(property: Dictionary) -> void:
	ContentIdSuggestions.apply_to_array_property(property, "action_ids", "PlayerAction", "action_id")
	ContentIdSuggestions.apply_to_array_property(property, "action_related_rewards", "RewardDefinition", "reward_id")

func get_rewards_that_should_be_unlocked(save_game_state: SaveGameState) -> Array[String]:
	var rewards_ids: Array[String]
	var defeat_count: int = 0
	for action in action_ids:
		defeat_count += save_game_state.get_opponents_defeated_by_action(action)

	for reward_id in rewards_per_guy_defeated.keys():
		if defeat_count >= rewards_per_guy_defeated[reward_id]:
			rewards_ids.append(reward_id)
	
	return rewards_ids


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

### For the "Available rewards" list: a track reward should only show up once the
### player has one of the track's actions and it's actually next in line - not every
### not-yet-unlocked reward on the track at once.
func is_reward_available_to_show(reward_id: String,save_game_state: SaveGameState) -> bool:
	var player_has_track_action: bool = false
	for action_id in action_ids:
		if action_id in save_game_state.get_owned_player_actions():
			player_has_track_action = true
			break
	if not player_has_track_action:
		return false
	return get_next_reward_id(save_game_state) == reward_id

#region Mod export
func get_mod_export_subfolder() -> String:
	return "action_progressions"

### Generic JSON (plain ids and counts), without the is_modded flag.
func _get_fields_excluded_from_generic_json() -> Array[String]:
	return ["is_modded"]

### Read by hand: JSON numbers come back as floats, and the generic reader passes a dictionary's values on untyped, which the
### int-typed rewards_per_guy_defeated would not take.
static func from_json_dict(data: Dictionary) -> ActionProgressionDefinition:
	var progression: ActionProgressionDefinition = ActionProgressionDefinition.new()
	for action_id in data.get("action_ids", []):
		progression.action_ids.append(str(action_id))
	var rewards: Dictionary = data.get("rewards_per_guy_defeated", {})
	for reward_id in rewards.keys():
		progression.rewards_per_guy_defeated[str(reward_id)] = int(rewards[reward_id])
	for reward_id in data.get("action_related_rewards", []):
		progression.action_related_rewards.append(str(reward_id))
	return progression
#endregion
