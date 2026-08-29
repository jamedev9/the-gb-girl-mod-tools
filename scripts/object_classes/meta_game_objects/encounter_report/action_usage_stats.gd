extends Resource
class_name ActionUsageStats

var action_id: String

var damage_dealt_by_opponent_type: Dictionary[String,int]
func record_damage_to_opponent(opponent_type_id: String, damage: int) -> void:
	Utils.increase_value_in_dictionary(damage_dealt_by_opponent_type,opponent_type_id,damage)

var opponents_defeated_by_type: Dictionary[String,int]
func record_opponent_type_defeated(opponent_type_id: String) -> void:
	Utils.increase_value_in_dictionary(opponents_defeated_by_type,opponent_type_id,1)

func get_total_damage_dealt() -> int:
	var count: int = 0
	for type_id in damage_dealt_by_opponent_type.keys():
		var damage_dealt: int = damage_dealt_by_opponent_type[type_id]
		count += damage_dealt
	return count
		
