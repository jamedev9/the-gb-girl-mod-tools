@tool
extends ModExportable
class_name EffectAndTargetIntent

@export var targeting_intent: TargetingSystem.TargetingMode
@export var targeting_rules: Array[TargetingRule] = []
@export var effect_intent: EffectIntent

### Generic description support (see DescriptionBuilder) - composes a targeting phrase with
### the effect's own phrase, e.g. "Deal 30 Pleasure" + "to" + "the opponent with the least
### health remaining" -> one combined sentence. The mode/rule templates are bare noun phrases
### with no preposition of their own (see TargetingSystem.get_targeting_mode_description_segments()
### and EffectIntent.get_targeting_preposition()) - the same targeting mode can read differently
### depending on the effect ("Deal X to Y" vs "Trigger X on Y"), so the preposition is the
### effect's call, not the mode's. For RULE_BASED targeting, see describe_targeting_phrase().
func get_description_segments() -> Array[DescriptionSegment]:
	var targeting_segments: Array[DescriptionSegment] = describe_targeting_phrase(targeting_intent, targeting_rules)

	### Order is effect, then targeting, then any trailing clause (e.g. "for 3 turns") - reads
	### as "Apply X to Y for 3 turns" rather than "Apply X for 3 turns to Y". Ends with a period:
	### this is one complete sentence, and join_segment_lists() relies on that to separate
	### multiple intents with a plain space rather than inserting its own punctuation.
	### Three-way fallback: an effect that embeds its target mid-phrase
	### (get_targeted_description_segments()) wins first, regardless of mode; then, if targeting
	### resolves to the player, the effect's self-targeted phrasing
	### (get_self_targeted_description_segments()); otherwise the normal phrase.
	var effect_segments: Array[DescriptionSegment] = []
	if effect_intent:
		effect_segments = effect_intent.get_targeted_description_segments(targeting_intent, targeting_rules)
		if effect_segments.is_empty() and targeting_intent == TargetingSystem.TargetingMode.PLAYER:
			effect_segments = effect_intent.get_self_targeted_description_segments()
		if effect_segments.is_empty():
			effect_segments = effect_intent.get_description_segments()
	var trailing_segments: Array[DescriptionSegment] = effect_intent.get_trailing_description_segments() if effect_intent else []
	var includes_targeting: bool = effect_intent.description_includes_targeting(targeting_intent, targeting_rules) if effect_intent else true
	var preposition: String = effect_intent.get_targeting_preposition() if effect_intent else tr("PREPOSITION_TO")
	var combined: Array[DescriptionSegment] = effect_segments.duplicate()
	if includes_targeting and not targeting_segments.is_empty():
		combined.append(DescriptionSegment.text_segment(" %s " % preposition))
		combined.append_array(targeting_segments)
	if not trailing_segments.is_empty():
		combined.append(DescriptionSegment.text_segment(" "))
		combined.append_array(trailing_segments)
	combined.append(DescriptionSegment.text_segment("."))
	return combined

### Computes just the targeting phrase for a mode/rules combination - the same logic
### get_description_segments() uses for its own "to {target}" composition, exposed as a static
### utility so an EffectIntent's own get_targeted_description_segments() override can embed the
### target INSIDE its own phrase (see HealForValueEffect/RandomlyHealOrDealDamage: "{target}
### loses X Pleasure" reads correctly in a way "Lose X Pleasure to {target}" doesn't - "lose X to
### Y" means the SPEAKER loses X and Y benefits, not "Y loses X") instead of reimplementing
### rule-based targeting composition.
###
### RULE_BASED targeting can mix two structurally different kinds of TargetingRule -
### TargetingSystem.get_targets_matching_rules() calls them "filter" and "selector" rules, and
### resolves them in two distinct passes: every filter rule narrows the active-opponent set down
### (an AND of independent conditions - "has this passive AND isn't an ally"), THEN every
### selector rule (OnlyOneOpponent, OpponentWithMostHealthRemaining) reduces THAT already-
### filtered set further (e.g. "pick one at random", "keep whichever has the most Pleasure
### left"). A selector doesn't add another independent condition to the list - it operates ON
### the filtered result - so flatly and/or-joining every rule's own phrase together was wrong:
### "the Partners with Bros for Life Passive and a random Partner" reads as two unrelated
### targets, not "a random pick from that group". Mirrors the resolver's own split
### (TargetingSystem._is_selector_rule() - the actual source of truth for which rules are
### selectors, reused here rather than duplicated) so the description can never drift out of
### sync with how targeting actually resolves: build the filter rules' phrase first, exactly as
### before, then hand it to each selector in turn via TargetingRule.describe_selection(), which
### wraps/rephrases around it instead of sitting beside it.
### Static, so TranslationServer.translate() rather than tr() - see
### DescriptionBuilder.parse_pluralized_template() for the same reasoning.
static func describe_targeting_phrase(
		targeting_intent: TargetingSystem.TargetingMode, targeting_rules: Array[TargetingRule]) -> Array[DescriptionSegment]:
	if targeting_intent != TargetingSystem.TargetingMode.RULE_BASED or targeting_rules.is_empty():
		return TargetingSystem.get_targeting_mode_description_segments(targeting_intent)

	var filter_rules: Array[TargetingRule] = []
	var selector_rules: Array[TargetingRule] = []
	for rule in targeting_rules:
		if TargetingSystem._is_selector_rule(rule):
			selector_rules.append(rule)
		else:
			filter_rules.append(rule)

	var filter_segment_lists: Array = []
	for rule in filter_rules:
		### Some rules (e.g. OpponentCantTargetSelf) are pure implementation-detail filters
		### with nothing meaningful to say - skip them rather than joining in an empty list,
		### which would otherwise produce a dangling "and"/"or" with nothing on one side.
		var rule_segments: Array[DescriptionSegment] = rule.get_description_segments()
		if not rule_segments.is_empty():
			filter_segment_lists.append(rule_segments)
	var result: Array[DescriptionSegment] = DescriptionBuilder.join_segment_lists_with_conjunction(
		filter_segment_lists, TranslationServer.translate("TARGETINGMODE_RULE_BASED_JOINER"))

	for selector in selector_rules:
		result = selector.describe_selection(result)
	return result

### Whether a mode/rules combination is guaranteed to resolve to exactly one target - for
### singular/plural verb agreement when an effect embeds its target as the grammatical subject
### (see HealForValueEffect/RandomlyHealOrDealDamage's get_targeted_description_segments()). A
### selector rule (OnlyOneOpponent, OpponentWithMostHealthRemaining) always reduces to exactly
### one, regardless of what filters precede it; without a selector, singular only if every filter
### rule individually guarantees a single match (TargetingRule.targets_potentially_multiple() ==
### false for ALL of them - one uncertain rule makes the combination uncertain) - conservative
### default (plural) when uncertain, matching targets_potentially_multiple()'s own "assume
### multiple unless proven otherwise" philosophy.
static func targeting_is_singular(
		targeting_intent: TargetingSystem.TargetingMode, targeting_rules: Array[TargetingRule]) -> bool:
	match targeting_intent:
		TargetingSystem.TargetingMode.PLAYER, TargetingSystem.TargetingMode.SINGLE_OPPONENT, TargetingSystem.TargetingMode.SOURCE_OF_EFFECT:
			return true
		TargetingSystem.TargetingMode.ALL_OPPONENTS:
			return false
		TargetingSystem.TargetingMode.RULE_BASED:
			for rule in targeting_rules:
				if TargetingSystem._is_selector_rule(rule):
					return true
			for rule in targeting_rules:
				if rule.targets_potentially_multiple():
					return false
			return not targeting_rules.is_empty()
	return false

### Top-level entry point: describes a whole Array[EffectAndTargetIntent] - what any
### EventCardDefinition/PlayerAction/OpponentActionDefinition effectively has - as one
### combined description, one sentence per intent (after merging consecutive duplicates -
### see _merge_consecutive_duplicates()).
static func describe_all(intents: Array[EffectAndTargetIntent]) -> Array[DescriptionSegment]:
	var segment_lists: Array = []
	for intent in intents:
		segment_lists.append(intent.get_description_segments())
	segment_lists = _merge_consecutive_duplicates(segment_lists)
	segment_lists = _merge_same_shape_sentences(segment_lists)
	### Exactly two sentences reads better joined as one ("X, then Y.") than as two full
	### sentences - three or more still read fine as separate sentences, so this only applies
	### at exactly two. Checked after merging, so e.g. Deepthroat's two identical "Trigger
	### Blowjob..." intents merge down to one "...twice." sentence first, not "X, then X.".
	if segment_lists.size() == 2:
		return _join_two_with_then(segment_lists[0], segment_lists[1])
	return DescriptionBuilder.join_segment_lists(segment_lists)

### Some cards genuinely repeat the exact same effect+target twice (e.g. Deepthroat triggers
### Blowjob on the same target twice) rather than it being a description bug - collapse runs of
### consecutive intents whose rendered text is identical into one sentence with a "twice"/
### "thrice"/"N times" suffix instead of printing the same sentence back to back. Compares
### rendered plain text (not the raw segments) since two intents can be structurally identical
### but that's the simplest reliable equality check available.
static func _merge_consecutive_duplicates(segment_lists: Array) -> Array:
	var merged: Array = []
	var i: int = 0
	while i < segment_lists.size():
		var current_text: String = DescriptionRenderer.to_plain_text(segment_lists[i])
		var run_length: int = 1
		while i + run_length < segment_lists.size() and DescriptionRenderer.to_plain_text(segment_lists[i + run_length]) == current_text:
			run_length += 1
		if run_length == 1:
			merged.append(segment_lists[i])
		else:
			merged.append(_append_repeat_count(segment_lists[i], run_length))
		i += run_length
	return merged

### Merges consecutive sentences that are identical except for one differing word/name into a
### single sentence listing all the names - e.g. Go Wild's "Trigger Blowjob twice." / "Trigger
### Vaginal twice." / "Trigger Anal twice." (already collapsed by _merge_consecutive_duplicates
### above) become "Trigger Blowjob, Vaginal, and Anal twice.". This is a plain-text heuristic
### (find the shared prefix/suffix around one differing chunk), not a semantic understanding of
### the underlying intents, so it's deliberately conservative - see _texts_share_shape() for the
### guards against misfiring (e.g. Double Handjob's "Handjob (R)"/"Handjob (L)" sentences share
### a similar-looking prefix/suffix pattern but must NOT merge, since the differing chunk there
### is a whole sub-phrase, not a clean name).
static func _merge_same_shape_sentences(segment_lists: Array) -> Array:
	var result: Array = []
	var i: int = 0
	while i < segment_lists.size():
		var group_texts: Array[String] = [DescriptionRenderer.to_plain_text(segment_lists[i])]
		var j: int = i + 1
		while j < segment_lists.size():
			var candidate_text: String = DescriptionRenderer.to_plain_text(segment_lists[j])
			if not _texts_share_shape(group_texts[0], candidate_text):
				break
			group_texts.append(candidate_text)
			j += 1
		if group_texts.size() < 2:
			result.append(segment_lists[i])
		else:
			result.append(_build_shape_merged_segments(group_texts))
		i = j
	return result

### Characters that count as a word boundary for _shape_boundaries()' snapping below - not just
### space. Without "(" here, "Trigger Handjob (R)." vs "Trigger Handjob (L)." would snap the
### prefix back past the opening paren (since "(" isn't a space, the raw match already stops
### right after it) and pull "(" into the differing middle, which then trips
### _texts_share_shape()'s "middle contains a paren" guard - even though the parenthetical here
### is a clean, mergeable difference ("(R)" vs "(L)"), not the multi-clause mess that guard
### exists to catch.
const _SHAPE_BOUNDARY_CHARS: String = " ()"

static func _is_shape_boundary_char(c: String) -> bool:
	return _SHAPE_BOUNDARY_CHARS.contains(c)

### Finds the shared prefix/suffix around one differing "hole" between two strings, snapped to
### whole-word boundaries - without the snap, "Daddy Provides" vs "Double Pleasure" would match
### a raw one-character prefix "D" (both start with it) and corrupt into "addy Provides"/"ouble
### Pleasure". Returns {prefix_len, suffix_len}; callers derive the middle from these.
static func _shape_boundaries(a: String, b: String) -> Dictionary:
	var prefix_len: int = 0
	while prefix_len < a.length() and prefix_len < b.length() and a[prefix_len] == b[prefix_len]:
		prefix_len += 1
	while prefix_len > 0 and prefix_len < a.length() \
			and not _is_shape_boundary_char(a[prefix_len]) and not _is_shape_boundary_char(a[prefix_len - 1]):
		prefix_len -= 1
	var suffix_len: int = 0
	while suffix_len < a.length() - prefix_len and suffix_len < b.length() - prefix_len \
			and a[a.length() - 1 - suffix_len] == b[b.length() - 1 - suffix_len]:
		suffix_len += 1
	var suffix_start: int = a.length() - suffix_len
	while suffix_start > prefix_len and suffix_start < a.length() \
			and not _is_shape_boundary_char(a[suffix_start]) and not _is_shape_boundary_char(a[suffix_start - 1]):
		suffix_start += 1
	suffix_len = a.length() - suffix_start
	return {"prefix_len": prefix_len, "suffix_len": suffix_len}

static func _texts_share_shape(a: String, b: String) -> bool:
	if a == b:
		return false ### exact duplicates are handled by _merge_consecutive_duplicates already
	var boundaries: Dictionary = _shape_boundaries(a, b)
	var prefix_len: int = boundaries.prefix_len
	var suffix_len: int = boundaries.suffix_len
	var a_middle: String = a.substr(prefix_len, a.length() - prefix_len - suffix_len)
	var b_middle: String = b.substr(prefix_len, b.length() - prefix_len - suffix_len)
	if a_middle.is_empty() or b_middle.is_empty():
		return false
	### Reject anything that looks like it's straddling more than a single clean name - a real
	### name (Blowjob, Vaginal, Rush of Adrenaline) is a few words with no punctuation.
	if a_middle.contains(".") or b_middle.contains(".") or a_middle.contains("(") or b_middle.contains("(") \
			or a_middle.contains(")") or b_middle.contains(")"):
		return false
	if a_middle.split(" ").size() > 3 or b_middle.split(" ").size() > 3:
		return false
	return prefix_len >= 3 and suffix_len >= 1

static func _build_shape_merged_segments(texts: Array[String]) -> Array[DescriptionSegment]:
	### Any pair sharing the shape gives the same prefix/suffix boundaries.
	var boundaries: Dictionary = _shape_boundaries(texts[0], texts[1])
	var prefix_len: int = boundaries.prefix_len
	var suffix_len: int = boundaries.suffix_len
	var prefix: String = texts[0].substr(0, prefix_len)
	var suffix: String = texts[0].substr(texts[0].length() - suffix_len)
	var middles: Array[String] = []
	for text in texts:
		middles.append(text.substr(prefix_len, text.length() - prefix_len - suffix_len))
	### When the differing part is glued directly onto a preceding word rather than being a
	### fresh word of its own (no space right before it - e.g. "Trigger Handjob (R)"/"Trigger
	### Handjob (L)", where "(R)"/"(L)" qualifies "Handjob" instead of replacing it), merging
	### more than one of them now refers to that word in the plural: "Trigger Handjobs (R and
	### L)", not "Trigger Handjob (R and L)". A differing part that IS a fresh whole word (Go
	### Wild's "Blowjob"/"Vaginal"/"Anal") doesn't need this - "Trigger Blowjob, Vaginal, and
	### Anal" is already correct, nothing before it needs to pluralize.
	if middles.size() > 1 and prefix_len > 0 and prefix[prefix_len - 1] != " ":
		prefix = _pluralize_trailing_word(prefix)
	return [DescriptionSegment.text_segment(prefix + DescriptionBuilder.join_with_and(middles) + suffix)]

### Simple English pluralization of the last word in a string - good enough for this game's
### finite, curated vocabulary of action/status names (Handjob, Blowjob, ...), not a
### general-purpose pluralizer. Used only by _build_shape_merged_segments() above.
static func _pluralize_trailing_word(text: String) -> String:
	var word_end: int = text.length()
	while word_end > 0 and _is_shape_boundary_char(text[word_end - 1]):
		word_end -= 1
	var word_start: int = word_end
	while word_start > 0 and not _is_shape_boundary_char(text[word_start - 1]):
		word_start -= 1
	var word: String = text.substr(word_start, word_end - word_start)
	if word.is_empty():
		return text
	var lower: String = word.to_lower()
	var plural: String
	if lower.ends_with("s") or lower.ends_with("x") or lower.ends_with("z") \
			or lower.ends_with("ch") or lower.ends_with("sh"):
		plural = word + "es"
	elif lower.ends_with("y") and word.length() > 1 and not "aeiou".contains(lower[word.length() - 2]):
		plural = word.substr(0, word.length() - 1) + "ies"
	else:
		plural = word + "s"
	return text.substr(0, word_start) + plural + text.substr(word_end)

static func _append_repeat_count(segments: Array[DescriptionSegment], count: int) -> Array[DescriptionSegment]:
	var result: Array[DescriptionSegment] = _strip_trailing_period(segments)
	var repeat_word: String
	match count:
		2: repeat_word = TranslationServer.translate("EFFECTANDTARGETINTENT_REPEAT_TWICE")
		3: repeat_word = TranslationServer.translate("EFFECTANDTARGETINTENT_REPEAT_THRICE")
		_: repeat_word = TranslationServer.translate("EFFECTANDTARGETINTENT_REPEAT_N_TIMES").format({"count": str(count)})
	result.append(DescriptionSegment.text_segment(" %s." % repeat_word))
	return result

static func _join_two_with_then(first: Array[DescriptionSegment], second: Array[DescriptionSegment]) -> Array[DescriptionSegment]:
	var result: Array[DescriptionSegment] = _strip_trailing_period(first)
	result.append(DescriptionSegment.text_segment(", %s " % TranslationServer.translate("EFFECTANDTARGETINTENT_THEN_JOINER")))
	result.append_array(second)
	return result

### get_description_segments() always ends with a literal "." text segment - both merge helpers
### above need to remove it before appending something else in its place.
static func _strip_trailing_period(segments: Array[DescriptionSegment]) -> Array[DescriptionSegment]:
	var result: Array[DescriptionSegment] = segments.duplicate()
	if not result.is_empty() and result[-1].type == DescriptionSegment.Type.TEXT and result[-1].text == ".":
		result.remove_at(result.size() - 1)
	return result
