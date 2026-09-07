@tool
extends CardFlowEffect
class_name Intent_DrawCardsBasedOnDamageDealt

@export var damage_per_card: int

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var draw_context: EffectContext = EffectContext.new()
	_insert_card_flow_into_context_(draw_context)
	
	draw_context.cards_to_draw = roundi(_intent_context.damage_that_was_done/damage_per_card)
	print("Returning draw based on damage context")
	return draw_context

### The real card count is only known once damage has actually been dealt (see
### create_intent_context() above), so CardFlowEffect's own cards_to_draw-based description
### (always 0 here at description-time) would render empty - describe the ratio instead.
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DRAWCARDSBASEDONDAMAGEDEALT_TEMPLATE"), {"damage_per_card": str(damage_per_card)})
