@tool
extends VBoxContainer

### The Encounter Map editor tab (see encounter_map_editor_plugin.gd): edits one EncounterMap at a time on a GraphEdit.
### - Each map node is a graph node (encounter_map_graph_node.gd). A line from A's right port to B's left port = A is in
###   B.unlocked_by ("clearing A unlocks B"). Dragging a line off B's left port removes it.
### - The list on the left holds every encounter under ENCOUNTER_FOLDERS by file name; the Encounters panel on the right
###   shows the ones not on the map yet as cards (encounter_map_palette_card.gd), searchable by name or id. Drag either onto
###   the graph (or double-click it) to place it. "Add by id" under the list places an encounter that has no file here
###   (a base-game encounter on a mod map made in the mod tools) as a node that only names its id
###   (EncounterMapNode.encounter_id). Delete removes the selected nodes and every line that comes from them.
### - Selecting a node opens its EncounterMapNode in the Inspector (line requirement, extra conditions).
### The map's resources are the only state: every edit made here is a property change on them, done through the
### editor's undo history, and the graph is redrawn from them whenever they emit `changed` - whatever changed them (this
### tab, the Inspector, an undo).

const EncounterMapGraphNode = preload("./encounter_map_graph_node.gd")
const EncounterMapPaletteCard = preload("./encounter_map_palette_card.gd")

### The game's content packs, and the folder a mod's own content is made in (see ModConfig.export_configs).
const ENCOUNTER_FOLDERS: Array[String] = [GlobalAutoloadDatabase.CONTENT_PACKS_ROOT, "res://mod_export_data/"]
const PALETTE_DRAG_TYPE: String = "encounter_map_palette_encounter"
const PALETTE_MIN_WIDTH: float = 220.0
### Room for two cards side by side.
const ENCOUNTER_PANEL_MIN_WIDTH: float = 290.0
### Room left above and to the left of the top-left node when a map is opened.
const VIEW_MARGIN: Vector2 = Vector2(60, 60)
const HELP_TEXT: String = "Drag from a node's right dot to another node's left dot: clearing the first unlocks the second. Drag a line off its left end to remove it. Drag encounters in from the list or the Encounters panel (or double-click one), or type an encounter id under the list to add one that has no file here; Delete removes the selected ones. Select a node to edit its line requirement and extra conditions in the Inspector. Save (and every editor save) writes the map to its file."

var undo_redo: EditorUndoRedoManager

var _map: EncounterMap
var _unsaved_maps: Array[EncounterMap] = []
### Every map and map node this tab listens to, so each is connected once. A map stays connected after another one is
### opened: an undo can still change it, and it must still be saved then.
var _watched_resources: Array[Resource] = []
### Encounter id -> its graph node (an EncounterMapGraphNode, named after the id).
var _graph_nodes: Dictionary[String, GraphNode] = {}
var _positions_before_move: Dictionary[String, Vector2] = {}
var _redraw_queued: bool = false
### Map nodes that can't be shown: no encounter, or the same encounter twice.
var _skipped_node_count: int = 0
### Encounter file path -> its card in the Encounters panel.
var _encounter_cards: Dictionary[String, Control] = {}
### Encounter file path -> {"modified", "id", "name", "picture"}: what a card shows, read once per file version. Only the
### picture is kept, not the encounter itself, so the encounters' music isn't held in memory.
var _encounter_info_cache: Dictionary[String, Dictionary] = {}

var _file_label: Label
var _status_label: Label
var _save_button: Button
var _no_map_label: Label
var _split: HSplitContainer
var _palette_filter: LineEdit
var _palette_list: ItemList
var _id_entry: LineEdit
var _graph: GraphEdit
var _encounter_panel_title: Label
var _encounter_search: LineEdit
var _encounter_scroll: ScrollContainer
### A GridContainer, not a flow container: a FlowContainer inside a ScrollContainer can report a height of 0, so the
### scroll area shows nothing. The column count follows the panel's width (_update_encounter_grid_columns).
var _encounter_grid: GridContainer

func _init() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	_build_header()
	_no_map_label = Label.new()
	_no_map_label.text = "Open an EncounterMap resource (double-click it in the FileSystem dock) to edit it here."
	_no_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_map_label.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_no_map_label)
	_split = HSplitContainer.new()
	_split.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_split)
	_build_palette()
	_build_graph()
	var help_label: Label = Label.new()
	help_label.text = HELP_TEXT
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help_label)
	_show_map_controls(false)

func _ready() -> void:
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if not file_system.filesystem_changed.is_connected(_on_filesystem_changed):
		file_system.filesystem_changed.connect(_on_filesystem_changed)

#region Building the tab
func _build_header() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	add_child(header)
	_file_label = Label.new()
	header.add_child(_file_label)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_status_label)
	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.pressed.connect(_on_save_pressed)
	header.add_child(_save_button)

func _build_palette() -> void:
	var palette: VBoxContainer = VBoxContainer.new()
	palette.custom_minimum_size = Vector2(PALETTE_MIN_WIDTH, 0)
	_split.add_child(palette)
	var palette_title: Label = Label.new()
	palette_title.text = "Encounters"
	palette.add_child(palette_title)
	_palette_filter = LineEdit.new()
	_palette_filter.placeholder_text = "Filter"
	_palette_filter.clear_button_enabled = true
	_palette_filter.text_changed.connect(_on_palette_filter_changed)
	palette.add_child(_palette_filter)
	_palette_list = ItemList.new()
	_palette_list.size_flags_vertical = SIZE_EXPAND_FILL
	_palette_list.item_activated.connect(_on_palette_item_activated)
	_palette_list.set_drag_forwarding(_get_palette_drag_data, Callable(), Callable())
	palette.add_child(_palette_list)
	var id_row: HBoxContainer = HBoxContainer.new()
	palette.add_child(id_row)
	_id_entry = LineEdit.new()
	_id_entry.placeholder_text = "Encounter id"
	_id_entry.size_flags_horizontal = SIZE_EXPAND_FILL
	_id_entry.text_submitted.connect(_on_id_entry_submitted)
	id_row.add_child(_id_entry)
	var add_by_id_button: Button = Button.new()
	add_by_id_button.text = "Add by id"
	add_by_id_button.tooltip_text = "Places an encounter that has no file here (e.g. a base-game encounter on a mod map) by its id."
	add_by_id_button.pressed.connect(_on_add_by_id_pressed)
	id_row.add_child(add_by_id_button)

func _build_graph() -> void:
	_graph = GraphEdit.new()
	_graph.size_flags_horizontal = SIZE_EXPAND_FILL
	_graph.size_flags_vertical = SIZE_EXPAND_FILL
	_graph.snapping_enabled = true
	### Arranging would move the nodes without going through the map's resources (and their undo history).
	_graph.show_arrange_button = false
	### Lets a connected left (input) port pick up its line, so it can be dropped elsewhere or removed. Despite the names,
	### GraphEdit's "right" disconnect is the input-port end; its "left" disconnect types would instead make a connected
	### output port pick up its line, so an encounter could never start a second line out.
	_graph.right_disconnects = true
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.begin_node_move.connect(_on_begin_node_move)
	_graph.end_node_move.connect(_on_end_node_move)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)
	_graph.node_selected.connect(_on_graph_node_selected)
	_graph.set_drag_forwarding(Callable(), _can_drop_on_graph, _drop_on_graph)
	### The graph shares the right part of _split with the Encounters panel.
	var graph_split: HSplitContainer = HSplitContainer.new()
	graph_split.size_flags_horizontal = SIZE_EXPAND_FILL
	_split.add_child(graph_split)
	graph_split.add_child(_graph)
	_build_encounter_panel(graph_split)

### Every encounter that isn't on the map yet, as cards in a grid, with a search over names and ids.
func _build_encounter_panel(parent: Control) -> void:
	var encounter_panel: VBoxContainer = VBoxContainer.new()
	encounter_panel.custom_minimum_size = Vector2(ENCOUNTER_PANEL_MIN_WIDTH, 0)
	parent.add_child(encounter_panel)
	_encounter_panel_title = Label.new()
	_encounter_panel_title.text = "Encounters not on the map"
	encounter_panel.add_child(_encounter_panel_title)
	_encounter_search = LineEdit.new()
	_encounter_search.placeholder_text = "Search name or id"
	_encounter_search.clear_button_enabled = true
	_encounter_search.text_changed.connect(_on_encounter_search_changed)
	encounter_panel.add_child(_encounter_search)
	_encounter_scroll = ScrollContainer.new()
	_encounter_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_encounter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_encounter_scroll.resized.connect(_update_encounter_grid_columns)
	encounter_panel.add_child(_encounter_scroll)
	_encounter_grid = GridContainer.new()
	_encounter_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	_encounter_scroll.add_child(_encounter_grid)

### As many columns of cards as fit the panel's width (at least one).
func _update_encounter_grid_columns() -> void:
	var gap: float = float(_encounter_grid.get_theme_constant("h_separation"))
	var columns: int = int(floor((_encounter_scroll.size.x + gap) / (EncounterMapPaletteCard.CARD_WIDTH + gap)))
	_encounter_grid.columns = maxi(columns, 1)

func _show_map_controls(has_map: bool) -> void:
	_split.visible = has_map
	_no_map_label.visible = not has_map
#endregion

#region Opening, redrawing
func edit_map(map: EncounterMap) -> void:
	if map == _map:
		return
	_map = map
	_watch_resource(map, map)
	_clear_graph()
	_redraw_now()
	_refresh_palette()
	_refresh_encounter_cards()
	_show_map_controls(true)
	call_deferred("_frame_whole_map")

func _watch_resource(resource: Resource, owning_map: EncounterMap) -> void:
	if resource in _watched_resources:
		return
	_watched_resources.append(resource)
	resource.changed.connect(_on_map_resource_changed.bind(owning_map))

func _on_map_resource_changed(owning_map: EncounterMap) -> void:
	_mark_unsaved(owning_map)
	if owning_map == _map:
		_queue_redraw()

### Several properties often change at once (a move of many nodes, an undo): redraw once, after all of them.
func _queue_redraw() -> void:
	if _redraw_queued:
		return
	_redraw_queued = true
	call_deferred("_redraw_now")

### Makes the graph match the map: adds/removes graph nodes, updates what they show and where, redraws every line.
func _redraw_now() -> void:
	_redraw_queued = false
	if _map == null:
		return
	var shown_ids: Array[String] = []
	_skipped_node_count = 0
	for map_node: EncounterMapNode in _map.nodes.values():
		if map_node == null:
			_skipped_node_count += 1
			continue
		_watch_resource(map_node, _map)
		var encounter_id: String = map_node.get_encounter_id()
		if encounter_id.is_empty() or encounter_id in shown_ids:
			_skipped_node_count += 1
			continue
		shown_ids.append(encounter_id)
		var graph_node: EncounterMapGraphNode = _graph_nodes.get(encounter_id, null)
		var encounter_info: Dictionary = _get_encounter_info_for_id(encounter_id)
		if graph_node == null:
			graph_node = EncounterMapGraphNode.new()
			graph_node.show_map_node(map_node, encounter_info)
			_graph.add_child(graph_node)
			_graph_nodes[encounter_id] = graph_node
		else:
			graph_node.show_map_node(map_node, encounter_info)
		graph_node.set_map_position(map_node.position)
	for encounter_id: String in _graph_nodes.keys():
		if encounter_id not in shown_ids:
			_remove_graph_node(encounter_id)
	_redraw_lines()
	_update_header()
	_update_palette_placed_marks()

func _redraw_lines() -> void:
	_graph.clear_connections()
	for map_node: EncounterMapNode in _map.nodes.values():
		if map_node == null:
			continue
		var target_id: String = map_node.get_encounter_id()
		if not _graph_nodes.has(target_id):
			continue
		for source_id in map_node.unlocked_by:
			if source_id != target_id and _graph_nodes.has(source_id):
				_graph.connect_node(source_id, 0, target_id, 0)

func _remove_graph_node(encounter_id: String) -> void:
	var graph_node: GraphNode = _graph_nodes[encounter_id]
	_graph_nodes.erase(encounter_id)
	_graph.remove_child(graph_node)
	graph_node.queue_free()

func _clear_graph() -> void:
	_graph.clear_connections()
	for encounter_id: String in _graph_nodes.keys():
		_remove_graph_node(encounter_id)

### Scrolls the view to the map's top-left node at 100% zoom.
func _frame_whole_map() -> void:
	var top_left: Vector2 = Vector2.ZERO
	if not _graph_nodes.is_empty():
		top_left = Vector2(INF, INF)
		for graph_node: GraphNode in _graph_nodes.values():
			top_left = top_left.min(graph_node.position_offset)
	_graph.zoom = 1.0
	_graph.scroll_offset = top_left - VIEW_MARGIN

func _update_header() -> void:
	if _map == null:
		_file_label.text = ""
		_status_label.text = ""
		_save_button.disabled = true
		return
	_file_label.text = _map.resource_path.get_file() if not _map.resource_path.is_empty() else "(map not saved to a file)"
	_file_label.tooltip_text = _map.resource_path
	var status_parts: PackedStringArray = ["%d encounters" % _graph_nodes.size()]
	if _skipped_node_count > 0:
		status_parts.append("%d map node(s) not shown (no encounter, or an encounter that is already on the map)" % _skipped_node_count)
	if _map in _unsaved_maps:
		status_parts.append("unsaved changes")
	_status_label.text = "   " + " - ".join(status_parts)
	_save_button.disabled = _map not in _unsaved_maps

func _on_filesystem_changed() -> void:
	if _map == null:
		return
	_refresh_palette()
	_refresh_encounter_cards()
	_queue_redraw()
#endregion

#region Saving
func _mark_unsaved(map: EncounterMap) -> void:
	if map not in _unsaved_maps:
		_unsaved_maps.append(map)
	if map == _map:
		_update_header()

func _on_save_pressed() -> void:
	if _map == null:
		return
	if not _is_own_file(_map):
		push_error("Encounter map: '%s' isn't its own file, so this tab can't save it. Save it as a .tres first." % _map.resource_path)
		return
	_save_map(_map)

### Called on every editor save. A map that isn't its own file (embedded in a scene) is saved with that scene instead.
func save_all_unsaved_maps() -> void:
	for map: EncounterMap in _unsaved_maps.duplicate():
		if _is_own_file(map):
			_save_map(map)
		else:
			_unsaved_maps.erase(map)
	_update_header()

func _save_map(map: EncounterMap) -> void:
	var error: Error = ResourceSaver.save(map, map.resource_path)
	if error != OK:
		push_error("Encounter map: saving '%s' failed (%s)." % [map.resource_path, error_string(error)])
		return
	_unsaved_maps.erase(map)
	_update_header()

func get_unsaved_status_text() -> String:
	var paths: PackedStringArray = []
	for map: EncounterMap in _unsaved_maps:
		if _is_own_file(map):
			paths.append(map.resource_path)
	if paths.is_empty():
		return ""
	return "Save changes to the encounter map before closing?\n" + "\n".join(paths)

func _is_own_file(map: EncounterMap) -> bool:
	return map.resource_path.begins_with("res://") and not map.resource_path.contains("::")
#endregion

#region Moving nodes
func _on_begin_node_move() -> void:
	_positions_before_move.clear()
	for encounter_id: String in _graph_nodes.keys():
		_positions_before_move[encounter_id] = _graph_nodes[encounter_id].position_offset

### The GraphEdit has already moved the nodes; this writes the new positions to the map as one undoable step.
func _on_end_node_move() -> void:
	if _map == null:
		return
	var moved_ids: Array[String] = []
	for encounter_id: String in _positions_before_move.keys():
		if _graph_nodes.has(encounter_id) and _graph_nodes[encounter_id].position_offset != _positions_before_move[encounter_id]:
			moved_ids.append(encounter_id)
	_positions_before_move.clear()
	if moved_ids.is_empty():
		return
	undo_redo.create_action("Move encounter map node" if moved_ids.size() == 1 else "Move encounter map nodes", UndoRedo.MERGE_DISABLE, _map)
	for encounter_id in moved_ids:
		var map_node: EncounterMapNode = _map.get_node_for_encounter(encounter_id)
		if map_node == null:
			continue
		var graph_node: EncounterMapGraphNode = _graph_nodes[encounter_id] as EncounterMapGraphNode
		undo_redo.add_do_property(map_node, "position", graph_node.get_map_position())
		undo_redo.add_undo_property(map_node, "position", map_node.position)
	undo_redo.commit_action()
#endregion

#region Lines
func _on_connection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	if _map == null:
		return
	var source_id: String = str(from_node)
	var target: EncounterMapNode = _map.get_node_for_encounter(str(to_node))
	if target == null or source_id == target.get_encounter_id() or source_id in target.unlocked_by:
		return
	var new_lines: Array[String] = target.unlocked_by.duplicate()
	new_lines.append(source_id)
	_commit_lines(target, new_lines, "Add encounter map line")

### Sent when a line's left end is grabbed: the line is removed at once (dropping it on another node then adds a new one).
func _on_disconnection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	if _map == null:
		return
	var source_id: String = str(from_node)
	var target: EncounterMapNode = _map.get_node_for_encounter(str(to_node))
	if target == null or source_id not in target.unlocked_by:
		return
	var new_lines: Array[String] = target.unlocked_by.duplicate()
	new_lines.erase(source_id)
	_commit_lines(target, new_lines, "Remove encounter map line")

### The lists are always replaced, never edited in place: the undo history keeps the old and new list objects.
func _commit_lines(target: EncounterMapNode, new_lines: Array[String], action_name: String) -> void:
	undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, _map)
	undo_redo.add_do_property(target, "unlocked_by", new_lines)
	undo_redo.add_undo_property(target, "unlocked_by", target.unlocked_by.duplicate())
	undo_redo.commit_action()
#endregion

#region Placing and removing encounters
func _refresh_palette() -> void:
	_palette_list.clear()
	var paths: Array[String] = _collect_encounter_paths()
	paths.sort_custom(_is_file_name_before)
	var filter: String = _palette_filter.text.strip_edges().to_lower()
	for path in paths:
		var file_name: String = path.get_file().get_basename()
		if not filter.is_empty() and not file_name.to_lower().contains(filter):
			continue
		var index: int = _palette_list.add_item(file_name)
		_palette_list.set_item_metadata(index, path)
	_update_palette_placed_marks()

### The list shows file names (reading every encounter's display name would load all their music and pictures).
func _is_file_name_before(path_a: String, path_b: String) -> bool:
	return path_a.get_file().naturalnocasecmp_to(path_b.get_file()) < 0

### Every EncounterDefinition file under ENCOUNTER_FOLDERS (a folder that doesn't exist is skipped).
func _collect_encounter_paths() -> Array[String]:
	var paths: Array[String] = []
	for folder_path in ENCOUNTER_FOLDERS:
		_collect_paths_of_class(EditorInterface.get_resource_filesystem().get_filesystem_path(folder_path), "EncounterDefinition", paths)
	return paths

### The .tres files in the folder (and below) whose resource uses the script class wanted_class.
func _collect_paths_of_class(folder: EditorFileSystemDirectory, wanted_class: String, out_paths: Array[String]) -> void:
	if folder == null:
		return
	for file_index in range(folder.get_file_count()):
		var path: String = folder.get_file_path(file_index)
		if path.ends_with(".tres") and _get_resource_script_class(path) == wanted_class:
			out_paths.append(path)
	for subfolder_index in range(folder.get_subdir_count()):
		_collect_paths_of_class(folder.get_subdir(subfolder_index), wanted_class, out_paths)

### Read from the file's first line ([gd_resource ... script_class="EncounterDefinition" ...]) without loading it.
### EditorFileSystemDirectory.get_file_script_class_name() can't be used: it only answers for script files.
func _get_resource_script_class(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var header: String = file.get_line()
	file.close()
	var marker: String = "script_class=\""
	var start: int = header.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = header.find("\"", start)
	if end < 0:
		return ""
	return header.substr(start, end - start)

### Encounters already on the map are greyed out (an encounter can only be on the map once).
### In the Encounters panel they are hidden instead.
func _update_palette_placed_marks() -> void:
	var placed_paths: Array[String] = _get_placed_encounter_paths()
	for index in range(_palette_list.item_count):
		var path: String = str(_palette_list.get_item_metadata(index))
		var is_placed: bool = path in placed_paths
		_palette_list.set_item_disabled(index, is_placed)
		_palette_list.set_item_tooltip(index, path + ("\nAlready on the map." if is_placed else ""))
	_filter_encounter_cards()

### The encounter files whose encounter is on the map (map nodes name their encounter by id).
func _get_placed_encounter_paths() -> Array[String]:
	var placed_paths: Array[String] = []
	if _map == null:
		return placed_paths
	var placed_ids: Array[String] = []
	for map_node: EncounterMapNode in _map.nodes.values():
		if map_node:
			placed_ids.append(map_node.get_encounter_id())
	for path in _collect_encounter_paths():
		var info: Dictionary = _get_encounter_info(path)
		if not info.is_empty() and info["id"] in placed_ids:
			placed_paths.append(path)
	return placed_paths

### What a graph node shows for an encounter id: the info of the encounter file with that id, or {} when there is no
### such file here (a base-game encounter in the mod tools: the node shows only its id).
func _get_encounter_info_for_id(encounter_id: String) -> Dictionary:
	for path in _collect_encounter_paths():
		var info: Dictionary = _get_encounter_info(path)
		if not info.is_empty() and info["id"] == encounter_id:
			var info_with_path: Dictionary = info.duplicate()
			info_with_path["path"] = path
			return info_with_path
	return {}

### Makes the Encounters panel hold one card per encounter file, sorted by name (cards are kept and reused).
func _refresh_encounter_cards() -> void:
	var paths: Array[String] = _collect_encounter_paths()
	for path: String in _encounter_cards.keys():
		if path not in paths:
			var removed_card: Control = _encounter_cards[path]
			_encounter_cards.erase(path)
			_encounter_grid.remove_child(removed_card)
			removed_card.queue_free()
			_encounter_info_cache.erase(path)
	var sorted_paths: Array[String] = []
	for path in paths:
		var info: Dictionary = _get_encounter_info(path)
		if info.is_empty():
			continue
		sorted_paths.append(path)
		var card: EncounterMapPaletteCard = _encounter_cards.get(path, null)
		if card == null:
			card = EncounterMapPaletteCard.new()
			card.place_requested.connect(_on_encounter_card_place_requested)
			_encounter_grid.add_child(card)
			_encounter_cards[path] = card
		card.show_encounter(path, info["id"], info["name"], info["picture"], PALETTE_DRAG_TYPE)
	sorted_paths.sort_custom(_is_encounter_name_before)
	for index in range(sorted_paths.size()):
		_encounter_grid.move_child(_encounter_cards[sorted_paths[index]], index)
	_update_encounter_grid_columns()
	_filter_encounter_cards()

func _is_encounter_name_before(path_a: String, path_b: String) -> bool:
	return str(_encounter_info_cache[path_a]["name"]).naturalnocasecmp_to(str(_encounter_info_cache[path_b]["name"])) < 0

### What a card shows. Loads the encounter only when its file is new or changed since the last read.
func _get_encounter_info(path: String) -> Dictionary:
	var modified_time: int = FileAccess.get_modified_time(path)
	var cached: Dictionary = _encounter_info_cache.get(path, {})
	if not cached.is_empty() and int(cached["modified"]) == modified_time:
		return cached
	var encounter_def: EncounterDefinition = load(path) as EncounterDefinition
	if encounter_def == null or encounter_def.encounter_id.is_empty():
		return {}
	var display_name: String = encounter_def.encounter_display_name if not encounter_def.encounter_display_name.is_empty() else encounter_def.encounter_id
	var info: Dictionary = {"modified": modified_time, "id": encounter_def.encounter_id, "name": display_name, "picture": encounter_def.encounter_picture}
	_encounter_info_cache[path] = info
	return info

### Shows the cards that match the search and aren't on the map.
func _filter_encounter_cards() -> void:
	var placed_paths: Array[String] = _get_placed_encounter_paths()
	var filter: String = _encounter_search.text.strip_edges().to_lower()
	var not_placed_count: int = 0
	var shown_count: int = 0
	for path: String in _encounter_cards.keys():
		var card: EncounterMapPaletteCard = _encounter_cards[path]
		var is_placed: bool = path in placed_paths
		card.visible = not is_placed and card.matches_filter(filter)
		if not is_placed:
			not_placed_count += 1
		if card.visible:
			shown_count += 1
	if filter.is_empty():
		_encounter_panel_title.text = "Encounters not on the map (%d)" % not_placed_count
	else:
		_encounter_panel_title.text = "Encounters not on the map (%d of %d)" % [shown_count, not_placed_count]

func _on_encounter_search_changed(_new_text: String) -> void:
	_filter_encounter_cards()

func _on_encounter_card_place_requested(path: String) -> void:
	_place_encounter(path, _graph_position_to_map_position(_graph.size * 0.5))

func _on_palette_filter_changed(_new_text: String) -> void:
	_refresh_palette()

func _on_palette_item_activated(index: int) -> void:
	if _palette_list.is_item_disabled(index):
		return
	_place_encounter(str(_palette_list.get_item_metadata(index)), _graph_position_to_map_position(_graph.size * 0.5))

func _get_palette_drag_data(at_position: Vector2) -> Variant:
	var index: int = _palette_list.get_item_at_position(at_position, true)
	if index < 0 or _palette_list.is_item_disabled(index):
		return null
	var preview: Label = Label.new()
	preview.text = _palette_list.get_item_text(index)
	_palette_list.set_drag_preview(preview)
	return {"type": PALETTE_DRAG_TYPE, "path": _palette_list.get_item_metadata(index)}

func _can_drop_on_graph(_at_position: Vector2, data: Variant) -> bool:
	return _map != null and data is Dictionary and data.get("type", "") == PALETTE_DRAG_TYPE

func _drop_on_graph(at_position: Vector2, data: Variant) -> void:
	_place_encounter(str(data.get("path", "")), _graph_position_to_map_position(at_position))

### A point on the GraphEdit (its own coordinates) as a map position: the centre of a node dropped there, snapped like
### a moved node would be.
func _graph_position_to_map_position(at_position: Vector2) -> Vector2:
	var graph_position: Vector2 = (at_position + _graph.scroll_offset) / _graph.zoom
	var top_left: Vector2 = graph_position - EncounterMapGraphNode.NODE_SIZE * 0.5
	if _graph.snapping_enabled:
		top_left = top_left.snapped(Vector2.ONE * _graph.snapping_distance)
	return top_left + EncounterMapGraphNode.NODE_SIZE * 0.5

func _place_encounter(path: String, map_position: Vector2) -> void:
	if _map == null:
		return
	var encounter_def: EncounterDefinition = load(path) as EncounterDefinition
	if encounter_def == null:
		push_warning("Encounter map: '%s' is not an EncounterDefinition." % path)
		return
	var encounter_id: String = encounter_def.encounter_id
	if encounter_id.is_empty():
		push_warning("Encounter map: '%s' has no encounter_id." % path)
		return
	_place_encounter_by_id(encounter_id, map_position)

### Every node names its encounter by id (EncounterMapNode.encounter_id). "Add by id" places an encounter that has no file
### here (a base-game encounter in the mod tools); dragging a file in places it the same way.
func _place_encounter_by_id(encounter_id: String, map_position: Vector2) -> void:
	if _map == null or encounter_id.is_empty():
		return
	var map_node: EncounterMapNode = EncounterMapNode.new()
	map_node.encounter_id = encounter_id
	_add_map_node(map_node, map_position)

func _on_add_by_id_pressed() -> void:
	_place_encounter_by_id(_id_entry.text.strip_edges(), _graph_position_to_map_position(_graph.size * 0.5))
	_id_entry.clear()

func _on_id_entry_submitted(_new_text: String) -> void:
	_on_add_by_id_pressed()

func _add_map_node(map_node: EncounterMapNode, map_position: Vector2) -> void:
	var encounter_id: String = map_node.get_encounter_id()
	if _map.get_node_for_encounter(encounter_id) != null:
		push_warning("Encounter map: '%s' is already on the map." % encounter_id)
		return
	map_node.position = map_position
	var new_nodes: Dictionary[String, EncounterMapNode] = _copy_map_nodes()
	new_nodes[encounter_id] = map_node
	undo_redo.create_action("Add encounter to map", UndoRedo.MERGE_DISABLE, _map)
	undo_redo.add_do_property(_map, "nodes", new_nodes)
	undo_redo.add_undo_property(_map, "nodes", _copy_map_nodes())
	undo_redo.commit_action()
	### The encounter that was searched for has been found: start the next search from the full list.
	_encounter_search.clear()
	_filter_encounter_cards()

### A new dictionary (typed like EncounterMap.nodes) with the same map nodes: `nodes` is always replaced, never edited in
### place, since the undo history keeps the old and new dictionaries.
func _copy_map_nodes() -> Dictionary[String, EncounterMapNode]:
	var copy: Dictionary[String, EncounterMapNode] = {}
	for key: String in _map.nodes.keys():
		copy[key] = _map.nodes[key]
	return copy

### Delete key. Removes the nodes and every line that comes from them, as one undoable step.
func _on_delete_nodes_request(node_names: Array) -> void:
	if _map == null:
		return
	var deleted_ids: Array[String] = []
	for node_name in node_names:
		if _graph_nodes.has(str(node_name)):
			deleted_ids.append(str(node_name))
	if deleted_ids.is_empty():
		return
	var remaining_nodes: Dictionary[String, EncounterMapNode] = _copy_map_nodes()
	for key: String in remaining_nodes.keys():
		var map_node: EncounterMapNode = remaining_nodes[key]
		if map_node and map_node.get_encounter_id() in deleted_ids:
			remaining_nodes.erase(key)
	undo_redo.create_action("Remove encounter from map" if deleted_ids.size() == 1 else "Remove encounters from map", UndoRedo.MERGE_DISABLE, _map)
	undo_redo.add_do_property(_map, "nodes", remaining_nodes)
	undo_redo.add_undo_property(_map, "nodes", _copy_map_nodes())
	for map_node: EncounterMapNode in remaining_nodes.values():
		if map_node == null:
			continue
		var kept_lines: Array[String] = []
		for source_id in map_node.unlocked_by:
			if source_id not in deleted_ids:
				kept_lines.append(source_id)
		if kept_lines.size() != map_node.unlocked_by.size():
			undo_redo.add_do_property(map_node, "unlocked_by", kept_lines)
			undo_redo.add_undo_property(map_node, "unlocked_by", map_node.unlocked_by.duplicate())
	undo_redo.commit_action()
#endregion

#region Inspector
### Shows the node's EncounterMapNode in the Inspector only (the tab stays open), so its line requirement and extra
### conditions can be edited there; those edits come back through `changed`.
func _on_graph_node_selected(node: Node) -> void:
	var graph_node: EncounterMapGraphNode = node as EncounterMapGraphNode
	if graph_node == null or _map == null:
		return
	var map_node: EncounterMapNode = _map.get_node_for_encounter(graph_node.encounter_id)
	if map_node:
		EditorInterface.inspect_object(map_node, "", true)

#endregion
