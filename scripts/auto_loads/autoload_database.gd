extends Node
class_name GlobalAutoloadDatabase

const MODS_ROOT: String = "user://mods" ### Root path to where the mods are stored.
const CONTENT_PACKS_ROOT: String = "res://content_packs/"
const EXCLUDED_ENCOUNTER_IDS_IN_RELEASE: Array[String] = ["test"] ### use the actual encounter_id value, not a filename

class ResourceRegistration:
	var resource_class: Script
	var target_dict: Dictionary
	var key_extractor: Callable ### Callable(Resource) -> Array. Empty array = skip registering this resource.

	func _init(p_resource_class: Script, p_target_dict: Dictionary, p_key_extractor: Callable) -> void:
		resource_class = p_resource_class
		target_dict = p_target_dict
		key_extractor = p_key_extractor

var _resource_registrations: Array[ResourceRegistration] = []

### === Dictionaries populated by the generic pack loader ===
var status_effects_by_id: Dictionary[String,StatusEffectDefinition] = {}
var event_cards_by_id: Dictionary[String,EventCardDefinition] = {}
var opponent_types: Dictionary[String,OpponentType] = {}
var picture_lists: Dictionary[String,PictureList] = {}
var opponent_actions: Dictionary[String,OpponentActionDefinition] = {}
var passive_effect_definitions: Dictionary[String,PassiveEffectDefinition] = {}
var encounter_definitions: Dictionary[String,EncounterDefinition] = {}
var unlock_rewards: Dictionary[String,RewardDefinition] = {}
var action_progress_definitions: Dictionary[String,ActionProgressionDefinition] = {}
var map_region_definitions: Dictionary[String,MapRegionDefinition] = {}
var character_definitions: Dictionary[String,CharacterDefinition] = {}

### === Hardcoded, not part of content packs (left as-is per your call) ===
var player_actions_by_id: Dictionary[String,PlayerAction] = {}

### VideoClips aren't keyed by a unique id (looked up by tag combination instead via
### VideoPlayerSystem), so they don't fit the ResourceRegistration dict pattern above -
### collected as a flat list in the same scan pass instead.
var video_clips: Array[VideoClip] = []

### True once every content-pack resource is loaded and registered (event cards,
### encounters, graphs, etc.) - false while the background load kicked off in _ready()
### is still in progress. Anything that reads from this database (starting/loading a
### game) must wait for this, or for the content_packs_loaded signal.
var is_content_loaded: bool = false
signal content_packs_loaded

var _pending_load_paths: Array[String] = []

## Calls action() immediately if content is already loaded, otherwise waits for
## content_packs_loaded first. Use for anything that reads this database's
## dictionaries and might run before the background load (kicked off in _ready())
## has finished - e.g. code that runs during initial scene setup, before the player
## has clicked anything.
func run_when_content_loaded(action: Callable) -> void:
	if is_content_loaded:
		action.call()
		return
	content_packs_loaded.connect(action, CONNECT_ONE_SHOT)

func _ready() -> void:
	_register_resource_types()
	_begin_loading_all_content_packs()

### Loads every content-pack resource via Godot's threaded ResourceLoader instead of
### blocking synchronously on load() for each of ~650 files in turn - lets the main
### scene (and the main menu within it) appear immediately instead of waiting on this.
### See the main menu scene's _run_when_content_ready() for how callers wait for this to finish.
func _begin_loading_all_content_packs() -> void:
	_pending_load_paths = []
	_collect_tres_paths_recursive(CONTENT_PACKS_ROOT, _pending_load_paths)
	for path in _pending_load_paths:
		ResourceLoader.load_threaded_request(path)
	set_process(true)

func _process(_delta: float) -> void:
	if _pending_load_paths.is_empty():
		set_process(false)
		return
	var still_pending: Array[String] = []
	for path in _pending_load_paths:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var resource: Resource = ResourceLoader.load_threaded_get(path)
				_handle_loaded_content_pack_resource(resource, path)
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				still_pending.append(path)
			_:
				push_warning("Failed to load resource: %s (status %s)" % [path, status])
	_pending_load_paths = still_pending
	if _pending_load_paths.is_empty():
		_finish_loading_content_packs()

func _handle_loaded_content_pack_resource(resource: Resource, path: String) -> void:
	if not resource:
		push_warning("Failed to load resource: %s" % path)
		return
	if resource is PlayerAction:
		### duplicated (unlike other content-pack types) to match prior behavior of the
		### hardcoded loader this replaced - preserved defensively even though no code
		### currently mutates a PlayerAction's fields at runtime.
		resource = resource.duplicate(true)
	if resource is VideoClip:
		video_clips.append(resource)
	_register_resource(resource, path)

func _finish_loading_content_packs() -> void:
	_load_character_definitions_from_mods()

	_init_graphs()
	_build_graph_edges()
	_compute_all_depths()
	_assign_encounter_ids_to_depth()
	rewards_requiring_encounters = _cache_reward_unlocking_from_encounters()
	if OS.has_feature("editor"):
		_run_auto_localization_check()
	is_content_loaded = true
	emit_signal("content_packs_loaded")

### === Auto-localization: adds missing translation keys for new/edited resources ===
### Editor-only - OS.has_feature("editor") is false in every exported build, where res://
### isn't writable anyway. Runs once every registered resource is loaded, diffs each one's
### get_translation_entries() (if it has one - see EffectDefinition/EventCardDefinition/etc)
### against what's already in game.csv, and appends rows for anything missing. English is
### seeded from the resource's own text; other locale columns are left blank for translators.
const GAME_CSV_PATH: String = "res://localization/game.csv"

func _run_auto_localization_check() -> void:
	var existing_keys: Dictionary[String, bool] = _read_existing_translation_csv_keys()
	var missing_entries: Dictionary[String, String] = {} ### key -> english text
	for registration in _resource_registrations:
		for resource in registration.target_dict.values():
			if not resource.has_method("get_translation_entries"):
				continue
			for entry in resource.get_translation_entries():
				var key: String = entry.get("key", "")
				var text: String = entry.get("text", "")
				if key == "" or text == "":
					continue
				if existing_keys.has(key):
					continue
				if missing_entries.has(key) and missing_entries[key] != text:
					push_warning("Auto-localization: key '%s' produced different text from two resources - keeping the first." % key)
					continue
				missing_entries[key] = text
	if missing_entries.is_empty():
		return
	_append_missing_translation_keys(missing_entries)

func _read_existing_translation_csv_keys() -> Dictionary[String, bool]:
	var keys: Dictionary[String, bool] = {}
	var file := FileAccess.open(GAME_CSV_PATH, FileAccess.READ)
	if not file:
		push_warning("Auto-localization: could not open %s for reading." % GAME_CSV_PATH)
		return keys
	file.get_csv_line() ### header row, discarded
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 0 or row[0] == "":
			continue
		keys[row[0]] = true
	file.close()
	return keys

func _append_missing_translation_keys(missing_entries: Dictionary[String, String]) -> void:
	var locale_column_count: int = _get_locale_column_count()
	var file := FileAccess.open(GAME_CSV_PATH, FileAccess.READ_WRITE)
	if not file:
		push_warning("Auto-localization: could not open %s for writing." % GAME_CSV_PATH)
		return
	var needs_leading_newline: bool = false
	if file.get_length() > 0:
		file.seek(file.get_length() - 1)
		needs_leading_newline = file.get_8() != "\n".to_utf8_buffer()[0]
	file.seek_end()
	if needs_leading_newline:
		file.store_line("")
	var added_keys: Array[String] = []
	for key in missing_entries.keys():
		var row: PackedStringArray = PackedStringArray([key, missing_entries[key]])
		for _i in range(locale_column_count - 1): ### -1: "en" already added above
			row.append("")
		file.store_csv_line(row)
		added_keys.append(key)
	file.close()
	print("[Auto-localization] Added %d new translation key(s) to game.csv: %s" % [added_keys.size(), ", ".join(added_keys)])

func _get_locale_column_count() -> int:
	var file := FileAccess.open(GAME_CSV_PATH, FileAccess.READ)
	if not file:
		return 2 ### key + en, safe fallback
	var header: PackedStringArray = file.get_csv_line()
	file.close()
	return header.size() - 1 ### minus the "key" column

### === Registration table: add a new moddable/pack resource type by adding ONE line here ===
func _register_resource_types() -> void:
	_resource_registrations = [
		ResourceRegistration.new(StatusEffectDefinition, status_effects_by_id, Callable(self, "_get_status_effect_keys")),
		ResourceRegistration.new(EventCardDefinition, event_cards_by_id, Callable(self, "_get_event_card_keys")),
		ResourceRegistration.new(OpponentType, opponent_types, Callable(self, "_get_opponent_type_keys")),
		ResourceRegistration.new(PictureList, picture_lists, Callable(self, "_get_picture_list_keys")),
		ResourceRegistration.new(OpponentActionDefinition, opponent_actions, Callable(self, "_get_opponent_action_keys")),
		ResourceRegistration.new(PassiveEffectDefinition, passive_effect_definitions, Callable(self, "_get_passive_effect_keys")),
		ResourceRegistration.new(EncounterDefinition, encounter_definitions, Callable(self, "_get_encounter_keys")),
		ResourceRegistration.new(RewardDefinition, unlock_rewards, Callable(self, "_get_reward_keys")),
		ResourceRegistration.new(ActionProgressionDefinition, action_progress_definitions, Callable(self, "_get_action_progression_keys")),
		ResourceRegistration.new(MapRegionDefinition, map_region_definitions, Callable(self, "_get_map_region_keys")),
		ResourceRegistration.new(CharacterDefinition, character_definitions, Callable(self, "_get_character_keys")),
		ResourceRegistration.new(PlayerAction, player_actions_by_id, Callable(self, "_get_player_action_keys")),
	]

### === Key extractors — one per type, named methods (no inline lambdas) ===
func _get_status_effect_keys(resource: StatusEffectDefinition) -> Array:
	return [resource.status_id]

func _get_event_card_keys(resource: EventCardDefinition) -> Array:
	return [resource.card_type_id]

func _get_opponent_type_keys(resource: OpponentType) -> Array:
	return [resource.opponent_type_id]

func _get_picture_list_keys(resource: PictureList) -> Array:
	return [resource.id]

func _get_opponent_action_keys(resource: OpponentActionDefinition) -> Array:
	return [resource.opponent_action_id]

func _get_passive_effect_keys(resource: PassiveEffectDefinition) -> Array:
	return [resource.passive_id]

func _get_encounter_keys(resource: EncounterDefinition) -> Array:
	if not OS.is_debug_build() and resource.encounter_id in EXCLUDED_ENCOUNTER_IDS_IN_RELEASE:
		return []
	return [resource.encounter_id]

func _get_reward_keys(resource: RewardDefinition) -> Array:
	return [resource.reward_id]

func _get_action_progression_keys(resource: ActionProgressionDefinition) -> Array:
	return resource.action_ids ### one resource can register under multiple keys

func _get_map_region_keys(resource: MapRegionDefinition) -> Array:
	return [resource.region_id]

func _get_character_keys(resource: CharacterDefinition) -> Array:
	return [resource.character_id]

### === Generic pack scanning ===
func _collect_tres_paths_recursive(folder_path: String, out_paths: Array) -> void:
	if not DirAccess.dir_exists_absolute(folder_path):
		return
	out_paths.append_array(Utils.get_files_in_folder(folder_path, ".tres", [".uid",".remap"]))

	var dir := DirAccess.open(folder_path)
	if not dir:
		push_warning("Could not open folder for scanning: %s" % folder_path)
		return
	dir.list_dir_begin()
	var item_name := dir.get_next()
	while item_name != "":
		if dir.current_is_dir() and not item_name.begins_with("."):
			_collect_tres_paths_recursive(folder_path.path_join(item_name) + "/", out_paths)
		item_name = dir.get_next()
	dir.list_dir_end()

func _register_resource(resource: Resource, path: String) -> void:
	for registration in _resource_registrations:
		if is_instance_of(resource, registration.resource_class):
			var keys: Array = registration.key_extractor.call(resource)
			for key in keys:
				if key == null or key == "":
					continue
				if registration.target_dict.has(key):
					push_warning("Duplicate id '%s' — resource at '%s' is overwriting a previously loaded resource with this id." % [key, path])
				registration.target_dict[key] = resource
			return ### matched one registered type, stop checking others
	### No matching type found — silently skipped. This is expected for sub-resources
	### (e.g. TargetingRule/effect component .tres files) that aren't top-level content types.

func _get_player_action_keys(resource: PlayerAction) -> Array:
	return [resource.action_id]

func get_player_action_by_id(action_id: String) -> PlayerAction:
	if action_id not in player_actions_by_id.keys():
		return null
	return player_actions_by_id[action_id]

### === Simple getters, unchanged behavior ===
func get_status_effect_by_id(status_id: String) -> StatusEffectDefinition:
	if status_id not in status_effects_by_id.keys():
		return null
	return status_effects_by_id[status_id]

func get_all_event_cards() -> Dictionary[String,EventCardDefinition]:
	return event_cards_by_id

func get_event_card_def_by_id(card_id: String) -> EventCardDefinition:
	if card_id not in event_cards_by_id.keys():
		return null
	return event_cards_by_id[card_id]

func get_picture_list(list_id: String) -> PictureList:
	if list_id not in picture_lists:
		return null
	return picture_lists[list_id]

func get_opponent_action_by_id(action_id: String) -> OpponentActionDefinition:
	return opponent_actions[action_id]

func get_passive_effect_def(passive_effect_id: String) -> PassiveEffectDefinition:
	if passive_effect_id not in passive_effect_definitions.keys():
		return null
	return passive_effect_definitions[passive_effect_id]

func get_encounter_def_by_id(encounter_id: String) -> EncounterDefinition:
	if encounter_id not in encounter_definitions.keys():
		return null
	return encounter_definitions[encounter_id]

func get_unlock_reward_definition(reward_id: String) -> RewardDefinition:
	if reward_id not in unlock_rewards.keys():
		return null
	return unlock_rewards[reward_id]

func get_next_reward_for_action(save_game_state: SaveGameState,action_id: String) -> String:
	var action_progression_definition: ActionProgressionDefinition = get_action_progression_def(action_id)
	if not action_progression_definition:
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

func get_map_region_by_id(region_id: String) -> MapRegionDefinition:
	if region_id not in map_region_definitions.keys():
		return null
	return map_region_definitions[region_id]

func get_character_definition_by_id(character_id: String) -> CharacterDefinition:
	return character_definitions[character_id]

func get_all_character_definitions() -> Array[CharacterDefinition]:
	var defs: Array[CharacterDefinition] = []
	for key in character_definitions.keys():
		defs.append(character_definitions[key])
	return defs

### === Mod-loaded characters (JSON, unrelated to the .tres pack scan) ===
func _load_character_definitions_from_mods() -> void:
	var dir = DirAccess.open(MODS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var characters_folder: String = MODS_ROOT + "/" + folder_name + "/characters/"
			if DirAccess.dir_exists_absolute(characters_folder):
				var json_files = Utils.get_files_in_folder(characters_folder, "json")
				for file in json_files:
					var char_def = _load_character_from_mod(folder_name, file)
					if char_def is not CharacterDefinition:
						continue
					char_def.is_modded = true
					character_definitions[char_def.character_id] = char_def
		folder_name = dir.get_next()
	dir.list_dir_end()

func _load_character_from_mod(mod_name: String, json_path: String) -> CharacterDefinition:
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

### === Map graph logic — unchanged ===
var start_encounters: Array[String] = ["college_dorm","test"]

var encounter_prereq_graph: Dictionary[String, Array]
var encounter_forward_graph: Dictionary[String, Array]
var encounter_depth: Dictionary[String, int]
var max_depth: int
var encounters_by_depth: Dictionary[int,Array] = {}
var rewards_requiring_encounters: Dictionary[String,Array] = {}

func _init_graphs() -> void:
	encounter_prereq_graph.clear()
	encounter_forward_graph.clear()
	for encounter_id in encounter_definitions.keys():
		encounter_prereq_graph[encounter_id] = []
		encounter_forward_graph[encounter_id] = []

func _build_graph_edges() -> void:
	_init_graphs()
	for encounter_def in encounter_definitions.values():
		var target_id: String = encounter_def.encounter_id
		for condition in encounter_def.unlock_conditions:
			if condition is Condition_IsEncounterCleared:
				var prereq_id: String = condition.encounter_id
				if not encounter_definitions.has(prereq_id):
					push_warning("Encounter '%s' depends on missing encounter '%s'" % [target_id, prereq_id])
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
	if encounter_depth.has(encounter_id):
		return encounter_depth[encounter_id]
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

func get_rewards_requiring_encounter_to_unlock(query_encounter_id: String) -> Array[String]:
	return rewards_requiring_encounters[query_encounter_id]

#extends Node
#class_name GlobalAutoloadDatabase
#
#const MODS_ROOT: String = "user://mods" ### Root path to where the mods are stored.
#const EXCLUDED_ENCOUNTER_IDS_IN_RELEASE: Array[String] = ["test"] ### use the actual encounter_id value, not a filename
#
#@onready var status_effects_by_id: Dictionary[String,StatusEffectDefinition] = _load_status_effects()
 ##{
	##"weak": load("res://object_classes/status_effects/WeakDebuff.tres"),
	##"burn": load("res://object_classes/status_effects/BurnDoT.tres"),
	##"ironskin": load("res://object_classes/status_effects/IronSkinBuff.tres"),
	##"targetready": load("res://object_classes/status_effects/ReduceMoveCostToTarget.tres"),
	##"deal_double_damage": load("res://object_classes/status_effects/DoubleDamage.tres"),
	##"invert_damage": load("res://object_classes/status_effects/InvertDamage.tres"),
	##"spit_lube": load("res://object_classes/status_effects/SpitLube.tres")
##}
#func _load_status_effects() -> Dictionary[String,StatusEffectDefinition]:
	#var resource_dict: Dictionary[String,StatusEffectDefinition] = {}
	#var all_resources: Array = Utils.get_files_in_folder("res://object_classes/status_effects/",".tres",[".uid",".remap"])
	#for path in all_resources:
		#var resource: StatusEffectDefinition = load(path)
		#resource_dict[resource.status_id] = resource
	#return resource_dict
#func get_status_effect_by_id(status_id: String) -> StatusEffectDefinition:
	#if status_id not in status_effects_by_id.keys():
		#return null
	#return status_effects_by_id[status_id]
	#
#@onready var player_actions_by_id: Dictionary[String,PlayerAction] = {
	#"bj": load("res://object_classes/player_actions/BJ.tres").duplicate(true),
	#"vaginal": load("res://object_classes/player_actions/Vaginal.tres").duplicate(true),
	#"right_hj": load("res://object_classes/player_actions/RightHJ.tres").duplicate(true),
	#"left_hj":load("res://object_classes/player_actions/LeftHJ.tres").duplicate(true),
	#"anal": load("res://object_classes/player_actions/Anal.tres").duplicate(true),
	#}
#func get_player_action_by_id(action_id: String) -> PlayerAction:
	#if action_id not in player_actions_by_id.keys():
		#return null
	#return player_actions_by_id[action_id]
#
#@onready var event_cards_by_id: Dictionary[String,EventCardDefinition] = _load_event_cards()
#
#func get_all_event_cards() -> Dictionary[String,EventCardDefinition]:
	#return event_cards_by_id
#
#func get_event_card_def_by_id(card_id: String) -> EventCardDefinition:
	#if card_id not in event_cards_by_id.keys():
		#return null
	#return event_cards_by_id[card_id]
#
#func _load_event_cards() -> Dictionary[String,EventCardDefinition]:
	#var card_folders: Array[String] = [
		#"res://object_classes/event_cards/event_card_definitions/",
		#"res://object_classes/event_cards/problem_event_cards/",
		#"res://object_classes/event_cards/combo_event_cards/",
		#"res://object_classes/event_cards/reward_event_cards/",
		#"res://object_classes/event_cards/orgasm_event_cards/"
	#]
	#var resource_dict: Dictionary[String,EventCardDefinition] = {}
	#for folder in card_folders:
		#var resources_in_folder: Array = Utils.get_files_in_folder(folder,".tres",[".uid",".gd",".remap"])
		#for path in resources_in_folder:
			#var resource: EventCardDefinition = load(path)
			#resource_dict[resource.card_type_id] = resource
	#return resource_dict
		#
#
#@onready var opponent_types: Dictionary[String,OpponentType] = _load_opponents() 
#func _load_opponents() -> Dictionary[String,OpponentType]:
	#var resource_dict: Dictionary[String,OpponentType] = {}
	#var all_resources: Array = Utils.get_files_in_folder("res://object_classes/opponent_types/",".tres",[".uid",".remap"])
	#for path in all_resources:
		#var resource: OpponentType = load(path)
		#resource_dict[resource.opponent_type_id] = resource
	#return resource_dict
	#
#@onready var picture_lists: Dictionary[String, PictureList] = _load_picture_lists()
#func _load_picture_lists() -> Dictionary[String, PictureList]:
	#var picture_list_folders: Array[String] = [
		#"res://resources/picture_lists/cock_pictures/",
	#]
	#var resource_dict: Dictionary[String,PictureList] = {}
	#for folder in picture_list_folders:
		#var resources_in_folder: Array = Utils.get_files_in_folder(folder,".tres",[".uid",".gd",".remap"])
		#for path in resources_in_folder:
			#var resource: PictureList = load(path)
			#resource_dict[resource.id] = resource
	#return resource_dict
	#
#func get_picture_list(list_id: String) -> PictureList:
	#if list_id not in picture_lists:
		#return null
	#return picture_lists[list_id]
#
#@onready var opponent_actions: Dictionary[String,OpponentActionDefinition] = _load_opponent_actions()
#func _load_opponent_actions() -> Dictionary[String,OpponentActionDefinition]:
	#var resource_dict: Dictionary[String,OpponentActionDefinition] = {}
	#var all_resources: Array = Utils.get_files_in_folder("res://object_classes/opponent_actions/",".tres",[".uid",".remap"])
	#for path in all_resources:
		#var resource: OpponentActionDefinition = load(path)
		#resource_dict[resource.opponent_action_id] = resource
	#return resource_dict
#func get_opponent_action_by_id(action_id: String) -> OpponentActionDefinition:
	#return opponent_actions[action_id]
#
#@onready var passive_effect_definitions: Dictionary[String,PassiveEffectDefinition] = _load_passive_effects()
#func _load_passive_effects() -> Dictionary[String,PassiveEffectDefinition]:
	#var resource_dict: Dictionary[String,PassiveEffectDefinition] = {}
	#var all_resources: Array = Utils.get_files_in_folder("res://object_classes/passive_effects/passive_effect_resources/",".tres",[".uid",".remap"])
	#for path in all_resources:
		#var resource: PassiveEffectDefinition = load(path)
		#resource_dict[resource.passive_id] = resource
	#return resource_dict
#func get_passive_effect_def(passive_effect_id: String) -> PassiveEffectDefinition:
	#if passive_effect_id not in passive_effect_definitions.keys():
		#return null
	#return passive_effect_definitions[passive_effect_id]
#
#@onready var encounter_definitions: Dictionary[String,EncounterDefinition] = _load_encounters()
#func _load_encounters() -> Dictionary[String,EncounterDefinition]:
	#var encounter_defs: Dictionary[String,EncounterDefinition] = {}
	#var filter_strings: Array[String] = [".uid",".remap"]
	#var all_encounters: Array = Utils.get_files_in_folder("res://object_classes/meta_game_objects/encounter_definitions/",".tres",filter_strings)
	#for encounter_path in all_encounters:
		#var encounter_def: EncounterDefinition = load(encounter_path)
		#if not encounter_def:
			#push_warning("Failed to load encounter at path: %s" % encounter_path)
			#continue
		#if not OS.is_debug_build() and encounter_def.encounter_id in EXCLUDED_ENCOUNTER_IDS_IN_RELEASE:
			#continue
		#encounter_defs[encounter_def.encounter_id] = encounter_def
	#return encounter_defs
#
#func get_encounter_def_by_id(encounter_id: String) -> EncounterDefinition:
	#if encounter_id not in encounter_definitions.keys():
		#return null
	#return encounter_definitions[encounter_id]
	#
#@onready var unlock_rewards = _load_unlock_rewards()
#func _load_unlock_rewards() -> Dictionary[String,RewardDefinition]:
	#var reward_folders: Array[String] = [
		#"res://object_classes/meta_game_objects/reward_definition/",
		#"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/",
		#"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/anal/",
		#"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/bj/",
		#"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/hjs/",
		#"res://object_classes/meta_game_objects/reward_definition/action_specific_rewards/vaginal/",
		#"res://object_classes/meta_game_objects/reward_definition/character_unlocks/"
		#
	#]
	#var reward_defs: Dictionary[String,RewardDefinition] = {}
	#var all_files: Array
	#for path in reward_folders:
		#all_files.append_array(Utils.get_files_in_folder(path,".tres",[".uid",".remap"]))
	##var all_files: Array = Utils.get_files_in_folder("res://object_classes/meta_game_objects/reward_definition/",".tres",[".uid",".remap"])
	#for file_path in all_files:
		#var reward_def: RewardDefinition = load(file_path)
		#reward_defs[reward_def.reward_id] = reward_def
	#return reward_defs
#
#func get_unlock_reward_definition(reward_id: String) -> RewardDefinition:
	#if reward_id not in unlock_rewards.keys():
		#return null
	#return unlock_rewards[reward_id]
#
#@onready var action_progress_definitions: Dictionary[String,ActionProgressionDefinition] = _load_action_progress_defs()
#
#func _load_action_progress_defs() -> Dictionary[String,ActionProgressionDefinition]:
	#var resource_dict: Dictionary[String,ActionProgressionDefinition] = {}
	#var all_resources: Array = Utils.get_files_in_folder("res://object_classes/player_actions/action_progression_definitions/",".tres",[".uid",".remap"])
	#for path in all_resources:
		#var resource: ActionProgressionDefinition = load(path)
		#for action_id in resource.action_ids:
			#resource_dict[action_id] = resource
	#return resource_dict
#
#func get_next_reward_for_action(save_game_state: SaveGameState,action_id: String) -> String:
	##print("Running get_next_reward_for_action for acition: %s"%action_id)
	#var action_progression_definition: ActionProgressionDefinition = get_action_progression_def(action_id)
	#if not action_progression_definition:
		##print("No action progression found")
		#return ""
	#var next_reward_id: String = action_progression_definition.get_next_reward_id(save_game_state)
	#return next_reward_id
#
#func get_action_progression_def(action_id: String) -> ActionProgressionDefinition:
	#if action_id not in action_progress_definitions.keys():
		#return null
	#return action_progress_definitions[action_id]
#
#func get_guys_needed_for_reward(action_id: String,next_reward_unlock_id: String) -> int:
	#var action_progression_definition: ActionProgressionDefinition = get_action_progression_def(action_id)
	#if not action_progression_definition:
		#return 0
	#return action_progression_definition.get_count_for_reward(next_reward_unlock_id)
#
#@onready var rewards_requiring_encounters: Dictionary[String,Array] = _cache_reward_unlocking_from_encounters() #Encounter_id, Array[RewardIDs]
#func _cache_reward_unlocking_from_encounters() -> Dictionary[String,Array]:
	#var reward_encounter_dict: Dictionary[String,Array] = {}
	#for encounter_id in encounter_definitions.keys():
		#var rewards_needing_encounter: Array[String] = []
		#for reward_id in unlock_rewards.keys():
			#var reward_def = unlock_rewards[reward_id]
			#var unlock_conditions: Array[UnlockCondition] = reward_def.unlock_conditions
			#for condition in unlock_conditions:
				#match condition.get_script():
					#Condition_IsEncounterCleared:
						#if condition.encounter_id == encounter_id:
							#rewards_needing_encounter.append(reward_id)
					#Condition_OnlyUseCertainActionsForGivenEncounter:
						#if condition.encounter_id == encounter_id:
							#rewards_needing_encounter.append(reward_id)
					#Condition_ClearGivenEncounterWithoutUsingSpecifiedActions:
						#if condition.encounter_id == encounter_id:
							#rewards_needing_encounter.append(reward_id)
					#Condition_OrgasmNTimesAndWinEncounter:
						#if condition.encounter_id == encounter_id:
							#rewards_needing_encounter.append(reward_id)
					#Condition_SimultaneousCumInGivenEncounter:
						#if condition.encounter_id == encounter_id:
							#rewards_needing_encounter.append(reward_id)
					#Condition_PlayCardsGivenTimeInEncounter:
						#if condition.encounter_id == encounter_id:
							#rewards_needing_encounter.append(reward_id)
					#Condition_WinByTurnN:
						#if condition.encounter_id == encounter_id:
							#rewards_needing_encounter.append(reward_id)
					#Condition_WinEncounterWithActivePassive:
						#if condition.encounter_id == encounter_id:
							#rewards_needing_encounter.append(reward_id)
		#reward_encounter_dict[encounter_id] = rewards_needing_encounter
	#return reward_encounter_dict
#func get_rewards_requiring_encounter_to_unlock(query_encounter_id:String) -> Array[String]:
	#return rewards_requiring_encounters[query_encounter_id]
	#
#### Map:
##var start_encounters: Array[String] = ["college_dorm"	]
#var start_encounters: Array[String] = ["college_dorm","test"]
#
#var encounter_prereq_graph: Dictionary[String, Array]
## encounter_id -> encounters required to unlock it
#var encounter_forward_graph: Dictionary[String, Array]
## encounter_id -> encounters unlocked by it
#var encounter_depth: Dictionary[String, int]
#var max_depth: int
#var encounters_by_depth: Dictionary[int,Array] = {}
#func _init_graphs() -> void:
	#encounter_prereq_graph.clear()
	#encounter_forward_graph.clear()
#
	#for encounter_id in encounter_definitions.keys():
		#encounter_prereq_graph[encounter_id] = []
		#encounter_forward_graph[encounter_id] = []
#
#func _build_graph_edges() -> void:
	#_init_graphs()
	#for encounter_def in encounter_definitions.values():
		#var target_id : String= encounter_def.encounter_id
		#for condition in encounter_def.unlock_conditions:
			#if condition is Condition_IsEncounterCleared:
				#var prereq_id : String= condition.encounter_id
				## Defensive check (very useful during iteration)
				#if not encounter_definitions.has(prereq_id):
					#push_warning(
						#"Encounter '%s' depends on missing encounter '%s'"
						#% [target_id, prereq_id]
					#)
					#continue
				#encounter_prereq_graph[target_id].append(prereq_id)
				#encounter_forward_graph[prereq_id].append(target_id)
#
#func is_encounter_playable(encounter_id: String, save: SaveGameState) -> bool:
	#for prereq_id in encounter_prereq_graph[encounter_id]:
		#if prereq_id not in save.encounters_completed.keys():
			#return false
	#return true
#func _init_depths() -> void:
	#encounter_depth.clear()
#func _compute_depth(encounter_id: String, visiting: Dictionary[String, bool]) -> int:
	## Memoized result
	#if encounter_depth.has(encounter_id):
		#return encounter_depth[encounter_id]
	## Cycle detection (should never happen, but protects you)
	#if visiting.get(encounter_id, false):
		#push_error("Cycle detected in encounter graph at: %s" % encounter_id)
		#return 0
#
	#visiting[encounter_id] = true
	#var prereqs: Array = encounter_prereq_graph[encounter_id]
	#var depth := 0
	#if prereqs.size() > 0:
		#var max_prereq_depth := 0
		#for prereq_id in prereqs:
			#var prereq_depth := _compute_depth(prereq_id, visiting)
			#max_prereq_depth = max(max_prereq_depth, prereq_depth)
		#depth = max_prereq_depth + 1
	#encounter_depth[encounter_id] = depth
	#visiting[encounter_id] = false
	#max_depth = depth
	#return depth
#func _compute_all_depths() -> void:
	#_init_depths()
	#for encounter_id in encounter_definitions.keys():
		#_compute_depth(encounter_id, {})
#func _assign_encounter_ids_to_depth() -> void:
	#for i in range(max_depth):
		#var encounter_ids: Array = []
		#for encounter_id in encounter_depth.keys():
			#if encounter_depth[encounter_id] == i:
				#encounter_ids.append(encounter_id)
		#encounters_by_depth[i] = encounter_ids
#
#@onready var map_region_definitions: Dictionary[String,MapRegionDefinition] = _load_map_regions()
#func _load_map_regions() -> Dictionary[String,MapRegionDefinition]:
	#var resource_dict: Dictionary[String,MapRegionDefinition] = {}
	#var all_resources: Array = Utils.get_files_in_folder("res://object_classes/meta_game_objects/map_region_definitions/",".tres",[".uid",".remap"])
	#for path in all_resources:
		#var resource: MapRegionDefinition = load(path)
		#resource_dict[resource.region_id] = resource
	#return resource_dict
#func get_map_region_by_id(region_id: String) -> MapRegionDefinition:
	#if region_id not in map_region_definitions.keys():
		#return null
	#return map_region_definitions[region_id]
#
#
#@onready var character_definitions: Dictionary[String,CharacterDefinition] = _load_character_definitions()
#func _load_character_definitions() -> Dictionary[String,CharacterDefinition]:
	#var resource_dict: Dictionary[String,CharacterDefinition] = {}
	#var all_resources: Array = Utils.get_files_in_folder("res://object_classes/run_defining_objects/character_definitions/",".tres",[".uid",".remap"])
	#for path in all_resources:
		#var resource: CharacterDefinition = load(path)
		#print("Loaded character preset: %s"%resource.character_id)
		#resource_dict[resource.character_id] = resource
	#
	#_load_character_from_mods(resource_dict)
	#
	#return resource_dict
#
#func _load_character_from_mods(resource_dict: Dictionary) -> void:
	#var dir = DirAccess.open(MODS_ROOT)
	#if dir:
		#dir.list_dir_begin()
		#var folder_name = dir.get_next()
		#while folder_name != "":
			#if dir.current_is_dir():
				#print("Found mod directory: " + folder_name)
				#var characters_folder =  MODS_ROOT+"/"+folder_name+"/characters/"
				#print("Character folder path: %s"%characters_folder)
				#if not DirAccess.dir_exists_absolute(characters_folder):
					#print("No characters folder found")
					#folder_name = dir.get_next()
					#continue
				#print("Found characters folder! Looking for .json files")
				#var json_files = Utils.get_files_in_folder(characters_folder,"json")
				#print("Found these json files:")
				#for file in json_files:
					#print(file)
					#var char_def = load_character_from_mod(folder_name,file)
					#if char_def is not CharacterDefinition:
						#continue
					#char_def.is_modded = true
					#resource_dict[char_def.character_id] = char_def
					#
			#folder_name = dir.get_next()
		#
#
#
#func load_character_from_mod(mod_name: String, json_path: String) -> CharacterDefinition:
	#var mod_characters_dir: String = MODS_ROOT.path_join(mod_name).path_join("images")
#
	#var file := FileAccess.open(json_path, FileAccess.READ)
	#if not file:
		#push_error("Could not open mod character file: %s" % json_path)
		#return null
#
	#var parsed = JSON.parse_string(file.get_as_text())
	#if parsed == null or not (parsed is Dictionary):
		#push_error("Invalid JSON in mod character file: %s" % json_path)
		#return null
#
	#return CharacterDefinition.from_json_dict(parsed, mod_characters_dir)
#
#
#func get_character_definition_by_id(character_id: String) -> CharacterDefinition:
	#return character_definitions[character_id]
#func get_all_character_definitions() -> Array[CharacterDefinition]:
	#var defs: Array[CharacterDefinition] = []
	#for key in character_definitions.keys():
		#defs.append(character_definitions[key])
	#return defs
#
#func _ready() -> void:
	#_init_graphs()
	#_build_graph_edges()
	#_compute_all_depths()
	#_assign_encounter_ids_to_depth()
