@tool
extends RefCounted
class_name ContentIdSuggestions

### Inspector help for fields that name content by id (e.g. ApplyStatusEffect.status_id): turns a String field into a
### text field with a dropdown of the ids found in the project's content files, while any other id can still be typed
### (a base-game id in the mod tools, which has no base-game content files). Editor only, and it never loads a resource:
### it reads each .tres file's header (script_class) and its id line, so it stays cheap and never runs in a game build.

### The folders searched: the game's content packs, and the folder mods are made in (see ModConfig.export_configs).
const SEARCH_FOLDERS: Array[String] = ["res://content_packs/", "res://mod_export_data/"]
### How long a list is reused before the folders are read again (a newly made file shows up after this).
const CACHE_MSEC: int = 5000

### script_class + "|" + id_field -> {"time": msec, "ids": PackedStringArray}
static var _cache: Dictionary = {}

### Call from a @tool script's _validate_property(). Does nothing outside the editor or for other properties.
static func apply_to_property(property: Dictionary, field_name: String, script_class: String, id_field: String) -> void:
	if not Engine.is_editor_hint() or property.name != field_name:
		return
	property.hint = PROPERTY_HINT_ENUM_SUGGESTION
	property.hint_string = ",".join(get_ids(script_class, id_field))

### Every id found in .tres files whose resource uses script_class (the file's own [resource], not sub-resources), sorted.
static func get_ids(script_class: String, id_field: String) -> PackedStringArray:
	var cache_key: String = script_class + "|" + id_field
	var cached: Dictionary = _cache.get(cache_key, {})
	if not cached.is_empty() and Time.get_ticks_msec() - int(cached["time"]) < CACHE_MSEC:
		return cached["ids"]
	var ids: PackedStringArray = []
	for folder in SEARCH_FOLDERS:
		_collect_ids(folder, script_class, id_field, ids)
	ids.sort()
	_cache[cache_key] = {"time": Time.get_ticks_msec(), "ids": ids}
	return ids

static func _collect_ids(folder: String, script_class: String, id_field: String, ids: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var item_name: String = dir.get_next()
	while item_name != "":
		if dir.current_is_dir():
			if not item_name.begins_with("."):
				_collect_ids(folder.path_join(item_name), script_class, id_field, ids)
		elif item_name.ends_with(".tres"):
			var id: String = _read_id(folder.path_join(item_name), script_class, id_field)
			if id != "" and not ids.has(id):
				ids.append(id)
		item_name = dir.get_next()
	dir.list_dir_end()

### The id_field value of the file's [resource] section, or "" when the file's resource isn't a script_class.
static func _read_id(path: String, script_class: String, id_field: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	if not file.get_line().contains("script_class=\"%s\"" % script_class):
		return ""
	var in_resource_section: bool = false
	var prefix: String = id_field + " = \""
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.begins_with("["):
			in_resource_section = line.begins_with("[resource]")
			continue
		if in_resource_section and line.begins_with(prefix):
			return line.trim_prefix(prefix).trim_suffix("\"")
	return ""
