extends Cardgame_UI_Element
class_name PassiveEffectMiniDisplay

@export var picture: TextureRect

var represented_passive_effect: PassiveEffectDefinition
var represented_target: Variant

func display_passive(passive_definition: PassiveEffectDefinition) -> void:
	self.represented_passive_effect =  passive_definition
	picture.texture = passive_definition.picture


func _on_mouse_entered():
	emit_signal("tooltip_requested",TooltipId.PASSIVE_EFFECT,self)

func _on_mouse_exited():
	emit_signal("tooltip_cleared",self)
