@tool
extends SetPlayerPleasure
class_name SetPleasureToValue

### Sets the player's Pleasure to a fixed amount, whatever their max is. At or above the max it is an orgasm, like any Pleasure.

@export_range(0, 1000, 1, "or_greater") var pleasure_value: int = 0

func get_target_pleasure(_max_pleasure: int) -> int:
	return pleasure_value

### "Set your Pleasure to 30"
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_SETPLEASURETOVALUE_TEMPLATE"), {"value": str(pleasure_value)})
