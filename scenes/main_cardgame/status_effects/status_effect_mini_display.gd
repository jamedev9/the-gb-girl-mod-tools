extends Cardgame_UI_Element
class_name StatusEffectMiniDisplay

@export var picture: TextureRect
@export var duration_value: Label
@export var stacks_value: Label
### The bordered panels around the two labels, hidden as a whole (otherwise an empty box would stay behind).
@export var duration_box: Control
@export var stacks_box: Control


var represented_status_effect: StatusEffectDefinition
var represented_target: Variant
### What set_displayed_duration() was last given (the tooltip reads it); 0 = a persistent status.
var displayed_duration: int = 0
### What set_displayed_stacks() was last given (the tooltip reads it).
var displayed_stacks: int = 1

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
	set_displayed_duration(duration)
	set_displayed_stacks(stacks)

func _set_border_color(status_category: StatusEffectDefinition.StatusCategory) -> void:
	var existing_style = get_theme_stylebox("panel")
	var new_style: StyleBoxFlat = existing_style.duplicate()
	var color: Color = get_color_for_category(status_category)
	new_style.border_color = color
	add_theme_stylebox_override("panel", new_style)

func get_color_for_category(status_category:StatusEffectDefinition.StatusCategory) -> Color:
	match status_category:
		StatusEffectDefinition.StatusCategory.BUFF:
			return SettingsManager.active_positive_color()
		StatusEffectDefinition.StatusCategory.DEBUFF:
			return SettingsManager.active_negative_color()
	return Color.WHITE
	
func set_displayed_duration(given_duration: int) -> void:
	displayed_duration = given_duration
	duration_value.text = str(given_duration)
	### A persistent status has no duration to count down: hide the whole box, not just the text.
	_set_label_and_box_visible(duration_value, duration_box, not StatusEffectManager.is_duration_persistent(given_duration))

func set_displayed_stacks(given_stacks: int) -> void:
	displayed_stacks = given_stacks
	stacks_value.text = str(given_stacks)
	### Only shown from 2 stacks up, "S:" and the box around it included.
	_set_label_and_box_visible(stacks_value, stacks_box, given_stacks > 1)

### Shows or hides a label's own row (its parent) and, when the scene gives one, the panel around it.
func _set_label_and_box_visible(label: Label, box: Control, should_show: bool) -> void:
	label.get_parent().visible = should_show
	if box:
		box.visible = should_show
	

func _on_mouse_entered():
	emit_signal("tooltip_requested",TooltipId.STATUS_EFFECT,self)

func _on_mouse_exited():
	emit_signal("tooltip_cleared",self)
