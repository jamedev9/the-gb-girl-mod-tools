extends Control
class_name EllipticalCardContainer

@export var position_offset: Vector2 = Vector2.ZERO
@export var ellipse_radius_x: float = 400.0
@export var ellipse_radius_y: float = 200.0
@export var arc_start_angle: float = 200.0 # Degrees, left side of arc
@export var arc_end_angle: float = 340.0 # Degrees, right side of arc
@export var move_duration: float = 0.3

signal request_opponent_card_moving_sound_effect

var _opponent_cards: Array[OpponentCard] = []

const MOVE_DELAY: float = 0.2

func _get_ellipse_position(index: int, total: int) -> Vector2:
	var center: Vector2 = size / 2.0
	if total == 1:
		var mid_angle: float = deg_to_rad((arc_start_angle + arc_end_angle) / 2.0)
		return center + Vector2(cos(mid_angle) * ellipse_radius_x, sin(mid_angle) * ellipse_radius_y)
	var t: float = float(index) / float(total - 1)
	var angle_deg: float = lerp(arc_start_angle, arc_end_angle, t)
	var angle_rad: float = deg_to_rad(angle_deg)
	return center + Vector2(cos(angle_rad) * ellipse_radius_x, sin(angle_rad) * ellipse_radius_y)#-position_offset
	
func insert_new_opponent_card(opponent_card: OpponentCard) -> void:
	add_child(opponent_card)
	_opponent_cards.append(opponent_card)
	opponent_card.position = Vector2(size.x, size.y / 2.0) # Spawn from the right
	#_reflow_cards()
	#emit_signal("request_opponent_card_moving_sound_effect")

func remove_opponent_card(opponent_card: OpponentCard) -> void:
	_opponent_cards.erase(opponent_card)

func _reflow_cards() -> void:
	var total: int = _opponent_cards.size()
	var tweens: Array[Tween] = []
	for i in total:
		var target_pos: Vector2 = _get_ellipse_position(i, total) - Vector2(0.5 * _opponent_cards[i].size.x, 0)
		var tween: Tween = _animate_card_to(_opponent_cards[i], target_pos)
		tweens.append(tween)
	if total > 0:
		emit_signal("request_opponent_card_moving_sound_effect")
	for tween in tweens:
		if tween and tween.is_running():
			await tween.finished

func _animate_card_to(opponent_card: OpponentCard, target_pos: Vector2) -> Tween:
	return opponent_card.tween_to_position_and_return_tween(target_pos, move_duration)

#func _reflow_cards() -> void:
	#var total: int = _opponent_cards.size()
	#for i in total:
		#var target_pos: Vector2 = _get_ellipse_position(i, total) - Vector2(0.5*_opponent_cards[i].size.x,0)
		#_animate_card_to(_opponent_cards[i], target_pos)
	#if total > 0:
		#emit_signal("request_opponent_card_moving_sound_effect")
	#await _move_delay_timer()
#
#
#func _animate_card_to(opponent_card: OpponentCard, target_pos: Vector2) -> void:
	#opponent_card.tween_to_position(target_pos, move_duration)

func _move_delay_timer() -> void:
	var timer: Timer = Timer.new()
	add_child(timer)
	timer.autostart = true
	timer.start(MOVE_DELAY)
	await timer.timeout
	timer.queue_free()
