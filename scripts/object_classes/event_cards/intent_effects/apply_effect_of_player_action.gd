@tool
extends EffectIntent
class_name ApplyEffectOfPlayerAction

@export var player_action_id: String

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new_player_action_damage_intent(
		game_state,player_action_id,null
	)
	context.source = PlayerEntity.new(game_state)

	return context

func get_description_segments() -> Array[DescriptionSegment]:
	var action_def: PlayerAction = AutoloadDatabase.get_player_action_by_id(player_action_id)
	var action_name: String = action_def.get_action_name() if action_def else "?"
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_APPLYEFFECTOFPLAYERACTION_TEMPLATE"), {"action_name": action_name})

func get_targeting_preposition() -> String:
	return tr("PREPOSITION_ON")

### "Trigger Anal on the Partner with your Anal Action" is redundant - if the only targeting
### rule is "whoever has this exact action assigned", that target is already implied by
### triggering the action itself, so drop the targeting phrase entirely and just say
### "Trigger Anal". Any other targeting (a different/additional action, a different rule
### entirely, SINGLE_OPPONENT, ALL_OPPONENTS, ...) still needs to be stated, since it's not
### implied by the effect.
func description_includes_targeting(
		targeting_intent: TargetingSystem.TargetingMode, targeting_rules: Array[TargetingRule]) -> bool:
	if targeting_intent != TargetingSystem.TargetingMode.RULE_BASED:
		return true
	if targeting_rules.size() != 1:
		return true
	var rule: TargetingRule = targeting_rules[0]
	if rule is TargetsHaveOneOfSeveralActionsAssigned:
		var action_rule: TargetsHaveOneOfSeveralActionsAssigned = rule as TargetsHaveOneOfSeveralActionsAssigned
		if action_rule.action_ids.size() == 1 and action_rule.action_ids[0] == player_action_id:
			return false
	return true
