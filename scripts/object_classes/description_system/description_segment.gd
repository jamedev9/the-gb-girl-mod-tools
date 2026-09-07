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
enum Type { TEXT, KEYWORD, NESTED, HEADING }

var type: Type
var text: String = "" ### literal text for TEXT/HEADING segments, or the label for NESTED segments
var keyword_id: String = "" ### GameplayKeyword id for KEYWORD segments
var nested_segments: Array[DescriptionSegment] = [] ### the on-hover description for NESTED segments

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

static func heading_segment(given_text: String) -> DescriptionSegment:
	var segment := DescriptionSegment.new()
	segment.type = Type.HEADING
	segment.text = given_text
	return segment
