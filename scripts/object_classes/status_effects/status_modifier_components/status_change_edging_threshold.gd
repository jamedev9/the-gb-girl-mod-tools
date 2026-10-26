@tool
extends StatusModifierComponent
class_name Status_ChangeEdgingThreshold

### While a status or passive of the player has this, their Edging threshold is moved by threshold_change_per_stack for EACH STACK
### of the status (a passive counts as 1), on top of the base threshold. The stacks add up: -0.1 per stack is 10 points of max Pleasure
### lower at 1 stack, 20 at 2, 30 at 3 (80% -> 70% -> 60% -> 50%). The result is kept between 0% and 100%.
### Nothing needs to run on a context: GameState.get_edging_threshold() finds the component by scanning the player's statuses and passives,
### like Status_PreventPlayerOrgasm. The effect goes with the status, so when it is cleared or runs out the threshold is back where it was.
### MainCardgame moves the pleasure bar's marker whenever a status or passive comes or goes (_sync_edging_threshold()).

### The change in the threshold per stack, as a share of max Pleasure: -0.1 lowers it by 10 points, +0.1 raises it.
@export_range(-1.0, 1.0, 0.01) var threshold_change_per_stack: float = -0.1

### The total change this component makes at the given stack count (1 for a passive).
func get_threshold_change(stacks: int) -> float:
	return threshold_change_per_stack * float(maxi(stacks, 1))

### Generic description support (see DescriptionBuilder): "Your Edging threshold is lowered by 10% per stack (additive)". Edging is a
### hoverable link to the status, the percent is points of max Pleasure (the unit the bar's marker uses).
func get_description_segments() -> Array[DescriptionSegment]:
	var template_key: String = "STATUS_CHANGEEDGINGTHRESHOLD_RAISED_TEMPLATE" if threshold_change_per_stack > 0.0 else "STATUS_CHANGEEDGINGTHRESHOLD_LOWERED_TEMPLATE"
	var segments: Array[DescriptionSegment] = DescriptionBuilder.parse_template(tr(template_key), {
		"status_name": _status_name_segment(),
		"percent": str(roundi(absf(threshold_change_per_stack) * 100.0))})
	segments.append(DescriptionSegment.text_segment(" "))
	segments.append_array(DescriptionBuilder.per_stack_additive_segments())
	return segments

func _status_name_segment() -> DescriptionSegment:
	var edging: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(EdgingRules.STATUS_ID)
	if edging:
		return DescriptionSegment.nested_segment(edging.get_effect_name(), edging.get_description_segments())
	return DescriptionSegment.text_segment(tr("STATUSEFFECTDEFINITION_EDGING_STATUS_NAME"))
