@tool
extends EffectIntent
class_name Intent_ChangeOpponentAction

@export var opponent_action_id: String

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var move_intent: EffectContext = EffectContext.new_change_opponent_action_intent(
		game_state,
		opponent_action_id,
		self,
		self.intent_effect_id)
	return move_intent

### "Switch next Move to X on target Partner" put the target in an awkward spot at the very
### end - "Switch target Partner's next Move to X" reads more naturally with the target right
### up front, so this embeds it in the phrase itself (see get_targeted_description_segments())
### instead of using the normal end-of-sentence targeting composition.
func get_targeted_description_segments(
		targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> Array[DescriptionSegment]:
	var action_def: OpponentActionDefinition = AutoloadDatabase.opponent_actions.get(opponent_action_id, null)
	var action_name: String = action_def.get_action_name() if action_def else "?"
	var key: String
	match targeting_intent:
		TargetingSystem.TargetingMode.SINGLE_OPPONENT:
			key = "EFFECTINTENT_CHANGEOPPONENTACTION_SINGLE_TEMPLATE"
		TargetingSystem.TargetingMode.ALL_OPPONENTS:
			key = "EFFECTINTENT_CHANGEOPPONENTACTION_ALL_TEMPLATE"
		_:
			key = "EFFECTINTENT_CHANGEOPPONENTACTION_GENERIC_TEMPLATE"
	return DescriptionBuilder.parse_template(tr(key), {"action_name": action_name})

### The target is already embedded in get_targeted_description_segments() above, so never
### append a separate targeting phrase too.
func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
