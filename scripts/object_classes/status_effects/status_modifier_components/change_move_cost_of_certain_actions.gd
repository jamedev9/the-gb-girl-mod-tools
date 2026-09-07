@tool
extends ChangeMoveCost
class_name ChangeMoveCostOfCertainActions

@export var action_ids: Array[String]

func modify_context(effect_context: EffectContext) -> void:
	if effect_context.energy_reason == EffectContext.EnergyReason.MOVED_PLAYER_ACTION:
		if effect_context.player_action_id not in action_ids:
			return
		var energy_delta: int = effect_context.energy_delta
		if self.reduction_type == ChangeType.FLAT:
			#effect_context.energy_delta += flat_change
			energy_delta += flat_change
			effect_context.energy_delta = energy_delta
			return
		if self.reduction_type == ChangeType.PERCENTAGE:
			#effect_context.energy_delta *= percentage_mult
			energy_delta = roundi(energy_delta*percentage_mult)
			effect_context.energy_delta = energy_delta
			return

func _move_cost_subject() -> String:
	return tr("CHANGEMOVECOST_SUBJECT_SPECIFIC_TEMPLATE").format({"action_names": _action_names(action_ids)})
