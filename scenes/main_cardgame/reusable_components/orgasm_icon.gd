extends Cardgame_UI_Element
class_name OrgasmIcon


func _on_mouse_entered():
	emit_signal("tooltip_requested",TooltipId.GENERIC_TOOLTIP,self)

func _on_mouse_exited():
	emit_signal("tooltip_cleared",self)
