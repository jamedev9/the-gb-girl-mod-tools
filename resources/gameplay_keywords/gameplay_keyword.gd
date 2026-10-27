@tool
extends ModExportable
class_name GameplayKeyword

### A core piece of game vocabulary (Pleasure, Energy, Duration, Opponent, ...) that generated
### descriptions can reference by id. keyword_id is the internal, code-facing name and never
### changes; display_name is the player-facing word and is free to be renamed/reworded/retranslated
### independently (e.g. "Opponent" -> "Partner") without touching any code that generates
### descriptions - those only ever reference the keyword_id.
@export var keyword_id: String
@export var display_name: String
@export var color: Color = Color.WHITE
@export var icon: Texture2D
### One-line vocabulary definition shown as the hover tooltip for this keyword (see
### DescriptionRenderer._render_keyword()). Optional - a keyword with no description just
### falls back to showing its display_name again.
@export_multiline var description: String

### True for a keyword loaded from a mod: its name and description are shown as written, never through tr().
### @export_storage so duplicate() keeps it (keywords with a replacement icon are copies); never written to JSON.
@export_storage var is_modded: bool = false

func get_display_name() -> String:
	if is_modded:
		return display_name
	return tr("GAMEPLAYKEYWORD_"+keyword_id.to_upper()+"_DISPLAY_NAME")

func get_description() -> String:
	if description.is_empty():
		return get_display_name()
	if is_modded:
		return description
	return tr("GAMEPLAYKEYWORD_"+keyword_id.to_upper()+"_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	if is_modded:
		return [] ### Mod text is shown as written, and must not be written into game.csv by the editor's auto-localization.
	var entries: Array[Dictionary] = [
		{"key": "GAMEPLAYKEYWORD_"+keyword_id.to_upper()+"_DISPLAY_NAME", "text": display_name},
	]
	if not description.is_empty():
		entries.append({"key": "GAMEPLAYKEYWORD_"+keyword_id.to_upper()+"_DESCRIPTION", "text": description})
	return entries

#region Mod export
func get_mod_export_subfolder() -> String:
	return "keywords"

func get_file_reference_fields() -> Dictionary:
	return {"icon": "images"}

### Hand-written: icon is a file (see get_file_reference_fields()), the colour is written as HTML.
func to_json_dict() -> Dictionary:
	return {
		"_class": get_script().get_global_name(),
		"keyword_id": keyword_id,
		"display_name": display_name,
		"description": description,
		"color": color.to_html(true),
		"icon": ModExportable.resolve_to_res_path(icon.resource_path, resource_path) if icon else "",
	}

### mod_folder_path: the mod's images folder (resolves icon).
static func from_json_dict(data: Dictionary, mod_folder_path: String = "") -> GameplayKeyword:
	var keyword: GameplayKeyword = GameplayKeyword.new()
	keyword.keyword_id = str(data.get("keyword_id", ""))
	keyword.display_name = str(data.get("display_name", ""))
	keyword.description = str(data.get("description", ""))
	keyword.color = Color.from_string(str(data.get("color", "")), keyword.color)
	var icon_file_name: String = str(data.get("icon", ""))
	if icon_file_name != "" and mod_folder_path != "":
		keyword.icon = Utils.load_texture_from_path(mod_folder_path.path_join(icon_file_name))
	return keyword
#endregion
