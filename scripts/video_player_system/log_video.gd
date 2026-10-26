extends Cardgame_UI_Element
class_name LogVideo

@export var hover_delay := 0.5
var hover_scale_factor: float = 3.5
@export var hover_scale := Vector2(hover_scale_factor, hover_scale_factor)
@export var scale_duration := 0.2

var _hover_timer: Timer
var _hover_tween: Tween
var _is_hovered := false
var _is_scaled := false
var _hover_locked := false
var _original_scale := Vector2.ONE
var original_z_index: int
const HOVERED_Z_INDEX: int = 100

var _original_parent: Control
var _original_index: int
var _original_global_position: Vector2

var _layout_placeholder: Control

@onready var video_playback: VideoPlayback = $VideoPlayback
@onready var video_border: Control = $VideoPlayback/VideoBorder

func _ready() -> void:
	_original_scale = scale
	original_z_index = self.z_index
	# Pivot on the right-center so growth goes left/up/down
	pivot_offset = Vector2(size.x, size.y * 0.5)

	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = hover_delay
	_hover_timer.timeout.connect(_on_hover_delay_finished)
	add_child(_hover_timer)

	video_playback.video_loaded.connect(_update_border_to_match_video)
	video_playback.resized.connect(_update_border_to_match_video)

## VideoPlayback's internal video_texture uses STRETCH_KEEP_ASPECT_CENTERED (see
## video_playback.gd), so the actual visible video image is letterboxed/pillarboxed inside
## VideoPlayback's rect rather than filling it exactly. VideoBorder is a plain sibling anchored
## to that full outer rect, so it needs to be repositioned/resized to match the real letterboxed
## image rect instead - otherwise it sits outside the video on the letterboxed sides and gets
## covered by the video on the sides that do reach the edge. Mirrors Godot's own
## STRETCH_KEEP_ASPECT_CENTERED math (scale to fit, then center).
func _update_border_to_match_video() -> void:
	var texture: Texture2D = video_playback.video_texture.texture
	if not texture:
		return
	var tex_size: Vector2 = texture.get_size()
	var container_size: Vector2 = video_playback.size
	if tex_size.x <= 0 or tex_size.y <= 0 or container_size.x <= 0 or container_size.y <= 0:
		return

	var fit_scale: float = min(container_size.x / tex_size.x, container_size.y / tex_size.y)
	var displayed_size: Vector2 = tex_size * fit_scale
	var top_left: Vector2 = (container_size - displayed_size) / 2.0

	video_border.position = top_left - Vector2(2, 2)
	video_border.size = displayed_size + Vector2(4, 4)


func _on_hover_delay_finished() -> void:
	if not _is_hovered or _hover_locked:
		return

	_hover_locked = true
	_free_from_container()
	_is_scaled = true
	_start_scale_tween(hover_scale)

func _on_mouse_entered() -> void:
	if _hover_locked:
		return
	if _is_hovered:
		return

	_is_hovered = true
	_hover_timer.start()
	#self.volume_db = -10 # This needs to be a Tween
		
func _on_mouse_exited() -> void:
	_is_hovered = false
	_hover_timer.stop()

	if not _is_scaled:
		return

	_is_scaled = false
	self.z_index = original_z_index
	_start_scale_tween(_original_scale)
	#self.volume_db = -80
	#push_error("Running _on_mouse_exited, check for error in tween")
	#push_error("_on_mouse_exited for log video")
	_hover_tween.finished.connect(func():
		if not is_instance_valid(self):
			return
		_hover_locked = false
		_restore_to_container()
	, CONNECT_ONE_SHOT)
		
func _start_scale_tween(target_scale: Vector2) -> void:
	#_is_scaled = true
	
	self.z_index = HOVERED_Z_INDEX
	if _hover_tween and _hover_tween.is_running():
		#_hover_tween.kill()
		_hover_tween.custom_step(1000000)  # force-complete, fires "finished" instead of silently dying

	_hover_tween = create_tween()
	_hover_tween.tween_property(
		self,
		"scale",
		target_scale,
		scale_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)



func _free_from_container() -> void:
	if not get_parent():
		return

	_original_parent = get_parent()
	_original_index = get_index()
	_original_global_position = global_position

	# --- Create layout placeholder ---
	_layout_placeholder = Control.new()
	_layout_placeholder.custom_minimum_size = custom_minimum_size
	_layout_placeholder.size_flags_horizontal = size_flags_horizontal
	_layout_placeholder.size_flags_vertical = size_flags_vertical

	_original_parent.add_child(_layout_placeholder)
	_original_parent.move_child(_layout_placeholder, _original_index)

	# --- Detach real node ---
	_original_parent.remove_child(self)
	main_game.add_child(self)

	global_position = _original_global_position
	pivot_offset = Vector2(size.x, size.y * 0.5)
	_clamp_vertical_position_to_screen()
	_reinitialize_video_playback()

### The hover scale-up pivots on the vertical center (pivot_offset.y = size.y * 0.5), so growth
### is symmetric up/down from that fixed center regardless of scale - only global_position.y
### needs adjusting, computed once here before the scale tween starts, since the center itself
### doesn't move during the tween.
func _clamp_vertical_position_to_screen() -> void:
	var viewport_height: float = get_viewport_rect().size.y
	var scaled_half_height: float = size.y * hover_scale.y * 0.5
	var min_center: float = scaled_half_height
	var max_center: float = viewport_height - scaled_half_height
	var vertical_center: float = global_position.y + size.y * 0.5
	if min_center > max_center:
		vertical_center = viewport_height * 0.5 ### Taller than the screen - just center it.
	else:
		vertical_center = clamp(vertical_center, min_center, max_center)
	global_position.y = vertical_center - size.y * 0.5

func _restore_to_container() -> void:
	if not _original_parent:
		return

	var final_global_position := global_position

	get_parent().remove_child(self)

	if _layout_placeholder:
		_original_parent.remove_child(_layout_placeholder)
		_layout_placeholder.queue_free()
		_layout_placeholder = null

	_original_parent.add_child(self)
	_original_parent.move_child(self, _original_index)

	global_position = final_global_position
	scale = _original_scale
	_reinitialize_video_playback()

### VideoPlayback (addons/gde_gozen) calls close() from _exit_tree(), which sets its `video`
### member (the actual GoZenVideo decoder instance) to null. _free_from_container()/
### _restore_to_container() actually remove_child()+add_child() this node (and VideoPlayback
### along with it) to reparent it during the hover zoom, which fires _exit_tree() and nulls
### `video` out from under it - permanently, since nothing else ever reopens it afterward. By
### the time this runs, `video` is already gone, so re-driving playback from it (what an earlier
### attempt at this fix tried) is a no-op. `path` (the source file path) survives close()/
### _exit_tree() untouched, so re-triggering set_video_path() with it forces a full fresh reopen
### (mirrors how the video was loaded originally in log_entry_panel.gd), restoring playback from
### frame 0 - the video loops, so a hover-triggered restart isn't noticeable in practice.
func _reinitialize_video_playback() -> void:
	if video_playback.path != "":
		video_playback.set_video_path(video_playback.path)
