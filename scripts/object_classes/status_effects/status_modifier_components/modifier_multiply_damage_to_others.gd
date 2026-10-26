@tool
extends MultiplyDamage
class_name MultiplyDamageToOthers

### MultiplyDamage for hits on OTHER targets only: when the source hits itself (the player's own Finger Yourself) it does
### nothing. For a "Pleasure given" boost that must not also boost the pleasure a source gives itself (Edging); plain
### MultiplyDamage applies to every target, the source included. It has its own wording ("given to others"), so the
### two read differently to the player.

func modify_context(context: EffectContext) -> void:
	if is_self_directed(context):
		return
	super.modify_context(context)

func _get_description_participle() -> String:
	return tr("MULTIPLYDAMAGE_INCOMING_VERB_PARTICIPLE_OTHERS" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_PARTICIPLE_OTHERS")

### "Cannot give Pleasure to others" / "Cannot receive Pleasure from others" - the shared blocked template can't take
### the "to/from others" part.
func _get_blocked_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr(
		"MULTIPLYDAMAGETOOTHERS_BLOCKED_INCOMING_TEMPLATE" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGETOOTHERS_BLOCKED_OUTGOING_TEMPLATE"))
