extends Cardgame_UI_Element
class_name NewTurnPhaseSplash

@export var textlabel: RichTextLabel

## Size of the visible panel. The root Control has zero size and the panel hangs off its top-left,
## so this is what the root's position has to be offset by to centre the panel on a point.
func get_panel_size() -> Vector2:
	var panel: Control = textlabel.get_parent_control()
	return panel.size.max(panel.get_combined_minimum_size())

## Value for this node's `position` that puts the centre of the visible panel at `center_point`
## (in the parent's coordinate space).
func get_position_for_panel_center(center_point: Vector2) -> Vector2:
	return center_point - get_panel_size() * 0.5

func update_text(new_text: String) -> void:
	var text_to_display: String = "[center][b][font_size=48][color=#49b6ff]"+ new_text + "[/color][/font_size][/b]"
	textlabel.text = text_to_display
