@tool
extends StatusModifierComponent
class_name Modifier_FlatDeltaToPlayerActionDamage

@export var actions_ids: Array[String] = []
@export var damage_delta: int

func modify_context(context: EffectContext) -> void:
	#print("Effect context origin id: %s"%context.id_of_effect_origin)
	if context.effect_origin is not PlayerAction:
		#print("Effect origin is not player action. ")
		return
	if context.source is not PlayerEntity:
		#print("Source is not player entity")
		return
	if context.id_of_effect_origin not in actions_ids:
		#print("Action is not on the list ")
		return
	if context.source == context.target:
		### Do not multiply damage to self.
		return
	if not context.damage_amount:
		return
	#if context.damage_phase != DamageSystem.DamagePhase.OUTGOING:
		#return
	
	context.damage_amount += self.damage_delta

	#context.damage_amount = int(context.damage_amount*damage_delta)

func get_description_segments() -> Array[DescriptionSegment]:
	var action_names: String = _action_names(actions_ids)
	var verb: String = _agreement_verb(actions_ids.size(), "VERB_DEALS_SINGULAR", "VERB_DEALS_PLURAL")
	var key: String = "MODIFIER_FLATDELTATOPLAYERACTIONDAMAGE_INCREASE_TEMPLATE" if damage_delta >= 0 else "MODIFIER_FLATDELTATOPLAYERACTIONDAMAGE_DECREASE_TEMPLATE"
	return DescriptionBuilder.parse_template(
		tr(key), {"action_names": action_names, "verb": verb, "amount": str(abs(damage_delta))})
