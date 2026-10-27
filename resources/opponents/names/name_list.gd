@tool
extends ModExportable
class_name NameList

### First names a Partner of an opponent type is given at random (OpponentType.get_random_name()). A list several types
### share is its own file in a content pack with a name_list_id: registered content (AutoloadDatabase.name_lists_by_id),
### named by OpponentType.name_list_ids, and moddable. A list only one type uses is embedded in that type's file, no id.
@export var name_list_id: String = ""
@export var names: Array[String] = []

### True for a list loaded from a mod. @export_storage so duplicate() keeps it; never written to JSON.
@export_storage var is_modded: bool = false

#region Mod export
func get_mod_export_subfolder() -> String:
	return "name_lists"

### Generic JSON (name_list_id + names), without the is_modded flag.
func _get_fields_excluded_from_generic_json() -> Array[String]:
	return ["is_modded"]

static func from_json_dict(data: Dictionary) -> NameList:
	var name_list: NameList = NameList.new()
	name_list.populate_from_json_dict(data)
	return name_list
#endregion
