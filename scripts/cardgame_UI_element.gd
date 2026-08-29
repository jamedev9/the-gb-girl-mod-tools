extends Control
class_name Cardgame_UI_Element

@onready var main_game: Node = get_tree().get_current_scene()

@export var tooltip_info: TooltipInfo

var position_tween: Tween

const DARKENING: float = 0.33
const FLASH_DURATION:  float = 0.75
const FLASH_SCALE: float = 1.5

signal tooltip_requested(tooltip_id: TooltipId ,source_node: Control)
signal tooltip_cleared(source_node: Control)

enum TooltipId {
	CARD,
	DISCARD_PILE,
	DRAW_PILE,
	OPPONENT_ACTION,
	STATUS_EFFECT,
	PASSIVE_EFFECT,
	ENERGY,
	ACTIVE_PLAYER_ACTION,
	PLEASURE_DEALT_ICON,
	CURRENT_PLEASURE_ICON,
	ENERGY_ICON,
	EVENT_CARD_PERMANENT,
	EVENT_CARD_REWARD,
	EVENT_CARD_COMBO,
	EVENT_CARD_PROBLEM,
	OPPONENT_TYPE,
	ENCOUNTER_STATUS_EXPLANATION,
	GENERIC_TOOLTIP
}

func _ready() -> void:
	main_game.connect("game_state_changed", Callable(self,"update_class_specific_displays"))
	connect("tooltip_requested",Callable(main_game.popup_controller,"_handle_tooltip_request"))
	connect("tooltip_cleared",Callable(main_game.popup_controller,"_handle_clear_tooltip_request"))
	main_game.connect("finished_playing_fragment_animations",Callable(self,"_on_fragment_animations_finished"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()

func _refresh_text() -> void:
	### For localization
	pass

func _on_fragment_animations_finished() -> void:
	#Overwrite in child classes 
	pass

func update_class_specific_displays(_game_state: GameState) -> void:
	#Overwrite in child classes 
	pass

func _make_unavailable_during_opponents_turn(_game_state: GameState) -> void:
	if _game_state.current_game_phase == 1:
		darken_node()
		self.mouse_filter = MOUSE_FILTER_IGNORE
	else:
		darken_node(0)
		self.mouse_filter = MOUSE_FILTER_STOP

func _make_unavailable_after_game_end(game_state: GameState) -> void:
	if game_state.game_is_over():
		darken_node()
		self.mouse_filter = MOUSE_FILTER_IGNORE

func _make_unavailable() -> void:
	darken_node()
	self.mouse_filter = MOUSE_FILTER_IGNORE
func _make_available() -> void:
	darken_node(0)
	self.mouse_filter = MOUSE_FILTER_STOP


func darken_node(percent: float = DARKENING) -> void:
	var factor: float = 1.0 - clamp(percent, 0.0, 1.0)
	modulate = Color(factor, factor, factor, 1.0)

func get_meta_game() -> Node:
	return main_game.meta_game
func get_save_game_state() -> SaveGameState:
	return get_meta_game().save_game_state

## --- INTERRUPTIBLE movement: use for UI-driven repositioning (hand reflow, hover shifts) ---
## Safe to interrupt because callers here fire-and-forget; nothing awaits completion,
## so kill()-without-finished never strands a coroutine. Kept node-bound + kill() 
## specifically because this stays visually smooth on rapid re-triggering.
func tween_to_position(target: Vector2, duration := 0.5):
	if position_tween and position_tween.is_running():
		position_tween.kill()

	position_tween = create_tween()
	position_tween.tween_property(
		self,
		"position",
		target,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await position_tween.finished

func tween_to_position_and_return_tween(target: Vector2, duration := 0.5) -> Tween:
	if position_tween and position_tween.is_running():
		position_tween.kill()
	position_tween = create_tween()
	position_tween.tween_property(
		self,
		"position",
		target,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return position_tween

## --- FRAGMENT-CRITICAL movement: use inside AnimationHandlers awaited by AnimationRouter ---
## Must never silently hang, since AnimationRouter.play() awaits these directly, and a hung
## await here permanently stalls the whole fragment queue. Two protections:
##  1. get_tree().create_tween() - survives this node being freed mid-animation
##  2. custom_step() instead of kill() - guarantees "finished" fires for any concurrent awaiter
func tween_position_using_curve(
	target: Vector2,
	duration := 0.5,
	curve_points: Array[Vector2] = []
):
	if not is_instance_valid(self):
		return
	if position_tween and position_tween.is_running():
		position_tween.custom_step(1000000)

	var start := position
	
	var curve := Curve2D.new()
	curve.add_point(start)
	
	for point in curve_points:
		curve.add_point(point)
	
	curve.add_point(target)

	curve.bake_interval = 5.0
	var curve_length := curve.get_baked_length()

	position_tween = get_tree().create_tween()
	position_tween.tween_method(
		func(progress: float):
			if not is_instance_valid(self):
				return
			position = curve.sample_baked(progress * curve_length),
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	await position_tween.finished

func tween_position_using_path(
	target: Vector2,
	duration := 0.5,
	waypoints: Array[Vector2] = []
):
	if not is_instance_valid(self):
		return
	if position_tween and position_tween.is_running():
		position_tween.custom_step(1000000)

	var points: Array[Vector2] = [position]
	points.append_array(waypoints)
	points.append(target)

	var segment_lengths: Array[float] = []
	var total_length := 0.0

	for i in range(points.size() - 1):
		var length := points[i].distance_to(points[i + 1])
		segment_lengths.append(length)
		total_length += length

	position_tween = get_tree().create_tween()
	position_tween.tween_method(
		func(progress: float):
			if not is_instance_valid(self):
				return
			var distance := progress * total_length

			for i in range(segment_lengths.size()):
				if distance <= segment_lengths[i]:
					var t := distance / segment_lengths[i]
					position = points[i].lerp(points[i + 1], t)
					return

				distance -= segment_lengths[i]

			position = target,
		0.0,
		1.0,
		duration
	)

	await position_tween.finished
