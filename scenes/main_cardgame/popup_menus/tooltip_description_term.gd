extends TooltipUI
class_name Tooltip_DescriptionTerm

### Tooltip for a term in description-system text (see DescriptionLabel): a keyword (Pleasure, Energy, ...) shows
### its vocabulary definition, any other term (status, action, card, ...) shows the description segments that
### were put into it. The description is a DescriptionLabel too, so the terms in it are links that open the next
### layer; PopupController keeps the layers (it calls show_term() itself, not update_tooltip_information()).

@export var name_label: RichTextLabel
@export var description_label: DescriptionLabel

func show_term(term: DescriptionSegment) -> void:
	match term.type:
		DescriptionSegment.Type.KEYWORD:
			var keyword_segments: Array[DescriptionSegment] = [term]
			name_label.text = "[b]" + DescriptionRenderer.to_bbcode(keyword_segments) + "[/b]"
			var keyword: GameplayKeyword = AutoloadDatabase.get_gameplay_keyword(term.keyword_id)
			### A keyword's description can name other keywords as {KEYWORD_ID} tokens - they become links too.
			var description_segments: Array[DescriptionSegment] = []
			if keyword:
				description_segments = DescriptionBuilder.parse_template(keyword.get_description())
			description_label.show_segments(description_segments)
		DescriptionSegment.Type.NESTED:
			name_label.text = "[b]" + term.text.replace("[", "[lb]") + "[/b]"
			description_label.show_segments(term.nested_segments)
