@tool
extends EffectIntent
class_name RandomlyHealOrDealDamage

@export var damage: int
@export_range(0,1,0.01) var chance_to_heal: float

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context = EffectContext.new()
	var random_nr: float = randf_range(0,1)
	if random_nr <= chance_to_heal:
		context.healing_amount = damage
	else:
		context.damage_amount = self.damage
	return context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_RANDOMLYHEALORDEALDAMAGE_TEMPLATE"),
		{"chance": str(round(chance_to_heal * 100)), "damage": str(damage)})

### Same reasoning as HealForValueEffect.get_targeted_description_segments() - "chance to lose X
### to {target}" reads backwards, target goes first as the grammatical subject instead.
func get_targeted_description_segments(
		targeting_intent: TargetingSystem.TargetingMode, targeting_rules: Array[TargetingRule]) -> Array[DescriptionSegment]:
	if targeting_intent == TargetingSystem.TargetingMode.PLAYER or targeting_intent == TargetingSystem.TargetingMode.NO_TARGET:
		return []
	var target_segments: Array[DescriptionSegment] = EffectAndTargetIntent.describe_targeting_phrase(targeting_intent, targeting_rules)
	if target_segments.is_empty():
		return []
	var singular: bool = EffectAndTargetIntent.targeting_is_singular(targeting_intent, targeting_rules)
	var key: String = "EFFECTINTENT_RANDOMLYHEALORDEALDAMAGE_TARGETED_TEMPLATE_SINGULAR" if singular else "EFFECTINTENT_RANDOMLYHEALORDEALDAMAGE_TARGETED_TEMPLATE"
	### The target phrase's own template is written lowercase (meant to normally follow "to"/
	### "When") - capitalize it here since it's now sentence-initial.
	var result: Array[DescriptionSegment] = DescriptionBuilder.capitalize_first_letter(target_segments)
	result.append(DescriptionSegment.text_segment(" "))
	result.append_array(DescriptionBuilder.parse_template(
		tr(key), {"chance": str(round(chance_to_heal * 100)), "damage": str(damage)}))
	return result

### The target is already embedded above - never append a separate targeting phrase too.
func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false

### Same reasoning as DealDamageEffect.get_self_targeted_description_segments() - explicit
### "Player" since targeting_intent=PLAYER always means the player, regardless of which side
### owns the surrounding status/passive.
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_RANDOMLYHEALORDEALDAMAGE_SELF_TEMPLATE"),
		{"chance": str(round(chance_to_heal * 100)), "damage": str(damage)})
