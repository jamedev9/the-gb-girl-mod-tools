extends HBoxContainer
class_name SingleRegionLegend

@export var name_of_region_label: RichTextLabel
@export var region_texture_rect: ColorRect

var region: MapRegionDefinition

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()

func _refresh_text() -> void:
	if not region:
		return
	_set_text(region)

func display_region(map_region: MapRegionDefinition) -> void:
	region = map_region
	_set_text(map_region)
	_set_texture(map_region)
	
func _set_text(map_region: MapRegionDefinition) -> void:
	#name_of_region_label.text = map_region.region_name
	name_of_region_label.text = map_region.get_region_name()

func _set_texture(map_region: MapRegionDefinition) -> void:
	region_texture_rect.modulate = map_region.background_color
