extends Cardgame_UI_Element
class_name TooltipUI


func update_tooltip_information(
	_game_state: GameState,
	_tooltip_id: Cardgame_UI_Element.TooltipId,
	_control_node: Control) -> void:
	#Overwritten by child classes
	pass

### True if the tooltip contains links to other tooltips (a DescriptionLabel showing description-system
### text with terms in it). PopupController lets such a tooltip receive the mouse and keeps it open while
### the pointer is on it, so a term in it can be hovered to open a tooltip of its own. Only meaningful once
### the tooltip has been filled in.
func is_interactive() -> bool:
	return _contains_description_links(self)

func _contains_description_links(node: Node) -> bool:
	for child in node.get_children():
		var description_label: DescriptionLabel = child as DescriptionLabel
		if description_label and description_label.has_links():
			return true
		if _contains_description_links(child):
			return true
	return false
