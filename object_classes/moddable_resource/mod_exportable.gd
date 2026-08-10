@tool
extends Resource
class_name ModExportable

func get_mod_export_subfolder() -> String:
	push_error("get_mod_export_subfolder() not implemented")
	return ""

func to_json_dict() -> Dictionary:
	push_error("to_json_dict() not implemented")
	return {}

## Flat field -> subfolder, for single file-reference fields
func get_file_reference_fields() -> Dictionary:
	return {}

## Array field name -> {file_key, subfolder}, for arrays of dicts that each hold a file reference
func get_array_file_reference_fields() -> Dictionary:
	return {}

static func resolve_to_res_path(path: String) -> String:
	if path.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid)
		push_warning("Could not resolve uid path: %s" % path)
		return ""
	return path

static func find_case_insensitive_enum_key(enum_keys: Array, tag_name: String) -> String:
	for enum_key in enum_keys:
		if enum_key.to_upper() == tag_name.to_upper():
			return enum_key
	return ""
