@tool
extends TargetingRule
class_name OnlyOneOpponent

### A selector rule (see TargetingSystem._is_selector_rule()) - picks exactly one at random from
### whatever the other rules leave valid, so this is always a single target.
func targets_potentially_multiple() -> bool:
	return false

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TARGETINGRULE_ONLYONEOPPONENT_TEMPLATE"))

### See TargetingRule.describe_selection(). With no filter siblings (or only implementation-
### detail ones like OpponentCantTargetSelf, which contribute no text), reads as the standalone
### "a random {OPPONENT}" above. With a real filter phrase to pick from, wraps it instead of
### sitting beside it: "a random one of the Partners with Bros for Life Passive", not "the
### Partners with Bros for Life Passive and a random Partner".
func describe_selection(filter_segments: Array[DescriptionSegment]) -> Array[DescriptionSegment]:
	if filter_segments.is_empty():
		return get_description_segments()
	var result: Array[DescriptionSegment] = [DescriptionSegment.text_segment(tr("TARGETINGRULE_ONLYONEOPPONENT_AMONG_PREFIX") + " ")]
	result.append_array(filter_segments)
	return result
