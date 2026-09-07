@tool
extends TargetingRule
class_name OpponentWithMostHealthRemaining

### "The most" is a single winner by definition (ties notwithstanding) - always singular.
func targets_potentially_multiple() -> bool:
	return false

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TARGETINGRULE_OPPONENTWITHMOSTHEALTHREMAINING_TEMPLATE"))

### See TargetingRule.describe_selection(). With no filter siblings, reads as the standalone
### "the {OPPONENT} with the most {PLEASURE} remaining" above. With a real filter phrase to pick
### among, wraps it instead: "whichever of the Partners with X Passive has the most Pleasure
### remaining".
func describe_selection(filter_segments: Array[DescriptionSegment]) -> Array[DescriptionSegment]:
	if filter_segments.is_empty():
		return get_description_segments()
	var result: Array[DescriptionSegment] = [DescriptionSegment.text_segment(tr("TARGETINGRULE_OPPONENTWITHMOSTHEALTHREMAINING_AMONG_PREFIX") + " ")]
	result.append_array(filter_segments)
	result.append(DescriptionSegment.text_segment(" "))
	result.append_array(DescriptionBuilder.parse_template(tr("TARGETINGRULE_OPPONENTWITHMOSTHEALTHREMAINING_AMONG_SUFFIX")))
	return result
