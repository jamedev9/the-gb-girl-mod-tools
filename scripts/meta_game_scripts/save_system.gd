extends Node
class_name GlobalSaveSystem

const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "save_"
### Saves in the unique-id format (PlayModeSettings.Mode.FULL_REWORK). Deliberately not
### "save_<int>" shaped, so the legacy slot scan below never picks them up (and vice versa).
const UNIQUE_ID_SAVE_FILE_PREFIX: String = "game_"
const SAVE_FILE_EXT: String = ".json"
const SETTINGS_PATH: String = SAVE_DIR+"settings"+SAVE_FILE_EXT
const BACKUP_FILE_PREFIX: String = "backup_"
const PROGRESSION_PATH: String = SAVE_DIR + "player_progression" + SAVE_FILE_EXT

var player_progression: PlayerProgression

signal _player_progression_changed

func _ready() -> void:
	player_progression = _load_player_progression()

func get_current_game_version() -> String:
	return get_tree().get_current_scene().game_version

func save_exists(save_id: String) -> bool:
	var path := _get_save_path(save_id)
	return FileAccess.file_exists(path)

func load_save(save_id: String) -> SaveGameState:
	var path: String = _get_save_path(save_id)

	if not FileAccess.file_exists(path):
		push_warning("Save file with id %s does not exist, making a new save." % save_id)
		return _create_new_save()

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save at path %s" % path)
		return _create_new_save()

	var json_text: String = FileAccess.get_file_as_string(path)
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("Failed to parse saved JSON. Returning new save.")
		return _create_new_save()

	var data: Dictionary = json.data
	var save_version: String = data.get("game_version", "0.0.0")

	if save_version != get_current_game_version():
		_backup_save(save_id, save_version)

	var result: SaveGameState = _build_save_from_dict(data)
	return result

func _backup_save(save_id: String, old_version: String) -> void:
	var original_path: String = _get_save_path(save_id)
	var id_label: String = save_id if uses_unique_id_saves() else "slot" + save_id
	var backup_path: String = SAVE_DIR + BACKUP_FILE_PREFIX + "v" + old_version + "_" + id_label + SAVE_FILE_EXT
	
	if FileAccess.file_exists(backup_path):
		push_warning("Backup for version %s already exists, skipping backup." % old_version)
		return
	
	var json_text: String = FileAccess.get_file_as_string(original_path)
	var file = FileAccess.open(backup_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write backup save.")
		return
	file.store_string(json_text)
	file.close()
	push_warning("Save backed up to %s before migration." % backup_path)
	
func write_save(save_id: String, save_game_state: SaveGameState) -> void:
	#print("Running write_save")
	_ensure_save_dir_exists()

	var path = _get_save_path(save_id)
	#print("path: %s"%path)
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing.")
		return
	
	var data = _convert_save_to_dict(save_game_state)
	var json_text = JSON.stringify(data, "\t")
	#print("json text:")
	
	file.store_string(json_text)
	file.close()

#region Helper functions:
func _convert_save_to_dict(save: SaveGameState) -> Dictionary:
	return save.to_dict()

func _build_save_from_dict(data: Dictionary) -> SaveGameState:
	var save := SaveGameState.new()
	save.from_dict(data)
	return save

func _ensure_save_dir_exists() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _get_save_path(save_id: String) -> String:
	var prefix: String = UNIQUE_ID_SAVE_FILE_PREFIX if uses_unique_id_saves() else SAVE_FILE_PREFIX
	return SAVE_DIR + prefix + save_id + SAVE_FILE_EXT

### Full Rework saves get unique ids ("<creation unix time>_<random hex>") instead of reusable
### slot numbers; the prototype keeps its slot numbers. Either way a save is addressed by a
### String id, which for a legacy slot is just the slot number as text ("3" -> save_3.json).
func uses_unique_id_saves() -> bool:
	return PlayModeSettings.current == PlayModeSettings.Mode.FULL_REWORK

func _create_new_save() -> SaveGameState:
	var save := SaveGameState.new()
	#save.initialize_defaults()
	return save

#endregion
func save_settings(settings: Dictionary) -> void:
	var save_json: String = JSON.stringify(settings, "\t")
	var file = FileAccess.open(SETTINGS_PATH,FileAccess.WRITE)
	file.store_string(save_json)
	file.close()

func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file = FileAccess.open(SETTINGS_PATH,FileAccess.READ)

	var json = JSON.new()
	var json_text: String = FileAccess.get_file_as_string(SETTINGS_PATH)
	
	var _parse_result = json.parse(json_text)
	var data: Dictionary = json.data
	file.close()
	return data

#region v0.2.0 rewrite: Multiple saves
### Ids of every save in the current format, oldest first: legacy by slot number, unique-id
### saves by the creation time baked into the id.
func get_all_save_ids() -> Array[String]:
	_ensure_save_dir_exists()
	var save_ids: Array[String] = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		push_error("Failed to open save directory.")
		return save_ids
	var prefix: String = UNIQUE_ID_SAVE_FILE_PREFIX if uses_unique_id_saves() else SAVE_FILE_PREFIX
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with(prefix) and file_name.ends_with(SAVE_FILE_EXT):
			var save_id: String = file_name.trim_prefix(prefix).trim_suffix(SAVE_FILE_EXT)
			if _is_valid_save_id(save_id):
				save_ids.append(save_id)
		file_name = dir.get_next()
	dir.list_dir_end()
	if uses_unique_id_saves():
		save_ids.sort_custom(_compare_unique_save_ids_by_creation)
	else:
		save_ids.sort_custom(_compare_legacy_save_ids_by_slot)
	return save_ids

### An id for a save that doesn't exist yet. Legacy: the first unused slot number (which is how
### deleted slots get reused). Unique-id: never reused, even after the save is deleted.
func create_new_save_id() -> String:
	if not uses_unique_id_saves():
		var used_ids: Array[String] = get_all_save_ids()
		var slot: int = 0
		while str(slot) in used_ids:
			slot += 1
		return str(slot)
	var new_id: String = _make_unique_save_id()
	while FileAccess.file_exists(_get_save_path(new_id)):
		new_id = _make_unique_save_id()
	return new_id

### The most recently created save of the current format, or "" if there are none.
func get_newest_save_id() -> String:
	var save_ids: Array[String] = get_all_save_ids()
	if save_ids.is_empty():
		return ""
	return save_ids[save_ids.size() - 1]

### What a save's list entry shows to identify it: the slot number for legacy saves, the
### creation date for unique-id saves.
func get_save_display_label(save_id: String) -> String:
	if not uses_unique_id_saves():
		return save_id
	return Time.get_date_string_from_unix_time(_get_creation_time_of_unique_save_id(save_id))

func _make_unique_save_id() -> String:
	return "%d_%08x" % [int(Time.get_unix_time_from_system()), randi()]

func _is_valid_save_id(save_id: String) -> bool:
	if not uses_unique_id_saves():
		return save_id.is_valid_int()
	return save_id.contains("_") and save_id.get_slice("_", 0).is_valid_int()

func _get_creation_time_of_unique_save_id(save_id: String) -> int:
	return save_id.get_slice("_", 0).to_int()

func _compare_legacy_save_ids_by_slot(a: String, b: String) -> bool:
	return int(a) < int(b)

func _compare_unique_save_ids_by_creation(a: String, b: String) -> bool:
	var time_a: int = _get_creation_time_of_unique_save_id(a)
	var time_b: int = _get_creation_time_of_unique_save_id(b)
	if time_a != time_b:
		return time_a < time_b
	return a < b

func delete_save(save_id: String) -> void:
	var path: String = _get_save_path(save_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
#region Player progression (cross-character, machine-wide):
func _load_player_progression() -> PlayerProgression:
	if not FileAccess.file_exists(PROGRESSION_PATH):
		push_warning("No player progression file found, creating new.")
		var new_progression := _create_new_player_progression()
		_write_player_progression(new_progression)
		return new_progression
	
	var file = FileAccess.open(PROGRESSION_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open player progression file.")
		var new_progression := _create_new_player_progression()
		player_progression = new_progression
		_write_player_progression()
		return new_progression
	
	var json_text: String = FileAccess.get_file_as_string(PROGRESSION_PATH)
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("Failed to parse player progression JSON. Returning new progression.")
		var new_progression := _create_new_player_progression()
		player_progression = new_progression
		_write_player_progression()
		return new_progression
	
	var data: Dictionary = json.data
	var progression := PlayerProgression.new()
	progression.from_dict(data)
	progression._retroactively_add_missing_features_()
	return progression

func _write_player_progression(progression: PlayerProgression = player_progression) -> void:
	_ensure_save_dir_exists()
	var file = FileAccess.open(PROGRESSION_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open player progression file for writing.")
		return
	var data = progression.to_dict()
	var json_text = JSON.stringify(data, "\t")
	file.store_string(json_text)
	file.close()


func _create_new_player_progression() -> PlayerProgression:
	return PlayerProgression.new()

## Public API — reward classes and UI call these directly:

func get_unlocked_characters() -> Array:
	return player_progression.get_unlocked_characters()

func is_character_unlocked(character_id: String) -> bool:
	return player_progression.is_character_unlocked(character_id)

func unlock_character(character_id: String) -> void:
	player_progression.unlock_character(character_id)
	_write_player_progression()
	_emit_signal_that_player_progression_changed()

func lock_character(character_id: String) -> void:
	player_progression.lock_character(character_id)
	_write_player_progression()
	_emit_signal_that_player_progression_changed()

func is_video_seen(video_key: String) -> bool:
	return player_progression.is_video_seen(video_key)

### Only writes to disk the first time a given video is seen. Doesn't emit
### _player_progression_changed - that one rebuilds the character selection screen, and this
### gets called mid-combat.
func mark_video_as_seen(video_key: String) -> void:
	if video_key == "":
		return
	if player_progression.is_video_seen(video_key):
		return
	player_progression.mark_video_as_seen(video_key)
	_write_player_progression()

#region Code typed in the video gallery:
### Only stores the text: the gallery panel does the checking, so nothing here has to know how a code is made. "" = no code saved.
func get_gallery_unlock_code() -> String:
	return player_progression.gallery_unlock_code

func set_gallery_unlock_code(code: String) -> void:
	player_progression.gallery_unlock_code = code
	_write_player_progression()
#endregion

#region Video unlock points:
### Earned by winning encounters (MetaGame.handle_game_progression()), spent in the video gallery to unlock a video. None of these
### emit _player_progression_changed, for the same reason as mark_video_as_seen().
func get_video_unlock_points() -> int:
	_grant_video_points_for_earlier_wins_if_needed()
	return player_progression.video_unlock_points

func add_video_unlock_points(amount: int) -> void:
	_grant_video_points_for_earlier_wins_if_needed()
	player_progression.add_video_unlock_points(amount)
	_write_player_progression()

### Spends 1 point to unlock the video. False if there is no point left or the video is already unlocked.
func unlock_video_with_point(video_key: String) -> bool:
	_grant_video_points_for_earlier_wins_if_needed()
	if not player_progression.spend_video_unlock_point_on(video_key):
		return false
	_write_player_progression()
	return true

### A progression file written before the points existed gets one point per win already in the player's saves, once. Done on first use
### rather than in _ready(): writing the progression needs the main scene (get_current_game_version()), which does not exist yet then.
### Must run before a point is added, so a win is never counted twice (the win that triggers it is not in the save FILE yet).
func _grant_video_points_for_earlier_wins_if_needed() -> void:
	if not player_progression.needs_video_points_for_earlier_wins():
		return
	player_progression.set_video_unlock_points_for_earlier_wins(_count_wins_in_existing_saves())
	_write_player_progression()

### Wins in every save file on disk, both formats (prototype slots and rework ids); backups, settings and the progression file are not
### counted. Only reads the files.
func _count_wins_in_existing_saves() -> int:
	var total_wins: int = 0
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var is_save_file: bool = file_name.ends_with(SAVE_FILE_EXT) and (file_name.begins_with(SAVE_FILE_PREFIX) or file_name.begins_with(UNIQUE_ID_SAVE_FILE_PREFIX))
		if is_save_file:
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_DIR + file_name))
			if parsed is Dictionary:
				total_wins += count_wins_in_save_data(parsed)
		file_name = dir.get_next()
	dir.list_dir_end()
	return total_wins

### encounters_completed holds how many times each encounter was won, so the total is the number of wins.
static func count_wins_in_save_data(save_data: Dictionary) -> int:
	var encounters_completed: Variant = save_data.get("encounters_completed", {})
	if encounters_completed is not Dictionary:
		return 0
	var total_wins: int = 0
	for encounter_id in encounters_completed.keys():
		total_wins += maxi(int(encounters_completed[encounter_id]), 0)
	return total_wins
#endregion

func _emit_signal_that_player_progression_changed() -> void:
	emit_signal("_player_progression_changed")

#endregion
