@tool
extends ModExportable
class_name StatusTriggeredComponent

@export var trigger_component_id: String
@export var only_require_one_condition: bool = false
@export var trigger_conditions: Array[TriggerCondition]
@export var effect_intents: Array[EffectAndTargetIntent]

func should_component_trigger(
	input_context: EffectContext,
	game_state: GameState,
	save_game_state: SaveGameState,
	owner_of_trigger: TargetEntity) -> bool:
		var conditions_met: int = 0
		#print("Runnin should_component_trigger for %s"%trigger_component_id)
		if trigger_conditions.is_empty():
			#print("No trigger conditions - returning false")
			return false
		for condition in trigger_conditions:
			if condition.is_condition_met(input_context,game_state,save_game_state,owner_of_trigger):
				#print("Found contition that is not met, returning false.")
				conditions_met += 1
		#print("Conditions all met! Returning true")
		
		if only_require_one_condition and conditions_met >= 1:
			#print("trigger %s only needs one condition, this is met, returning true"%trigger_component_id)
			return true
		if not only_require_one_condition and conditions_met == trigger_conditions.size():
			#print("trigger %s has all its conditions met, returning true"%trigger_component_id)
			return true
		#print("Trigger is not met, returning false")
		return false

func return_trigger_context(_intent_context: EffectContext, source: TargetEntity = null) -> TriggeredEffectContext:
	return null

### Generic description support (see DescriptionBuilder) - the "when" half of this trigger's
### tooltip line (paired with effect_intents for the "then" half - see
### EffectDefinition.get_tooltip_description_segments()). See
### TriggerCondition.describe_conditions() - OpponentActionDefinition shares this same
### trigger_conditions/only_require_one_condition shape and uses the same helper.
func get_when_description_segments() -> Array[DescriptionSegment]:
	return TriggerCondition.describe_conditions(trigger_conditions, only_require_one_condition)
