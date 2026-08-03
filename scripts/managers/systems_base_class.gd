extends Node
class_name GameSystem
### These are JUDGES: They check signals, and if OK they ask main script for game state change.

@onready var main_game: Node = get_tree().get_current_scene()
