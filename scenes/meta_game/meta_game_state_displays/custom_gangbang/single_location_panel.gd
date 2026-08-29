extends PanelContainer
class_name SingleLocationPanel

@export var location_picture: TextureRect
@export var location_label: RichTextLabel
@export var green_highlight_border: PanelContainer

var displayed_encounter: EncounterDefinition

signal location_was_clicked(location_panel: SingleLocationPanel)

func display_location_from_encounter(encounter_def: EncounterDefinition) -> void:
	location_picture.texture = encounter_def.encounter_picture
	location_label.text = encounter_def.encounter_display_name


func _on_select_location_button_pressed() -> void:
	emit_signal("location_was_clicked", self)

func show_green_highlight() -> void:
	green_highlight_border.show()
	
func hide_green_highlight() -> void:
	green_highlight_border.hide()
