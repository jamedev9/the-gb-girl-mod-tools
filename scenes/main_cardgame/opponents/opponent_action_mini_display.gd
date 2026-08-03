extends Cardgame_UI_Element
class_name OpponentActionMiniDisplay

@export var picture: TextureRect

var represented_action: OpponentActionDefinition

func display_action(action: OpponentActionDefinition) -> void:
	self.represented_action =  action
	picture.texture = represented_action.picture

func _on_mouse_entered():
	if not represented_action:
		return
	emit_signal("tooltip_requested",TooltipId.OPPONENT_ACTION,self)

func _on_mouse_exited():
	emit_signal("tooltip_cleared",self)
