extends Control
class_name SimplePleasureBar

@export var full_bar_container: PanelContainer
@export var pleasure_indicator_panel: PanelContainer
@export var pleasure_value_label: RichTextLabel

### The vertical line that shows where Edging starts. Only the player's bar uses it (it stays hidden until
### set_edging_threshold_pleasure() is called), so opponent bars are untouched.
@export var edging_marker: Panel
@export var edging_marker_width: float = 3.0
### How far the marker sticks out above and below the bar.
@export var edging_marker_overshoot: float = 4.0
@export var edging_marker_move_duration: float = 0.3

### The fill pulses towards a hotter color while the pleasure it shows is at or above the edging threshold (shader:
### resources/shaders/pleasure_bar_pulse.gdshader). The shader is only put on the fill of the bar that gets a threshold
### (the player's), so opponent bars never use it.
@export var pleasure_fill: ColorRect
@export var edging_pulse_color: Color = Color(1.0, 0.3, 0.4)
### Pulses per second.
@export var edging_pulse_speed: float = 0.8
### How far towards edging_pulse_color the fill goes at the top of a pulse (0 to 1; 1 = all the way to that color).
@export var edging_pulse_depth: float = 1.0
### How strong the pulse is at its lowest, as a share of its top (0 to 1): 0.5 swings between half and full strength.
@export_range(0.0, 1.0) var edging_pulse_min_intensity: float = 0.5
### Seconds the pulse takes to fade in and out.
@export var edging_pulse_fade_duration: float = 0.3

@export var drain_bar_duration: float = 3

### The upcoming change to this bar's Pleasure: a "+15" / "-10" label and a shaded region from the fill's edge over the stretch the
### change covers (see set_pleasure_preview()). Their looks are set in the scene; both are tinted with the color the owner passes.
### The region pulses with the Edging pulse shader (a ShaderMaterial on the node in the scene; its pulse settings are set there).
@export var preview_region: Control
@export var preview_label: Label
### Space between the end of the value text ("45 / 100") and the "+X" label, which follows the text as its width changes.
@export var preview_label_gap: float = 6.0

const HIDDEN_TEXT_KEY: String = "UI_OPPONENT_INFO_HIDDEN"
const EDGING_PULSE_SHADER_PATH: String = "res://resources/shaders/pleasure_bar_pulse.gdshader"

var max_pleasure: int
var current_pleasure: int = 0
### True while the player can't see the numbers or the fill (see Status_BlindPlayer). The values are
### still tracked and animated underneath, so revealing them again shows the right amount.
var pleasure_hidden: bool = false

func set_pleasure_hidden(hidden: bool) -> void:
	if hidden == pleasure_hidden:
		return
	pleasure_hidden = hidden
	pleasure_indicator_panel.visible = not hidden
	_update_pleasure_label_text(current_pleasure)
	_update_edging_pulse()
	_update_edging_marker(false)
	_update_pleasure_preview()

func _ready() -> void:
	### The marker is placed from the bar's pixel width, so it follows whenever the bar is resized.
	if is_instance_valid(full_bar_container):
		full_bar_container.resized.connect(_on_full_bar_container_resized)

func initialize_values(_max_pleasure: int) -> void:
	self.max_pleasure = _max_pleasure
	current_pleasure = 0
	_update_pleasure_label_text(0)
	_update_edging_pulse()
	_update_edging_marker(false)

#region Edging marker
### Whole Pleasure at which Edging starts; 0 = no marker (every bar except the player's).
var _edging_threshold_pleasure: int = 0
var _edging_marker_tween: Tween

### Shows the marker at the given whole-Pleasure threshold (GameState.get_edging_threshold_pleasure()), or moves it there
### (animated: slides). It is measured on the same scale as the fill, so the fill's edge reaches the marker exactly when
### pleasure is at the threshold. 0 hides it. Hidden too while the player can't see their pleasure (blinded).
func set_edging_threshold_pleasure(threshold_pleasure: int, animated: bool = false) -> void:
	_edging_threshold_pleasure = threshold_pleasure
	_update_edging_marker(animated)
	_update_edging_pulse()

func _update_edging_marker(animated: bool) -> void:
	if not is_instance_valid(edging_marker) or not is_instance_valid(full_bar_container):
		return
	var marker_is_shown: bool = _edging_threshold_pleasure > 0 and max_pleasure > 0 and not pleasure_hidden
	edging_marker.visible = marker_is_shown
	if not marker_is_shown:
		return
	edging_marker.size = Vector2(edging_marker_width,full_bar_container.size.y + 2.0*edging_marker_overshoot)
	var marker_position: Vector2 = Vector2(
		_get_edging_marker_x(),full_bar_container.position.y - edging_marker_overshoot)
	if is_instance_valid(_edging_marker_tween):
		_edging_marker_tween.kill()
	if animated and edging_marker_move_duration > 0.0:
		_edging_marker_tween = create_tween()
		_edging_marker_tween.tween_property(
			edging_marker,"position",marker_position,edging_marker_move_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		edging_marker.position = marker_position

### Where the marker's left edge goes: the right edge of the fill at the threshold (the fill starts inside the bar's border
### and is sized with calculate_pleasure_bar_length()), centered on that line. Uses the marker's real width: its own minimum
### size can make it wider than edging_marker_width.
func _get_edging_marker_x() -> float:
	var left_inset: float = full_bar_container.get_theme_stylebox("panel").get_margin(SIDE_LEFT)
	var fill_length: float = calculate_pleasure_bar_length(get_max_pleasure_bar_length(),_edging_threshold_pleasure)
	return full_bar_container.position.x + left_inset + fill_length - 0.5*edging_marker.size.x

func _on_full_bar_container_resized() -> void:
	_update_edging_marker(false)
#endregion

#region Edging pulse
var _edging_pulse_active: bool = false
var _edging_pulse_amount: float = 0.0
var _edging_pulse_material: ShaderMaterial
var _edging_pulse_tween: Tween

### The fill pulses while the pleasure the bar DISPLAYS (not the game state: the animations catch up later) is at or above
### the threshold. Called whenever the displayed pleasure, the threshold or the visibility changes.
func _update_edging_pulse() -> void:
	_set_edging_pulse_active(_is_edging_pulse_wanted_for(current_pleasure))

func _is_edging_pulse_wanted_for(displayed_pleasure: int) -> bool:
	return _edging_threshold_pleasure > 0 and not pleasure_hidden and displayed_pleasure >= _edging_threshold_pleasure

func _set_edging_pulse_active(active: bool) -> void:
	if active == _edging_pulse_active:
		return
	if not _ensure_edging_pulse_material():
		return
	_edging_pulse_active = active
	if is_instance_valid(_edging_pulse_tween):
		_edging_pulse_tween.kill()
	var target_amount: float = 1.0 if active else 0.0
	if edging_pulse_fade_duration <= 0.0:
		_set_edging_pulse_amount(target_amount)
		return
	_edging_pulse_tween = create_tween()
	_edging_pulse_tween.tween_method(
		_set_edging_pulse_amount,_edging_pulse_amount,target_amount,edging_pulse_fade_duration)

func _set_edging_pulse_amount(amount: float) -> void:
	_edging_pulse_amount = amount
	_edging_pulse_material.set_shader_parameter("pulse_amount",amount)

### Puts the pulse shader on the fill the first time it is needed, so bars that never pulse (opponents') never get it.
func _ensure_edging_pulse_material() -> bool:
	if is_instance_valid(_edging_pulse_material):
		return true
	if not is_instance_valid(pleasure_fill):
		return false
	var pulse_shader: Shader = load(EDGING_PULSE_SHADER_PATH) as Shader
	if pulse_shader == null:
		push_warning("SimplePleasureBar: could not load the pulse shader at %s." % EDGING_PULSE_SHADER_PATH)
		return false
	_edging_pulse_material = ShaderMaterial.new()
	_edging_pulse_material.shader = pulse_shader
	_edging_pulse_material.set_shader_parameter("pulse_amount",_edging_pulse_amount)
	_edging_pulse_material.set_shader_parameter("pulse_speed",edging_pulse_speed)
	_edging_pulse_material.set_shader_parameter("pulse_color",edging_pulse_color)
	_edging_pulse_material.set_shader_parameter("pulse_depth",edging_pulse_depth)
	_edging_pulse_material.set_shader_parameter("pulse_min",edging_pulse_min_intensity)
	pleasure_fill.material = _edging_pulse_material
	return true
#endregion

#region Pleasure preview
var _preview_change: int = 0
var _preview_color: Color = Color.WHITE

### change: whole Pleasure (negative = taken away); 0 hides the preview. color: the tint of the label and the region. Set every
### frame by the bar's owner (OpponentCard, PlayerCombatStatDisplay) from PleasureBarPreviews, so the region also follows the fill
### while it animates. Hidden while the player can't see the bar (blinded).
func set_pleasure_preview(change: int, color: Color) -> void:
	_preview_change = change
	_preview_color = color
	_update_pleasure_preview()

func _update_pleasure_preview() -> void:
	if not is_instance_valid(preview_region) or not is_instance_valid(preview_label):
		return
	var preview_is_shown: bool = _preview_change != 0 and max_pleasure > 0 and not pleasure_hidden
	preview_label.visible = preview_is_shown
	if not preview_is_shown:
		preview_region.visible = false
		return
	var label_text: String = ("+%d" % _preview_change) if _preview_change > 0 else str(_preview_change)
	if preview_label.text != label_text:
		preview_label.text = label_text
	preview_label.modulate = _preview_color
	preview_region.modulate = _preview_color
	_place_preview_label()
	_place_preview_region()

### Right after the value text. The value label is centered and its text is centered in it, so the text ends half its drawn width
### to the right of the label's middle. Only the x is set here; the height and look come from the scene.
func _place_preview_label() -> void:
	var text_width: float = pleasure_value_label.get_content_width()
	var text_end: float = pleasure_value_label.position.x + 0.5 * (pleasure_value_label.size.x + text_width)
	preview_label.position.x = text_end + preview_label_gap

### From the edge of the fill as it is drawn right now (it animates behind the game state), forwards for a gain, backwards over
### the fill for a loss, on the same scale as the fill and kept inside the bar. Hidden when nothing of it fits (a bar already full).
func _place_preview_region() -> void:
	var bar_style: StyleBox = full_bar_container.get_theme_stylebox("panel")
	var bar_start: float = bar_style.get_margin(SIDE_LEFT)
	var bar_end: float = full_bar_container.size.x - bar_style.get_margin(SIDE_RIGHT)
	var fill_end: float = pleasure_indicator_panel.position.x + pleasure_indicator_panel.size.x
	var change_length: float = get_max_pleasure_bar_length() * absi(_preview_change) / max_pleasure
	var region_start: float = fill_end
	var region_end: float = fill_end + change_length
	if _preview_change < 0:
		region_start = fill_end - change_length
		region_end = fill_end
	region_start = clampf(region_start, bar_start, bar_end)
	region_end = clampf(region_end, bar_start, bar_end)
	preview_region.visible = region_end - region_start >= 1.0
	if not preview_region.visible:
		return
	preview_region.position = full_bar_container.position + Vector2(region_start, pleasure_indicator_panel.position.y)
	preview_region.size = Vector2(region_end - region_start, pleasure_indicator_panel.size.y)
#endregion

func set_current_pleasure(_current_pleasure: int) -> void:
	### DEPRECATED 16.7.26: Damage animation now handles damage to entering opponents.
	current_pleasure = _current_pleasure
	var max_length: float = get_max_pleasure_bar_length()
	var pleasure_length: float = calculate_pleasure_bar_length(max_length,_current_pleasure)
	pleasure_indicator_panel.size.x = pleasure_length
	_update_pleasure_label_text(_current_pleasure)
	_update_edging_pulse()

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
	if pleasure_hidden:
		return tr(HIDDEN_TEXT_KEY)
	return str(displayed_pleasure)+" / "+str(max_pleasure)

func get_current_pleasure() -> int:
	return current_pleasure

func drain_pleasure_bar() -> void:
	var value_to_hit: int = 0
	await _tween_pleasure_bar_to_value(value_to_hit,drain_bar_duration)
	current_pleasure = 0
	_update_edging_pulse()

func animate_pleasure_bar_to_value(value_to_hit: int, duration: float) -> void:
	await _tween_pleasure_bar_to_value(value_to_hit, duration)
	current_pleasure = value_to_hit
	_update_edging_pulse()

func _tween_pleasure_bar_to_value(value_to_hit:int, duration: float) -> void:
	### A bar that is about to empty below the threshold stops pulsing as the tween starts (the orgasm drain).
	if not _is_edging_pulse_wanted_for(value_to_hit):
		_set_edging_pulse_active(false)
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
