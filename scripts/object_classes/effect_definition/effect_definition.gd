@tool
extends ModExportable
class_name EffectDefinition

### When true, live tooltips must never show the generated Modifiers/Triggers description for
### this effect (get_description_segments()/get_tooltip_description_segments()) - always fall back to the hand-written get_effect_description()
### text instead. For an effect whose real mechanism should stay unexplained to the player (a
### "secret" status/passive), not just one that hasn't been reviewed yet.
@export var has_secret_description: bool = false

func get_effect_id() -> String:
	push_error("get_effect_id() not implemented")
	return ""

func get_modifier_components() -> Array:
	push_error("get_modifier_components() not implemented")
	return []

func get_triggered_components() -> Array:
	push_error("get_triggered_components() not implemented")
	return []

### Ticking components (StatusTickComponent) - the per-turn half of the trigger system,
### alongside get_triggered_components()'s reactive/event-based half. Both feed the "Triggers"
### section of get_tooltip_description_segments() below.
func get_ticking_components() -> Array:
	push_error("get_ticking_components() not implemented")
	return []

### Trigger lines for rules the game logic handles itself (no StatusTriggeredComponent behind them, e.g. what an
### orgasm does to Edging), each already a full "When ...: ..." line. Added to the "Triggers" section below.
func get_built_in_trigger_lines() -> Array:
	return []

func get_effect_name() -> String:
	return ""

func get_effect_description() -> String:
	return ""

### The hand-written description as segments: its {KEYWORD} and {STATUS:id}-style tokens become hover links (see
### DescriptionBuilder.parse_template() and DescriptionTerms). Show this with DescriptionLabel.show_segments(), never the raw string.
func get_hand_written_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		get_effect_description(), {}, DescriptionTerms.card_permanence_hints_of_effect(self))

### Overridden by subclasses that have translatable text - see AutoloadDatabase's
### auto-localization check, which calls this (if present) on every registered resource.
func get_translation_entries() -> Array[Dictionary]:
	return []

### Generic description support (see DescriptionBuilder) - the full standalone tooltip for a
### PassiveEffectDefinition/StatusEffectDefinition, split into two sections so a player can tell
### "always on" behavior from "conditional" behavior at a glance:
###   - Modifiers: passive stat modifiers with no on/off condition of their own (MultiplyDamage
###     and friends) - in effect for as long as the passive/status itself is.
###   - Triggers: both ticking (StatusTickComponent, per-turn) and reactive
###     (StatusTriggeredComponent, event-based) components, each rendered as its own
###     "{when}: {effect}" line - a trigger doesn't mean anything to a player without both halves.
### Built once here (not duplicated per subclass) purely from the get_*_components() accessors
### above, which every EffectDefinition subclass already implements - PassiveEffectDefinition and
### StatusEffectDefinition only need to supply those, not their own copy of this composition.
### Either section is omitted entirely if it has no components; returns empty if both are empty,
### leaving the fallback (e.g. a hand-written *_description field) to the caller.
### stacks is how many stacks the displayed status has, for a modifier that shows its current strength
### (StatusModifierComponent.get_description_segments_for_stacks()); 0 = not known.
func get_tooltip_description_segments(stacks: int = 0) -> Array[DescriptionSegment]:
	var sections: Array[DescriptionSegment] = []

	var modifier_lines: Array = []
	for modifier in get_modifier_components():
		modifier_lines.append(modifier.get_description_segments_for_stacks(stacks))
	if not modifier_lines.is_empty():
		sections.append_array(tooltip_section("EFFECTDEFINITION_MODIFIERS_HEADER", modifier_lines))

	var trigger_lines: Array = []
	for tick in get_ticking_components():
		trigger_lines.append(trigger_line(tick.get_when_description_segments(), tick.effect_intents))
	for triggered in get_triggered_components():
		trigger_lines.append(trigger_line(triggered.get_when_description_segments(), triggered.effect_intents))
	trigger_lines.append_array(get_built_in_trigger_lines())
	if not trigger_lines.is_empty():
		if not sections.is_empty():
			sections.append(DescriptionSegment.text_segment("\n\n"))
		sections.append_array(tooltip_section("EFFECTDEFINITION_TRIGGERS_HEADER", trigger_lines))

	return sections

### Heading is its own HEADING-type segment (bold/colored - see DescriptionRenderer) rather than
### plain text, and each line is bullet-prefixed, so a tooltip with multiple sections reads as
### distinct labeled regions instead of one undifferentiated paragraph.
### Static (so TranslationServer.translate() rather than tr()) because PlayerAction, which isn't an
### EffectDefinition, builds its own Triggers section with this too.
static func tooltip_section(header_key: String, lines: Array) -> Array[DescriptionSegment]:
	var header: String = TranslationServer.translate(header_key)
	var result: Array[DescriptionSegment] = [DescriptionSegment.heading_segment(header)]
	for line in lines:
		result.append(DescriptionSegment.text_segment("\n• ")) ### bullet - structural punctuation, not localizable content
		result.append_array(line)
	return result

### A trigger line reads "When {when}: {effect}." - see DescriptionBuilder.describe_when_then(),
### shared with OpponentActionDefinition (a move that only resolves under a condition, same
### trigger_conditions shape) and PlayerAction.get_description_segments().
static func trigger_line(when_segments: Array[DescriptionSegment], effect_intents: Array[EffectAndTargetIntent]) -> Array[DescriptionSegment]:
	return DescriptionBuilder.describe_when_then(when_segments, EffectAndTargetIntent.describe_all(effect_intents))
