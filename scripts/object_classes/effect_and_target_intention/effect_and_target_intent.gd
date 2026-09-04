@tool
extends Resource
class_name EffectAndTargetIntent

@export var targeting_intent: TargetingSystem.TargetingMode
@export var targeting_rules: Array[TargetingRule] = []
@export var effect_intent: EffectIntent

func to_json_dict() -> Dictionary:
	var rule_dicts: Array = []
	for rule in targeting_rules:
		rule_dicts.append(rule.to_json_dict())
	return {
		"targeting_intent": TargetingSystem.TargetingMode.keys()[targeting_intent],
		"targeting_rules": rule_dicts,
		"effect_intent": effect_intent.to_json_dict() if effect_intent else {},
	}

static func from_json_dict(data: Dictionary) -> EffectAndTargetIntent:
	var intent := EffectAndTargetIntent.new()

	var mode_name: String = data.get("targeting_intent", "")
	var matched_key: String = ModExportable.find_case_insensitive_enum_key(TargetingSystem.TargetingMode.keys(), mode_name)
	if matched_key != "":
		intent.targeting_intent = TargetingSystem.TargetingMode[matched_key]

	for rule_data in data.get("targeting_rules", []):
		var rule: TargetingRule = TargetingRule.from_json_dict(rule_data)
		if rule:
			intent.targeting_rules.append(rule)

	var effect_intent_data: Dictionary = data.get("effect_intent", {})
	if not effect_intent_data.is_empty():
		intent.effect_intent = EffectIntent.from_json_dict(effect_intent_data)

	return intent
	
