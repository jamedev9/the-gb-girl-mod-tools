extends AnimationHelper
class_name AnimationHelper_NodeFlasher


#region Methods to flash the color of nodes
static func alert_player_of_value_change(
	nodes: Array[Control], 
	delta: int,
	significance_multiplier: float = 1,
	pop_scale:float=1.0,
	flash_duration:float = 1.0) -> void:
		
	if delta == 0:
		return

	if delta < 0:
		await _flash_nodes_green(nodes,significance_multiplier,pop_scale,flash_duration)
	else:
		await _flash_nodes_red(nodes,significance_multiplier,pop_scale,flash_duration)
		
static func _flash_nodes_red(nodes: Array[Control],significance_multiplier: float,pop_scale:float,flash_duration:float) -> void:
	for node in nodes:
		await _flash_node(node, Color.RED,significance_multiplier,pop_scale,flash_duration)

static func _flash_nodes_green(nodes: Array[Control],significance_multiplier: float,pop_scale:float,flash_duration:float) -> void:
	for node in nodes:
		await _flash_node(node, Color.GREEN,significance_multiplier,pop_scale,flash_duration)

	
static func _flash_node(node: Control, flash_color: Color, significance_multiplier: float, pop_scale: float, duration: float) -> void:
	if not is_instance_valid(node):
		return

	# Force-complete existing flash instead of killing, so any pending await elsewhere resolves
	if node.has_meta("flash_tween"):
		var old_tween = node.get_meta("flash_tween")
		if old_tween is Tween:
			old_tween.custom_step(1000000)

	_center_control_pivot(node)

	var tween := node.get_tree().create_tween()
	node.set_meta("flash_tween", tween)

	var base_scale := Vector2.ONE
	node.scale = base_scale
	node.modulate = flash_color

	var target_scale := base_scale * pop_scale * significance_multiplier

	tween.tween_property(node, "scale", target_scale, duration * 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(node, "scale", base_scale, duration * 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		node,
		"modulate",
		Color.WHITE,
		duration
	)

	await tween.finished
	if is_instance_valid(node):
		node.remove_meta("flash_tween")

static func _pop_node(node: Control,significance_multiplier: float, pop_scale: float, duration: float) -> void:
	if not is_instance_valid(node):
		return
	if node is not Control:
		return

	var tree := node.get_tree()
	await tree.process_frame
	if not is_instance_valid(node):
		return

	_center_control_pivot(node)
	
	var original_scale = node.scale
	node.scale = original_scale * pop_scale * significance_multiplier

	var tween := tree.create_tween()
	tween.tween_property(
		node,
		"scale",
		original_scale,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

static func _pop_node_without_awaiting(node: Control,significance_multiplier: float, pop_scale: float, duration: float) -> void:
	if not is_instance_valid(node):
		return
	if node is not Control:
		return

	var tree := node.get_tree()
	await tree.process_frame
	if not is_instance_valid(node):
		return

	_center_control_pivot(node)
	
	var original_scale = node.scale
	node.scale = original_scale * pop_scale * significance_multiplier

	var tween := tree.create_tween()
	tween.tween_property(
		node,
		"scale",
		original_scale,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

static func _center_control_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


static func alert_player_of_value_change_and_fade(
	nodes: Array[Control],
	delta: int,
	significance_multiplier: float = 1.0,
	pop_scale: float = 1.0,
	flash_duration: float = 0.6,
	fade_duration: float = 0.4
) -> void:
	if delta == 0:
		return

	var color := Color.GREEN if delta < 0 else Color.RED

	for node in nodes:
		await _flash_and_fade_node(
			node,
			color,
			significance_multiplier,
			pop_scale,
			flash_duration,
			fade_duration
		)

static func _flash_and_fade_node(
	node: Control,
	flash_color: Color,
	significance_multiplier: float,
	pop_scale: float,
	flash_duration: float,
	fade_duration: float
) -> void:
	if not is_instance_valid(node):
		return

	# Force-complete existing flash/fade instead of killing
	if node.has_meta("flash_tween"):
		var old_tween = node.get_meta("flash_tween")
		if old_tween is Tween:
			old_tween.custom_step(1000000)

	var tree := node.get_tree()
	await tree.process_frame
	if not is_instance_valid(node):
		return

	_center_control_pivot(node)

	var tween := tree.create_tween()
	node.set_meta("flash_tween", tween)

	# Baseline
	var base_scale := Vector2.ONE
	node.scale = base_scale
	node.modulate = flash_color
	node.visible = true

	var target_scale := base_scale * pop_scale * significance_multiplier

	# --- Flash / pop ---
	tween.tween_property(
		node,
		"scale",
		target_scale,
		flash_duration * 0.2
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		node,
		"scale",
		base_scale,
		flash_duration * 0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(
		node,
		"modulate",
		Color.WHITE,
		flash_duration
	)

	# --- Fade out ---
	tween.tween_property(
		node,
		"modulate:a",
		0.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished
	if is_instance_valid(node):
		node.remove_meta("flash_tween")

#extends AnimationHelper
#class_name AnimationHelper_NodeFlasher
#
#
##region Methods to flash the color of nodes
#static func alert_player_of_value_change(
	#nodes: Array[Control], 
	#delta: int,
	#significance_multiplier: float = 1,
	#pop_scale:float=1.0,
	#flash_duration:float = 1.0) -> void:
		#
	#if delta == 0:
		#return
#
	#if delta < 0:
		#await _flash_nodes_green(nodes,significance_multiplier,pop_scale,flash_duration)
	#else:
		#await _flash_nodes_red(nodes,significance_multiplier,pop_scale,flash_duration)
		#
#static func _flash_nodes_red(nodes: Array[Control],significance_multiplier: float,pop_scale:float,flash_duration:float) -> void:
	#for node in nodes:
		#await _flash_node(node, Color.RED,significance_multiplier,pop_scale,flash_duration)
#
#static func _flash_nodes_green(nodes: Array[Control],significance_multiplier: float,pop_scale:float,flash_duration:float) -> void:
	#for node in nodes:
		#await _flash_node(node, Color.GREEN,significance_multiplier,pop_scale,flash_duration)
#
	#
#static func _flash_node(node: Control, flash_color: Color, significance_multiplier: float, pop_scale: float, duration: float) -> void:
	#if node == null:
		#return
#
	## Kill existing flash
	#if node.has_meta("flash_tween"):
		#var old_tween = node.get_meta("flash_tween")
		#if old_tween is Tween:
			##old_tween.kill()
			#old_tween.custom_step(1000000)  # force-complete, fires "finished" instead of silently dying
#
	## Ensure stable baseline
#
	##await node.get_tree().process_frame
	#if not node:
		#return
	#_center_control_pivot(node)
#
	#var tween := node.create_tween()
	#node.set_meta("flash_tween", tween)
#
	#var base_scale := Vector2.ONE
	#node.scale = base_scale
	#node.modulate = flash_color
#
	#var target_scale := base_scale * pop_scale * significance_multiplier
#
	#tween.tween_property(node, "scale", target_scale, duration * 0.2)\
		#.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
#
	#tween.tween_property(node, "scale", base_scale, duration * 0.8)\
		#.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#
	#tween.parallel().tween_property(
		#node,
		#"modulate",
		#Color.WHITE,
		#duration
	#)
#
	#await tween.finished
	#node.remove_meta("flash_tween")
#
#static func _pop_node(node: Control,significance_multiplier: float, pop_scale: float, duration: float) -> void:
	#if node == null:
		#return
#
	#if node is not Control:
		#return
	#await node.get_tree().process_frame
	#_center_control_pivot(node)
	#
	#var original_scale = node.scale
	#node.scale = original_scale * pop_scale * significance_multiplier
#
	#var tween := node.create_tween()
	#tween.tween_property(
		#node,
		#"scale",
		#original_scale,
		#duration
	#).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#await tween.finished
#
#static func _pop_node_without_awaiting(node: Control,significance_multiplier: float, pop_scale: float, duration: float) -> void:
	#if node == null:
		#return
#
	#if node is not Control:
		#return
	#await node.get_tree().process_frame
	#_center_control_pivot(node)
	#
	#var original_scale = node.scale
	#node.scale = original_scale * pop_scale * significance_multiplier
#
	#var tween := node.create_tween()
	#tween.tween_property(
		#node,
		#"scale",
		#original_scale,
		#duration
	#).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#
#static func _center_control_pivot(control: Control) -> void:
	#control.pivot_offset = control.size * 0.5
#
#
#static func alert_player_of_value_change_and_fade(
	#nodes: Array[Control],
	#delta: int,
	#significance_multiplier: float = 1.0,
	#pop_scale: float = 1.0,
	#flash_duration: float = 0.6,
	#fade_duration: float = 0.4
#) -> void:
	#if delta == 0:
		#return
#
	#var color := Color.GREEN if delta < 0 else Color.RED
#
	#for node in nodes:
		#await _flash_and_fade_node(
			#node,
			#color,
			#significance_multiplier,
			#pop_scale,
			#flash_duration,
			#fade_duration
		#)
#
#static func _flash_and_fade_node(
	#node: Control,
	#flash_color: Color,
	#significance_multiplier: float,
	#pop_scale: float,
	#flash_duration: float,
	#fade_duration: float
#) -> void:
	#if node == null:
		#return
#
	## Kill existing flash/fade
	#if node.has_meta("flash_tween"):
		#var old_tween = node.get_meta("flash_tween")
		#if old_tween is Tween:
			##old_tween.kill()
			#old_tween.custom_step(1000000)  # force-complete, fires "finished" instead of silently dying
#
	#await node.get_tree().process_frame
	#_center_control_pivot(node)
#
	#var tween := node.create_tween()
	#node.set_meta("flash_tween", tween)
#
	## Baseline
	#var base_scale := Vector2.ONE
	#node.scale = base_scale
	#node.modulate = flash_color
	#node.visible = true
#
	#var target_scale := base_scale * pop_scale * significance_multiplier
#
	## --- Flash / pop ---
	#tween.tween_property(
		#node,
		#"scale",
		#target_scale,
		#flash_duration * 0.2
	#).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
#
	#tween.tween_property(
		#node,
		#"scale",
		#base_scale,
		#flash_duration * 0.8
	#).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#
	#tween.parallel().tween_property(
		#node,
		#"modulate",
		#Color.WHITE,
		#flash_duration
	#)
#
	## --- Fade out ---
	#tween.tween_property(
		#node,
		#"modulate:a",
		#0.0,
		#fade_duration
	#).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#
	#await tween.finished
	#node.remove_meta("flash_tween")
