extends Cardgame_UI_Element
class_name ActivePlayerActionPic

var active_player_action: PlayerAction

func _on_mouse_entered():
	if not active_player_action:
		return
	emit_signal("tooltip_requested",TooltipId.ACTIVE_PLAYER_ACTION,self)

func _on_mouse_exited():
	emit_signal("tooltip_cleared",self)
