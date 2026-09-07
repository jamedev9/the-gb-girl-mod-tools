@tool
extends StatusModifierComponent
class_name Modifier_DrawCardsFromDamage

@export var pleasure_per_card: int

func modify_context(context: EffectContext) -> void:
	if context.source is not OpponentEntity:
		return
	if not context.damage_amount:
		return
	
	var cards_to_draw: int = int(floor(float(float(context.damage_amount) / float(pleasure_per_card))))
	
	if cards_to_draw == 0:
		return
	
	context.card_flow_effect = true
	context.cards_to_draw = cards_to_draw

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("MODIFIER_DRAWCARDSFROMDAMAGE_TEMPLATE"), {"pleasure_per_card": str(pleasure_per_card)})
