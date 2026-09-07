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
var gameplay_keywords_by_id: Dictionary[String,GameplayKeyword] = {}

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
	_load_passive_effect_definitions_from_mods()
	_load_event_card_definitions_from_mods()

	_init_graphs()
	_build_graph_edges()
	_compute_all_depths()
	_assign_encounter_ids_to_depth()
	rewards_requiring_encounters = _cache_reward_unlocking_from_encounters()
	if OS.has_feature("editor"):
		_run_auto_localization_check()
	is_content_loaded = true
	emit_signal("content_packs_loaded")

### === Auto-localization: adds missing translation keys, and updates existing ones whose
### === source text has changed, for new/edited resources ===
### Editor-only - OS.has_feature("editor") is false in every exported build, where res://
### isn't writable anyway. Runs once every registered resource is loaded, diffs each one's
### get_translation_entries() (if it has one - see EffectDefinition/EventCardDefinition/etc)
### against what's already in game.csv. New keys get appended; keys that already exist but
### whose resource text no longer matches the CSV's "en" column get that column refreshed in
### place (other locale columns are left untouched - a changed source string doesn't imply the
### existing translations are wrong, just possibly stale, which is a translator's call).
### The only extra per-launch cost versus the old missing-only check is a string compare per
### entry (already iterating every resource anyway); the CSV is only re-read/rewritten at all
### when there's actually something to add or update, not on every launch. When there is, the
### loaded "en" translation is also rebuilt live and NOTIFICATION_TRANSLATION_CHANGED is
### broadcast (see _rebuild_live_english_translation()) so the change shows up immediately in
### the running game instead of needing a restart.
const GAME_CSV_PATH: String = "res://localization/game.csv"

func _run_auto_localization_check() -> void:
	var existing_rows: Dictionary[String, PackedStringArray] = _read_existing_translation_csv_rows()
	var missing_entries: Dictionary[String, String] = {} ### key -> english text
	var changed_entries: Dictionary[String, String] = {} ### key -> new english text
	for registration in _resource_registrations:
		for resource in registration.target_dict.values():
			if not resource.has_method("get_translation_entries"):
				continue
			for entry in resource.get_translation_entries():
				var key: String = entry.get("key", "")
				var text: String = entry.get("text", "")
				if key == "" or text == "":
					continue
				if existing_rows.has(key):
					var current_en: String = existing_rows[key][1] if existing_rows[key].size() > 1 else ""
					if current_en == text:
						continue
					if changed_entries.has(key) and changed_entries[key] != text:
						push_warning("Auto-localization: key '%s' produced different text from two resources - keeping the first." % key)
						continue
					changed_entries[key] = text
					continue
				if missing_entries.has(key) and missing_entries[key] != text:
					push_warning("Auto-localization: key '%s' produced different text from two resources - keeping the first." % key)
					continue
				missing_entries[key] = text
	### Update before append: the update rewrite is based on existing_rows as read from disk,
	### so it must happen before append adds anything new to the end of that same file.
	if not changed_entries.is_empty():
		_update_changed_translation_keys(existing_rows, changed_entries)
	if not missing_entries.is_empty():
		_append_missing_translation_keys(missing_entries)
	if not changed_entries.is_empty() or not missing_entries.is_empty():
		_rebuild_live_english_translation()

### game.csv is only the *source* for Godot's CSV import step, which produces the compiled
### game.en.translation resource that tr() actually reads at runtime - editing the CSV alone
### doesn't touch what's already loaded, so without this the change wouldn't show up until the
### editor re-imports and the game is restarted.
###
### The loaded game.en.translation is an OptimizedTranslation (a read-only hash/bucket-table
### resource Godot's CSV importer generates for runtime), not a plain Translation - its
### add_message() is a no-op, so patching it in place doesn't work. Adding a second plain
### Translation alongside it isn't reliable either: TranslationServer stores translations in a
### HashSet, and when two translations tie for the same locale, lookup order (and therefore
### which one "wins") is undefined - not simply whichever was added last.
###
### So instead this fully replaces the loaded "en" translation: rebuild a fresh plain Translation
### from the current (just-written) game.csv and swap it in, so there's only ever one "en"
### translation loaded and no ambiguity about which one tr() reads. Then broadcast
### NOTIFICATION_TRANSLATION_CHANGED - the same notification every Cardgame_UI_Element/
### Metagame_UI_Element already listens for on a manual locale switch (see cardgame_UI_element.gd)
### - so visible UI refreshes immediately. Only "en" is rebuilt, matching
### _update_changed_translation_keys() only touching the "en" CSV column.
func _rebuild_live_english_translation() -> void:
	var new_translation := Translation.new()
	new_translation.locale = "en"
	var file := FileAccess.open(GAME_CSV_PATH, FileAccess.READ)
	if not file:
		push_warning("Auto-localization: could not open %s to rebuild live translations." % GAME_CSV_PATH)
		return
	file.get_csv_line() ### header row, discarded
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		new_translation.add_message(row[0], row[1])
	file.close()
	var old_translation: Translation = TranslationServer.get_translation_object("en")
	if old_translation:
		TranslationServer.remove_translation(old_translation)
	TranslationServer.add_translation(new_translation)
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)

func _read_existing_translation_csv_rows() -> Dictionary[String, PackedStringArray]:
	var rows: Dictionary[String, PackedStringArray] = {}
	var file := FileAccess.open(GAME_CSV_PATH, FileAccess.READ)
	if not file:
		push_warning("Auto-localization: could not open %s for reading." % GAME_CSV_PATH)
		return rows
	file.get_csv_line() ### header row, discarded
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 0 or row[0] == "":
			continue
		rows[row[0]] = row
	file.close()
	return rows

func _update_changed_translation_keys(existing_rows: Dictionary[String, PackedStringArray], changed_entries: Dictionary[String, String]) -> void:
	for key in changed_entries.keys():
		existing_rows[key][1] = changed_entries[key]
	var read_file := FileAccess.open(GAME_CSV_PATH, FileAccess.READ)
	if not read_file:
		push_warning("Auto-localization: could not open %s to read header for update." % GAME_CSV_PATH)
		return
	var header: PackedStringArray = read_file.get_csv_line()
	read_file.close()
	var write_file := FileAccess.open(GAME_CSV_PATH, FileAccess.WRITE)
	if not write_file:
		push_warning("Auto-localization: could not open %s for writing." % GAME_CSV_PATH)
		return
	write_file.store_csv_line(header)
	for row in existing_rows.values():
		write_file.store_csv_line(row)
	write_file.close()
	print("[Auto-localization] Updated %d translation key(s) in game.csv: %s" % [changed_entries.size(), ", ".join(changed_entries.keys())])

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
		ResourceRegistration.new(GameplayKeyword, gameplay_keywords_by_id, Callable(self, "_get_gameplay_keyword_keys")),
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

func _get_gameplay_keyword_keys(resource: GameplayKeyword) -> Array:
	return [resource.keyword_id]

func get_gameplay_keyword(keyword_id: String) -> GameplayKeyword:
	return gameplay_keywords_by_id.get(keyword_id, null)

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

func get_action_progression_def_for_reward(reward_id: String) -> ActionProgressionDefinition:
	var checked_progressions: Array[ActionProgressionDefinition] = []
	for progression in action_progress_definitions.values():
		if progression in checked_progressions:
			continue
		checked_progressions.append(progression)
		if reward_id in progression.rewards_per_guy_defeated.keys():
			return progression
	return null

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

### === Mod-loaded passives (JSON, unrelated to the .tres pack scan) ===
func _load_passive_effect_definitions_from_mods() -> void:
	var dir = DirAccess.open(MODS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var passives_folder: String = MODS_ROOT + "/" + folder_name + "/passives/"
			if DirAccess.dir_exists_absolute(passives_folder):
				var json_files = Utils.get_files_in_folder(passives_folder, "json")
				for file in json_files:
					var passive_def = _load_passive_from_mod(folder_name, file)
					if passive_def is not PassiveEffectDefinition:
						continue
					passive_effect_definitions[passive_def.passive_id] = passive_def
		folder_name = dir.get_next()
	dir.list_dir_end()

func _load_passive_from_mod(mod_name: String, json_path: String) -> PassiveEffectDefinition:
	var mod_images_dir: String = MODS_ROOT.path_join(mod_name).path_join("images")

	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Could not open mod passive file: %s" % json_path)
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid JSON in mod passive file: %s" % json_path)
		return null

	return PassiveEffectDefinition.from_json_dict(parsed, mod_images_dir)

### === Mod-loaded event cards (JSON, unrelated to the .tres pack scan) ===
func _load_event_card_definitions_from_mods() -> void:
	var dir = DirAccess.open(MODS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var event_cards_folder: String = MODS_ROOT + "/" + folder_name + "/event_cards/"
			if DirAccess.dir_exists_absolute(event_cards_folder):
				var json_files = Utils.get_files_in_folder(event_cards_folder, "json")
				for file in json_files:
					var card_def = _load_event_card_from_mod(folder_name, file)
					if card_def is not EventCardDefinition:
						continue
					event_cards_by_id[card_def.card_type_id] = card_def
		folder_name = dir.get_next()
	dir.list_dir_end()

func _load_event_card_from_mod(mod_name: String, json_path: String) -> EventCardDefinition:
	var mod_images_dir: String = MODS_ROOT.path_join(mod_name).path_join("images")

	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Could not open mod event card file: %s" % json_path)
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid JSON in mod event card file: %s" % json_path)
		return null

	return EventCardDefinition.from_json_dict(parsed, mod_images_dir)

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
				if condition and "encounter_id" in condition and condition.encounter_id == encounter_id:
					rewards_needing_encounter.append(reward_id)
		reward_encounter_dict[encounter_id] = rewards_needing_encounter
	return reward_encounter_dict

func get_rewards_requiring_encounter_to_unlock(query_encounter_id: String) -> Array[String]:
	return rewards_requiring_encounters[query_encounter_id]
