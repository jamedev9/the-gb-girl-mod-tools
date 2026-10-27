@tool
extends GraphNode

### One encounter on the Encounter Map editor tab's graph (encounter_map_editor_panel.gd). It only shows an
### EncounterMapNode; every edit goes to the resource, and the panel calls show_map_node() again when it changes.
### Every node has the same fixed size, so the graph position (position_offset, the top-left corner) and the map
### position (EncounterMapNode.position, the centre) convert exactly, whatever the node shows.
### Row 0 (the picture) has the ports: the left one takes the lines in (what unlocks this encounter), the right one sends
### the lines out (what clearing it unlocks). The rows below say what else the node needs.

const NODE_SIZE: Vector2 = Vector2(130, 140)
const PICTURE_HEIGHT: float = 48.0
const INFO_FONT_SIZE: int = 12
const PORT_TYPE: int = 0
const PORT_COLOR: Color = Color(0.85, 0.85, 0.85)

var encounter_id: String = ""

var _picture: TextureRect
var _info_label: Label

func _init() -> void:
	custom_minimum_size = NODE_SIZE
	size = NODE_SIZE
	_picture = TextureRect.new()
	_picture.custom_minimum_size = Vector2(0, PICTURE_HEIGHT)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	_info_label = _make_small_label()
	add_child(_info_label)
	set_slot(0, true, PORT_TYPE, PORT_COLOR, true, PORT_TYPE, PORT_COLOR)
	_keep_title_from_widening_the_node()

### encounter_info: what the panel found for the node's encounter id ({"name", "picture", "path"}, see
### _get_encounter_info_for_id() in encounter_map_editor_panel.gd), or {} when there is no encounter file with that id here (e.g. a
### base-game encounter on a mod map): the node then shows the id, without a picture.
func show_map_node(map_node: EncounterMapNode, encounter_info: Dictionary) -> void:
	encounter_id = map_node.get_encounter_id()
	name = encounter_id
	if not encounter_info.is_empty():
		title = str(encounter_info["name"])
		_picture.texture = encounter_info["picture"]
	else:
		title = encounter_id
		_picture.texture = null

	var info_lines: PackedStringArray = []
	### With a single line (or none) ALL and ANY mean the same, so the requirement is only shown from two lines on.
	if map_node.unlocked_by.size() > 1:
		if map_node.line_requirement == EncounterMapNode.LineRequirement.ANY:
			info_lines.append("Needs any line")
		else:
			info_lines.append("Needs all lines")
	var condition_count: int = 0
	for condition in map_node.unlock_conditions:
		if condition:
			condition_count += 1
	if condition_count == 1:
		info_lines.append("+1 condition")
	elif condition_count > 1:
		info_lines.append("+%d conditions" % condition_count)
	_info_label.text = "\n".join(info_lines)
	_info_label.visible = not info_lines.is_empty()

	var source_text: String = str(encounter_info["path"]) if not encounter_info.is_empty() else "By id only (no encounter file here)"
	tooltip_text = "%s (%s)\n%s" % [title, encounter_id, source_text]

func get_map_position() -> Vector2:
	return position_offset + NODE_SIZE * 0.5

func set_map_position(map_position: Vector2) -> void:
	position_offset = map_position - NODE_SIZE * 0.5

func _make_small_label() -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", INFO_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

### A long encounter name would otherwise grow the node (which must keep its size, see above): cut it off instead. The
### full name is in the tooltip.
func _keep_title_from_widening_the_node() -> void:
	for child in get_titlebar_hbox().get_children(true):
		if child is Label:
			var title_label: Label = child as Label
			title_label.clip_text = true
			title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
