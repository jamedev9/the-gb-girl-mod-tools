@tool
extends DealDamageEffect
class_name DealDamageIfSourceHasPlayerActions

@export var action_ids: Array[String] = []

func create_intent_context(game_state:GameState,intent_context: EffectContext) -> EffectContext:
	var context = EffectContext.new()
	
	var source: TargetEntity = intent_context.source
	context.damage_amount = 0
	
	if source is not OpponentEntity:
		return context
	
	var opponent_id: String = source.opponent_id
	var action_on_opponent: String = game_state.get_action_assigned_to_opponent(opponent_id)
	
	if action_on_opponent != "" and action_on_opponent in action_ids:
		context.damage_amount = self.damage
		
	return context
	
