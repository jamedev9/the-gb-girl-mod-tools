@tool
extends EditorScript
class_name ModConfig

### Before running this script, make sure you set the mod config by running res://tools/modding/mod_exporter/mod_info_config.gd

const CONFIG_PATH: String = "user://mod_config.cfg"
const GAME_APP_USER_DATA_FOLDER_NAME: String = "The Gangbang Girl" ### must match your game's project name exactly

class ExportConfig:
	var search_path: String
	var resource_script: Script
	func _init(p_search_path: String, p_resource_script: Script) -> void:
		search_path = p_search_path
		resource_script = p_resource_script

## Add a new moddable resource type here — nothing else in this script needs to change.
var export_configs: Array[ExportConfig] = [
	ExportConfig.new("res://mod_export_data/characters/", CharacterDefinition),
	ExportConfig.new("res://mod_export_data/videos/", VideoClip),
]

func _run() -> void:
	export_mod("build")

static func load_or_create() -> Dictionary:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err != OK:
		return {"mod_name": "", "author": "", "mod_version": "1.0.0"}
	return {
		"mod_name": config.get_value("mod", "mod_name", ""),
		"author": config.get_value("mod", "author", ""),
		"mod_version": config.get_value("mod", "mod_version", "1.0.0"),
	}

static func save(mod_name: String, author: String, mod_version: String) -> void:
	var config := ConfigFile.new()
	config.set_value("mod", "mod_name", mod_name)
	config.set_value("mod", "author", author)
	config.set_value("mod", "mod_version", mod_version)
	config.save(CONFIG_PATH)

func export_mod(output_mode: String) -> void:
	var mod_config: Dictionary = ModConfig.load_or_create()
	if mod_config["mod_name"] == "":
		push_error("No mod config found. Run the setup script first.")
		return

	var mod_root: String
	match output_mode:
		"test":
			mod_root = _get_game_mods_folder().path_join(mod_config["mod_name"])
		"build":
			mod_root = "res://mod_build_output/".path_join(mod_config["mod_name"])
		_:
			push_error("Unknown output_mode: %s" % output_mode)
			return

	_write_mod_info(mod_root, mod_config)
	for config in export_configs:
		_export_all_of_type(config, mod_root)
	print("Exported '%s' to: %s" % [mod_config["mod_name"], ProjectSettings.globalize_path(mod_root)])

func _get_game_mods_folder() -> String:
	### Windows: %APPDATA%\Godot\app_userdata\<game_name>\mods
	### This mirrors OS.get_user_data_dir() logic but for the GAME project, not this tool project.
	var base_appdata: String = OS.get_environment("APPDATA") if OS.get_name() == "Windows" else OS.get_environment("HOME")
	var godot_app_data_root: String = base_appdata if OS.get_name() == "Windows" else base_appdata.path_join(".local/share/godot")
	return godot_app_data_root.path_join("app_userdata").path_join(GAME_APP_USER_DATA_FOLDER_NAME).path_join("mods")

func _export_all_of_type(config: ExportConfig, mod_root: String) -> void:
	var dir := DirAccess.open(config.search_path)
	if not dir:
		push_warning("Could not open search path: %s" % config.search_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.get_extension() == "tres":
			var resource: Resource = load(config.search_path.path_join(file_name))
			if resource is ModExportable:
				_export_single_resource(resource, mod_root)
			else:
				push_warning("Skipped non-ModExportable resource: %s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _export_single_resource(resource: ModExportable, mod_root: String) -> void:
	if resource.has_method("validate"):
		var errors: Array[String] = []
		if not resource.validate(errors):
			push_warning("Validation failed, skipping export: %s" % errors)
			return

	var json_dict: Dictionary = resource.to_json_dict()
	var file_fields: Dictionary = resource.get_file_reference_fields()

	for json_key in file_fields.keys():
		var subfolder: String = file_fields[json_key]
		var source_path: String = json_dict.get(json_key, "")
		if source_path == "":
			continue
		var copied_file_name: String = _copy_file_into_mod(source_path, mod_root, subfolder)
		json_dict[json_key] = copied_file_name ### rewrite res:// path -> plain filename

	var output_subfolder: String = resource.get_mod_export_subfolder()
	var output_path: String = mod_root.path_join(output_subfolder).path_join(resource.resource_path.get_file().get_basename() + ".json")
	_ensure_folder_exists(mod_root.path_join(output_subfolder))
	_write_json_file(output_path, json_dict)

#func _copy_file_into_mod(source_path: String, mod_root: String, subfolder: String) -> String:
	#var file_name: String = source_path.get_file()
	#var dest_folder: String = mod_root.path_join(subfolder)
	#_ensure_folder_exists(dest_folder)
	#var dest_path: String = dest_folder.path_join(file_name)
	#DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), dest_path)
	#return file_name

func _copy_file_into_mod(source_path: String, mod_root: String, subfolder: String) -> String:
	if source_path.begins_with("uid://"):
		push_warning("Received an unresolved uid:// path — resource's to_json_dict() should resolve this before export: %s" % source_path)
		var uid: int = ResourceUID.text_to_id(source_path)
		if ResourceUID.has_id(uid):
			source_path = ResourceUID.get_id_path(uid)
	var file_name: String = source_path.get_file()
	var dest_folder: String = mod_root.path_join(subfolder)
	_ensure_folder_exists(dest_folder)
	var dest_path: String = dest_folder.path_join(file_name)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), dest_path)
	return file_name

func _ensure_folder_exists(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

func _write_json_file(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))

func _write_mod_info(mod_root: String, mod_config: Dictionary) -> void:
	_ensure_folder_exists(mod_root)
	_write_json_file(mod_root.path_join("mod_info.json"), {
		"mod_name": mod_config["mod_name"],
		"author": mod_config["author"],
		"mod_version": mod_config["mod_version"],
		"schema_version": 1,
	})
