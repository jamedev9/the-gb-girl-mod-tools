@tool
extends StatusModifierComponent
class_name Status_ReducePlayerEnergy

@export var energy_reduction: int

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "Status_ReducePlayerEnergy"
	d["energy_reduction"] = energy_reduction
	return d

static func from_json_dict(data: Dictionary) -> Status_ReducePlayerEnergy:
	var component := Status_ReducePlayerEnergy.new()
	component.status_modifer_component_id = data.get("status_modifer_component_id", "")
	component.energy_reduction = int(data.get("energy_reduction", 0))
	return component

func modify_context(context: EffectContext) -> void:
	context.player_energy_reduction = self.energy_reduction
