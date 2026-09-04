@tool
extends StatusModifierComponent
class_name Modifier_FlatDeltaToPlayerActionDamage

@export var actions_ids: Array[String] = []
@export var damage_delta: int

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "Modifier_FlatDeltaToPlayerActionDamage"
	d["actions_ids"] = actions_ids
	d["damage_delta"] = damage_delta
	return d

static func from_json_dict(data: Dictionary) -> Modifier_FlatDeltaToPlayerActionDamage:
	var component := Modifier_FlatDeltaToPlayerActionDamage.new()
	component.status_modifer_component_id = data.get("status_modifer_component_id", "")
	var ids: Array[String] = []
	for id in data.get("actions_ids", []):
		ids.append(str(id))
	component.actions_ids = ids
	component.damage_delta = int(data.get("damage_delta", 0))
	return component

func modify_context(context: EffectContext) -> void:
	if context.effect_origin is not PlayerAction:
		return
	if context.source is not PlayerEntity:
		return
	if context.id_of_effect_origin not in actions_ids:
		return
	if context.source == context.target:
		return
	if not context.damage_amount:
		return

	context.damage_amount += self.damage_delta
