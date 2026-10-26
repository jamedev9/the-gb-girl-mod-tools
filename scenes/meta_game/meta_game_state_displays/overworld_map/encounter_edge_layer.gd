extends Node2D
class_name EncounterEdgeLayer

var node_lookup: Dictionary[String, MapEncounterNode] = {}
var forward_graph: Dictionary[String, Array] = {}

const LINE_WIDTH: float = 3

func _draw() -> void:
	for from_id in forward_graph.keys():
		if not node_lookup.has(from_id):
			continue

		var from_node := node_lookup[from_id]
		var from_global := _get_from_anchor_global(from_node)

		for to_id in forward_graph[from_id]:
			if not node_lookup.has(to_id):
				continue

			var to_node = node_lookup[to_id]
			var _to_global = _get_to_anchor_global(to_node)

			 #IMPORTANT: convert global → local
			var from_local : Vector2 = to_local(from_global)
			var to_local_pos : Vector2 = to_local(_to_global)

			#draw_edge(from_local, to_local_pos)
			
			var mid_x := (from_local.x + to_local_pos.x) * 0.5
			
			draw_line(from_local, Vector2(mid_x, from_local.y), Color.GRAY, LINE_WIDTH)
			draw_line(Vector2(mid_x, from_local.y), Vector2(mid_x, to_local_pos.y), Color.GRAY, LINE_WIDTH)
			draw_line(Vector2(mid_x, to_local_pos.y), to_local_pos, Color.GRAY, LINE_WIDTH)


func _get_from_anchor_global(node: Control) -> Vector2:
	#var rect := node.get_global_rect()
	#return rect.position + Vector2(rect.size.x, rect.size.y * 0.5)
	return node.global_position+node.size*0.5

func _get_to_anchor_global(node: Control) -> Vector2:
	#var rect := node.get_global_rect()
	#return rect.position + Vector2(0, rect.size.y * 0.5)
	return node.global_position+node.size*0.5

func _get_node_anchor(node: Control) -> Vector2:
	var rect := node.get_global_rect()
	return rect.position + Vector2(rect.size.x, rect.size.y * 0.5)
func _get_target_anchor(node: Control) -> Vector2:
	var rect := node.get_global_rect()
	return rect.position + Vector2(0, rect.size.y * 0.5)
func draw_edge(from: Vector2, to: Vector2) -> void:
	var mid_x := (from.x + to.x) * 0.5
	var p1 := from
	var p2 := Vector2(mid_x, from.y)
	var p3 := Vector2(mid_x, to.y)
	var p4 := to

	draw_line(p1, p2, Color.GRAY, LINE_WIDTH)
	draw_line(p2, p3, Color.GRAY, LINE_WIDTH)
	draw_line(p3, p4, Color.GRAY, LINE_WIDTH)
