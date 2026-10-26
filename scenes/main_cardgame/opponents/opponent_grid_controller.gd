extends Control
class_name OpponentGridController

@export var columns: int = 4
@export var rows: int = 2
@export var opponent_card_size: Vector2 = Vector2(270, 290)

var grid: Array = [] # grid[col][row]

const FLOW_TIMER_DELAY: float = 0.1

signal request_opponent_card_moving_sound_effect

func _ready() -> void:
	_initialize_grid()
	
func _initialize_grid() -> void:
	grid.resize(columns)
	for c in columns:
		grid[c] = []
		grid[c].resize(rows)
		
func _grid_to_local_position(col: int, row: int) -> Vector2:
	return Vector2(col * opponent_card_size.x, row * opponent_card_size.y)

func remove_opponent_card(opponent_card: OpponentCard):
	var pos: Vector2i = opponent_card.grid_position
	grid[pos.x][pos.y] = null

func _reflow_grid():
	var moved := true
	
	while moved:
		moved = false
		
		# Phase A: cascade UP fully
		while true:
			var up_moves = _collect_upward_moves()
			if up_moves.is_empty():
				break
			
			_apply_moves(up_moves)
			await _animate_moves(up_moves)
			moved = true
		
		# Phase B: cascade LEFT fully
		while true:
			var left_moves = _collect_left_moves()
			if left_moves.is_empty():
				break
			
			_apply_moves(left_moves)
			await _animate_moves(left_moves)
			moved = true

func _collect_upward_moves() -> Array:
	var moves := []
	
	for row in range(1, rows):
		for col in columns:
			if grid[col][row] != null and grid[col][row - 1] == null:
				moves.append({
					"from": Vector2i(col, row),
					"to": Vector2i(col, row - 1)
				})
	
	return moves

func _collect_left_moves() -> Array:
	var moves := []
	
	for col in range(1, columns):
		for row in rows:
			if grid[col][row] != null and grid[col - 1][row] == null:
				moves.append({
					"from": Vector2i(col, row),
					"to": Vector2i(col - 1, row)
				})
	
	return moves

func _apply_moves(moves: Array):
	for move in moves:
		var from: Vector2i = move["from"]
		var to: Vector2i = move["to"]
		
		var opponent = grid[from.x][from.y]
		grid[from.x][from.y] = null
		grid[to.x][to.y] = opponent
		
		opponent.grid_position = to

func _animate_moves(moves: Array) -> void:
	var timer: Timer = Timer.new()
	add_child(timer)
	timer.autostart = true
	timer.start(FLOW_TIMER_DELAY)
	
	for move in moves:
		var to: Vector2i = move["to"]
		var opponent_card: OpponentCard = grid[to.x][to.y]
		
		var target_pos = _grid_to_local_position(to.x, to.y)
		animate_opponent_card_moving(opponent_card,target_pos)
		#opponent_card.tween_to_position(target_pos)
	
	emit_signal("request_opponent_card_moving_sound_effect")
	await timer.timeout


func _move_opponent(from_col: int, from_row: int, to_col: int, to_row: int):
	var opponent_card: OpponentCard = grid[from_col][from_row]
	grid[from_col][from_row] = null
	grid[to_col][to_row] = opponent_card
	
	opponent_card.grid_position = Vector2i(to_col, to_row)
	
	var target_pos = _grid_to_local_position(to_col, to_row)
	await opponent_card.tween_to_position(target_pos, 0.3)

func find_next_spawn_position() -> Vector2i:
	for row in rows:
		for col in columns:
			if grid[col][row] == null:
				#print("next spawn location: %s"%[Vector2i(col, row)])
				return Vector2i(col, row)
	
	return Vector2i(-1, -1) # grid full

func insert_new_opponent_card(opponent_card: OpponentCard) -> void:
	var cell: Vector2i = find_next_spawn_position()
	if cell.x == -1:
		push_warning("Opponent grid full.")
		return
		
	add_child(opponent_card)
	#opponent_card.size = opponent_card_size
	grid[cell.x][cell.y] = opponent_card
	opponent_card.grid_position = cell
	
	var spawning_position: Vector2 = Vector2(self.size.x,cell.y*opponent_card_size.y)
	opponent_card.position = spawning_position
	var target_pos = _grid_to_local_position(cell.x, cell.y)
	animate_opponent_card_moving(opponent_card,target_pos)
	emit_signal("request_opponent_card_moving_sound_effect")

func animate_opponent_card_moving(opponent_card: OpponentCard,target_pos: Vector2) -> void:
	opponent_card.tween_to_position(target_pos, 0.3)
	
