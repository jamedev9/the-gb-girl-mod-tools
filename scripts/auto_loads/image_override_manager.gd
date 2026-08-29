extends Node
class_name GlobalImageOverrideManager

enum ReplacementType {
	EVENT_CARD_IMAGE,
	ACTION_CARD_IMAGE,
	OPPONENT_TYPE_IMAGE
}

var _overrides: Dictionary = {} # "%s:%s" % [ReplacementType, type_instance] -> full file path (String)
var _texture_cache: Dictionary = {} # image_path -> Texture2D

func _ready() -> void:
	_load_all_mod_image_replacements()

func _load_all_mod_image_replacements() -> void:
	_overrides.clear()
	var mods_root: String = AutoloadDatabase.MODS_ROOT
	if not DirAccess.dir_exists_absolute(mods_root):
		return
	var mods_dir := DirAccess.open(mods_root)
	if not mods_dir:
		push_warning("Could not open mods root: %s" % mods_root)
		return
	mods_dir.list_dir_begin()
	var mod_folder_name := mods_dir.get_next()
	print("Mod folder name: %s"%mod_folder_name)
	while mod_folder_name != "":
		if mods_dir.current_is_dir() and not mod_folder_name.begins_with(".") and SettingsManager.is_mod_enabled_on_disk(mod_folder_name):
			_load_image_replacements_for_mod(mod_folder_name)
		mod_folder_name = mods_dir.get_next()
	mods_dir.list_dir_end()

func _load_image_replacements_for_mod(mod_folder_name: String) -> void:
	var mod_path: String = AutoloadDatabase.MODS_ROOT.path_join(mod_folder_name)
	var replacements_dir: String = mod_path.path_join("image_replacements")
	if not DirAccess.dir_exists_absolute(replacements_dir):
		print("Cant find replacements directory")
		return

	var dir := DirAccess.open(replacements_dir)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	print("Checking filename: %s"%file_name)
	while file_name != "":
		if file_name.get_extension() == "json":
			_register_replacement_set(replacements_dir.path_join(file_name), mod_path, mod_folder_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _register_replacement_set(json_path: String, mod_path: String, mod_folder_name: String) -> void:
	var file := FileAccess.open(json_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed.has("replacements"):
		push_warning("Invalid image replacement file in mod '%s'" % mod_folder_name)
		return
	for entry in parsed["replacements"]:
		var type_name: String = str(entry.get("replacement_type", ""))
		var matched_key: String = ModExportable.find_case_insensitive_enum_key(ReplacementType.keys(), type_name)
		if matched_key == "":
			push_warning("Unknown replacement_type '%s' in mod '%s'" % [type_name, mod_folder_name])
			continue
		var target_id: String = str(entry.get("target_id", ""))
		var image_file_name: String = str(entry.get("image_path", ""))
		var image_path: String = mod_path.path_join("images").path_join(image_file_name) ### was: .path_join("image_replacements").path_join("images")
		if not FileAccess.file_exists(image_path):
			push_warning("Image '%s' not found for mod '%s'" % [image_path, mod_folder_name])
			continue
		var lookup_key: String = "%s:%s" % [matched_key, target_id]
		_overrides[lookup_key] = image_path
		


func get_override_texture(replacement_type: ReplacementType, type_instance: String) -> Texture2D:
	var type_name: String = ReplacementType.keys()[replacement_type]
	var lookup_key: String = "%s:%s" % [type_name, type_instance]
	if lookup_key not in _overrides.keys():
		return null

	var image_path: String = _overrides[lookup_key]
	if image_path in _texture_cache.keys():
		return _texture_cache[image_path]

	var image := Image.load_from_file(image_path)
	if not image:
		push_warning("Failed to load override image at '%s'" % image_path)
		return null
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[image_path] = texture
	return texture
