@tool
extends SetPlayerPleasure
class_name SetPleasureToPercent

### Sets the player's Pleasure to a share of their max: 0.5 = half the bar, 0.99 = one point under a full 100 bar, 0 = empty. A share
### that doesn't come out as a whole amount rounds DOWN, so anything under 100% can never round up into an orgasm.

### Float error margin, so 0.29 x 100 (28.999999999999996 in floats) still gives 29. Same idea as EdgingRules.ROUNDING_TOLERANCE.
const ROUNDING_TOLERANCE: float = 0.000001

@export_range(0.0, 1.0, 0.01, "or_greater") var share_of_max: float = 0.5

func get_target_pleasure(max_pleasure: int) -> int:
	return get_pleasure_for_share(share_of_max, max_pleasure)

static func get_pleasure_for_share(share: float, max_pleasure: int) -> int:
	return maxi(floori(share * float(max_pleasure) + ROUNDING_TOLERANCE), 0)

### "Set your Pleasure to 50% of max"
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_SETPLEASURETOPERCENT_TEMPLATE"), {"percent": str(roundi(share_of_max * 100.0))})
