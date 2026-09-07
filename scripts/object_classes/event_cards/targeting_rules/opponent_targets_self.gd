@tool
extends TargetingRule
class_name OpponentTargetsSelf

### Targets whoever owns this passive/status itself (e.g. Breeding Kink: the opponent with the
### passive gives themselves extra Pleasure when hit by Vaginal) - always exactly one target.
func targets_potentially_multiple() -> bool:
	return false

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TARGETINGRULE_OPPONENTTARGETSSELF_TEMPLATE"))
