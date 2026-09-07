@tool
extends EffectIntent
class_name Intent_GivePlayerUnlockRewards

@export var reward_ids: Array[String]

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var intent_context: TriggeredEffectContext = TriggeredEffectContext.new()
	intent_context.id_of_effect_origin = intent_effect_id
	intent_context.effect_origin = self
	
	intent_context.unlock_rewards_to_give_player = reward_ids

	return intent_context

func get_description_segments() -> Array[DescriptionSegment]:
	var names: Array[String] = []
	for id in reward_ids:
		var reward_def: RewardDefinition = AutoloadDatabase.get_unlock_reward_definition(id)
		names.append(reward_def.get_reward_name() if reward_def else "?")
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_GIVEPLAYERUNLOCKREWARDS_TEMPLATE"), {"names": DescriptionBuilder.join_with_and(names)})
