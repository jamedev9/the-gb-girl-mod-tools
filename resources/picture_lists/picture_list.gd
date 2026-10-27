@tool
extends ModExportable
class_name PictureList

### A list of pictures one is picked from at random. Registered content (AutoloadDatabase.picture_lists); opponent types
### name the list their idle picture comes from by this id (OpponentType.idle_picture_list_id).
@export var id: String

@export var pictures: Array[Texture2D]

### True for a list loaded from a mod. @export_storage so duplicate() keeps it; never written to JSON.
@export_storage var is_modded: bool = false

func get_random_picture() -> Texture2D:
	return Utils.get_random_item(pictures)

#region Mod export
func get_mod_export_subfolder() -> String:
	return "picture_lists"

### Each picture is a file, copied into the mod's images/ folder.
func get_array_file_reference_fields() -> Dictionary:
	return {"pictures": {"file_key": "file", "subfolder": "images"}}

### Hand-written: the pictures are files, written as [{"file": path}, ...] (see get_array_file_reference_fields()).
func to_json_dict() -> Dictionary:
	var picture_entries: Array = []
	for picture in pictures:
		if picture:
			picture_entries.append({"file": ModExportable.resolve_to_res_path(picture.resource_path, resource_path)})
	return {
		"_class": get_script().get_global_name(),
		"id": id,
		"pictures": picture_entries,
	}

### mod_folder_path: the mod's images folder.
static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> PictureList:
	var picture_list: PictureList = PictureList.new()
	picture_list.id = str(data.get("id", ""))
	for entry in data.get("pictures", []):
		var file_name: String = str(entry.get("file", "")) if entry is Dictionary else ""
		if file_name == "" or mod_folder_path == "":
			continue
		var picture: Texture2D = Utils.load_texture_from_path(mod_folder_path.path_join(file_name))
		if picture:
			picture_list.pictures.append(picture)
	return picture_list
#endregion
