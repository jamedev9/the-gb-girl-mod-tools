extends RefCounted
class_name DescriptionRenderer

### Turns a segment list (the shared "plumbing") into BBCode for a RichTextLabel. This is the
### presentation layer the user explicitly expects to differ between the debug view and the
### eventual player-facing tooltips - only this file (or its future sibling) should ever need
### to change for that; nothing above (GameplayKeyword/DescriptionSegment/DescriptionBuilder/
### get_description_segments()) is debug-specific.
###
### Uses RichTextLabel's built-in [hint=...] tag for hover tooltips - a real system tooltip,
### native to Godot, no custom hover/signal plumbing needed for this first pass. A
### player-facing renderer could later swap this for the game's own custom-styled tooltip
### popups (TooltipId/tooltip_requested) without touching anything upstream of this file.
const ICON_SIZE: int = 20
### Distinguishes a NESTED reference (hover for a whole other description, e.g. a status name)
### from a KEYWORD reference (hover for a one-line vocabulary definition) at a glance.
const NESTED_COLOR: String = "#a0e0e0"
### Section heading color ("Modifiers"/"Triggers") - a warm, UI-chrome tone distinct from every
### GameplayKeyword color and from NESTED_COLOR, so a heading reads as structure, not content.
const HEADING_COLOR: String = "#ffe066"

static func to_bbcode(segments: Array[DescriptionSegment]) -> String:
	var result: String = ""
	for segment in segments:
		match segment.type:
			DescriptionSegment.Type.TEXT:
				result += _escape_bbcode(segment.text)
			DescriptionSegment.Type.KEYWORD:
				result += _render_keyword(segment.keyword_id)
			DescriptionSegment.Type.NESTED:
				result += _render_nested(segment)
			DescriptionSegment.Type.HEADING:
				result += _render_heading(segment.text)
	return result

static func _render_heading(heading_text: String) -> String:
	return "[b][color=%s]%s[/color][/b]" % [HEADING_COLOR, _escape_bbcode(heading_text)]

static func _render_keyword(keyword_id: String) -> String:
	var keyword: GameplayKeyword = AutoloadDatabase.get_gameplay_keyword(keyword_id)
	if not keyword:
		return "[%s]" % keyword_id
	var color_hex: String = "#" + keyword.color.to_html(false)
	var icon_bbcode: String = ""
	if keyword.icon:
		icon_bbcode = "[img=%dx%d]%s[/img] " % [ICON_SIZE, ICON_SIZE, keyword.icon.resource_path]
	var display_name: String = _escape_bbcode(keyword.get_display_name())
	var hint_text: String = _escape_bbcode(keyword.get_description())
	return "[hint=%s][color=%s]%s%s[/color][/hint]" % [hint_text, color_hex, icon_bbcode, display_name]

### [hint=...]'s tooltip text is plain text only (not itself BBCode-rendered), so the nested
### description is flattened via to_plain_text() rather than to_bbcode() - it won't show
### keyword colors/icons inside the tooltip yet. A player-facing renderer using the game's own
### custom-styled tooltip popups instead of the native [hint] tag wouldn't have this limit.
static func _render_nested(segment: DescriptionSegment) -> String:
	var label: String = _escape_bbcode(segment.text)
	var nested_text: String = _escape_bbcode(to_plain_text(segment.nested_segments))
	return "[hint=%s][color=%s][u]%s[/u][/color][/hint]" % [nested_text, NESTED_COLOR, label]

### Flattens a segment list to plain text - no color/icons/hover, just readable words. Used for
### nested-tooltip content (see _render_nested()) and anywhere else BBCode isn't renderable.
static func to_plain_text(segments: Array[DescriptionSegment]) -> String:
	var result: String = ""
	for segment in segments:
		match segment.type:
			DescriptionSegment.Type.TEXT:
				result += segment.text
			DescriptionSegment.Type.KEYWORD:
				var keyword: GameplayKeyword = AutoloadDatabase.get_gameplay_keyword(segment.keyword_id)
				result += keyword.get_display_name() if keyword else segment.keyword_id
			DescriptionSegment.Type.NESTED:
				result += segment.text
			DescriptionSegment.Type.HEADING:
				result += segment.text
	return result

static func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")
