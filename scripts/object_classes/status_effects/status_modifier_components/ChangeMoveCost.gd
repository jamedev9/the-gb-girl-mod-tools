@tool
extends StatusModifierComponent
class_name ChangeMoveCost

enum ChangeType {
	FLAT,
	PERCENTAGE
}
@export var reduction_type: ChangeType

@export var flat_change: int
@export var percentage_mult: float


func modify_context(effect_context: EffectContext) -> void:
	if effect_context.energy_reason == EffectContext.EnergyReason.MOVED_PLAYER_ACTION:
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

### Overridden by ChangeMoveCostOfCertainActions to name the specific actions instead of "an
### Action".
func _move_cost_subject() -> String:
	return tr("CHANGEMOVECOST_SUBJECT_GENERIC")

func get_description_segments() -> Array[DescriptionSegment]:
	var subject: String = _move_cost_subject()
	if reduction_type == ChangeType.FLAT:
		var key: String = "CHANGEMOVECOST_FLAT_INCREASE_TEMPLATE" if flat_change > 0 else "CHANGEMOVECOST_FLAT_DECREASE_TEMPLATE"
		return DescriptionBuilder.parse_template(tr(key), {"subject": subject, "amount": str(abs(flat_change))})
	if is_zero_approx(percentage_mult):
		return DescriptionBuilder.parse_template(tr("CHANGEMOVECOST_PERCENTAGE_FREE_TEMPLATE"), {"subject": subject})
	var percent: int = roundi(abs(percentage_mult - 1.0) * 100.0)
	var key: String = "CHANGEMOVECOST_PERCENTAGE_INCREASE_TEMPLATE" if percentage_mult > 1.0 else "CHANGEMOVECOST_PERCENTAGE_DECREASE_TEMPLATE"
	return DescriptionBuilder.parse_template(tr(key), {"subject": subject, "percent": str(percent)})
