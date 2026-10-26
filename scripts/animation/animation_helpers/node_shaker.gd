extends AnimationHelper
class_name AnimationHelper_NodeShaker

static func shake_node(node: Control, strength: float = 10.0, duration: float = 0.3, steps: int = 6) -> void:
	var original_position: Vector2 = node.global_position
	var tween = node.create_tween()
	for i in steps:
		var t: float = 1.0 - (float(i) / float(steps))
		var tapered_strength: float = strength * t
		var direction: float = tapered_strength if i % 2 == 0 else -tapered_strength
		tween.tween_property(node, "global_position", original_position + Vector2(direction, 0.0), duration / steps)
	tween.tween_property(node, "global_position", original_position, 0.05)
	await tween.finished
