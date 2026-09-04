@tool
extends EffectIntent
class_name ApplyStatusEffect

@export var status_definition: StatusEffectDefinition
@export var status_duration: int = 1
@export var number_of_stacks: int = 1

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "ApplyStatusEffect"
	d["status_id"] = status_definition.status_id if status_definition else ""
	d["status_duration"] = status_duration
	d["number_of_stacks"] = number_of_stacks
	return d

static func from_json_dict(data: Dictionary) -> ApplyStatusEffect:
	var e := ApplyStatusEffect.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	e.status_definition = AutoloadDatabase.get_status_effect_by_id(str(data.get("status_id", "")))
	e.status_duration = int(data.get("status_duration", 1))
	e.number_of_stacks = int(data.get("number_of_stacks", 1))
	return e

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var ctx = EffectContext.new()
	ctx.statuses_to_apply.append(self)
	return ctx
