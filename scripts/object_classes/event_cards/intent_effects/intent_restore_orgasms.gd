@tool
extends EffectIntent
class_name Intent_RestoreOrgasms

@export var orgasms_to_restore: int

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.restore_orgasms = self.orgasms_to_restore
	return context

### Orgasms are a player-only resource (like Energy), no keyword for it yet - flagging as a
### candidate if you want one, plain text for now.
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_pluralized_template(
		orgasms_to_restore,
		"EFFECTINTENT_RESTOREORGASMS_TEMPLATE_SINGULAR",
		"EFFECTINTENT_RESTOREORGASMS_TEMPLATE",
		{"count": str(orgasms_to_restore)})

func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
