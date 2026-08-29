extends PanelContainer
class_name SingleProfilePicPanel

@export var picture: TextureRect

var displayed_encounter: EncounterDefinition

signal picture_was_clicked(location_panel: SingleLocationPanel)

func display_picture(texture: Texture2D) -> void:
	picture.texture = texture


func _on_select_picture_button_pressed() -> void:
	emit_signal("picture_was_clicked", self)
