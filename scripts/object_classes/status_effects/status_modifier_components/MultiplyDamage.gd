@tool
extends StatusModifierComponent
class_name MultiplyDamage

@export var damage_phase: DamageSystem.DamagePhase
@export var multiplier: float = 1.0

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "MultiplyDamage"
	d["damage_phase"] = DamageSystem.DamagePhase.keys()[damage_phase]
	d["multiplier"] = multiplier
	return d

static func from_json_dict(data: Dictionary) -> MultiplyDamage:
	var component := MultiplyDamage.new()
	component.status_modifer_component_id = data.get("status_modifer_component_id", "")
	var phase_name: String = data.get("damage_phase", "")
	var matched_key: String = ModExportable.find_case_insensitive_enum_key(DamageSystem.DamagePhase.keys(), phase_name)
	if matched_key != "":
		component.damage_phase = DamageSystem.DamagePhase[matched_key]
	component.multiplier = float(data.get("multiplier", 1.0))
	return component

func modify_context(context: EffectContext) -> void:
	if not context.damage_amount:
		return
	if not context.damage_phase == self.damage_phase:
		return
	if context.source == context.target:
		return

	context.damage_multipliers.append(self.multiplier)
