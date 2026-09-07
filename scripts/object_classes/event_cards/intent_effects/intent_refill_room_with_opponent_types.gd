@tool
extends EffectIntent
class_name Intent_RefillRoomWithOpponentTypes

@export var opponent_type_ids: Array[String]


func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	
	var missing_opponents: int = game_state.get_missing_opponent_count()
	
	var opponent_spawn_array: Array[String] = []
	for i in missing_opponents:
		var type: String = opponent_type_ids[randi_range(0,opponent_type_ids.size()-1)]
		opponent_spawn_array.append(type)
		
	context.spawn_multiple_opponents = opponent_spawn_array

	return context

func get_description_segments() -> Array[DescriptionSegment]:
	var names: Array[String] = []
	for id in opponent_type_ids:
		var opponent_type: OpponentType = AutoloadDatabase.opponent_types.get(id, null)
		names.append(opponent_type.get_opponent_type_name() if opponent_type else "?")
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_REFILLROOMWITHOPPONENTTYPES_TEMPLATE"), {"names": DescriptionBuilder.join_with_and(names, true)})
