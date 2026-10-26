@tool
extends VBoxContainer

### One encounter in the Encounter Map tab's Encounters panel (encounter_map_editor_panel.gd). Looks like the graph's
### nodes (title bar over a picture) and also shows the encounter id. Drag it onto the graph to place it, or
### double-click it to place it in the middle of the view.

const EncounterMapGraphNode = preload("./encounter_map_graph_node.gd")

const CARD_WIDTH: float = 130.0
const ID_FONT_SIZE: int = 11

signal place_requested(encounter_path: String)

var encounter_path: String = ""
var _drag_type: String = ""
var _encounter_id: String = ""
var _encounter_name: String = ""
var _title_label: Label
var _picture: TextureRect
var _id_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, 0)
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_DRAG
	add_theme_constant_override("separation", 0)
	var editor_theme: Theme = EditorInterface.get_editor_theme()

	var title_bar: PanelContainer = PanelContainer.new()
	title_bar.mouse_filter = MOUSE_FILTER_IGNORE
	title_bar.add_theme_stylebox_override("panel", editor_theme.get_stylebox("titlebar", "GraphNode"))
	add_child(title_bar)
	_title_label = Label.new()
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.mouse_filter = MOUSE_FILTER_IGNORE
	title_bar.add_child(_title_label)

	var body: PanelContainer = PanelContainer.new()
	body.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", editor_theme.get_stylebox("panel", "GraphNode"))
	add_child(body)
	var body_rows: VBoxContainer = VBoxContainer.new()
	body_rows.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(body_rows)
	_picture = TextureRect.new()
	_picture.custom_minimum_size = Vector2(0, EncounterMapGraphNode.PICTURE_HEIGHT)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = MOUSE_FILTER_IGNORE
	body_rows.add_child(_picture)
	_id_label = Label.new()
	_id_label.add_theme_font_size_override("font_size", ID_FONT_SIZE)
	_id_label.add_theme_color_override("font_color", editor_theme.get_color("font_disabled_color", "Editor"))
	_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_id_label.clip_text = true
	_id_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_id_label.mouse_filter = MOUSE_FILTER_IGNORE
	body_rows.add_child(_id_label)

func show_encounter(path: String, encounter_id: String, encounter_name: String, picture: Texture2D, drag_type: String) -> void:
	encounter_path = path
	_drag_type = drag_type
	_encounter_id = encounter_id
	_encounter_name = encounter_name
	_title_label.text = encounter_name
	_picture.texture = picture
	_id_label.text = encounter_id
	tooltip_text = "%s (%s)\n%s" % [encounter_name, encounter_id, path]

### filter: lower case. Matches part of the display name or of the id.
func matches_filter(filter: String) -> bool:
	return filter.is_empty() or _encounter_name.to_lower().contains(filter) or _encounter_id.to_lower().contains(filter)

func get_encounter_name() -> String:
	return _encounter_name

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview: Label = Label.new()
	preview.text = _encounter_name
	set_drag_preview(preview)
	return {"type": _drag_type, "path": encounter_path}

func _gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and mouse_event.double_click:
		place_requested.emit(encounter_path)
		accept_event()
