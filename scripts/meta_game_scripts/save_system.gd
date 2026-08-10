extends Node
class_name GlobalSaveSystem

const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "save_"
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

func save_exists(slot: int) -> bool:
	var path := _get_save_path(slot)
	return FileAccess.file_exists(path)

func load_save(slot: int) -> SaveGameState:
	var path: String = _get_save_path(slot)
	
	if not FileAccess.file_exists(path):
		push_warning("Save file at slot %s does not exist, making a new save." % slot)
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
		_backup_save(slot, save_version)
	
	return _build_save_from_dict(data)

func _backup_save(slot: int, old_version: String) -> void:
	var original_path: String = _get_save_path(slot)
	var backup_path: String = SAVE_DIR + BACKUP_FILE_PREFIX + "v" + old_version + "_slot" + str(slot) + SAVE_FILE_EXT
	
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
	
func write_save(slot: int, save_game_state: SaveGameState) -> void:
	#print("Running write_save")
	_ensure_save_dir_exists()
	
	var path = _get_save_path(slot)
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

func _get_save_path(slot: int) -> String:
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT

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
func get_used_save_slots() -> Array[int]:
	_ensure_save_dir_exists()
	var used_slots: Array[int] = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		push_error("Failed to open save directory.")
		return used_slots
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with(SAVE_FILE_PREFIX) and file_name.ends_with(SAVE_FILE_EXT):
			var slot_string: String = file_name.trim_prefix(SAVE_FILE_PREFIX).trim_suffix(SAVE_FILE_EXT)
			if slot_string.is_valid_int():
				used_slots.append(int(slot_string))
		file_name = dir.get_next()
	dir.list_dir_end()
	used_slots.sort()
	return used_slots

func get_first_empty_slot() -> int:
	var used_slots: Array[int] = get_used_save_slots()
	var slot: int = 0
	while slot in used_slots:
		slot += 1
	return slot

func delete_save(slot: int) -> void:
	var path: String = _get_save_path(slot)
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

func _emit_signal_that_player_progression_changed() -> void:
	emit_signal("_player_progression_changed")

#endregion
