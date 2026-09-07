@tool
extends EffectIntent
class_name Intent_SummonOpponent

@export var opponent_type_id: String
@export var opponent_is_unique: bool = false

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.spawn_opponent = true
	context.spawn_opponent_type = opponent_type_id
	context.spawned_opponent_is_unique = opponent_is_unique
	return context

func get_description_segments() -> Array[DescriptionSegment]:
	var type_def: OpponentType = AutoloadDatabase.opponent_types.get(opponent_type_id, null)
	var type_name: String = type_def.get_opponent_type_name() if type_def else "?"
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_SUMMONOPPONENT_TEMPLATE"), {"type_name": type_name})

### Summoning a new opponent never targets an already-existing one.
func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
