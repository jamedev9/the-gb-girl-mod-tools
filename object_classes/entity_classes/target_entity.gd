extends Node
class_name TargetEntity

var game_state: GameState

#region Status methods - overwritten by children
func get_data():
	pass
func get_status_effects() -> Dictionary:
	return {}
func get_passive_effects() -> Array:
	return []

#endregion
