@tool
extends ModExportable
class_name RewardDefinition

@export var reward_id: String
@export var reward_name: String
@export var reward_description: String
@export var reward_picture: Texture2D
@export var unlock_conditions: Array[UnlockCondition]

### Set by AutoloadDatabase on rewards loaded from a mod's JSON: the text is shown as written instead of going through
### tr() (see EventCardDefinition.is_modded). @export_storage so duplicate() keeps it.
@export_storage var is_modded: bool = false

func get_reward_name() -> String:
	if is_modded:
		return reward_name
	return tr("REWARDDEFINITION_"+reward_id.to_upper()+"_REWARD_NAME")
func get_description() -> String:
	if is_modded:
		return reward_description
	return tr("REWARDDEFINITION_"+reward_id.to_upper()+"_REWARD_DESCRIPTION")

### The description as segments: its {KEYWORD} and {CARD:id}-style tokens become hover links (see DescriptionBuilder.parse_template()
### and DescriptionTerms). Show this with DescriptionLabel.show_segments(), never the raw string.
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(get_description(), {}, get_card_permanence_hints())

### card id -> CardInstance.CardPermanence of the cards this reward unlocks, so a {CARD:id} in its text shows the card the way it looks
### in play (a Reward Card, an Orgasm Card). A card that is not listed looks like a plain deck card. Overridden by the rewards that unlock a card.
func get_card_permanence_hints() -> Dictionary:
	return {}

func get_translation_entries() -> Array[Dictionary]:
	if is_modded:
		return [] ### Mod text is shown as written, and must not be written into game.csv by the editor's auto-localization.
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

	var run_conditions_met: bool = _are_run_conditions_met(save_game_state,encounter_report)

	for condition in unlock_conditions:
		if condition.is_judged_on_a_single_run():
			if not run_conditions_met:
				return false
		elif not condition.is_condition_met(save_game_state,encounter_report):
			#print("Found this condition is not true: %s"%condition.description)
			return false

	return true
	

### The reward's run conditions (UnlockCondition.is_judged_on_a_single_run()) count as met when ONE run met all of them together - the
### way they always had to be - and that is remembered in the save (SaveGameState.remember_run_conditions_met()), so the reward can
### still unlock once its other conditions are met after that run. Judged before the other conditions, whether or not those are met
### yet, since the end of the run is the only moment the report can be seen. A reward without run conditions has nothing to wait for.
func _are_run_conditions_met(save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	var has_run_conditions: bool = false
	var all_met_by_this_run: bool = true
	for condition in unlock_conditions:
		if not condition.is_judged_on_a_single_run():
			continue
		has_run_conditions = true
		if not condition.is_condition_met(save_game_state,encounter_report):
			all_met_by_this_run = false
	if not has_run_conditions:
		return true
	if all_met_by_this_run:
		save_game_state.remember_run_conditions_met(reward_id)
		return true
	return save_game_state.has_met_run_conditions(reward_id)

### Whether the requirement panel should show this condition as met without a report: it is judged on a single run, and a run that
### met all of this reward's run conditions has been remembered. (Conditions that read the save show their own state.)
func is_condition_remembered_as_met(save_game_state: SaveGameState,condition: UnlockCondition) -> bool:
	return condition.is_judged_on_a_single_run() and save_game_state.has_met_run_conditions(reward_id)

func apply_reward(_save_game_state:SaveGameState) -> void:
	#Overwritten by children
	pass

### True for a reward whose apply_reward() changes the save's progressed player actions (player_action_progress /
### player_action_trigger_progress). SaveGameState notes every time such a reward is applied, so an upgrade that an older
### build threw away when it re-saved the file can be rebuilt from rewards_unlocked (SaveGameState._restore_lost_action_progress()).
### Rebuilding means applying the reward again, so apply_reward() must give the same result on every call.
func changes_player_action_progress() -> bool:
	return false


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

#region Mod export
### The content this reward hands out or works on, by kind -> ids: "passives", "cards", "actions", "characters". A mod
### reward naming one that isn't installed is not loaded at all (AutoloadDatabase), so it can never give content that
### doesn't exist. Overridden by every reward class that names content.
func get_referenced_content_ids() -> Dictionary:
	return {}

func get_mod_export_subfolder() -> String:
	return "rewards"

func get_file_reference_fields() -> Dictionary:
	return {"reward_picture": "images"}

### Written by the generic walk (every reward class's own fields are plain data or ids; the unlock conditions are
### ModExportable), with a "_class" tag for the reward class, except the picture: a file reference (see
### get_file_reference_fields()) written as its path. is_modded is set on load, never written.
func _get_fields_excluded_from_generic_json() -> Array[String]:
	return ["reward_picture", "is_modded"]

func to_json_dict() -> Dictionary:
	var result: Dictionary = super.to_json_dict()
	result["reward_picture"] = ModExportable.resolve_to_res_path(reward_picture.resource_path, resource_path) if reward_picture else ""
	return result

### mod_folder_path: the mod's images folder (resolves reward_picture). Builds the reward class the "_class" tag names
### (ModdableResourceRegistry); null when the tag is missing or unknown.
static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> RewardDefinition:
	var reward: RewardDefinition = ModdableResourceRegistry.instantiate(data) as RewardDefinition
	if reward == null:
		return null
	var picture_file_name: String = str(data.get("reward_picture", ""))
	if picture_file_name != "" and mod_folder_path != "":
		reward.reward_picture = Utils.load_texture_from_path(mod_folder_path.path_join(picture_file_name))
	return reward
#endregion
