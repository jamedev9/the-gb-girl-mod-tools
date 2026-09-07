extends RefCounted
class_name DescriptionBuilder

### Shared "plumbing" for turning a translated template string into a list of
### DescriptionSegments. Every EffectIntent/TargetingRule's get_description_segments()
### calls parse_template() with its own tr()'d template and its own instance-specific
### values - this is the one place that actually understands the {placeholder} syntax,
### so individual effect/targeting classes never need to know how keywords get resolved.
###
### Template syntax: "Deal {damage} {PLEASURE} to your {OPPONENT}" - plain {word} tokens.
### Each token is resolved in this order:
###   1. Is "word" a registered GameplayKeyword id? -> KEYWORD segment.
###   2. Otherwise, look it up in `substitutions` -> a DescriptionSegment value is inserted
###      as-is (e.g. a NESTED segment for "apply this status, hover for what it does"), any
###      other value becomes a TEXT segment via str().
###   3. Otherwise, leave the literal "{word}" in place (missing substitution - visible bug,
###      not a silent failure).
### The same uniform {word} syntax for both keywords and values is deliberate: translators
### can freely move any placeholder around in a translated template without needing to know
### which ones are "special".
static func parse_template(template: String, substitutions: Dictionary = {}) -> Array[DescriptionSegment]:
	var segments: Array[DescriptionSegment] = []
	var regex := RegEx.new()
	regex.compile("\\{(\\w+)\\}")
	var last_end: int = 0
	for match_result in regex.search_all(template):
		var token_start: int = match_result.get_start()
		var token_end: int = match_result.get_end()
		if token_start > last_end:
			segments.append(DescriptionSegment.text_segment(template.substr(last_end, token_start - last_end)))
		var token_name: String = match_result.get_string(1)
		if AutoloadDatabase.get_gameplay_keyword(token_name):
			segments.append(DescriptionSegment.keyword_segment(token_name))
		elif substitutions.has(token_name):
			var value = substitutions[token_name]
			if value is DescriptionSegment:
				segments.append(value)
			else:
				segments.append(DescriptionSegment.text_segment(str(value)))
		else:
			push_warning("DescriptionBuilder: unresolved placeholder '{%s}' in template '%s'" % [token_name, template])
			segments.append(DescriptionSegment.text_segment("{%s}" % token_name))
		last_end = token_end
	if last_end < template.length():
		segments.append(DescriptionSegment.text_segment(template.substr(last_end)))
	return segments

### Picks a singular or plural template key based on count and parses whichever one applies -
### e.g. "for 1 turn" vs "for 3 turns", "Draw 1 card" vs "Draw 3 cards". English only has these
### two forms; a language with more plural categories (Russian, Arabic, ...) would need real
### pluralization-rule support here, not just an if/else, if this project ever needs one.
static func parse_pluralized_template(count: int, singular_key: String, plural_key: String, substitutions: Dictionary = {}) -> Array[DescriptionSegment]:
	var key: String = singular_key if count == 1 else plural_key
	### Static function, no `self` for tr() - see TargetingSystem.get_targeting_mode_description_segments().
	return parse_template(TranslationServer.translate(key), substitutions)

### Joins a list of names into proper English list form: "X" / "X and Y" / "X, Y, and Z" - not
### a bare comma join, which reads like a broken/truncated list ("Retract Handjob (R), Handjob
### (L)"). Used anywhere a list of resolved names (statuses to clear, cards played, actions
### retracted, ...) gets built.
static func join_with_and(items: Array[String], use_or: bool = false) -> String:
	if items.is_empty():
		return ""
	if items.size() == 1:
		return items[0]
	var joiner: String = TranslationServer.translate(
		"EFFECTANDTARGETINTENT_LIST_OR_JOINER" if use_or else "EFFECTANDTARGETINTENT_LIST_AND_JOINER")
	if items.size() == 2:
		return "%s %s %s" % [items[0], joiner, items[1]]
	var all_but_last: String = ", ".join(items.slice(0, items.size() - 1))
	return "%s, %s %s" % [all_but_last, joiner, items[items.size() - 1]]

### Segment-preserving equivalent of join_with_and() above - "X" / "X {conjunction} Y" / "X, Y,
### {conjunction} Z" - for joining a list of already-built segment lists (e.g. one per
### TargetingRule or TriggerCondition) rather than plain strings, so a list item that carries its
### own keyword segment (e.g. a rule mentioning {PLEASURE}) keeps its color/hover intact instead
### of being flattened to text first. `conjunction` is a plain translated word ("and"/"or"), not
### a template.
static func join_segment_lists_with_conjunction(segment_lists: Array, conjunction: String) -> Array[DescriptionSegment]:
	if segment_lists.is_empty():
		return []
	if segment_lists.size() == 1:
		return segment_lists[0]
	var result: Array[DescriptionSegment] = []
	for i in range(segment_lists.size()):
		if i > 0:
			if i == segment_lists.size() - 1:
				result.append(DescriptionSegment.text_segment(
					" %s " % conjunction if segment_lists.size() == 2 else ", %s " % conjunction))
			else:
				result.append(DescriptionSegment.text_segment(", "))
		result.append_array(segment_lists[i])
	return result

### Capitalizes the first letter of a segment list's leading text - for phrases normally written
### lowercase to follow another word ("to {target}", "When {condition}": see TargetingRule/
### TriggerCondition templates) that occasionally need to lead a sentence instead (see
### HealForValueEffect/RandomlyHealOrDealDamage's target-embedded get_targeted_description_segments(),
### "{target} loses X Pleasure" - the target phrase is now sentence-initial and needs capitalizing
### even though its own template is lowercase). Only touches a leading TEXT segment - if the list
### starts with a KEYWORD/NESTED/HEADING segment (or is empty), returns it unchanged rather than
### guessing how to capitalize something that isn't plain text.
static func capitalize_first_letter(segments: Array[DescriptionSegment]) -> Array[DescriptionSegment]:
	if segments.is_empty() or segments[0].type != DescriptionSegment.Type.TEXT or segments[0].text.is_empty():
		return segments
	var result: Array[DescriptionSegment] = segments.duplicate()
	result[0] = DescriptionSegment.text_segment(result[0].text[0].to_upper() + result[0].text.substr(1))
	return result

### Classifies a float multiplier for a "Pleasure given/received is increased/reduced by X%"
### style description - shared by every StatusModifierComponent that scales a Pleasure-like
### quantity (MultiplyDamage, MultiplyHealing, Modifier_MultiplyDamageFromAllExceptGivenIDs,
### Modifier_MultiplyDamageFromPassives, Modifier_MultiplyEventCardDamage,
### Modifier_MultiplyPlayerActionDamage), so the actual number-crunching (and its edge cases)
### exists once instead of being reimplemented - and re-broken - six times.
### Returns {"case": one of "blocked"/"increased"/"reduced"/"inverted"/"inverted_scaled",
### "percent": int}. A negative multiplier (e.g. Invert Damage's -1.0) is NOT just "a very large
### reduction" - naively computing abs(multiplier - 1.0) * 100 for multiplier=-1.0 gives "reduced
### by 200%", which is nonsensical (you can't reduce something by more than 100% and still call
### it a reduction) - it's a sign flip, described as "inverted" instead, with "percent" only
### included in the string for a case (e.g. -0.5) where the invert is ALSO scaled.
static func classify_percent_multiplier(multiplier: float) -> Dictionary:
	if is_zero_approx(multiplier):
		return {"case": "blocked", "percent": 0}
	if multiplier < 0.0:
		var magnitude_percent: int = roundi(abs(multiplier) * 100.0)
		if magnitude_percent == 100:
			return {"case": "inverted", "percent": 0}
		return {"case": "inverted_scaled", "percent": magnitude_percent}
	var percent: int = roundi(abs(multiplier - 1.0) * 100.0)
	return {"case": "increased" if multiplier > 1.0 else "reduced", "percent": percent}

### Composes a "When {condition}: {effect}." line - shared by
### EffectDefinition._trigger_line() (a passive/status's Triggers section) and
### OpponentActionDefinition.get_description_segments() (a move that only resolves under a
### condition) - both wrap a TriggerCondition/StatusTickComponent-style "when" clause around an
### effect the exact same way. condition_segments is expected to already be a lowercase clause
### fragment with no leading conjunction of its own (see the get_when_description_segments()/
### get_description_segments() overrides on TriggerCondition and StatusTickComponent) - "When" is
### prepended here, not baked into each condition template, so every caller reads consistently.
### Static, so TranslationServer.translate() rather than tr() - see
### DescriptionBuilder.parse_pluralized_template() for the same reasoning.
static func describe_when_then(condition_segments: Array[DescriptionSegment], effect_segments: Array[DescriptionSegment]) -> Array[DescriptionSegment]:
	var result: Array[DescriptionSegment] = [DescriptionSegment.text_segment(TranslationServer.translate("EFFECTDEFINITION_WHEN_PREFIX") + " ")]
	result.append_array(condition_segments)
	result.append(DescriptionSegment.text_segment(": "))
	result.append_array(effect_segments)
	return result

### Joins several already-built segment lists (e.g. one per EffectAndTargetIntent) into one.
### Each list is expected to already end with its own "." (EffectAndTargetIntent.
### get_description_segments() adds one) - so this only needs a plain space between them,
### not its own punctuation.
static func join_segment_lists(segment_lists: Array) -> Array[DescriptionSegment]:
	var joined: Array[DescriptionSegment] = []
	for i in range(segment_lists.size()):
		if i > 0:
			joined.append(DescriptionSegment.text_segment(" "))
		joined.append_array(segment_lists[i])
	return joined
