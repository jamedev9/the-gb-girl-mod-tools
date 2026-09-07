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

	if not does_player_have_actions_required_for_reward(save_game_state):
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
	if not does_player_have_actions_required_for_reward(save_game_state):
		return true

	for condition in unlock_conditions:
		if condition.is_condition_hidden_from_player(save_game_state):
			return true

	return false

func is_reward_disabled_for_player(save_game_state: SaveGameState) -> bool:
	### child classes overwrite
	return false

#region Action requirements:
### Overridden by subclasses whose own fields represent a genuine action
### prerequisite - e.g. Reward_UnlockRewardCardForActions.action_ids. A subclass
### whose action field represents something this reward *grants* instead
### (e.g. Reward_UnlockPlayerActions.action_ids) must NOT override this, or the
### reward would require owning the very action it exists to unlock.
func get_action_ids_required_by_this_reward() -> Array[String]:
	return []

func does_player_have_actions_required_for_reward(save_game_state: SaveGameState) -> bool:
	var owned_actions: Array = save_game_state.get_owned_player_actions()
	for action_id in _get_required_action_ids():
		if action_id not in owned_actions:
			return false
	return true

func _get_required_action_ids() -> Array[String]:
	var required_action_ids: Array[String] = get_action_ids_required_by_this_reward().duplicate()
	### Only resolve through cards this reward itself grants - a raw action_id/
	### action_ids field on self is subclass-specific (see the hook above) and not
	### safe to read directly here.
	_collect_action_references(self,required_action_ids,false)
	for condition in unlock_conditions:
		if not condition:
			continue
		### Conditions are always requirements, so their own action_id/action_ids
		### fields can be read directly here, unlike on self.
		_collect_action_references(condition,required_action_ids,true)
	return required_action_ids

### Generic scan of an object's exported fields for action/event-card references,
### reusing the codebase's existing naming convention rather than a hardcoded
### per-condition-type list: action_id/action_ids fields, and any "*card*"-named
### field resolved through EventCardDefinition.get_actions_triggered_by_card() to
### catch cards like DoubleVaginal/Blowbang that trigger an action indirectly.
func _collect_action_references(
		object: Object,required_action_ids: Array[String],include_direct_action_fields: bool) -> void:
	for property in object.get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		var property_name: String = property.name
		var value = object.get(property_name)
		if include_direct_action_fields and property_name == "action_id" and value is String:
			_append_action_id(value,required_action_ids)
		elif include_direct_action_fields and property_name == "action_ids" and value is Array:
			for action_id in value:
				_append_action_id(action_id,required_action_ids)
		elif "card" in property_name.to_lower():
			_collect_action_references_from_card_ids(value,required_action_ids)

func _collect_action_references_from_card_ids(value,required_action_ids: Array[String]) -> void:
	var card_ids: Array = []
	if value is String:
		card_ids.append(value)
	elif value is Array:
		card_ids.append_array(value)
	elif value is Dictionary:
		card_ids.append_array(value.keys())
	for card_id in card_ids:
		if card_id is not String or card_id == "":
			continue
		var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
		if not card_def:
			continue
		for action_id in card_def.get_actions_triggered_by_card():
			_append_action_id(action_id,required_action_ids)

func _append_action_id(action_id: String,required_action_ids: Array[String]) -> void:
	if action_id != "" and action_id not in required_action_ids:
		required_action_ids.append(action_id)
#endregion
