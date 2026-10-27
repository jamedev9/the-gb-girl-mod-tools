extends Label
class_name ShrinkToFitLabel
## A Label for names that should stay on one line. When the text is too wide for the width
## the label was given, it lowers the font size (down to min_font_size) instead of wrapping.
## Only when the text still doesn't fit at min_font_size does it wrap like a normal label, so
## keep autowrap_mode on AUTOWRAP_WORD_SMART (see CLAUDE.md: unspaced Chinese never wraps otherwise).
##
## Set the text with set_fitted_text(), not `text = ...`: a Label has no signal for a text change.
## The size it shrinks from is the font_size the node has when it first fits (the scene's override).

@export var min_font_size: int = 12

var _base_font_size: int = 0
var _fitted_text: String = ""
var _fitted_width: float = -1.0


func set_fitted_text(new_text: String) -> void:
	text = new_text
	_fit_font_size()


func _notification(what: int) -> void:
	### The width isn't known until the container has laid the label out.
	if what == NOTIFICATION_RESIZED:
		_fit_font_size()


func _fit_font_size() -> void:
	var available_width: float = size.x
	if available_width <= 0.0:
		return
	var shown_text: String = atr(text)
	if shown_text == _fitted_text and is_equal_approx(available_width, _fitted_width):
		return
	_fitted_text = shown_text
	_fitted_width = available_width
	if _base_font_size <= 0:
		_base_font_size = get_theme_font_size("font_size")
	var font: Font = get_theme_font("font")
	var smallest_size: int = mini(min_font_size, _base_font_size)
	var fitted_size: int = _base_font_size
	var text_width: float = font.get_string_size(shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size).x
	if text_width > available_width:
		### The width follows the size almost linearly, so jump close to the answer and then
		### step down for what hinting rounds off (each measure re-shapes the text, which is slow for CJK).
		fitted_size = clampi(floori(_base_font_size * available_width / text_width), smallest_size, _base_font_size)
		while fitted_size > smallest_size and font.get_string_size(shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size).x > available_width:
			fitted_size -= 1
	add_theme_font_size_override("font_size", fitted_size)
