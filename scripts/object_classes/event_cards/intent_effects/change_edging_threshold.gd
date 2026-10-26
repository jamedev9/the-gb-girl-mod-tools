@tool
extends EffectIntent
class_name ChangeEdgingThreshold

### Moves the player's Edging threshold for the rest of the encounter (it edits the encounter's own copy, see
### GameState.set_edging_threshold(); the next encounter starts from the save's value again). The change is relative and
### in share of max Pleasure: -0.1 lowers the threshold by 10 points (80% -> 70%), +0.1 raises it. The result is kept between
### 0% and 100%. Moving it gives no Edging stack by itself: lowering it only makes it easier to be on the edge when a turn ends
### (MainCardgame._set_player_edging_threshold()). Player-only, so author it with NO_TARGET.

@export_range(-1.0, 1.0, 0.01) var threshold_change: float = -0.1

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.edging_threshold_change = self.threshold_change
	return context

### "Lower your Edging threshold by 10%" - Edging is a hoverable link to the status. The percentage is points of max
### Pleasure, the same unit the bar's marker uses.
func get_description_segments() -> Array[DescriptionSegment]:
	var template_key: String = "EFFECTINTENT_CHANGEEDGINGTHRESHOLD_RAISE_TEMPLATE" if threshold_change > 0.0 else "EFFECTINTENT_CHANGEEDGINGTHRESHOLD_LOWER_TEMPLATE"
	return DescriptionBuilder.parse_template(tr(template_key), {
		"status_name": _status_name_segment(),
		"percent": str(roundi(absf(threshold_change) * 100.0))})

func _status_name_segment() -> DescriptionSegment:
	var edging: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(EdgingRules.STATUS_ID)
	if edging:
		return DescriptionSegment.nested_segment(edging.get_effect_name(), edging.get_description_segments())
	return DescriptionSegment.text_segment(tr("STATUSEFFECTDEFINITION_EDGING_STATUS_NAME"))

func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
