extends AnimationHelper
class_name AnimationHelper_NodeMover

static func move_node_with_tween(
	moving_node: Control,
	target_position: Vector2,
	duration,global_or_local: String = "global_position",
	transition: Tween.TransitionType = Tween.TRANS_SINE,
	ease_mode: Tween.EaseType = Tween.EASE_OUT,
	delay: float = 0) -> void:
	
	if not is_instance_valid(moving_node):
		return
	
	var tween := moving_node.get_tree().create_tween()
	tween.tween_property(
		moving_node,
		global_or_local,
		target_position,
		duration
	).set_trans(transition).set_ease(ease_mode).set_delay(delay)
	
	await tween.finished
	
	if not is_instance_valid(moving_node):
		return

#static func move_node_with_tween(
	#moving_node: Control,
	#target_position: Vector2,
	#duration,global_or_local: String = "global_position",
	#transition: Tween.TransitionType = Tween.TRANS_SINE,
	#ease_mode: Tween.EaseType = Tween.EASE_OUT,
	#delay: float = 0) -> void:
	#
	#var tween := moving_node.create_tween()
	#
	#tween.tween_property(
	#moving_node,
	#global_or_local,
	#target_position,
	#duration
#).set_trans(transition).set_ease(ease_mode).set_delay(delay)
	#await tween.finished 
