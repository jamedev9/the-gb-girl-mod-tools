@tool
extends EffectIntent
class_name DrawCardsBasedOnOrgasms

@export var cards_per_orgasm: int

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	var orgasm_count: int = game_state.get_current_orgasm_count()
	
	#Card flow system
	context.card_flow_effect = true
	context.cards_to_draw = cards_per_orgasm*orgasm_count

	return context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_pluralized_template(
		cards_per_orgasm,
		"EFFECTINTENT_DRAWCARDSBASEDONORGASMS_TEMPLATE_SINGULAR",
		"EFFECTINTENT_DRAWCARDSBASEDONORGASMS_TEMPLATE",
		{"amount": str(cards_per_orgasm)})

func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
