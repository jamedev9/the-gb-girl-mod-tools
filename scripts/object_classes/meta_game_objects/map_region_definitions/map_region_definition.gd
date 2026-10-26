@tool
extends ModExportable
class_name MapRegionDefinition

@export var region_id: String
@export var region_name: String

@export_category("Visuals")
#@export var base_color: Color
@export var background_color: Color

### Set by AutoloadDatabase on regions loaded from a mod's JSON: the name is shown as written instead of going through
### tr() (see EventCardDefinition.is_modded). @export_storage so duplicate() keeps it.
@export_storage var is_modded: bool = false

func get_region_name() -> String:
	if is_modded:
		return region_name
	return tr("MAPREGIONDEFINITION_"+region_id.to_upper()+"_REGION_NAME")

func get_translation_entries() -> Array[Dictionary]:
	if is_modded:
		return [] ### Mod text is shown as written, and must not be written into game.csv by the editor's auto-localization.
	return [
		{"key": "MAPREGIONDEFINITION_"+region_id.to_upper()+"_REGION_NAME", "text": region_name},
	]

#region Mod export
func get_mod_export_subfolder() -> String:
	return "map_regions"

### Hand-written: the colour is written as an HTML colour with alpha ("rrggbbaa"), which JSON can hold.
func to_json_dict() -> Dictionary:
	return {
		"_class": get_script().get_global_name(),
		"region_id": region_id,
		"region_name": region_name,
		"background_color": background_color.to_html(true),
	}

static func from_json_dict(data: Dictionary) -> MapRegionDefinition:
	var region: MapRegionDefinition = MapRegionDefinition.new()
	region.region_id = str(data.get("region_id", ""))
	region.region_name = str(data.get("region_name", ""))
	var color_text: String = str(data.get("background_color", ""))
	if Color.html_is_valid(color_text):
		region.background_color = Color.html(color_text)
	return region
#endregion
