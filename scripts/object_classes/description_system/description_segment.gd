extends RefCounted
class_name DescriptionSegment

### One piece of a generated description: plain text, a reference to a GameplayKeyword
### (Pleasure, Energy, Duration, Opponent, ...), a NESTED reference - a label (e.g. a status's
### name) that itself expands to another whole segment list on hover (e.g. what that status
### actually does) - or a HEADING (a section label like "Modifiers"/"Triggers" in a passive's
### tooltip - see EffectDefinition.get_tooltip_description_segments()), rendered distinctly from
### body text so a tooltip with multiple sections reads as distinct regions rather than one
### undifferentiated paragraph. Purely an in-memory, transient value - never saved to disk, so
### this is a plain RefCounted rather than a Resource. This is the shared "plumbing" both the
### debug renderer and (later) the player-facing renderer consume - only the rendering layer
### differs between them, not this data.
### An EMPHASIS is a value or a name picked out in the text without being a link (a number, an encounter's name): bold,
### and italic too when emphasis_italic is set (names).
### A LIVE_PLEASURE is the Pleasure number of one effect (live_effect_intent), which a tooltip that knows the effect's
### situation fills in with the live amount (LivePleasureValues.apply_to(), colored when modifiers change it). Unfilled it
### shows text: the plain number, or nothing for the "(currently N)" form (live_shows_total, for effects counted per energy,
### per orgasm, per stack ...).
enum Type { TEXT, KEYWORD, NESTED, HEADING, EMPHASIS, LIVE_PLEASURE }

var type: Type
var text: String = "" ### literal text for TEXT/HEADING segments, or the label for NESTED segments
var keyword_id: String = "" ### GameplayKeyword id for KEYWORD segments
var nested_segments: Array[DescriptionSegment] = [] ### the on-hover description for NESTED segments
### Set on a NESTED segment that stands for an event card: its tooltip then shows the card itself (a Tooltip_EventCard)
### instead of nested_segments, which stay as the text for anywhere that cannot show a card (no PopupController, plain text).
var card_id: String = ""
### EMPHASIS segments only: bold italic (a name) instead of just bold (a number).
var emphasis_italic: bool = false
### How that card looks in its tooltip (a CardInstance.CardPermanence value: permanent, temporary/combo, reward, problem, ...).
### Taken from the effect that hands the card out (CardsToAddIntent.permanence), see DescriptionTerms.
var card_permanence: int = CardInstance.CardPermanence.PERMANENT
### LIVE_PLEASURE segments only (see Type). The effect whose number this is, and whether it shows " (currently N)" after a
### per-unit rule instead of being the number itself.
var live_effect_intent: EffectIntent
var live_shows_total: bool = false
### LIVE_PLEASURE segments only: the number is the per-unit amount of a counted effect ("5" of "5 Pleasure per Energy"), filled with
### what one unit gives after modifiers rather than the total (an event card's {VALUE:...} token).
var live_shows_per_unit: bool = false
### Filled in by LivePleasureValues.apply_to(): the amount after modifiers, and its color as an HTML color ("" = the text's own
### color, when modifiers don't change it).
var live_is_filled: bool = false
var live_amount: int = 0
var live_color_html: String = ""

static func text_segment(given_text: String) -> DescriptionSegment:
	var segment := DescriptionSegment.new()
	segment.type = Type.TEXT
	segment.text = given_text
	return segment

static func keyword_segment(given_keyword_id: String) -> DescriptionSegment:
	var segment := DescriptionSegment.new()
	segment.type = Type.KEYWORD
	segment.keyword_id = given_keyword_id
	return segment

static func nested_segment(label: String, given_nested_segments: Array[DescriptionSegment]) -> DescriptionSegment:
	var segment := DescriptionSegment.new()
	segment.type = Type.NESTED
	segment.text = label
	segment.nested_segments = given_nested_segments
	return segment

### A NESTED segment for an event card. See card_id.
static func card_segment(
		label: String, given_card_id: String, given_nested_segments: Array[DescriptionSegment],
		given_permanence: int = CardInstance.CardPermanence.PERMANENT) -> DescriptionSegment:
	var segment: DescriptionSegment = nested_segment(label, given_nested_segments)
	segment.card_id = given_card_id
	segment.card_permanence = given_permanence
	return segment

static func emphasis_segment(given_text: String, italic: bool = false) -> DescriptionSegment:
	var segment := DescriptionSegment.new()
	segment.type = Type.EMPHASIS
	segment.text = given_text
	segment.emphasis_italic = italic
	return segment

### The Pleasure number of effect_intent, shown as base_text until a tooltip fills in the live amount.
static func live_pleasure_segment(base_text: String, effect_intent: EffectIntent) -> DescriptionSegment:
	var segment := DescriptionSegment.new()
	segment.type = Type.LIVE_PLEASURE
	segment.text = base_text
	segment.live_effect_intent = effect_intent
	return segment

### The per-unit number of a counted effect_intent ("5" of "5 Pleasure per Energy"), live as what one unit gives after modifiers.
static func live_pleasure_per_unit_segment(base_text: String, effect_intent: EffectIntent) -> DescriptionSegment:
	var segment: DescriptionSegment = live_pleasure_segment(base_text, effect_intent)
	segment.live_shows_per_unit = true
	return segment

### " (currently N)" after a per-unit rule ("5 Pleasure per Energy"): the total effect_intent comes to right now. Shows nothing
### until a tooltip fills it in.
static func live_pleasure_total_segment(effect_intent: EffectIntent) -> DescriptionSegment:
	var segment: DescriptionSegment = live_pleasure_segment("", effect_intent)
	segment.live_shows_total = true
	return segment

static func heading_segment(given_text: String) -> DescriptionSegment:
	var segment := DescriptionSegment.new()
	segment.type = Type.HEADING
	segment.text = given_text
	return segment
