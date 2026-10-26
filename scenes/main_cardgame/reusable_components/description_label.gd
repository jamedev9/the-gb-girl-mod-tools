extends RichTextLabel
class_name DescriptionLabel

### A RichTextLabel for text built by the description system. show_segments() renders the keywords and nested
### terms (statuses, actions, cards, ...) in the text as links: hovering one (or clicking/tapping it) opens a
### tooltip with that term's description, and the terms inside THAT tooltip are links too - see PopupController,
### which owns the stack of layered tooltips. Use show_segments() instead of
### `text = DescriptionRenderer.to_bbcode(segments)` anywhere the game shows description-system output.
###
### Where there is no PopupController (a debug scene, for example) it falls back to the native [hint] tooltips.
### Plain text can still be put in with `text = ...`; such a label simply has no links.

### The terms behind the [url=N] links of the segments last shown: N is the index here.
var _link_targets: Array[DescriptionSegment] = []

func _ready() -> void:
	meta_hover_started.connect(_on_meta_hover_started)
	meta_hover_ended.connect(_on_meta_hover_ended)
	meta_clicked.connect(_on_meta_clicked)

func _exit_tree() -> void:
	var popup_controller: PopupController = _get_popup_controller()
	if popup_controller:
		popup_controller.link_host_removed(self)

func show_segments(segments: Array[DescriptionSegment]) -> void:
	_link_targets.clear()
	if not _get_popup_controller():
		text = DescriptionRenderer.to_bbcode(segments)
		return
	text = DescriptionRenderer.to_bbcode_with_links(segments, _link_targets)
	if has_links():
		### Links need the mouse; PASS leaves clicks on the rest of the label to whatever is behind it.
		mouse_filter = Control.MOUSE_FILTER_PASS

func has_links() -> bool:
	return not _link_targets.is_empty()

### Closes the tooltips opened from this label (e.g. because the label is about to be hidden).
func close_tooltips() -> void:
	var popup_controller: PopupController = _get_popup_controller()
	if popup_controller:
		popup_controller.link_host_removed(self)

func _on_meta_hover_started(meta: Variant) -> void:
	var popup_controller: PopupController = _get_popup_controller()
	var term: DescriptionSegment = _get_term_for_meta(meta)
	if popup_controller and term:
		popup_controller.link_hover_started(self, term)

func _on_meta_hover_ended(_meta: Variant) -> void:
	var popup_controller: PopupController = _get_popup_controller()
	if popup_controller:
		popup_controller.link_hover_ended(self)

func _on_meta_clicked(meta: Variant) -> void:
	var popup_controller: PopupController = _get_popup_controller()
	var term: DescriptionSegment = _get_term_for_meta(meta)
	if popup_controller and term:
		popup_controller.link_clicked(self, term)

func _get_term_for_meta(meta: Variant) -> DescriptionSegment:
	var link_index: int = int(str(meta))
	if link_index < 0 or link_index >= _link_targets.size():
		return null
	return _link_targets[link_index]

### The main scene (MainCardgame, also the meta game's) holds the popup controller.
func _get_popup_controller() -> PopupController:
	if not is_inside_tree():
		return null
	var main_scene: Node = get_tree().get_current_scene()
	if not main_scene:
		return null
	return main_scene.get("popup_controller") as PopupController
