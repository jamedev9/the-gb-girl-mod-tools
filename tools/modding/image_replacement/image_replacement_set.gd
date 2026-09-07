@tool
extends ModExportable
class_name ImageReplacementSet

## Leave empty to apply to all characters. Set to a character_id to scope every
## replacement in this set to only that character's runs - put character-specific
## overrides in their own set rather than setting this per-entry.
@export var character_id: String = ""
@export var replacements: Array[ImageReplacement] = []

func get_mod_export_subfolder() -> String:
	return "image_replacements"

func get_file_reference_fields() -> Dictionary:
	return {}

func get_array_file_reference_fields() -> Dictionary:
	### array_field_name -> {file_key: key inside each entry dict holding a file path, subfolder: output subfolder}
	return {"replacements": {"file_key": "image_path", "subfolder": "images"}}

func to_json_dict() -> Dictionary:
	var replacement_dicts: Array = []
	for replacement in replacements:
		if replacement == null:
			push_warning("Skipping empty ImageReplacement entry")
			continue
		if replacement.target_id == "":
			push_warning("Skipping ImageReplacement with empty target_id")
			continue
		replacement_dicts.append({
			"replacement_type": ImageReplacement.ReplacementType.keys()[replacement.replacement_type],
			"target_id": replacement.target_id,
			"image_path": ModExportable.resolve_to_res_path(replacement.image_path),
		})
	return {"character_id": character_id, "replacements": replacement_dicts}
