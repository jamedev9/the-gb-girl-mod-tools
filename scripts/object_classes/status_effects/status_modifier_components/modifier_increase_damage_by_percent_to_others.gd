@tool
extends IncreaseDamageByPercent
class_name IncreaseDamageByPercentToOthers

### IncreaseDamageByPercent for hits on OTHER targets only: when the source hits itself (the player's own Finger Yourself) it does
### nothing. For a "Pleasure given" boost that must not also boost the pleasure a source gives itself (Edging); the plain version
### applies to every target, the source included. It has its own wording ("given to others"), like MultiplyDamageToOthers.

func modify_context(context: EffectContext) -> void:
	if is_self_directed(context):
		return
	super.modify_context(context)

func _get_description_participle() -> String:
	return tr("MULTIPLYDAMAGE_INCOMING_VERB_PARTICIPLE_OTHERS" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_PARTICIPLE_OTHERS")
