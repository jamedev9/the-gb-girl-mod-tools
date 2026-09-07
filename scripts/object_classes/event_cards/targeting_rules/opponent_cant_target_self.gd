@tool
extends TargetingRule
class_name OpponentCantTargetSelf

### Pure implementation-detail exclusion (the entity performing this effect can't be its own
### target) - not meaningful to state explicitly in a description, so this contributes no text.
### EffectAndTargetIntent.get_description_segments() skips empty rule descriptions when
### and/or-joining RULE_BASED targeting rules, rather than leaving a dangling conjunction.
func get_description_segments() -> Array[DescriptionSegment]:
	return []
