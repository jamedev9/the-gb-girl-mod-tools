extends Cardgame_UI_Element
class_name StatusEffectMiniDisplay

@export var picture: TextureRect
@export var duration_value: Label
@export var stacks_value: Label


var represented_status_effect: StatusEffectDefinition
var represented_target: Variant

static func new_status_display(status_id: String,status_duration: int,status_stacks: int) -> StatusEffectMiniDisplay:
	var status_mini_display_scene: PackedScene = load("res://scenes/main_cardgame/status_effects/status_effect_mini_display.tscn")
	var status_display: StatusEffectMiniDisplay = status_mini_display_scene.instantiate()
	var status_definition: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[status_id]
	status_display.display_status(
		status_definition,
		status_duration,
		status_stacks
	)
	return status_display

func display_status(status_definition: StatusEffectDefinition,
	duration: int,
	stacks: int) -> void:
	self.represented_status_effect =  status_definition
	_set_border_color(status_definition.status_category)
	picture.texture = represented_status_effect.status_picture
	duration_value.text = str(duration)
	stacks_value.text = str(stacks)

func _set_border_color(status_category: StatusEffectDefinition.StatusCategory) -> void:
	var existing_style = get_theme_stylebox("panel")
	var new_style: StyleBoxFlat = existing_style.duplicate()
	var color: Color = get_color_for_category(status_category)
	new_style.border_color = color
	add_theme_stylebox_override("panel", new_style)

func get_color_for_category(status_category:StatusEffectDefinition.StatusCategory) -> Color:
	match status_category:
		StatusEffectDefinition.StatusCategory.BUFF:
			return Color.GREEN
		StatusEffectDefinition.StatusCategory.DEBUFF:
			return Color.RED
	return Color.WHITE
	
func set_displayed_duration(given_duration: int) -> void:
	duration_value.text = str(given_duration)
	

func _on_mouse_entered():
	emit_signal("tooltip_requested",TooltipId.STATUS_EFFECT,self)

func _on_mouse_exited():
	emit_signal("tooltip_cleared",self)
