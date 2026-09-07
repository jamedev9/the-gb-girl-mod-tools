extends Control
class_name SimplePleasureBar

@export var full_bar_container: PanelContainer
@export var pleasure_indicator_panel: PanelContainer
@export var pleasure_value_label: RichTextLabel

@export var drain_bar_duration: float = 3

var max_pleasure: int
var current_pleasure: int = 0

func initialize_values(_max_pleasure: int) -> void: 
	self.max_pleasure = _max_pleasure
	current_pleasure = 0
	_update_pleasure_label_text(0)

func set_current_pleasure(_current_pleasure: int) -> void:
	### DEPRECATED 16.7.26: Damage animation now handles damage to entering opponents.
	current_pleasure = _current_pleasure
	var max_length: float = get_max_pleasure_bar_length()
	var pleasure_length: float = calculate_pleasure_bar_length(max_length,_current_pleasure)
	pleasure_indicator_panel.size.x = pleasure_length
	_update_pleasure_label_text(_current_pleasure)

func get_max_pleasure_bar_length() -> float:
	return full_bar_container.size.x

func  calculate_pleasure_bar_length(max_length,_current_pleasure) -> float:
	var pleasure_length: float
	if _current_pleasure == 0:
		return 0
	if _current_pleasure > max_pleasure:
		pleasure_length = max_length
	else:
		pleasure_length = max_length*_current_pleasure/max_pleasure
	return pleasure_length

func _update_pleasure_label_text(displayed_pleasure) -> void:
	var displayed_text: String = get_label_text_for_pleasure(displayed_pleasure)
	pleasure_value_label.text = displayed_text

func get_label_text_for_pleasure(displayed_pleasure) -> String:
	return str(displayed_pleasure)+" / "+str(max_pleasure)

func get_current_pleasure() -> int:
	return current_pleasure

func drain_pleasure_bar() -> void:
	var value_to_hit: int = 0
	await _tween_pleasure_bar_to_value(value_to_hit,drain_bar_duration)
	current_pleasure = 0

func animate_pleasure_bar_to_value(value_to_hit: int, duration: float) -> void:
	await _tween_pleasure_bar_to_value(value_to_hit, duration)
	current_pleasure = value_to_hit

func _tween_pleasure_bar_to_value(value_to_hit:int, duration: float) -> void:
	var pleasure_bar_final_length: float =calculate_pleasure_bar_length(
		get_max_pleasure_bar_length(),value_to_hit)
	var tween := create_tween()
	tween.tween_property(pleasure_indicator_panel,"size:x",pleasure_bar_final_length,duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(
		func(value: int): pleasure_value_label.text = get_label_text_for_pleasure(value),
		current_pleasure,
		value_to_hit,
		duration
	)
	await tween.finished
