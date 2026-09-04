@tool
extends Resource
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

func to_json_dict() -> Dictionary:
	var condition_dicts: Array = []
	for condition in trigger_conditions:
		condition_dicts.append(condition.to_json_dict())
	var intent_dicts: Array = []
	for intent in effect_intents:
		intent_dicts.append(intent.to_json_dict())
	return {
		"trigger_component_id": trigger_component_id,
		"only_require_one_condition": only_require_one_condition,
		"trigger_conditions": condition_dicts,
		"effect_intents": intent_dicts,
	}

static func from_json_dict(data: Dictionary) -> StatusTriggeredComponent:
	var component := StatusTriggeredComponent.new()
	component.trigger_component_id = data.get("trigger_component_id", "")
	component.only_require_one_condition = data.get("only_require_one_condition", false)
	for condition_data in data.get("trigger_conditions", []):
		var condition: TriggerCondition = TriggerCondition.from_json_dict(condition_data)
		if condition:
			component.trigger_conditions.append(condition)
	for intent_data in data.get("effect_intents", []):
		var intent: EffectAndTargetIntent = EffectAndTargetIntent.from_json_dict(intent_data)
		if intent:
			component.effect_intents.append(intent)
	return component
