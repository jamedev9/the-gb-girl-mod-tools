extends Metagame_UI_Element
class_name OverworldMap

@export var map_top_margin: float = 400.0
@export var map_left_margin: float = 100.0
@export var column_width: float = 125.0
@export var row_height: float = 70.0
@export var column_padding: float = 30.0
@export var vertical_padding: float = 75



@export var map_node_container: Control
@export var edge_layer: EncounterEdgeLayer
@export var voronoi_background: ColorRect
@export var scroll_content_root: Control ### Used for minimum map size
@export var scroll_container: ScrollContainer

@export var region_legend_list: Container

### The map dropdown ("Main game" + every installed mod map), shown only while a mod adds a map.
@export var map_selector: Control
@export var map_option_button: OptionButton


@export var edge_softness: float = 0.01
@export var darken_edges: float = 0.4
@export var max_x_length: float
@export var max_y_length: float
@export var fade_width: float
@export var fade_power: float = 2.5
@export var background_fixed_height: float = 3000.0

@onready var overworld_map_node_scene: PackedScene = load("res://scenes/meta_game/meta_game_state_displays/overworld_map/map_encounter_node.tscn")
@onready var single_region_list_scene: PackedScene = load("res://scenes/meta_game/meta_game_state_displays/overworld_map/single_region_legend.tscn")

var encounter_node_instances: Dictionary[String,MapEncounterNode]

var _map_size: Vector2 = Vector2.ZERO        # background ColorRect size
var _map_content_size: Vector2 = Vector2.ZERO # actual node area, used for UV normalization

signal forwarded_request_to_display_encounter(encounter_def: EncounterDefinition)
signal forwarded_double_click_tostart_encounter_request(encounter_def: EncounterDefinition)
signal map_selected(map_id: String)

func update_on_meta_game_enter_finished(save_game_state: SaveGameState) -> void:
#func update_when_save_game_changes(save_game_state: SaveGameState) -> void:
	display_map_nodes(save_game_state)

func _create_map_node(encounter_def: EncounterDefinition) -> MapEncounterNode:
	var new_node: MapEncounterNode = _get_map_node_scene().instantiate()
	new_node.display_encounter_on_node(encounter_def)
	#new_node.set_size_of_background_panel(column_width,row_height+vertical_padding)
	new_node.connect("request_displaying_encounter",Callable(self,"_forward_request_to_display_encounter"))
	new_node.connect("double_click_to_start_encounter_requested",Callable(self,"_forward_double_click_tostart_encounter_request"))
	return new_node

### Full Rework draws its own node (ContentSet.map_encounter_node_scene); every other mode uses the prototype's.
func _get_map_node_scene() -> PackedScene:
	if PlayModeSettings.current == PlayModeSettings.Mode.FULL_REWORK:
		var content_set: ContentSet = AutoloadDatabase.get_active_content_set()
		if content_set and content_set.map_encounter_node_scene:
			return content_set.map_encounter_node_scene
	return overworld_map_node_scene

func _forward_request_to_display_encounter(encounter_def: EncounterDefinition) -> void:
	emit_signal("forwarded_request_to_display_encounter",encounter_def)

func _forward_double_click_tostart_encounter_request(encounter_def: EncounterDefinition) -> void:
	emit_signal("forwarded_double_click_tostart_encounter_request",encounter_def)

#region GPT-code for tree creation:
func _group_encounters_by_depth() -> Dictionary[int, Array]:
	var encounter_depth = AutoloadDatabase.encounter_depth
	var result: Dictionary[int, Array] = {}
	for encounter_id in encounter_depth.keys():
		var depth: int = encounter_depth[encounter_id]
		if not result.has(depth):
			result[depth] = []
		result[depth].append(encounter_id)
	return result

func _get_branch_index(encounter_id: String) -> int:
	var encounter_def: EncounterDefinition = AutoloadDatabase.get_encounter_def_by_id(encounter_id)
	return encounter_def.branch_index

func _get_max_branch() -> int:
	var max_branch: int = 0
	for encounter_id in AutoloadDatabase.map_definition.encounter_nodes.keys():
		var encounter_def: EncounterDefinition = AutoloadDatabase.get_encounter_def_by_id(encounter_id)
		if encounter_def.branch_index > max_branch:
			max_branch = encounter_def.branch_index
	return max_branch
	

func _clear_nodes() -> void:
	encounter_node_instances.clear()
	for child in map_node_container.get_children():
		child.queue_free()

func _update_map_node_statuses(save_game_state: SaveGameState) -> void:
	for child in map_node_container.get_children():
		if child is MapEncounterNode:
			child.update_when_save_game_changes(save_game_state)
		
#endregion

func _build_map_nodes() -> void:
	_clear_nodes()
	if AutoloadDatabase.encounter_map:
		_build_map_nodes_from_encounter_map()
		return
	for encounter_id in AutoloadDatabase.encounter_depth.keys():
		var depth: int = AutoloadDatabase.encounter_depth[encounter_id]
		var branch: int = _get_branch_index(encounter_id)
		var encounter_def: EncounterDefinition = AutoloadDatabase.encounter_definitions[encounter_id]
		var new_node: MapEncounterNode = _create_map_node(encounter_def)
		map_node_container.add_child(new_node)
		main_game.entity_registry.register_entity(encounter_id,new_node)

		# --- Region tint ---
		#var region_data: MapRegionDefinition = AutoloadDatabase.get_map_region_by_id(encounter_def.map_region_id)
		#if region_data:base_color
			#new_node.modulate = region_data.
		# -------------------

		var x := map_left_margin + depth * (column_width + column_padding)
		var y := map_top_margin + branch * (row_height + vertical_padding)
		#new_node.call_deferred("set_position", Vector2(x, y))
		new_node.set_position(Vector2(x, y))
		encounter_node_instances[encounter_id] = new_node

#region Encounter map (Full Rework)
### Every node at its place on the encounter map, the whole map moved so its top-left node sits at the margins. The map
### stores node centres; since every map node is the same size, placing their top-left corners the same way keeps the
### distances between the centres.
func _build_map_nodes_from_encounter_map() -> void:
	var map_origin: Vector2 = _get_encounter_map_bounds().position
	for map_node in _get_placed_encounter_map_nodes():
		var encounter_id: String = map_node.get_encounter_id()
		var encounter_def: EncounterDefinition = AutoloadDatabase.encounter_definitions[encounter_id]
		var new_node: MapEncounterNode = _create_map_node(encounter_def)
		map_node_container.add_child(new_node)
		main_game.entity_registry.register_entity(encounter_id,new_node)
		new_node.set_position(map_node.position - map_origin + Vector2(map_left_margin, map_top_margin))
		encounter_node_instances[encounter_id] = new_node

### The map's nodes whose encounter is registered (a node without one, or the test encounter in a release build, is left out).
func _get_placed_encounter_map_nodes() -> Array[EncounterMapNode]:
	var placed: Array[EncounterMapNode] = []
	for map_node: EncounterMapNode in AutoloadDatabase.encounter_map.nodes.values():
		if map_node == null or not AutoloadDatabase.encounter_definitions.has(map_node.get_encounter_id()):
			continue
		placed.append(map_node)
	return placed

### The smallest rectangle around every placed node's centre.
func _get_encounter_map_bounds() -> Rect2:
	var placed: Array[EncounterMapNode] = _get_placed_encounter_map_nodes()
	if placed.is_empty():
		return Rect2()
	var bounds: Rect2 = Rect2(placed[0].position, Vector2.ZERO)
	for map_node in placed:
		bounds = bounds.expand(map_node.position)
	return bounds
#endregion

### Only the regions that have an encounter on the map (needs the map nodes built first, see update_on_meta_game_enter_finished).
func _update_region_list() -> void:
	_clear_region_list()
	var region_ids_on_map: Array[String] = []
	for encounter_id in encounter_node_instances.keys():
		region_ids_on_map.append(AutoloadDatabase.encounter_definitions[encounter_id].map_region_id)
	var map_regions: Dictionary[String,MapRegionDefinition] = AutoloadDatabase.map_region_definitions
	for key in map_regions.keys():
		if key not in region_ids_on_map:
			continue
		var region: MapRegionDefinition = map_regions[key]
		var new_region_entry: SingleRegionLegend = single_region_list_scene.instantiate()
		region_legend_list.add_child(new_region_entry)
		new_region_entry.display_region(region)


func _clear_region_list() -> void:
	for child in region_legend_list.get_children():
		if child is SingleRegionLegend:
			child.queue_free()


### Rewrtie 06.07.2026
func display_map_nodes(save_game_state: SaveGameState) -> void:
	_clear_nodes()
	_build_map_nodes()
	_update_map_node_statuses(save_game_state)
	_update_map_canvas_size()                      # size must be set first
	call_deferred("_update_voronoi_background")    # deferred so layout settles
	edge_layer.node_lookup = encounter_node_instances
	edge_layer.forward_graph = AutoloadDatabase.encounter_forward_graph
	edge_layer.call_deferred("queue_redraw")
	_update_region_list()
	_refresh_map_selector()

#region Map dropdown
### "Main game" + every installed mod map (by name), the active map selected. Hidden while no mod adds a map. The
### "Main game" text is a translation key (the button translates it); mod map names are shown as written.
func _refresh_map_selector() -> void:
	if map_selector == null or map_option_button == null:
		return
	var mod_map_ids: Array[String] = AutoloadDatabase.get_mod_map_ids()
	map_selector.visible = not mod_map_ids.is_empty()
	map_option_button.clear()
	map_option_button.add_item("UI_OVERWORLD_MAP_MAIN_GAME_MAP")
	map_option_button.set_item_metadata(0, AutoloadDatabase.MAIN_MAP_ID)
	var selected_index: int = 0
	for map_id in mod_map_ids:
		map_option_button.add_item(AutoloadDatabase.mod_maps[map_id].get_map_name())
		var index: int = map_option_button.item_count - 1
		map_option_button.set_item_metadata(index, map_id)
		if map_id == AutoloadDatabase.active_map_id:
			selected_index = index
	map_option_button.select(selected_index)

func _on_map_option_selected(index: int) -> void:
	emit_signal("map_selected", str(map_option_button.get_item_metadata(index)))
#endregion

func _update_map_canvas_size() -> void:
	var map_width: float = 0.0
	var map_height: float = 0.0
	if AutoloadDatabase.encounter_map:
		### From the top-left node to the furthest one, plus one node's room (as a column/row of the prototype's map).
		var map_extent: Vector2 = _get_encounter_map_bounds().size
		map_width = map_left_margin + map_extent.x + column_width + column_padding
		map_height = map_top_margin + map_extent.y + row_height + vertical_padding
	else:
		var max_depth: int = 0
		var max_branch: int = 0
		for encounter_id in AutoloadDatabase.encounter_depth.keys():
			max_depth = max(max_depth, AutoloadDatabase.encounter_depth[encounter_id])
			max_branch = max(max_branch, _get_branch_index(encounter_id))

		map_width = map_left_margin + (max_depth + 1) * (column_width + column_padding)
		map_height = map_top_margin + (max_branch + 1) * (row_height + vertical_padding)

	_map_content_size = Vector2(map_width, map_height)   # true node bounds
	_map_size = Vector2(map_width, background_fixed_height)  # background size

	scroll_content_root.custom_minimum_size = Vector2(map_width, 0)

	voronoi_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	voronoi_background.position = Vector2.ZERO
	voronoi_background.size = _map_size

func _update_voronoi_background() -> void:
	var mat := voronoi_background.material as ShaderMaterial
	if not mat:
		return
	if _map_content_size == Vector2.ZERO:
		return

	var positions: Array[Vector2] = []
	var colors: Array[Color] = []
	var bg_global_origin := voronoi_background.global_position

	for encounter_id in encounter_node_instances.keys():
		var encounter_def: EncounterDefinition = AutoloadDatabase.encounter_definitions[encounter_id]
		var region_data: MapRegionDefinition = AutoloadDatabase.get_map_region_by_id(encounter_def.map_region_id)
		if not region_data:
			continue

		var node: MapEncounterNode = encounter_node_instances[encounter_id]
		var node_global_center := node.global_position + node.size * 0.5
		var node_relative := node_global_center - bg_global_origin

		# Normalize against content size so Y is not compressed by the tall background
		var uv := node_relative / _map_content_size
		positions.append(uv)
		colors.append(region_data.background_color)

	var count := positions.size()
	while positions.size() < 64:
		positions.append(Vector2.ZERO)
		colors.append(Color.BLACK)

	mat.set_shader_parameter("edge_softness", edge_softness)
	mat.set_shader_parameter("darken_edges", darken_edges)
	mat.set_shader_parameter("point_count", count)
	mat.set_shader_parameter("points", positions)
	mat.set_shader_parameter("colors", colors)
	# Fade params also use content size, not background size
	mat.set_shader_parameter("max_x_length", max_x_length / _map_content_size.x)
	mat.set_shader_parameter("max_y_length", max_y_length / _map_content_size.y)
	mat.set_shader_parameter("fade_width", fade_width / _map_content_size.y)
	mat.set_shader_parameter("fade_power", fade_power)
	mat.set_shader_parameter("uv_scale", _map_size / _map_content_size)
