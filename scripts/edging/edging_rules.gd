extends RefCounted
class_name EdgingRules

### Shared numbers and helpers for Edging, so the save, the encounter's game state and the pleasure bar all agree.
### The edging threshold is a share of max pleasure (0.75 = 75%), always kept between 0 and 1. Once the player's
### pleasure is at or above it, they are "on the edge" (see the Edging status in content_packs/04_patch050). A player who is on
### the edge when their own turn ends, and again when the Partners' turn ends, gets a stack of the status each time (STACK_TURN_STEPS).

### Id of the Edging status (StatusEffectDefinition.status_id).
const STATUS_ID: String = "edging"

### What a new save starts with: 75% of max pleasure.
const DEFAULT_THRESHOLD: float = 0.75
const MIN_THRESHOLD: float = 0.0
const MAX_THRESHOLD: float = 1.0

### Float error margin when turning a share of max pleasure into whole pleasure, see get_threshold_pleasure().
const ROUNDING_TOLERANCE: float = 0.000001

static func clamp_threshold(threshold: float) -> float:
	return clampf(threshold, MIN_THRESHOLD, MAX_THRESHOLD)

### The turn steps (TurnStepSystem.TurnStep) at which a player who is on the edge gets a stack: the end of their own turn and the end
### of the Partners' turn, so at most 2 stacks per turn cycle. MainCardgame._enter_turn_step() checks gives_stack_at_turn_step().
const STACK_TURN_STEPS: Array[int] = [TurnStepSystem.TurnStep.END_OF_PLAYER_TURN, TurnStepSystem.TurnStep.END_OF_OPPONENTS_TURN]

static func gives_stack_at_turn_step(step: int) -> bool:
	return step in STACK_TURN_STEPS

### True when the player is on the edge: their pleasure is at or above the threshold. "At or above" counts, and being above
### the max (an orgasm held back by Denied) is still above. threshold_pleasure is GameState.get_edging_threshold_pleasure(),
### which is at least 1, so a player with no pleasure is never on the edge.
static func is_on_the_edge(pleasure: int, threshold_pleasure: int) -> bool:
	return pleasure >= threshold_pleasure

### How many cards the player discards when they orgasm holding this many Edging stacks: 1 for each stack above the first
### (2 stacks = 1 card, 4 stacks = 3 cards), none for 0 or 1 stack.
static func get_cards_discarded_on_orgasm(stacks: int) -> int:
	return maxi(stacks - 1, 0)

### The Triggers line of the Edging tooltip for how a stack is gained ("When your turn or the Partners' turn ends with your Pleasure at
### or above the Edging threshold: Gain 1 stack."), matching STACK_TURN_STEPS and is_on_the_edge(). Static, so TranslationServer.translate().
static func get_stack_rule_trigger_line() -> Array[DescriptionSegment]:
	var effect_segments: Array[DescriptionSegment] = DescriptionBuilder.parse_template(TranslationServer.translate("EDGING_STACK_RULE_TEMPLATE"))
	effect_segments.append(DescriptionSegment.text_segment("."))
	var when_segments: Array[DescriptionSegment] = DescriptionBuilder.parse_template(TranslationServer.translate("EDGING_STACK_RULE_WHEN_TEMPLATE"))
	return DescriptionBuilder.describe_when_then(when_segments, effect_segments)

### The Triggers line of the Edging tooltip for what an orgasm does ("When you orgasm: ..."), matching get_cards_discarded_on_orgasm().
### Static, so TranslationServer.translate() rather than tr().
static func get_orgasm_rule_trigger_line() -> Array[DescriptionSegment]:
	var effect_segments: Array[DescriptionSegment] = DescriptionBuilder.parse_template(TranslationServer.translate("EDGING_ORGASM_RULE_TEMPLATE"))
	effect_segments.append(DescriptionSegment.text_segment("."))
	var when_segments: Array[DescriptionSegment] = DescriptionBuilder.parse_template(TranslationServer.translate("TRIGGERCONDITION_ONPLAYERORGASM_TEMPLATE"))
	return DescriptionBuilder.describe_when_then(when_segments, effect_segments)

### The lowest whole amount of Pleasure that counts as "at or above" the threshold: threshold x max pleasure,
### rounded up (pleasure is a whole number, so 50.5 means 51). The tolerance keeps float error from pushing an exact
### value up one (0.07 x 100 is 7.000000000000001 in floats, but 7 pleasure is exactly 7%). At least 1, so a
### threshold of 0 means "any pleasure at all" instead of being met while the player has none.
static func get_threshold_pleasure(max_pleasure: int, threshold: float) -> int:
	var exact_pleasure: float = clamp_threshold(threshold) * float(max_pleasure)
	return maxi(1, ceili(exact_pleasure - ROUNDING_TOLERANCE))
