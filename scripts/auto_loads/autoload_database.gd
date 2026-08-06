extends Node
class_name GlobalAutoloadDatabase

const MODS_ROOT: String = "user://mods" ### Root path to where the mods are stored.
const EXCLUDED_ENCOUNTER_IDS_IN_RELEASE: Array[String] = ["test"] ### use the actual encounter_id value, not a filename

@onready var status_effects_by_id: Dictionary[String,StatusEffectDefinition] = _load_status_effects()
 #{
	#"weak": load("res://object_classes/status_effects/WeakDebuff.tres"),
	#"burn": load("res://object_classes/status_effects/BurnDoT.tres"),
	#"ironskin": load("res://object_classes/status_effects/IronSkinBuff.tres"),
	#"targetready": load("res://object_classes/status_effects/ReduceMoveCostToTarget.tres"),
	#"deal_double_damage": load("res://object_classes/status_effects/DoubleDamage.tres"),
	#"invert_damage": load("res://object_classes/status_effects/InvertDamage.tres"),
	#"spit_lube": load("res://object_classes/status_effects/SpitLube.tres")
#}
func _load_status_effects() -> Dictionary[String,StatusEffectDefinition]:
	var resource_dict: Dictionary[String,StatusEffectDefinition] = {}
	var all_resources: Array = Utils.get_files_in_folder("res://object_classes/status_effects/",".tres",[".uid",".remap"])
	for path in all_resources:
		var resource: StatusEffectDefinition = load(path)
		resource_dict[resource.status_id] = resource
	return resource_dict
func get_status_effect_by_id(status_id: String) -> StatusEffectDefinition:
	if status_id not in status_effects_by_id.keys():
		return null
	return status_effects_by_id[status_id]
	
@onready var player_actions_by_id: Dictionary[String,PlayerAction] = {
	"bj": load("res://object_classes/player_actions/BJ.tres").duplicate(true),
	"vaginal": load("res://object_classes/player_actions/Vaginal.tres").duplicate(true),
	"right_hj": load("res://object_classes/player_actions/RightHJ.tres").duplicate(true),
	"left_hj":load("res://object_classes/player_actions/LeftHJ.tres").duplicate(true),
	"anal": load("res://object_classes/player_actions/Anal.tres").duplicate(true),
	}
func get_player_action_by_id(action_id: String) -> PlayerAction:
	if action_id not in player_actions_by_id.keys():
		return null
	return player_actions_by_id[action_id]

@onready var event_cards_by_id: Dictionary[String,EventCardDefinition] = _load_event_cards()


func get_event_card_def_by_id(card_id: String) -> EventCardDefinition:
	if card_id not in event_cards_by_id.keys():
		return null
	return event_cards_by_id[card_id]

func _load_event_cards() -> Dictionary[String,EventCardDefinition]:
	var card_folders: Array[String] = [
		"res://object_classes/event_cards/event_card_definitions/",
		"res://object_classes/event_cards/problem_event_cards/",
		"res://object_classes/event_cards/combo_event_cards/",
		"res://object_classes/event_cards/reward_event_cards/",
		"res://object_classes/event_cards/orgasm_event_cards/"
	]
	var resource_dict: Dictionary[String,EventCardDefinition] = {}
	for folder in card_folders:
		var resources_in_folder: Array = Utils.get_files_in_folder(folder,".tres",[".uid",".gd",".remap"])
		for path in resources_in_folder:
			var resource: EventCardDefinition = load(path)
			resource_dict[resource.card_type_id] = resource
	return resource_dict
		

@onready var opponent_types: Dictionary[String,OpponentType] = _load_opponents() 
func _load_opponents() -> Dictionary[String,OpponentType]:
	var resource_dict: Dictionary[String,OpponentType] = {}
	var all_resources: Array = Utils.get_files_in_folder("res://object_classes/opponent_types/",".tres",[".uid",".remap"])
	for path in all_resources:
		var resource: OpponentType = load(path)
		resource_dict[resource.opponent_type_id] = resource
	return resource_dict
	
@onready var picture_lists: Dictionary[String, PictureList] = _load_picture_lists()
func _load_picture_lists() -> Dictionary[String, PictureList]:
	var picture_list_folders: Array[String] = [
		"res://resources/picture_lists/cock_pictures/",
	]
	var resource_dict: Dictionary[String,PictureList] = {}
	for folder in picture_list_folders:
		var resources_in_folder: Array = Utils.get_files_in_folder(folder,".tres",[".uid",".gd",".remap"])
		for path in resources_in_folder:
			var resource: PictureList = load(path)
			resource_dict[resource.id] = resource
	return resource_dict
	
func get_picture_list(list_id: String) -> PictureList:
	if list_id not in picture_lists:
		return null
	return picture_lists[list_id]

@onready var opponent_actions: Dictionary[String,OpponentActionDefinition] = _load_opponent_actions()
func _load_opponent_actions() -> Dictionary[String,OpponentActionDefinition]:
	var resource_dict: Dictionary[String,OpponentActionDefinition] = {}
	var all_resources: Array = Utils.get_files_in_folder("res://object_classes/opponent_actions/",".tres",[".uid",".remap"])
	for path in all_resources:
		var resource: OpponentActionDefinition = load(path)
		resource_dict[resource.opponent_action_id] = resource
	return resource_dict
func get_opponent_action_by_id(action_id: String) -> OpponentActionDefinition:
	return opponent_actions[action_id]

@onready var passive_effect_definitions: Dictionary[String,PassiveEffectDefinition] = _load_passive_effects()
func _load_passive_effects() -> Dictionary[String,PassiveEffectDefinition]:
	var resource_dict: Dictionary[String,PassiveEffectDefinition] = {}
	var all_resources: Array = Utils.get_files_in_folder("res://object_classes/passive_effects/passive_effect_resources/",".tres",[".uid",".remap"])
	for path in all_resources:
		var resource: PassiveEffectDefinition = load(path)
		resource_dict[resource.passive_id] = resource
	return resource_dict
func get_passive_effect_def(passive_effect_id: String) -> PassiveEffectDefinition:
	if passive_effect_id not in passive_effect_definitions.keys():
		return null
	return passive_effect_definitions[passive_effect_id]

@onready var encounter_definitions: Dictionary[String,EncounterDefinition] = _load_encounters()
func _load_encounters() -> Dictionary[String,EncounterDefinition]:
	var encounter_defs: Dictionary[String,EncounterDefinition] = {}
	var filter_strings: Array[String] = [".uid",".remap"]
	var all_encounters: Array = Utils.get_files_in_folder("res://object_classes/meta_game_objects/encounter_definitions/",".tres",filter_strings)
	for encounter_path in all_encounters:
		var encounter_def: EncounterDefinition = load(encounter_path)
		if not encounter_def:
			push_warning("Failed to load encounter at path: %s" % encounter_path)
			continue
		if not OS.is_debug_build() and encounter_def.encounter_id in EXCLUDED_ENCOUNTER_IDS_IN_RELEASE:
			continue
		encounter_defs[encounter_def.encounter_id] = encounter_def
	return encounter_defs

func get_encounter_def_by_id(encounter_id: String) -> EncounterDefinition:
	if encounter_id not in encounter_definitions.keys():
		return null
	return encounter_definitions[encounter_id]
	
@onready var unlock_rewards = _load_unlock_rewards()
func _load_unlock_rewards() -> Dictionary[String,RewardDefinition]:
	var reward_folders: Array[String] = [
		"res://object_classes/meta_game_objects/reward_definition/",
		"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/",
		"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/anal/",
		"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/bj/",
		"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/hjs/",
		"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/vaginal/",
		"res://object_classes/meta_game_objects/reward_definition/character_unlocks/"
		
	]
	var reward_defs: Dictionary[String,RewardDefinition] = {}
	var all_files: Array
	for path in reward_folders:
		all_files.append_array(Utils.get_files_in_folder(path,".tres",[".uid",".remap"]))
	#var all_files: Array = Utils.get_files_in_folder("res://object_classes/meta_game_objects/reward_definition/",".tres",[".uid",".remap"])
	for file_path in all_files:
		var reward_def: RewardDefinition = load(file_path)
		reward_defs[reward_def.reward_id] = reward_def
	return reward_defs

func get_unlock_reward_definition(reward_id: String) -> RewardDefinition:
	if reward_id not in unlock_rewards.keys():
		return null
	return unlock_rewards[reward_id]

@onready var action_progress_definitions: Dictionary[String,ActionProgressionDefinition] = _load_action_progress_defs()

func _load_action_progress_defs() -> Dictionary[String,ActionProgressionDefinition]:
	var resource_dict: Dictionary[String,ActionProgressionDefinition] = {}
	var all_resources: Array = Utils.get_files_in_folder("res://object_classes/player_actions/action_progression_definitions/",".tres",[".uid",".remap"])
	for path in all_resources:
		var resource: ActionProgressionDefinition = load(path)
		for action_id in resource.action_ids:
			resource_dict[action_id] = resource
	return resource_dict

func get_next_reward_for_action(save_game_state: SaveGameState,action_id: String) -> String:
	#print("Running get_next_reward_for_action for acition: %s"%action_id)
	var action_progression_definition: ActionProgressionDefinition = get_action_progression_def(action_id)
	if not action_progression_definition:
		#print("No action progression found")
		return ""
	var next_reward_id: String = action_progression_definition.get_next_reward_id(save_game_state)
	return next_reward_id

func get_action_progression_def(action_id: String) -> ActionProgressionDefinition:
	if action_id not in action_progress_definitions.keys():
		return null
	return action_progress_definitions[action_id]

func get_guys_needed_for_reward(action_id: String,next_reward_unlock_id: String) -> int:
	var action_progression_definition: ActionProgressionDefinition = get_action_progression_def(action_id)
	if not action_progression_definition:
		return 0
	return action_progression_definition.get_count_for_reward(next_reward_unlock_id)

@onready var rewards_requiring_encounters: Dictionary[String,Array] = _cache_reward_unlocking_from_encounters() #Encounter_id, Array[RewardIDs]
func _cache_reward_unlocking_from_encounters() -> Dictionary[String,Array]:
	var reward_encounter_dict: Dictionary[String,Array] = {}
	for encounter_id in encounter_definitions.keys():
		var rewards_needing_encounter: Array[String] = []
		for reward_id in unlock_rewards.keys():
			var reward_def = unlock_rewards[reward_id]
			var unlock_conditions: Array[UnlockCondition] = reward_def.unlock_conditions
			for condition in unlock_conditions:
				match condition.get_script():
					Condition_IsEncounterCleared:
						if condition.encounter_id == encounter_id:
							rewards_needing_encounter.append(reward_id)
					Condition_OnlyUseCertainActionsForGivenEncounter:
						if condition.encounter_id == encounter_id:
							rewards_needing_encounter.append(reward_id)
					Condition_ClearGivenEncounterWithoutUsingSpecifiedActions:
						if condition.encounter_id == encounter_id:
							rewards_needing_encounter.append(reward_id)
					Condition_OrgasmNTimesAndWinEncounter:
						if condition.encounter_id == encounter_id:
							rewards_needing_encounter.append(reward_id)
					Condition_SimultaneousCumInGivenEncounter:
						if condition.encounter_id == encounter_id:
							rewards_needing_encounter.append(reward_id)
					Condition_PlayCardsGivenTimeInEncounter:
						if condition.encounter_id == encounter_id:
							rewards_needing_encounter.append(reward_id)
					Condition_WinByTurnN:
						if condition.encounter_id == encounter_id:
							rewards_needing_encounter.append(reward_id)
					Condition_WinEncounterWithActivePassive:
						if condition.encounter_id == encounter_id:
							rewards_needing_encounter.append(reward_id)
		reward_encounter_dict[encounter_id] = rewards_needing_encounter
	return reward_encounter_dict
func get_rewards_requiring_encounter_to_unlock(query_encounter_id:String) -> Array[String]:
	return rewards_requiring_encounters[query_encounter_id]
	
### Map:
#var start_encounters: Array[String] = ["college_dorm"	]
var start_encounters: Array[String] = ["college_dorm","test"]

var encounter_prereq_graph: Dictionary[String, Array]
# encounter_id -> encounters required to unlock it
var encounter_forward_graph: Dictionary[String, Array]
# encounter_id -> encounters unlocked by it
var encounter_depth: Dictionary[String, int]
var max_depth: int
var encounters_by_depth: Dictionary[int,Array] = {}
func _init_graphs() -> void:
	encounter_prereq_graph.clear()
	encounter_forward_graph.clear()

	for encounter_id in encounter_definitions.keys():
		encounter_prereq_graph[encounter_id] = []
		encounter_forward_graph[encounter_id] = []

func _build_graph_edges() -> void:
	_init_graphs()
	for encounter_def in encounter_definitions.values():
		var target_id : String= encounter_def.encounter_id
		for condition in encounter_def.unlock_conditions:
			if condition is Condition_IsEncounterCleared:
				var prereq_id : String= condition.encounter_id
				# Defensive check (very useful during iteration)
				if not encounter_definitions.has(prereq_id):
					push_warning(
						"Encounter '%s' depends on missing encounter '%s'"
						% [target_id, prereq_id]
					)
					continue
				encounter_prereq_graph[target_id].append(prereq_id)
				encounter_forward_graph[prereq_id].append(target_id)

func is_encounter_playable(encounter_id: String, save: SaveGameState) -> bool:
	for prereq_id in encounter_prereq_graph[encounter_id]:
		if prereq_id not in save.encounters_completed.keys():
			return false
	return true
func _init_depths() -> void:
	encounter_depth.clear()
func _compute_depth(encounter_id: String, visiting: Dictionary[String, bool]) -> int:
	# Memoized result
	if encounter_depth.has(encounter_id):
		return encounter_depth[encounter_id]
	# Cycle detection (should never happen, but protects you)
	if visiting.get(encounter_id, false):
		push_error("Cycle detected in encounter graph at: %s" % encounter_id)
		return 0

	visiting[encounter_id] = true
	var prereqs: Array = encounter_prereq_graph[encounter_id]
	var depth := 0
	if prereqs.size() > 0:
		var max_prereq_depth := 0
		for prereq_id in prereqs:
			var prereq_depth := _compute_depth(prereq_id, visiting)
			max_prereq_depth = max(max_prereq_depth, prereq_depth)
		depth = max_prereq_depth + 1
	encounter_depth[encounter_id] = depth
	visiting[encounter_id] = false
	max_depth = depth
	return depth
func _compute_all_depths() -> void:
	_init_depths()
	for encounter_id in encounter_definitions.keys():
		_compute_depth(encounter_id, {})
func _assign_encounter_ids_to_depth() -> void:
	for i in range(max_depth):
		var encounter_ids: Array = []
		for encounter_id in encounter_depth.keys():
			if encounter_depth[encounter_id] == i:
				encounter_ids.append(encounter_id)
		encounters_by_depth[i] = encounter_ids

@onready var map_region_definitions: Dictionary[String,MapRegionDefinition] = _load_map_regions()
func _load_map_regions() -> Dictionary[String,MapRegionDefinition]:
	var resource_dict: Dictionary[String,MapRegionDefinition] = {}
	var all_resources: Array = Utils.get_files_in_folder("res://object_classes/meta_game_objects/map_region_definitions/",".tres",[".uid",".remap"])
	for path in all_resources:
		var resource: MapRegionDefinition = load(path)
		resource_dict[resource.region_id] = resource
	return resource_dict
func get_map_region_by_id(region_id: String) -> MapRegionDefinition:
	if region_id not in map_region_definitions.keys():
		return null
	return map_region_definitions[region_id]
	
#@onready var tutorial_stages: Dictionary[String, TutorialStage] = _load_tutorial_regions()
#func _load_tutorial_regions() -> Dictionary[String, TutorialStage]:
	#var resource_dict: Dictionary[String,TutorialStage] = {}
	#var all_resources: Array = Utils.get_files_in_folder("res://resources/tutorial_stages/",".tres",[".uid",".remap"])
	#for path in all_resources:
		#var resource: TutorialStage = load(path)
		#resource_dict[resource.stage_id] = resource
	#return resource_dict
#func get_tutorial_stage_by_id(id: String) -> TutorialStage:
	#return tutorial_stages[id]

@onready var character_definitions: Dictionary[String,CharacterDefinition] = _load_character_definitions()
func _load_character_definitions() -> Dictionary[String,CharacterDefinition]:
	var resource_dict: Dictionary[String,CharacterDefinition] = {}
	var all_resources: Array = Utils.get_files_in_folder("res://object_classes/run_defining_objects/character_definitions/",".tres",[".uid",".remap"])
	for path in all_resources:
		var resource: CharacterDefinition = load(path)
		print("Loaded character preset: %s"%resource.character_id)
		resource_dict[resource.character_id] = resource
	
	_load_character_from_mods(resource_dict)
	
	return resource_dict

func _load_character_from_mods(resource_dict: Dictionary) -> void:
	var dir = DirAccess.open(MODS_ROOT)
	if dir:
		dir.list_dir_begin()
		var folder_name = dir.get_next()
		while folder_name != "":
			if dir.current_is_dir():
				print("Found mod directory: " + folder_name)
				var characters_folder =  MODS_ROOT+"/"+folder_name+"/characters/"
				print("Character folder path: %s"%characters_folder)
				if not DirAccess.dir_exists_absolute(characters_folder):
					print("No characters folder found")
					folder_name = dir.get_next()
					continue
				print("Found characters folder! Looking for .json files")
				var json_files = Utils.get_files_in_folder(characters_folder,"json")
				print("Found these json files:")
				for file in json_files:
					print(file)
					var char_def = load_character_from_mod(folder_name,file)
					if char_def is not CharacterDefinition:
						continue
					char_def.is_modded = true
					resource_dict[char_def.character_id] = char_def
					
			folder_name = dir.get_next()
		


func load_character_from_mod(mod_name: String, json_path: String) -> CharacterDefinition:
	var mod_characters_dir: String = MODS_ROOT.path_join(mod_name).path_join("images")

	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Could not open mod character file: %s" % json_path)
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid JSON in mod character file: %s" % json_path)
		return null

	return CharacterDefinition.from_json_dict(parsed, mod_characters_dir)


func get_character_definition_by_id(character_id: String) -> CharacterDefinition:
	return character_definitions[character_id]
func get_all_character_definitions() -> Array[CharacterDefinition]:
	var defs: Array[CharacterDefinition] = []
	for key in character_definitions.keys():
		defs.append(character_definitions[key])
	return defs

func _ready() -> void:
	_init_graphs()
	_build_graph_edges()
	_compute_all_depths()
	_assign_encounter_ids_to_depth()
