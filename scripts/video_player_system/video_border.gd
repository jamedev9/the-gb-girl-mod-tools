extends Cardgame_UI_Element
class_name VideoBorder

#func _ready() -> void:
	#self.visible = false

func update_class_specific_displays(_game_state: GameState) -> void:
	var parent_node: Control = self.get_parent()
	if parent_node is VideoPlayback:
		self.visible = parent_node.is_open()
