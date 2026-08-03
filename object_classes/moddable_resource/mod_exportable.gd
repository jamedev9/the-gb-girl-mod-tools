@tool
extends Resource
class_name ModExportable

## Subfolder name inside the mod output, e.g. "characters", "videos"
func get_mod_export_subfolder() -> String:
	push_error("get_mod_export_subfolder() not implemented")
	return ""

## Raw JSON dict. File-reference fields should hold the ACTUAL project path
## (res://...) here — the exporter rewrites them to mod-relative filenames.
func to_json_dict() -> Dictionary:
	push_error("to_json_dict() not implemented")
	return {}

## json_key -> output subfolder, for any field holding a file reference
## e.g. {"portrait_image_path": "images"}
func get_file_reference_fields() -> Dictionary:
	return {}
