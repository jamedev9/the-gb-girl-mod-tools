extends Label
class_name UnknownMark

### A big "?" drawn over a TextureRect (so no art is needed), sized to the TextureRect. Used where
### something is hidden from a blindfolded player (see Status_BlindPlayer), e.g. the upcoming Move.

const MARK_NODE_NAME: String = "UnknownMark"
const MARK_TEXT: String = "?"
const SIZE_FRACTION: float = 0.8
const MIN_FONT_SIZE: int = 10
const OUTLINE_SIZE: int = 4

### Shows or hides the mark on the given picture; creates it the first time it is needed.
static func set_shown_on(picture: TextureRect, shown: bool) -> void:
	if not is_instance_valid(picture):
		return
	var mark: UnknownMark = picture.get_node_or_null(MARK_NODE_NAME) as UnknownMark
	if not mark:
		if not shown:
			return
		mark = UnknownMark.new()
		mark.name = MARK_NODE_NAME
		picture.add_child(mark)
	mark.visible = shown

func _init() -> void:
	text = MARK_TEXT
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", OUTLINE_SIZE)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var parent_control: Control = get_parent() as Control
	if parent_control and not parent_control.resized.is_connected(_update_font_size):
		parent_control.resized.connect(_update_font_size)
	_update_font_size()

func _update_font_size() -> void:
	var parent_control: Control = get_parent() as Control
	if not parent_control:
		return
	var side: float = minf(parent_control.size.x, parent_control.size.y)
	add_theme_font_size_override("font_size", maxi(int(side * SIZE_FRACTION), MIN_FONT_SIZE))
