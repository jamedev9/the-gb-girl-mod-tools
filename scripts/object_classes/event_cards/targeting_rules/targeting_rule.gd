@tool
extends ModExportable
class_name TargetingRule

func is_target_valid(game_state: GameState, opponent_id: String) -> bool:
	return false

### Declares whether this rule could plausibly match more than one opponent at once - used to
### pick between singular ("the Partner with X active") and plural ("the Partners with X
### active") phrasing instead of each rule guessing independently (the actual bug behind
### TargetsOpponentsWithPassive reading as singular when its real runtime semantics are "any
### number of opponents could match"). Default true: most targeting rules in this game are
### qualifying filters (health/passive/action-based) that can match zero-to-many opponents at
### once, not single-opponent selectors - so true is the safer default for a rule that hasn't
### been audited yet. Override to false only for rules that are structurally guaranteed to
### resolve to exactly one opponent (e.g. OpponentWithMostHealthRemaining - "the most" is a
### single winner by definition; TargetSpecificOpponentId, TargetMostRecentlyEnteredOpponent),
### or make it conditional on the rule's own exported fields (e.g.
### TargetsHaveOneOfSeveralActionsAssigned - only multiple if it's tracking more than one
### action id).
func targets_potentially_multiple() -> bool:
	return true

### Generic description support (see DescriptionBuilder). Base fallback for any rule that
### hasn't been given a real template yet - deliberately NOT translated, since its purpose
### is to be an obviously-a-placeholder marker for coverage gaps, not real player-facing text.
func get_description_segments() -> Array[DescriptionSegment]:
	return [DescriptionSegment.text_segment("matching special conditions")]

### Only called on rules TargetingSystem.get_targets_matching_rules() treats as "selector"
### rules (see TargetingSystem._is_selector_rule() - currently OnlyOneOpponent and
### OpponentWithMostHealthRemaining). A selector doesn't narrow the candidate set the way a
### filter does - it picks one (or reduces to a smaller set) FROM whatever the filter rules in
### the same targeting_rules array already narrowed things down to. That's a fundamentally
### different relationship than "and"/"or"-joining a flat list of independent conditions, so
### EffectAndTargetIntent's RULE_BASED composition (see _describe_rule_based_targeting())
### separates filter rules from selector rules the same way the resolver does, builds the
### filter rules' phrase first, then hands it to the selector(s) via this method instead of
### joining the selector's own phrase in alongside the filters.
### filter_segments is that already-composed filter phrase - empty if this selector has no real
### filter siblings in the same array (only implementation-detail ones like
### OpponentCantTargetSelf, which contribute no text - see its own get_description_segments()).
### Base implementation just falls back to get_description_segments() and ignores
### filter_segments - correct for a rule that's never actually classified as a selector; a real
### selector class MUST override this to read naturally both with and without a filter phrase
### (see OnlyOneOpponent/OpponentWithMostHealthRemaining for the pattern).
func describe_selection(_filter_segments: Array[DescriptionSegment]) -> Array[DescriptionSegment]:
	return get_description_segments()
