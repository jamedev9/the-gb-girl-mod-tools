@tool
extends ModExportable
class_name EffectIntent

@export var intent_effect_id: String

### This method is overwritten by child classes.
### This only changes the effect of a context, not the target or source.
func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	return context

### Generic description support (see DescriptionBuilder for the shared parsing logic this
### is built on). Overridden per subclass with that class's own template + substitutions.
### Base fallback just shows the class name, so any subclass that hasn't been given a real
### template yet still shows up as *something* in a generated description instead of nothing.
func get_description_segments() -> Array[DescriptionSegment]:
	return [DescriptionSegment.text_segment("[%s]" % get_script().get_global_name())]

### Optional clause that belongs AFTER the targeting phrase rather than as part of the main
### effect phrase - e.g. "for 3 turns" reads better as "Apply X to Y for 3 turns" than
### "Apply X for 3 turns to Y". Base returns nothing; only override this if the effect has a
### clause that specifically needs to trail targeting (see ApplyStatusEffect).
func get_trailing_description_segments() -> Array[DescriptionSegment]:
	return []

### Whether EffectAndTargetIntent.get_description_segments() should append a targeting phrase
### at all. Descriptions are written from the player's own point of view, so "to yourself" is
### almost always redundant once the effect already reads as self-directed - base default is to
### not state it whenever targeting resolves to the player. Override to unconditionally false
### for effects whose target is always fixed/implied regardless of what targeting_intent even
### says (e.g. ApplyEnergyDelta - always the player, no matter what the resource is configured
### with), or to something more conditional - e.g. ApplyEffectOfPlayerAction drops "on the
### Partner with your X Action" specifically when X is the same action being triggered, since
### the target is then already implied by the effect itself.
func description_includes_targeting(
	targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return targeting_intent != TargetingSystem.TargetingMode.PLAYER

### The word joining the effect phrase to the targeting phrase - "Deal 30 Pleasure {to} target
### Partner", "Trigger Blowjob {on} target Partner". Tied to the effect's own verb, not the
### targeting mode (the mode/rule templates are bare noun phrases with no preposition of their
### own - see TargetingSystem.get_targeting_mode_description_segments()), since the same
### targeting mode can read differently depending on what the effect actually is.
func get_targeting_preposition() -> String:
	return tr("PREPOSITION_TO")

### Alternative to get_description_segments() used instead when targeting resolves to the
### player (see description_includes_targeting() above) - some effects need a different verb
### entirely for the self-directed phrasing, not just a dropped targeting phrase: "Give 20
### Pleasure to yourself" becomes "Gain 20 Pleasure" (DealDamageEffect), "Apply X to yourself
### for 3 turns" becomes "Gain X for 3 turns" (ApplyStatusEffect). Base returns empty, meaning
### "no special self-targeted phrasing - just use get_description_segments() with the targeting
### phrase suppressed as normal".
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return []

### Alternative to get_description_segments() for effects that need to embed the target INSIDE
### their own phrase - "Switch target Partner's next Move to X" - rather than appending it at
### the end via the normal preposition+targeting composition ("Switch next Move to X {on}
### target Partner" reads worse here). Checked first, before get_self_targeted_description_segments(),
### for every targeting mode (not just PLAYER). Base returns empty, meaning "use the normal
### composition". When this returns non-empty, the caller is expected to also make
### description_includes_targeting() return false for the same targeting_intent/targeting_rules,
### since the target is already embedded here - the two aren't linked automatically.
func get_targeted_description_segments(
	_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> Array[DescriptionSegment]:
	return []
