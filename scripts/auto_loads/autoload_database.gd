extends Node
class_name GlobalAutoloadDatabase

const MODS_ROOT: String = "user://mods" ### Root path to where the mods are stored.
const CONTENT_PACKS_ROOT: String = "res://content_packs/"
const EXCLUDED_ENCOUNTER_IDS_IN_RELEASE: Array[String] = ["test"] ### use the actual encounter_id value, not a filename
const REWORK_CONTENT_PACK_ROOT: String = "res://content_packs/publishable_rework_content/"
const REWORK_CONTENT_SET_PATH: String = "res://content_packs/publishable_rework_content/rework_content_set.tres"

### The ContentSet Full Rework mode loaded from, or the one whose art Default mode applies when the new-UI
### test scene asks for the rework art (PlayModeSettings.include_rework_content_in_default); otherwise null.
var active_content_set: ContentSet
### The map the player is looking at (set_active_map()); null = the prototype map (Default mode's main map, laid out
### from unlock depth and branch_index). While set, it decides which encounters are on the map, where, and what unlocks
### them (see EncounterMapNode): the graphs below come from its lines, and the encounters' own unlock_conditions are ignored.
var encounter_map: EncounterMap
### The main map's id; a mod map is picked by its EncounterMap.map_id.
const MAIN_MAP_ID: String = ""
### The id of the map the player is looking at: MAIN_MAP_ID or a mod map's map_id.
var active_map_id: String = MAIN_MAP_ID
### The main map: the rework's (ContentSet.encounter_map) in Full Rework; null (the prototype map) in Default mode.
var main_encounter_map: EncounterMap
### Maps added by mods (both modes), by map_id.
var mod_maps: Dictionary[String, EncounterMap] = {}
### The main map's start encounters (start_encounters follows the active map).
var _main_start_encounters: Array[String] = []

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
var music_tracks_by_id: Dictionary[String,MusicTrack] = {}
var name_lists_by_id: Dictionary[String,NameList] = {}
var sound_effects_by_id: Dictionary[String,AudioStreamsForSoundEffect] = {}

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
	### Deferred so the root scene has already set PlayModeSettings.current (its setter runs while
	### the scene is instantiated, which happens after the autoloads' _ready) before we pick what to load.
	call_deferred("_begin_loading_all_content_packs")

### Loads every content-pack resource via Godot's threaded ResourceLoader instead of
### blocking synchronously on load() for each of ~650 files in turn - lets the main
### scene (and the main menu within it) appear immediately instead of waiting on this.
### See the main menu scene's _run_when_content_ready() for how callers wait for this to finish.
### Both modes scan every pack (Default mode skips the rework pack, see _collect_tres_paths_recursive). Full Rework
### keeps only what _is_registered_from_scan() allows, then applies the ContentSet once the scan is done.
func _begin_loading_all_content_packs() -> void:
	_pending_load_paths = []
	if PlayModeSettings.current == PlayModeSettings.Mode.FULL_REWORK:
		_load_content_set_for_full_rework()
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
				if _is_registered_from_scan(resource, path):
					_handle_loaded_content_pack_resource(resource, path)
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				still_pending.append(path)
			_:
				push_warning("Failed to load resource: %s (status %s)" % [path, status])
	_pending_load_paths = still_pending
	if _pending_load_paths.is_empty():
		_finish_loading_content_packs()

### replaces_scanned: a ContentSet entry, registered over what the scan registered under the same id (no duplicate warning).
func _handle_loaded_content_pack_resource(resource: Resource, path: String, replaces_scanned: bool = false) -> void:
	if not resource:
		push_warning("Failed to load resource: %s" % path)
		return
	if resource is PlayerAction:
		### duplicated (unlike other content-pack types) to match prior behavior of the
		### hardcoded loader this replaced - preserved defensively even though no code
		### currently mutates a PlayerAction's fields at runtime.
		resource = resource.duplicate(true)
	resource = _apply_rework_art_from_content_set(resource)
	if resource is VideoClip:
		video_clips.append(resource)
	_register_resource(resource, path, replaces_scanned)

### Full Rework (and Default mode with the rework content included): the rework's art for opponent types
### (appearances) and player actions (art parts) lives in the ContentSet, not on the prototype's files - those must not reference rework art, since
### prototype builds don't ship it. Put it on the resource here, just before it is registered. An
### OpponentType is copied first so the shared file's resource stays untouched (opponent types are always
### looked up by id from this database, so nothing keeps pointing at the original); a PlayerAction is
### already a copy by now.
func _apply_rework_art_from_content_set(resource: Resource) -> Resource:
	if not PlayModeSettings.uses_rework_content():
		return resource
	var content_set: ContentSet = get_active_content_set()
	if content_set == null:
		return resource
	if resource is OpponentType:
		var opponent_type: OpponentType = resource as OpponentType
		var appearance_list: OpponentAppearanceList = content_set.opponent_appearances.get(opponent_type.opponent_type_id)
		if appearance_list == null:
			return resource
		var opponent_type_copy: OpponentType = opponent_type.duplicate() as OpponentType
		opponent_type_copy.appearance_variations = appearance_list.appearances.duplicate()
		return opponent_type_copy
	if resource is PlayerAction:
		var player_action: PlayerAction = resource as PlayerAction
		var art_part_list: ArtPartList = content_set.player_action_art_parts.get(player_action.action_id)
		if art_part_list != null:
			player_action.opponent_art_parts = art_part_list.parts.duplicate()
	return resource

### The ContentSet of the current play mode (null in Default mode unless it includes the rework content
### and the set is actually shipped). Loads it on demand, since things like a new SaveGameState can ask
### before the deferred content load has started.
func get_active_content_set() -> ContentSet:
	if active_content_set == null and PlayModeSettings.uses_rework_content() and ResourceLoader.exists(REWORK_CONTENT_SET_PATH):
		active_content_set = load(REWORK_CONTENT_SET_PATH) as ContentSet
	return active_content_set

#region Full Rework: what is registered
### Content types Full Rework takes from EVERY pack. Everything else (combo cards, characters, player actions, action
### progressions, rewards, picture lists, video clips) only comes from the rework pack or a ContentSet entry. Which
### encounters the player actually sees is decided by the encounter map, not by registering them.
### ComboEventCardDefinition extends EventCardDefinition but is left out on purpose (_is_open_in_full_rework): combos
### are found by going through every registered card, so every prototype combo would go live in the rework.
var _types_open_in_full_rework: Array[Script] = [
	EncounterDefinition, OpponentType, OpponentActionDefinition, PassiveEffectDefinition, StatusEffectDefinition,
	EventCardDefinition, MapRegionDefinition, GameplayKeyword, MusicTrack, NameList, AudioStreamsForSoundEffect,
]

### Full Rework: the ContentSet, its start encounters and its map are needed while the scan runs (opponent appearances
### are put on the opponent types as they load). Its entries are registered after the scan, see _register_content_set_entries().
func _load_content_set_for_full_rework() -> void:
	active_content_set = get_active_content_set()
	if not active_content_set:
		push_error("Full Rework mode: could not load the content set at %s." % REWORK_CONTENT_SET_PATH)
		return
	start_encounters = active_content_set.start_encounter_ids.duplicate()
	main_encounter_map = active_content_set.encounter_map
	encounter_map = main_encounter_map

func _is_registered_from_scan(resource: Resource, path: String) -> bool:
	if PlayModeSettings.current != PlayModeSettings.Mode.FULL_REWORK:
		return true
	if path.begins_with(REWORK_CONTENT_PACK_ROOT):
		return true
	return resource != null and _is_open_in_full_rework(resource)

func _is_open_in_full_rework(resource: Resource) -> bool:
	if resource is ComboEventCardDefinition:
		return false
	for open_type in _types_open_in_full_rework:
		if is_instance_of(resource, open_type):
			return true
	return false

### Full Rework, after the scan: every ContentSet entry's resource as the rework should see it (a replacement copy, or a
### copy with overridden unlock conditions / keyword icon; the plain resource for types that aren't open, e.g. combo
### cards and player actions), plus its replacement art. Done after the scan so a plain file from a pack can't
### overwrite an entry's copy. Entries inside the rework pack only get their art (the scan registered them).
func _register_content_set_entries() -> void:
	if PlayModeSettings.current != PlayModeSettings.Mode.FULL_REWORK or active_content_set == null:
		return
	for section in active_content_set.get_sections():
		for entry_key in section.keys():
			_register_carry_over_entry(str(entry_key), section[entry_key])
#endregion

func _register_carry_over_entry(entry_key: String, entry: CarryOverEntry) -> void:
	if entry == null or entry.content == null:
		push_warning("Content set entry '%s' is empty." % entry_key)
		return
	var resource: Resource = entry.content
	_warn_if_content_set_key_does_not_match(entry_key, resource)
	var is_in_rework_pack: bool = resource.resource_path.begins_with(REWORK_CONTENT_PACK_ROOT)
	if is_in_rework_pack and (entry.override_unlock_conditions or entry.replacement_content != null):
		push_warning("Content set overrides for '%s' are ignored: it is inside the rework pack, edit the file directly." % resource.resource_path)
	_warn_if_replacement_content_does_not_match(entry_key, resource, entry.replacement_content)
	if not is_in_rework_pack:
		_handle_loaded_content_pack_resource(_get_resource_with_overrides(entry), resource.resource_path, true)
	if entry.replacement_texture:
		_register_replacement_art(resource, entry.replacement_texture)

### The key is only a label for the inspector, so a typo changes nothing - but it is a sign the entry
### was pointed at the wrong resource, so say so. Content without an id (video clips) is skipped.
func _warn_if_content_set_key_does_not_match(entry_key: String, resource: Resource) -> void:
	var content_ids: Array = _get_registered_keys_of(resource)
	if not content_ids.is_empty() and entry_key not in content_ids:
		push_warning("Content set key '%s' doesn't match the id of '%s' (%s)." % [entry_key, resource.resource_path, ", ".join(PackedStringArray(content_ids))])

### A replacement is registered in place of the original, so it has to carry the same id(s) (and be the same
### kind of content) - otherwise it would register as new content and leave the original's id pointing at nothing.
func _warn_if_replacement_content_does_not_match(entry_key: String, original: Resource, replacement: Resource) -> void:
	if replacement == null:
		return
	var original_ids: Array = _get_registered_keys_of(original)
	var replacement_ids: Array = _get_registered_keys_of(replacement)
	if original_ids != replacement_ids:
		push_warning("Content set entry '%s': the replacement content has id(s) [%s] but the original has [%s]." % [entry_key, ", ".join(PackedStringArray(replacement_ids)), ", ".join(PackedStringArray(original_ids))])

func _get_registered_keys_of(resource: Resource) -> Array:
	for registration in _resource_registrations:
		if is_instance_of(resource, registration.resource_class):
			var content_ids: Array = []
			for key in registration.key_extractor.call(resource):
				if key != null and key != "":
					content_ids.append(str(key))
			return content_ids
	return []

### The entry's content as Full Rework should see it: the shared resource itself, or - if the entry
### overrides anything - a copy with the overrides applied, so the prototype's resource stays untouched.
### A replacement_content takes the place of the content itself; the other overrides then apply on top of a copy of it.
func _get_resource_with_overrides(entry: CarryOverEntry) -> Resource:
	### A gameplay keyword's replacement_texture is its icon (the other types' replacement art goes
	### through ImageOverrideManager instead, see _register_replacement_art).
	var replaces_keyword_icon: bool = entry.replacement_texture != null and entry.content is GameplayKeyword
	var base_resource: Resource = entry.replacement_content if entry.replacement_content != null else entry.content
	if not entry.override_unlock_conditions and not replaces_keyword_icon:
		return base_resource
	var overridden_resource: Resource = base_resource.duplicate()
	if entry.override_unlock_conditions:
		if "unlock_conditions" in base_resource:
			overridden_resource.set("unlock_conditions", entry.unlock_conditions.duplicate())
		else:
			push_warning("'%s' has no unlock conditions to override." % entry.content.resource_path)
	if replaces_keyword_icon:
		(overridden_resource as GameplayKeyword).icon = entry.replacement_texture
	return overridden_resource

func _register_replacement_art(resource: Resource, texture: Texture2D) -> void:
	if resource is EventCardDefinition:
		_register_art_for_keys(GlobalImageOverrideManager.ReplacementType.EVENT_CARD_IMAGE, resource, texture)
	elif resource is PlayerAction:
		_register_art_for_keys(GlobalImageOverrideManager.ReplacementType.ACTION_CARD_IMAGE, resource, texture)
	elif resource is OpponentType:
		_register_art_for_keys(GlobalImageOverrideManager.ReplacementType.OPPONENT_TYPE_IMAGE, resource, texture)
	elif resource is GameplayKeyword:
		pass ### Applied as the keyword's icon in _get_resource_with_overrides().
	else:
		push_warning("Replacement art isn't supported for '%s' yet (only event cards, player actions, opponent types and gameplay keywords)." % resource.resource_path)

func _register_art_for_keys(replacement_type: GlobalImageOverrideManager.ReplacementType, resource: Resource, texture: Texture2D) -> void:
	for registration in _resource_registrations:
		if is_instance_of(resource, registration.resource_class):
			for key in registration.key_extractor.call(resource):
				if key != null and key != "":
					ImageOverrideManager.register_texture_override(replacement_type, str(key), texture)
			return

### Default mode with the rework content included: the content set's replacement art (card images through
### ImageOverrideManager, keyword icons on a copy of the keyword) on top of what the prototype scan
### registered. Runs after the scan, otherwise the scan would overwrite the keyword copies. Unlock
### overrides, start encounters, starter deck and passives stay Full Rework only.
func _apply_rework_replacement_art_in_default_mode() -> void:
	if PlayModeSettings.current == PlayModeSettings.Mode.FULL_REWORK or not PlayModeSettings.include_rework_content_in_default:
		return
	var content_set: ContentSet = get_active_content_set()
	if content_set == null:
		return
	for section in content_set.get_sections():
		for entry_key in section.keys():
			var entry: CarryOverEntry = section[entry_key]
			if entry == null or entry.content == null or entry.replacement_texture == null:
				continue
			if entry.content is GameplayKeyword:
				var keyword_with_icon: GameplayKeyword = _get_resource_with_overrides(entry) as GameplayKeyword
				gameplay_keywords_by_id[keyword_with_icon.keyword_id] = keyword_with_icon
			else:
				_register_replacement_art(entry.content, entry.replacement_texture)

func _finish_loading_content_packs() -> void:
	_register_content_set_entries()
	_apply_rework_replacement_art_in_default_mode()
	### Every mod type loads in both modes (modding is coming to the rework too). Content that names nothing loads first;
	### statuses, passives, cards, Actions, characters, rewards, Moves and opponent types name each other (a reward unlocks an
	### Action, a card applies a status, a Move summons a type...), so all of them load before any is checked for missing
	### content (_drop_mod_content_naming_missing_content()). Action progressions, encounters and maps come after that check (they name
	### Actions, rewards and opponent types). Mod encounters are only ever played from a mod map (see is_encounter_on_map()).
	_load_status_effect_definitions_from_mods()
	_load_map_region_definitions_from_mods()
	_load_name_lists_from_mods()
	_load_sound_effects_from_mods()
	_load_music_tracks_from_mods()
	_load_picture_lists_from_mods()
	_load_gameplay_keywords_from_mods()
	_load_passive_effect_definitions_from_mods()
	_load_event_card_definitions_from_mods()
	_load_player_actions_from_mods()
	_load_character_definitions_from_mods()
	_load_reward_definitions_from_mods()
	_load_opponent_actions_from_mods()
	_load_opponent_types_from_mods()
	_drop_mod_content_naming_missing_content()
	_load_action_progressions_from_mods()
	_load_encounter_definitions_from_mods()
	_load_encounter_maps_from_mods()

	_main_start_encounters = start_encounters.duplicate()
	### The main map until a save picks another one (MetaGame).
	set_active_map(MAIN_MAP_ID)
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
		ResourceRegistration.new(MusicTrack, music_tracks_by_id, Callable(self, "_get_music_track_keys")),
		ResourceRegistration.new(NameList, name_lists_by_id, Callable(self, "_get_name_list_keys")),
		ResourceRegistration.new(AudioStreamsForSoundEffect, sound_effects_by_id, Callable(self, "_get_sound_effect_keys")),
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
	### The rework pack's own content (encounters, characters, ...) belongs to Full Rework only; Default mode
	### (the prototype, also in the new-UI test scene) scans every other pack but must not pick it up.
	### (Resources of other packs that merely reference rework assets, like art parts, still load as
	### dependencies - this only skips the scan.)
	if folder_path == REWORK_CONTENT_PACK_ROOT and PlayModeSettings.current != PlayModeSettings.Mode.FULL_REWORK:
		return
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

### replaces_scanned: see _handle_loaded_content_pack_resource().
func _register_resource(resource: Resource, path: String, replaces_scanned: bool = false) -> void:
	for registration in _resource_registrations:
		if is_instance_of(resource, registration.resource_class):
			var keys: Array = registration.key_extractor.call(resource)
			for key in keys:
				if key == null or key == "":
					continue
				if registration.target_dict.has(key) and not replaces_scanned:
					### Full Rework scans every pack: the rework pack's own version of an id wins, whichever loads first.
					var existing_path: String = (registration.target_dict[key] as Resource).resource_path
					var new_is_rework: bool = path.begins_with(REWORK_CONTENT_PACK_ROOT)
					var existing_is_rework: bool = existing_path.begins_with(REWORK_CONTENT_PACK_ROOT)
					if PlayModeSettings.current == PlayModeSettings.Mode.FULL_REWORK and existing_is_rework and not new_is_rework:
						continue
					if not (PlayModeSettings.current == PlayModeSettings.Mode.FULL_REWORK and new_is_rework and not existing_is_rework):
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

func _get_music_track_keys(resource: MusicTrack) -> Array:
	return [resource.track_id]

func get_music_track(track_id: String) -> MusicTrack:
	return music_tracks_by_id.get(track_id, null)

func _get_name_list_keys(resource: NameList) -> Array:
	return [resource.name_list_id]

func _get_sound_effect_keys(resource: AudioStreamsForSoundEffect) -> Array:
	return [resource.sound_effect_id]

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
### === Mod-loaded characters, passives and event cards (JSON) ===
### Like every mod type they load in both modes, and one with the id of the game's own is skipped. What they name that isn't
### installed is checked once every mod type has loaded (_drop_mod_content_naming_missing_content()): a passive or card is
### skipped whole, a character only loses the missing parts.
func _load_character_definitions_from_mods() -> void:
	for mod_file in _read_mod_json_files("characters"):
		var char_def: CharacterDefinition = CharacterDefinition.from_json_dict(mod_file["data"], MODS_ROOT.path_join(mod_file["mod"]).path_join("images"))
		if char_def and _can_register_mod_content(char_def.character_id, character_definitions, "character", mod_file):
			char_def.is_modded = true
			character_definitions[char_def.character_id] = char_def

func _load_passive_effect_definitions_from_mods() -> void:
	for mod_file in _read_mod_json_files("passives"):
		var passive_def: PassiveEffectDefinition = PassiveEffectDefinition.from_json_dict(mod_file["data"], MODS_ROOT.path_join(mod_file["mod"]).path_join("images"))
		if passive_def and _can_register_mod_content(passive_def.passive_id, passive_effect_definitions, "passive", mod_file):
			passive_def.is_modded = true
			passive_effect_definitions[passive_def.passive_id] = passive_def

func _load_event_card_definitions_from_mods() -> void:
	for mod_file in _read_mod_json_files("event_cards"):
		var card_def: EventCardDefinition = EventCardDefinition.from_json_dict(mod_file["data"], MODS_ROOT.path_join(mod_file["mod"]).path_join("images"))
		if card_def and _can_register_mod_content(card_def.card_type_id, event_cards_by_id, "event card", mod_file):
			card_def.is_modded = true
			event_cards_by_id[card_def.card_type_id] = card_def

### === Mod-loaded statuses (JSON) ===
### Content names statuses by id (ApplyStatusEffect.status_id), looked up when used, so the load order doesn't matter.
### A mod status may not take the id of a game status: it would change every card, Move and passive that applies it.
func _load_status_effect_definitions_from_mods() -> void:
	var dir = DirAccess.open(MODS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var statuses_folder: String = MODS_ROOT + "/" + folder_name + "/status_effects/"
			if DirAccess.dir_exists_absolute(statuses_folder):
				var json_files = Utils.get_files_in_folder(statuses_folder, "json")
				for file in json_files:
					var status_def: StatusEffectDefinition = _load_status_effect_from_mod(folder_name, file)
					if status_def == null:
						continue
					var existing_status: StatusEffectDefinition = status_effects_by_id.get(status_def.status_id, null)
					if existing_status and not existing_status.is_modded:
						push_warning("Mod '%s': status '%s' has the id of one of the game's statuses - skipped." % [folder_name, status_def.status_id])
						continue
					status_def.is_modded = true
					status_effects_by_id[status_def.status_id] = status_def
		folder_name = dir.get_next()
	dir.list_dir_end()

func _load_status_effect_from_mod(mod_name: String, json_path: String) -> StatusEffectDefinition:
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Could not open mod status file: %s" % json_path)
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid JSON in mod status file: %s" % json_path)
		return null

	var status_def: StatusEffectDefinition = StatusEffectDefinition.from_json_dict(parsed, MODS_ROOT.path_join(mod_name).path_join("images"))
	if status_def.status_id == "":
		push_error("Mod status file has no status_id: %s" % json_path)
		return null
	return status_def

### === Mod-loaded rewards (JSON) ===
### A mod reward may not take the id of a game reward (saves would mix them up), and a reward that names content that
### isn't installed (a card, passive, Action or character of a mod that is disabled or removed, or one that doesn't load
### in this mode) is not loaded at all, so it can never hand out something that doesn't exist. Rewards a save already
### earned stay in it; everything that reads them skips unknown ids.
func _load_reward_definitions_from_mods() -> void:
	var dir = DirAccess.open(MODS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var rewards_folder: String = MODS_ROOT + "/" + folder_name + "/rewards/"
			if DirAccess.dir_exists_absolute(rewards_folder):
				var json_files = Utils.get_files_in_folder(rewards_folder, "json")
				for file in json_files:
					var reward: RewardDefinition = _load_reward_from_mod(folder_name, file)
					if reward == null:
						continue
					var existing_reward: RewardDefinition = unlock_rewards.get(reward.reward_id, null)
					if existing_reward and not existing_reward.is_modded:
						push_warning("Mod '%s': reward '%s' has the id of one of the game's rewards - skipped." % [folder_name, reward.reward_id])
						continue
					reward.is_modded = true
					unlock_rewards[reward.reward_id] = reward
		folder_name = dir.get_next()
	dir.list_dir_end()

func _load_reward_from_mod(mod_name: String, json_path: String) -> RewardDefinition:
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Could not open mod reward file: %s" % json_path)
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid JSON in mod reward file: %s" % json_path)
		return null

	var reward: RewardDefinition = RewardDefinition.from_json_dict(parsed, MODS_ROOT.path_join(mod_name).path_join("images"))
	if reward == null:
		push_error("Mod reward file has no known reward class (_class): %s" % json_path)
		return null
	if reward.reward_id == "":
		push_error("Mod reward file has no reward_id: %s" % json_path)
		return null
	return reward

### "kind 'id'" for every id the reward names (RewardDefinition.get_referenced_content_ids()) that isn't registered.
func _get_missing_reward_content(reward: RewardDefinition) -> Array[String]:
	return _get_missing_content(reward.get_referenced_content_ids())

### "kind 'id'" for every id in referenced (kind -> Array of ids, see RewardDefinition / EffectIntent
### .get_referenced_content_ids()) that isn't registered. A kind with no registry here counts as missing.
func _get_missing_content(referenced: Dictionary) -> Array[String]:
	var registries: Dictionary = {
		"passives": passive_effect_definitions,
		"cards": event_cards_by_id,
		"actions": player_actions_by_id,
		"characters": character_definitions,
		"statuses": status_effects_by_id,
		"moves": opponent_actions,
		"opponent_types": opponent_types,
		"rewards": unlock_rewards,
	}
	var missing: Array[String] = []
	for kind in referenced.keys():
		var registry: Dictionary = registries.get(kind, {})
		for content_id in referenced[kind]:
			if not registry.has(content_id):
				missing.append("%s '%s'" % [kind, content_id])
	return missing

### === Mod-loaded opponent Moves (JSON) ===
### A mod Move may not take the id of a game Move (it would change the game's own Partners). A Move whose effects name
### content that isn't installed is skipped too, but only after every mod type has loaded (_drop_mod_moves_naming_missing_content()):
### a Move may name content of types that load after it.
func _load_opponent_actions_from_mods() -> void:
	var dir = DirAccess.open(MODS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var moves_folder: String = MODS_ROOT + "/" + folder_name + "/opponent_actions/"
			if DirAccess.dir_exists_absolute(moves_folder):
				var json_files = Utils.get_files_in_folder(moves_folder, "json")
				for file in json_files:
					var action_def: OpponentActionDefinition = _load_opponent_action_from_mod(folder_name, file)
					if action_def == null:
						continue
					var existing_action: OpponentActionDefinition = opponent_actions.get(action_def.opponent_action_id, null)
					if existing_action and not existing_action.is_modded:
						push_warning("Mod '%s': Move '%s' has the id of one of the game's Moves - skipped." % [folder_name, action_def.opponent_action_id])
						continue
					action_def.is_modded = true
					opponent_actions[action_def.opponent_action_id] = action_def
		folder_name = dir.get_next()
	dir.list_dir_end()

func _load_opponent_action_from_mod(mod_name: String, json_path: String) -> OpponentActionDefinition:
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Could not open mod Move file: %s" % json_path)
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid JSON in mod Move file: %s" % json_path)
		return null

	var action_def: OpponentActionDefinition = OpponentActionDefinition.from_json_dict(parsed, MODS_ROOT.path_join(mod_name).path_join("images"))
	if action_def.opponent_action_id == "":
		push_error("Mod Move file has no opponent_action_id: %s" % json_path)
		return null
	return action_def

### Every mod Move whose effects name content that isn't installed (another mod's, disabled or removed, or a type that
### doesn't load in this mode) is removed, so a Partner can never make it. Repeated until nothing changes: a Move that
### switches to another mod Move loses its target when that one is removed. True when a Move was removed.
func _drop_mod_moves_naming_missing_content() -> bool:
	var removed_any: bool = false
	var removed_this_pass: bool = true
	while removed_this_pass:
		removed_this_pass = false
		for action_id: String in opponent_actions.keys():
			var action_def: OpponentActionDefinition = opponent_actions[action_id]
			if not action_def.is_modded:
				continue
			var missing_content: Array[String] = _get_missing_content(action_def.get_referenced_content_ids())
			if missing_content.is_empty():
				continue
			push_warning("Mod Move '%s' names content that isn't installed (%s) - skipped." % [action_id, ", ".join(missing_content)])
			opponent_actions.erase(action_id)
			removed_this_pass = true
			removed_any = true
	return removed_any

### Mod content naming content that isn't installed (another mod's, disabled or removed, or a type that doesn't load in this
### mode): Moves, Actions, rewards, statuses, passives and cards are removed whole; opponent types only lose what is missing
### (and are removed with no Move left), characters only lose what is missing (checked last). They name each other (removing a Move can leave a type with no Moves, removing a type leaves a Move that
### summons it naming nothing, an Action can give a removed reward...), so this is repeated until nothing changes.
func _drop_mod_content_naming_missing_content() -> void:
	var changed: bool = true
	while changed:
		changed = _drop_mod_moves_naming_missing_content()
		if _drop_missing_content_from_mod_opponent_types():
			changed = true
		if _drop_mod_player_actions_naming_missing_content():
			changed = true
		if _drop_mod_rewards_naming_missing_content():
			changed = true
		if _drop_mod_effect_definitions_naming_missing_content(status_effects_by_id, "status"):
			changed = true
		if _drop_mod_effect_definitions_naming_missing_content(passive_effect_definitions, "passive"):
			changed = true
		if _drop_mod_event_cards_naming_missing_content():
			changed = true
	_drop_missing_content_from_mod_characters()

### Mod statuses or passives (registry: status_effects_by_id / passive_effect_definitions) whose ticks or triggers name content
### that isn't installed are removed whole (EffectDefinition.get_referenced_content_ids()). True when one was removed.
func _drop_mod_effect_definitions_naming_missing_content(registry: Dictionary, kind: String) -> bool:
	var removed_any: bool = false
	for content_id: String in registry.keys():
		var effect_def: EffectDefinition = registry[content_id]
		if not effect_def.get("is_modded"):
			continue
		var missing_content: Array[String] = _get_missing_content(effect_def.get_referenced_content_ids())
		if missing_content.is_empty():
			continue
		push_warning("Mod %s '%s' names content that isn't installed (%s) - skipped." % [kind, content_id, ", ".join(missing_content)])
		registry.erase(content_id)
		removed_any = true
	return removed_any

### Mod event cards whose effects name content that isn't installed are removed whole; sound effects that aren't installed
### are only left out. True when a card was removed.
func _drop_mod_event_cards_naming_missing_content() -> bool:
	var removed_any: bool = false
	for card_id: String in event_cards_by_id.keys():
		var card_def: EventCardDefinition = event_cards_by_id[card_id]
		if not card_def.is_modded:
			continue
		var missing_sounds: Array[String] = []
		card_def.sound_effect_ids = _keep_registered_ids(card_def.sound_effect_ids, sound_effects_by_id, "sound effect", missing_sounds)
		if not missing_sounds.is_empty():
			push_warning("Mod card '%s' names sound effects that aren't installed (%s) - left out." % [card_id, ", ".join(missing_sounds)])
		var missing_content: Array[String] = _get_missing_content(card_def.get_referenced_content_ids())
		if missing_content.is_empty():
			continue
		push_warning("Mod card '%s' names content that isn't installed (%s) - skipped." % [card_id, ", ".join(missing_content)])
		event_cards_by_id.erase(card_id)
		removed_any = true
	return removed_any

### A mod character loses the starting passives, Actions and cards that aren't installed (a character with no starting
### Action left keeps the game's default ones, see CharacterDefinition.apply_to_save_game()). Runs after the other checks, so
### it sees what they removed; it removes nothing itself.
func _drop_missing_content_from_mod_characters() -> void:
	for character_id: String in character_definitions.keys():
		var char_def: CharacterDefinition = character_definitions[character_id]
		if not char_def.is_modded:
			continue
		var missing: Array[String] = []
		char_def.starting_passives = _keep_registered_ids(char_def.starting_passives, passive_effect_definitions, "passive", missing)
		char_def.starting_actions = _keep_registered_ids(char_def.starting_actions, player_actions_by_id, "Action", missing)
		for card_id in char_def.extra_starting_cards.keys():
			if not event_cards_by_id.has(card_id):
				missing.append("card '%s'" % card_id)
				char_def.extra_starting_cards.erase(card_id)
		for action_id in char_def.starting_reward_cards_for_actions.keys():
			var kept_cards: Array = []
			for card_id in char_def.starting_reward_cards_for_actions[action_id]:
				if event_cards_by_id.has(card_id) and player_actions_by_id.has(action_id):
					kept_cards.append(card_id)
				else:
					missing.append("Reward Card '%s' for '%s'" % [card_id, action_id])
			char_def.starting_reward_cards_for_actions[action_id] = kept_cards
		if char_def.starting_ally_card != "" and not event_cards_by_id.has(char_def.starting_ally_card):
			missing.append("ally card '%s'" % char_def.starting_ally_card)
			char_def.starting_ally_card = ""
		if char_def.starting_orgasm_card != "" and not event_cards_by_id.has(char_def.starting_orgasm_card):
			missing.append("Orgasm Card '%s'" % char_def.starting_orgasm_card)
			char_def.starting_orgasm_card = ""
		if not missing.is_empty():
			push_warning("Mod character '%s' names content that isn't installed (%s) - left out." % [character_id, ", ".join(missing)])

### A mod reward that gives content that isn't installed is removed whole (decided 2026-10-26). True when one was removed.
func _drop_mod_rewards_naming_missing_content() -> bool:
	var removed_any: bool = false
	for reward_id: String in unlock_rewards.keys():
		var reward: RewardDefinition = unlock_rewards[reward_id]
		if not reward.is_modded:
			continue
		var missing_content: Array[String] = _get_missing_reward_content(reward)
		if missing_content.is_empty():
			continue
		push_warning("Mod reward '%s' names content that isn't installed (%s) - skipped." % [reward_id, ", ".join(missing_content)])
		unlock_rewards.erase(reward_id)
		removed_any = true
	return removed_any

### A mod Action whose effects or triggers name content that isn't installed is removed whole; Reward Cards that aren't
### installed are only left out. True when an Action was removed.
func _drop_mod_player_actions_naming_missing_content() -> bool:
	var removed_any: bool = false
	for action_id: String in player_actions_by_id.keys():
		var action: PlayerAction = player_actions_by_id[action_id]
		if not action.is_modded:
			continue
		var missing_cards: Array[String] = []
		action.reward_card_ids = _keep_registered_ids(action.reward_card_ids, event_cards_by_id, "card", missing_cards)
		if not missing_cards.is_empty():
			push_warning("Mod Action '%s' names Reward Cards that aren't installed (%s) - left out." % [action_id, ", ".join(missing_cards)])
		var missing_content: Array[String] = _get_missing_content(action.get_referenced_content_ids())
		if missing_content.is_empty():
			continue
		push_warning("Mod Action '%s' names content that isn't installed (%s) - skipped." % [action_id, ", ".join(missing_content)])
		player_actions_by_id.erase(action_id)
		removed_any = true
	return removed_any

### Leaves the Moves, passives and shared name lists that aren't installed out of every mod opponent type (a Partner just
### has fewer Moves / passives / names). A type with no Move left is removed. True when a type was removed.
func _drop_missing_content_from_mod_opponent_types() -> bool:
	var removed_any: bool = false
	for type_id: String in opponent_types.keys():
		var opponent_type: OpponentType = opponent_types[type_id]
		if not opponent_type.is_modded:
			continue
		var missing: Array[String] = []
		opponent_type.available_action_ids = _keep_registered_ids(opponent_type.available_action_ids, opponent_actions, "Move", missing)
		opponent_type.passive_effects = _keep_registered_ids(opponent_type.passive_effects, passive_effect_definitions, "passive", missing)
		opponent_type.name_list_ids = _keep_registered_ids(opponent_type.name_list_ids, name_lists_by_id, "name list", missing)
		if opponent_type.idle_picture_list_id != "" and not picture_lists.has(opponent_type.idle_picture_list_id):
			missing.append("picture list '%s'" % opponent_type.idle_picture_list_id)
			opponent_type.idle_picture_list_id = ""
		if not missing.is_empty():
			push_warning("Mod opponent type '%s' names content that isn't installed (%s) - left out." % [type_id, ", ".join(missing)])
		if opponent_type.available_action_ids.is_empty():
			push_warning("Mod opponent type '%s' has no installed Move left - skipped." % type_id)
			opponent_types.erase(type_id)
			removed_any = true
	return removed_any

### The ids that are keys of registry, in order; each other id is added to missing as "kind 'id'".
func _keep_registered_ids(ids: Array[String], registry: Dictionary, kind: String, missing: Array[String]) -> Array[String]:
	var kept: Array[String] = []
	for content_id in ids:
		if registry.has(content_id):
			kept.append(content_id)
		else:
			missing.append("%s '%s'" % [kind, content_id])
	return kept

### === Mod-loaded name lists (JSON) ===
### A mod list may not take the id of a game list: it would rename the game's own Partners.
func _load_name_lists_from_mods() -> void:
	for mod_file in _read_mod_json_files("name_lists"):
		var name_list: NameList = NameList.from_json_dict(mod_file["data"])
		if name_list.name_list_id == "":
			push_error("Mod name list file has no name_list_id: %s" % mod_file["path"])
			continue
		var existing_list: NameList = name_lists_by_id.get(name_list.name_list_id, null)
		if existing_list and not existing_list.is_modded:
			push_warning("Mod '%s': name list '%s' has the id of one of the game's lists - skipped." % [mod_file["mod"], name_list.name_list_id])
			continue
		name_list.is_modded = true
		name_lists_by_id[name_list.name_list_id] = name_list

### === Mod-loaded opponent types (JSON) ===
### A mod type may not take the id of a game type (it would change the game's own Partners). What it names that isn't
### installed is left out once every mod type has loaded (_drop_missing_content_from_mod_opponent_types()).
func _load_opponent_types_from_mods() -> void:
	for mod_file in _read_mod_json_files("opponent_types"):
		var opponent_type: OpponentType = OpponentType.from_json_dict(
			mod_file["data"], MODS_ROOT.path_join(mod_file["mod"]).path_join("images"))
		if opponent_type.opponent_type_id == "":
			push_error("Mod opponent type file has no opponent_type_id: %s" % mod_file["path"])
			continue
		var existing_type: OpponentType = opponent_types.get(opponent_type.opponent_type_id, null)
		if existing_type and not existing_type.is_modded:
			push_warning("Mod '%s': opponent type '%s' has the id of one of the game's types - skipped." % [mod_file["mod"], opponent_type.opponent_type_id])
			continue
		opponent_type.is_modded = true
		opponent_types[opponent_type.opponent_type_id] = opponent_type

### === Mod-loaded sound effects, music tracks, picture lists and keywords (JSON) ===
### Each may not take the id of the game's own (it would change the game's sounds, music, pictures or texts): skipped.
### Their files are read from the mod's sounds/, music/ and images/ folders.
func _load_sound_effects_from_mods() -> void:
	for mod_file in _read_mod_json_files("sound_effects"):
		var sound_effect: AudioStreamsForSoundEffect = AudioStreamsForSoundEffect.from_json_dict(mod_file["data"], MODS_ROOT.path_join(mod_file["mod"]))
		if _can_register_mod_content(sound_effect.sound_effect_id, sound_effects_by_id, "sound effect", mod_file):
			sound_effect.is_modded = true
			sound_effects_by_id[sound_effect.sound_effect_id] = sound_effect

func _load_music_tracks_from_mods() -> void:
	for mod_file in _read_mod_json_files("music_tracks"):
		var track: MusicTrack = MusicTrack.from_json_dict(mod_file["data"], MODS_ROOT.path_join(mod_file["mod"]))
		if _can_register_mod_content(track.track_id, music_tracks_by_id, "music track", mod_file):
			track.is_modded = true
			music_tracks_by_id[track.track_id] = track

func _load_picture_lists_from_mods() -> void:
	for mod_file in _read_mod_json_files("picture_lists"):
		var picture_list: PictureList = PictureList.from_json_dict(mod_file["data"], MODS_ROOT.path_join(mod_file["mod"]).path_join("images"))
		if _can_register_mod_content(picture_list.id, picture_lists, "picture list", mod_file):
			picture_list.is_modded = true
			picture_lists[picture_list.id] = picture_list

func _load_gameplay_keywords_from_mods() -> void:
	for mod_file in _read_mod_json_files("keywords"):
		var keyword: GameplayKeyword = GameplayKeyword.from_json_dict(mod_file["data"], MODS_ROOT.path_join(mod_file["mod"]).path_join("images"))
		if _can_register_mod_content(keyword.keyword_id, gameplay_keywords_by_id, "keyword", mod_file):
			keyword.is_modded = true
			gameplay_keywords_by_id[keyword.keyword_id] = keyword

### === Mod-loaded Actions (JSON) ===
### Players get a mod Action like the game's: from a reward (Reward_UnlockPlayerActions) or as a mod character's starting
### Action. What it names that isn't installed is checked once every mod type has loaded
### (_drop_mod_player_actions_naming_missing_content()). A save that owns an Action of a removed mod sets it aside
### (SaveGameState.set_aside_actions).
func _load_player_actions_from_mods() -> void:
	for mod_file in _read_mod_json_files("actions"):
		var action: PlayerAction = PlayerAction.from_json_dict(mod_file["data"], MODS_ROOT.path_join(mod_file["mod"]).path_join("images"))
		if _can_register_mod_content(action.action_id, player_actions_by_id, "Action", mod_file):
			action.is_modded = true
			player_actions_by_id[action.action_id] = action

### === Mod-loaded Action progressions (JSON) ===
### Registered under each of their Actions, like the game's. An Action that isn't installed, or that already has one of the
### game's progressions (a mod must not replace the game's reward track), is left out; rewards that aren't installed are
### left out too. A progression with no Action left is skipped. Loads after the missing-content check of Actions and rewards.
func _load_action_progressions_from_mods() -> void:
	for mod_file in _read_mod_json_files("action_progressions"):
		var progression: ActionProgressionDefinition = ActionProgressionDefinition.from_json_dict(mod_file["data"])
		_register_mod_action_progression(progression, "Mod '%s': Action progression %s" % [mod_file["mod"], mod_file["path"].get_file()])

### The rules above for one mod progression; label names it in the warnings. True when it was registered.
func _register_mod_action_progression(progression: ActionProgressionDefinition, label: String) -> bool:
	var left_out: Array[String] = []
	var kept_action_ids: Array[String] = []
	for action_id in progression.action_ids:
		var existing: ActionProgressionDefinition = action_progress_definitions.get(action_id, null)
		if not player_actions_by_id.has(action_id):
			left_out.append("Action '%s' (not installed)" % action_id)
		elif existing and not existing.is_modded:
			left_out.append("Action '%s' (has one of the game's progressions)" % action_id)
		else:
			kept_action_ids.append(action_id)
	progression.action_ids = kept_action_ids
	for reward_id in progression.rewards_per_guy_defeated.keys():
		if not unlock_rewards.has(reward_id):
			left_out.append("reward '%s'" % reward_id)
			progression.rewards_per_guy_defeated.erase(reward_id)
	progression.action_related_rewards = _keep_registered_ids(progression.action_related_rewards, unlock_rewards, "reward", left_out)
	if not left_out.is_empty():
		push_warning("%s - left out: %s." % [label, ", ".join(left_out)])
	if progression.action_ids.is_empty():
		push_warning("%s has no Action left - skipped." % label)
		return false
	progression.is_modded = true
	for action_id in progression.action_ids:
		action_progress_definitions[action_id] = progression
	return true

### True when a mod item with content_id may be registered in registry: it has an id, and the id isn't one of the game's
### (a mod item may replace another mod's). Reports why not otherwise.
func _can_register_mod_content(content_id: String, registry: Dictionary, kind: String, mod_file: Dictionary) -> bool:
	if content_id == "":
		push_error("Mod %s file has no id: %s" % [kind, mod_file["path"]])
		return false
	var existing: Resource = registry.get(content_id, null)
	if existing and not existing.get("is_modded"):
		push_warning("Mod '%s': %s '%s' has the id of one of the game's - skipped." % [mod_file["mod"], kind, content_id])
		return false
	return true

### Every JSON file in user://mods/<mod>/<subfolder>/ of the enabled mods, parsed: {"mod": mod folder name, "path", "data"}.
### A file that doesn't hold a JSON object is reported and left out.
func _read_mod_json_files(subfolder: String) -> Array[Dictionary]:
	var mod_files: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(MODS_ROOT)
	if not dir:
		return mod_files
	dir.list_dir_begin()
	var folder_name: String = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var content_folder: String = MODS_ROOT + "/" + folder_name + "/" + subfolder + "/"
			if DirAccess.dir_exists_absolute(content_folder):
				for json_path in Utils.get_files_in_folder(content_folder, "json"):
					var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
					if not file:
						push_error("Could not open mod file: %s" % json_path)
						continue
					var parsed = JSON.parse_string(file.get_as_text())
					if parsed == null or not (parsed is Dictionary):
						push_error("Invalid JSON in mod file: %s" % json_path)
						continue
					mod_files.append({"mod": folder_name, "path": json_path, "data": parsed})
		folder_name = dir.get_next()
	dir.list_dir_end()
	return mod_files

### === Mod-loaded map regions (JSON) ===
### A mod region may not take the id of a game region: it would recolour and rename the game's own map.
func _load_map_region_definitions_from_mods() -> void:
	var dir = DirAccess.open(MODS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var regions_folder: String = MODS_ROOT + "/" + folder_name + "/map_regions/"
			if DirAccess.dir_exists_absolute(regions_folder):
				var json_files = Utils.get_files_in_folder(regions_folder, "json")
				for file in json_files:
					var region: MapRegionDefinition = _load_map_region_from_mod(file)
					if region == null:
						continue
					var existing_region: MapRegionDefinition = map_region_definitions.get(region.region_id, null)
					if existing_region and not existing_region.is_modded:
						push_warning("Mod '%s': map region '%s' has the id of one of the game's regions - skipped." % [folder_name, region.region_id])
						continue
					region.is_modded = true
					map_region_definitions[region.region_id] = region
		folder_name = dir.get_next()
	dir.list_dir_end()

func _load_map_region_from_mod(json_path: String) -> MapRegionDefinition:
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Could not open mod map region file: %s" % json_path)
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid JSON in mod map region file: %s" % json_path)
		return null

	var region: MapRegionDefinition = MapRegionDefinition.from_json_dict(parsed)
	if region.region_id == "":
		push_error("Mod map region file has no region_id: %s" % json_path)
		return null
	return region

### === Mod-loaded encounters (JSON, unrelated to the .tres pack scan) ===
### A mod encounter may not take the id of a game encounter: it would replace it, and a mod encounter is left off the
### main map, so the game's encounter would disappear from it.
func _load_encounter_definitions_from_mods() -> void:
	var dir = DirAccess.open(MODS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var encounters_folder: String = MODS_ROOT + "/" + folder_name + "/encounters/"
			if DirAccess.dir_exists_absolute(encounters_folder):
				var json_files = Utils.get_files_in_folder(encounters_folder, "json")
				for file in json_files:
					var encounter_def = _load_encounter_from_mod(folder_name, file)
					if encounter_def is not EncounterDefinition:
						continue
					var existing_def: EncounterDefinition = encounter_definitions.get(encounter_def.encounter_id, null)
					if existing_def and not existing_def.is_modded:
						push_warning("Mod '%s': encounter '%s' has the id of one of the game's encounters - skipped." % [folder_name, encounter_def.encounter_id])
						continue
					if not _drop_missing_content_from_mod_encounter(encounter_def):
						push_warning("Mod '%s': encounter '%s' has no installed Partner left - skipped." % [folder_name, encounter_def.encounter_id])
						continue
					encounter_def.is_modded = true
					encounter_definitions[encounter_def.encounter_id] = encounter_def
		folder_name = dir.get_next()
	dir.list_dir_end()

func _load_encounter_from_mod(mod_name: String, json_path: String) -> EncounterDefinition:
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Could not open mod encounter file: %s" % json_path)
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid JSON in mod encounter file: %s" % json_path)
		return null

	var encounter_def: EncounterDefinition = EncounterDefinition.from_json_dict(parsed, MODS_ROOT.path_join(mod_name))
	if encounter_def.encounter_id == "":
		push_error("Mod encounter file has no encounter_id: %s" % json_path)
		return null
	return encounter_def

### A mod encounter may name content that isn't installed: another mod's (disabled or removed), or a mod type that doesn't
### load in this mode. That content is dropped with a warning, so starting or showing the encounter can't crash on it.
### Needs every other content type registered first. False when no installed Partner is left (the encounter is skipped).
func _drop_missing_content_from_mod_encounter(encounter_def: EncounterDefinition) -> bool:
	var label: String = "Mod encounter '%s'" % encounter_def.encounter_id
	for opponent_type_id in encounter_def.opponents_in_encounter_reserves.keys():
		if not opponent_types.has(opponent_type_id):
			push_warning("%s: the Partner type '%s' isn't installed - left out." % [label, opponent_type_id])
			encounter_def.opponents_in_encounter_reserves.erase(opponent_type_id)
	for spawn_number in encounter_def.fixed_spawn_order.keys():
		if not opponent_types.has(encounter_def.fixed_spawn_order[spawn_number]):
			encounter_def.fixed_spawn_order.erase(spawn_number)
	for card_id in encounter_def.event_cards_starting_hand.keys():
		if not event_cards_by_id.has(card_id):
			push_warning("%s: the starting hand card '%s' isn't installed - left out." % [label, card_id])
			encounter_def.event_cards_starting_hand.erase(card_id)
	for card_id in encounter_def.reward_cards_starting_hand.keys():
		if not event_cards_by_id.has(card_id):
			push_warning("%s: the starting hand Reward Card '%s' isn't installed - left out." % [label, card_id])
			encounter_def.reward_cards_starting_hand.erase(card_id)
	for passive_id in encounter_def.temporary_player_passives.duplicate():
		if not passive_effect_definitions.has(passive_id):
			push_warning("%s: the passive '%s' isn't installed - left out." % [label, passive_id])
			encounter_def.temporary_player_passives.erase(passive_id)
	if encounter_def.music_track_id != "" and not music_tracks_by_id.has(encounter_def.music_track_id):
		push_warning("%s: the music track '%s' isn't installed - left out." % [label, encounter_def.music_track_id])
		encounter_def.music_track_id = ""
	for reward_id in encounter_def.rewards_granted_by_clearing.duplicate():
		if not unlock_rewards.has(reward_id):
			push_warning("%s: the reward '%s' isn't installed - left out." % [label, reward_id])
			encounter_def.rewards_granted_by_clearing.erase(reward_id)
	for opponent_type_id in encounter_def.opponents_in_encounter_reserves.keys():
		if encounter_def.opponents_in_encounter_reserves[opponent_type_id] > 0:
			return true
	return false

### === Mod-loaded encounter maps (JSON) ===
### Loaded after the mod encounters. A node may name an encounter that isn't registered (its mod is disabled or removed):
### it stays in the map but is left off it wherever the map is used (is_encounter_on_given_map(), OverworldMap).
func _load_encounter_maps_from_mods() -> void:
	mod_maps.clear()
	var dir = DirAccess.open(MODS_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(folder_name):
			var maps_folder: String = MODS_ROOT + "/" + folder_name + "/maps/"
			if DirAccess.dir_exists_absolute(maps_folder):
				var json_files = Utils.get_files_in_folder(maps_folder, "json")
				for file in json_files:
					var map: EncounterMap = _load_encounter_map_from_mod(file)
					if map == null:
						continue
					if mod_maps.has(map.map_id):
						push_warning("Mod '%s': an encounter map with the id '%s' is already installed - skipped." % [folder_name, map.map_id])
						continue
					_warn_about_unregistered_map_encounters(map)
					_set_counted_map_on_region_conditions(map)
					mod_maps[map.map_id] = map
		folder_name = dir.get_next()
	dir.list_dir_end()

func _load_encounter_map_from_mod(json_path: String) -> EncounterMap:
	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Could not open mod encounter map file: %s" % json_path)
		return null

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Invalid JSON in mod encounter map file: %s" % json_path)
		return null

	var map: EncounterMap = EncounterMap.from_json_dict(parsed)
	if map.map_id == MAIN_MAP_ID:
		push_error("Mod encounter map file has no map_id: %s" % json_path)
		return null
	return map

func _warn_about_unregistered_map_encounters(map: EncounterMap) -> void:
	for map_node: EncounterMapNode in map.nodes.values():
		var encounter_id: String = map_node.get_encounter_id()
		if not encounter_definitions.has(encounter_id):
			push_warning("Encounter map '%s': the encounter '%s' isn't installed - left off the map." % [map.map_id, encounter_id])

### A region condition on a mod map's node counts that map's encounters, not the main map's (see
### Condition_ClearEncountersInRegion.counted_map_id).
func _set_counted_map_on_region_conditions(map: EncounterMap) -> void:
	for map_node: EncounterMapNode in map.nodes.values():
		for condition in map_node.unlock_conditions:
			if condition is Condition_ClearEncountersInRegion:
				condition.counted_map_id = map.map_id

### === Active map ===
### Shows another map: MAIN_MAP_ID or a mod map's id. An id that isn't installed (its mod was disabled or removed) falls
### back to the main map. Rebuilds the graphs (and the prototype map's depths); MetaGame refreshes what the player sees.
func set_active_map(map_id: String) -> void:
	if map_id != MAIN_MAP_ID and not mod_maps.has(map_id):
		push_warning("Encounter map '%s' isn't installed (its mod is disabled or removed) - showing the main map." % map_id)
		map_id = MAIN_MAP_ID
	active_map_id = map_id
	encounter_map = get_encounter_map_by_id(map_id)
	### On a mod map, the encounters open from the start are its nodes without lines and conditions (EncounterMapNode).
	if map_id == MAIN_MAP_ID:
		start_encounters = _main_start_encounters.duplicate()
	else:
		start_encounters.clear()
	_build_graph_edges()
	encounter_depth.clear()
	encounters_by_depth.clear()
	### Depths only lay out the prototype's map; an encounter map has its own positions (and may have loops between ANY
	### nodes, which the depth calculation would report as errors).
	if encounter_map == null:
		_compute_all_depths()
		_assign_encounter_ids_to_depth()

### MAIN_MAP_ID gives the main map (null in Default mode: the prototype map); an id that isn't installed gives null.
func get_encounter_map_by_id(map_id: String) -> EncounterMap:
	if map_id == MAIN_MAP_ID:
		return main_encounter_map
	return mod_maps.get(map_id, null)

### The installed mod maps' ids, sorted by the names the dropdown shows.
func get_mod_map_ids() -> Array[String]:
	var map_ids: Array[String] = []
	map_ids.assign(mod_maps.keys())
	map_ids.sort_custom(_is_mod_map_name_before)
	return map_ids

func _is_mod_map_name_before(map_id_a: String, map_id_b: String) -> bool:
	return mod_maps[map_id_a].get_map_name().naturalnocasecmp_to(mod_maps[map_id_b].get_map_name()) < 0

### === Map graph logic ===
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
	for encounter_id in _get_encounter_ids_in_graphs():
		encounter_prereq_graph[encounter_id] = []
		encounter_forward_graph[encounter_id] = []

### The encounters the graphs (and the prototype map's depths) cover: every registered one, except that the prototype
### map leaves out mod encounters. With an encounter map, encounters that aren't on it stay in the graphs without lines.
func _get_encounter_ids_in_graphs() -> Array[String]:
	var encounter_ids: Array[String] = []
	for encounter_id in encounter_definitions.keys():
		if encounter_map == null and encounter_definitions[encounter_id].is_modded:
			continue
		encounter_ids.append(encounter_id)
	return encounter_ids

### Whether the encounter is on the map the player sees (see is_encounter_on_given_map()).
func is_encounter_on_map(encounter_id: String) -> bool:
	return is_encounter_on_given_map(encounter_id, active_map_id)

### Whether the encounter is registered and on the given map (MAIN_MAP_ID or a mod map's id): on an encounter map, it
### has a node there; on the prototype map, every registered encounter except the mods' (a mod encounter is only played
### from a mod map). A mod map that isn't installed has nothing on it.
func is_encounter_on_given_map(encounter_id: String, map_id: String) -> bool:
	var encounter_def: EncounterDefinition = get_encounter_def_by_id(encounter_id)
	if encounter_def == null:
		return false
	var map: EncounterMap = get_encounter_map_by_id(map_id)
	if map:
		return map.get_node_for_encounter(encounter_id) != null
	if map_id != MAIN_MAP_ID:
		return false
	return not encounter_def.is_modded

func _build_graph_edges() -> void:
	_init_graphs()
	if encounter_map:
		_build_graph_edges_from_encounter_map()
		return
	for encounter_def in encounter_definitions.values():
		var target_id: String = encounter_def.encounter_id
		if not encounter_prereq_graph.has(target_id):
			continue
		for condition in encounter_def.unlock_conditions:
			if condition is Condition_IsEncounterCleared:
				var prereq_id: String = condition.encounter_id
				if not encounter_prereq_graph.has(prereq_id):
					push_warning("Encounter '%s' depends on missing encounter '%s'" % [target_id, prereq_id])
					continue
				encounter_prereq_graph[target_id].append(prereq_id)
				encounter_forward_graph[prereq_id].append(target_id)

### Full Rework: one edge per line on the encounter map (the encounter's own Condition_IsEncounterCleared are ignored).
func _build_graph_edges_from_encounter_map() -> void:
	for map_node: EncounterMapNode in encounter_map.nodes.values():
		if map_node == null:
			continue
		var target_id: String = map_node.get_encounter_id()
		if not encounter_definitions.has(target_id):
			continue
		for prereq_id in map_node.unlocked_by:
			if not encounter_definitions.has(prereq_id):
				push_warning("Encounter map: the line into '%s' comes from '%s', which isn't registered." % [target_id, prereq_id])
				continue
			encounter_prereq_graph[target_id].append(prereq_id)
			encounter_forward_graph[prereq_id].append(target_id)

func get_encounter_map_node(encounter_id: String) -> EncounterMapNode:
	if encounter_map == null:
		return null
	return encounter_map.get_node_for_encounter(encounter_id)

### What an encounter needs to unlock, as the conditions its description lists: with an encounter map, the map node's
### lines and extra conditions (nothing for an encounter that isn't on the map); otherwise the encounter's own.
func get_encounter_unlock_requirements(encounter_def: EncounterDefinition) -> Array[UnlockCondition]:
	if encounter_map == null:
		return encounter_def.unlock_conditions
	var map_node: EncounterMapNode = get_encounter_map_node(encounter_def.encounter_id)
	if map_node == null:
		return []
	return map_node.get_unlock_requirements()

func is_encounter_playable(encounter_id: String, save: SaveGameState) -> bool:
	for prereq_id in encounter_prereq_graph.get(encounter_id, []):
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
	for encounter_id in _get_encounter_ids_in_graphs():
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
	if not rewards_requiring_encounters.has(query_encounter_id):
		return []
	return rewards_requiring_encounters[query_encounter_id]
