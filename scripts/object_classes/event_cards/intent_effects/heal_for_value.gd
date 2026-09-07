@tool
extends EffectIntent
class_name HealForValueEffect

@export var healing: int

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context = EffectContext.new()
	context.healing_amount = self.healing
	return context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_HEALFORVALUEEFFECT_TEMPLATE"), {"healing": str(healing)})

### "Lose X Pleasure to {target}" is backwards English - "lose X to Y" means the SPEAKER loses X
### and Y is the beneficiary/cause (like "I lost the game to my opponent"), not "Y loses X". Puts
### the target first as the grammatical subject instead: "{target} loses X Pleasure" - singular/
### plural verb agreement via EffectAndTargetIntent.targeting_is_singular(), since the target
### phrase itself can resolve to either ("a random Partner" vs "the Partners with X Action").
### Doesn't apply to PLAYER/NO_TARGET - those have no named target to lead with (see
### get_self_targeted_description_segments() for PLAYER).
func get_targeted_description_segments(
		targeting_intent: TargetingSystem.TargetingMode, targeting_rules: Array[TargetingRule]) -> Array[DescriptionSegment]:
	if targeting_intent == TargetingSystem.TargetingMode.PLAYER or targeting_intent == TargetingSystem.TargetingMode.NO_TARGET:
		return []
	var target_segments: Array[DescriptionSegment] = EffectAndTargetIntent.describe_targeting_phrase(targeting_intent, targeting_rules)
	if target_segments.is_empty():
		return []
	var singular: bool = EffectAndTargetIntent.targeting_is_singular(targeting_intent, targeting_rules)
	var key: String = "EFFECTINTENT_HEALFORVALUEEFFECT_TARGETED_TEMPLATE_SINGULAR" if singular else "EFFECTINTENT_HEALFORVALUEEFFECT_TARGETED_TEMPLATE"
	### The target phrase's own template is written lowercase (meant to normally follow "to"/
	### "When") - capitalize it here since it's now sentence-initial.
	var result: Array[DescriptionSegment] = DescriptionBuilder.capitalize_first_letter(target_segments)
	result.append(DescriptionSegment.text_segment(" "))
	result.append_array(DescriptionBuilder.parse_template(tr(key), {"healing": str(healing)}))
	return result

### The target is already embedded above - never append a separate targeting phrase too.
func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false

### Statuses/passives can be owned by either side, so PLAYER-targeted effects can't rely on an
### implicit "you" the way a self-owned effect could - explicit "Player" keeps it unambiguous
### regardless of whether this is read from the player's own status bar or an opponent's (see
### After Anal: a debuff placed on either side that reduces the PLAYER's Pleasure specifically,
### since targeting_intent=PLAYER always means the player, not "whoever owns this").
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_HEALFORVALUEEFFECT_SELF_TEMPLATE"), {"healing": str(healing)})
