extends AnimationHelper
class_name AnimationHelper_ScaleNodeWithTween

const DURATION: float = 0.5

static func scale_node(node: Control, scale: Vector2,duration: float = DURATION) -> void:
	if not node:
		return
	node.pivot_offset = node.size / 2.0
	
	var scale_tween := node.create_tween()
	scale_tween.tween_property(
		node,"scale",scale,duration).set_trans(
			Tween.TransitionType.TRANS_CUBIC).set_ease(Tween.EaseType.EASE_OUT)
