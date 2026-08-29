extends Resource
class_name MapRegionDefinition

@export var region_id: String
@export var region_name: String

@export_category("Visuals")
#@export var base_color: Color
@export var background_color: Color

func get_region_name() -> String:
	return tr("MAPREGIONDEFINITION_"+region_id.to_upper()+"_REGION_NAME")

func get_translation_entries() -> Array[Dictionary]:
	return [
		{"key": "MAPREGIONDEFINITION_"+region_id.to_upper()+"_REGION_NAME", "text": region_name},
	]
