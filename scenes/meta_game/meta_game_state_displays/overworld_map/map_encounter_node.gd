extends Cardgame_UI_Element
class_name MapEncounterNode

@export var background_panel: PanelContainer
@export var encounter_name: RichTextLabel
### Optional: a node design without a picture (the rework's) leaves it unset.
@export var encounter_picture: TextureRect
@export var select_encounter_button: Button
@export var checkbox_container: PanelContainer
@export var green_highlight: Panel

### The first star of the difficulty row. Its parent is the row (StarContainer); it is the template the other
### stars are copied from, so whatever it looks like in the editor is what every star looks like.
@export var star_texture_node: TextureRect
### The "n/m" text of the difficulty badge (n = the encounter's difficulty, m = the highest, EncounterDifficultyModel.MAX_STARS),
### e.g. "3/5". It sits in the star row, so it is shown and hidden with it. When it is set the row shows ONE star icon next to
### it instead of one icon per step.
@export var difficulty_label: Label

@export_group("Difficulty stars")
### Shows the encounter's difficulty (MetaGame.get_encounter_difficulty_stars()) as that many stars - for every map
### node, set on the root node of map_encounter_node.tscn. Only works while EncounterDifficultySettings.ENABLED (the
### master switch of the whole feature, currently off) is true. Unrated and hidden encounters show no stars.
@export var show_difficulty_stars: bool = false
### Debug builds only, and only with the feature and show_difficulty_stars on: 1-5 shows that many stars on every map node whatever
### the real rating is, to judge the look. 0 = real ratings.
@export_range(0, 5) var debug_preview_star_count: int = 0

var displayed_encounter: EncounterDefinition
var _difficulty_star_row: DifficultyStarRow
var tooltip_type: TooltipId = TooltipId.ENCOUNTER_STATUS_EXPLANATION
### True while the pointer is over the difficulty badge, which shows the difficulty tooltip instead of tooltip_type.
var _showing_difficulty_tooltip: bool = false

@onready var meta_game: Node = main_game.meta_game

signal request_displaying_encounter(encounter_def: EncounterDefinition)
signal double_click_to_start_encounter_requested(encounter_def: EncounterDefinition)

const BACKGROUND_COLOR_ALPHA: float = 0.5
### The node's colour when its encounter names a region that isn't installed (a mod region whose mod was removed).
const COLOR_WITHOUT_REGION: Color = Color(0.5, 0.5, 0.5)

func _ready() -> void:
	super._ready()
	set_process(false) ### Only runs while the pointer is over the node, see _set_hover_tracking().
	meta_game.connect("save_game_state_changed",Callable(self,"update_when_save_game_changes"))
	select_encounter_button.connect("encounter_button_double_clicked",Callable(self,"_forward_double_click_to_start_request"))

func _refresh_text() -> void:
	if not displayed_encounter:
		return
	display_encounter_on_node(displayed_encounter)

func display_encounter_on_node(encounter_def: EncounterDefinition) -> void:

	displayed_encounter = encounter_def
	if encounter_picture:
		encounter_picture.texture = encounter_def.encounter_picture
	_set_default_encounter_name()

	if not meta_game:
		return
	var display_status: MetaGame.EncounterNodeState = meta_game.get_encounter_node_state(encounter_def.encounter_id)
	if display_status == MetaGame.EncounterNodeState.HIDDEN:
		encounter_name.text = "[b] ? [/b]"
	_update_difficulty_stars(display_status)

#region Difficulty stars
func _update_difficulty_stars(display_status: MetaGame.EncounterNodeState) -> void:
	if not star_texture_node:
		return
	if _difficulty_star_row == null:
		_difficulty_star_row = DifficultyStarRow.new(star_texture_node)
	var difficulty: int = 0
	### An encounter the player hasn't discovered yet doesn't give away its difficulty either.
	if display_status != MetaGame.EncounterNodeState.HIDDEN:
		difficulty = DifficultyStarRow.get_star_count(meta_game, displayed_encounter, show_difficulty_stars, debug_preview_star_count)
	var star_icons: int = difficulty
	if difficulty_label:
		star_icons = mini(difficulty, 1) ### "n/m" plus a single star icon, not one icon per step.
		if difficulty > 0:
			difficulty_label.text = "%d/%d" % [difficulty, EncounterDifficultyModel.MAX_STARS]
	_difficulty_star_row.show_count(star_icons)

### The select button sits on top of most of the badge, so the badge only gets mouse events where the button doesn't reach
### (its mouse_entered / mouse_exited go to the same handlers as the node's). Where the button does cover it, _process()
### checks where the pointer is while it is over the node, and swaps between the difficulty tooltip (a generic tooltip,
### which reads this node's tooltip_info) and the usual encounter tooltip.
func _process(_delta: float) -> void:
	var over_badge: bool = _is_pointer_over_difficulty_badge()
	if over_badge == _showing_difficulty_tooltip:
		return
	_showing_difficulty_tooltip = over_badge
	emit_signal("tooltip_requested",_get_current_tooltip_id(),self)

func _get_current_tooltip_id() -> TooltipId:
	if _showing_difficulty_tooltip:
		return TooltipId.GENERIC_TOOLTIP
	return tooltip_type

func _set_hover_tracking(enabled: bool) -> void:
	set_process(enabled)
	_showing_difficulty_tooltip = enabled and _is_pointer_over_difficulty_badge()

### The badge is the star row's container (the "n/m" text and the star icon together).
func _is_pointer_over_difficulty_badge() -> bool:
	if not star_texture_node:
		return false
	var star_row: Control = star_texture_node.get_parent() as Control
	if star_row == null or not star_row.is_visible_in_tree():
		return false
	return Rect2(Vector2.ZERO,star_row.size).has_point(star_row.get_local_mouse_position())
#endregion

func _set_default_encounter_name() -> void:
	if not displayed_encounter:
		return
	encounter_name.text = "[b]"+displayed_encounter.get_encounter_name()+"[/b]"
	

func set_size_of_background_panel(width: float,height:float) -> void:
	background_panel.custom_minimum_size = Vector2(width,height)

func _update_background_panel(encounter_def: EncounterDefinition) -> void:
	var background_color: Color = get_color_for_encounter_definition(encounter_def)
	background_color.a = BACKGROUND_COLOR_ALPHA
	set_panel_color(background_panel,background_color)

func set_panel_color(panel: PanelContainer, color: Color) -> void:
	var existing_style = panel.get_theme_stylebox("panel")
	var new_style = existing_style.duplicate()
	new_style.bg_color = color
	panel.add_theme_stylebox_override("panel", new_style)

func get_color_for_encounter_definition(encounter_def: EncounterDefinition) -> Color:
	var map_region: MapRegionDefinition = AutoloadDatabase.get_map_region_by_id(encounter_def.map_region_id)
	if map_region == null:
		return COLOR_WITHOUT_REGION
	return map_region.background_color

#func get_color_for_map_region(map_area: EncounterDefinition.MapAreas) -> Color:
	#return map_area_colors[map_area]

func update_when_save_game_changes(save_game_state:SaveGameState) -> void:
	green_highlight.visible = false
	var display_status: MetaGame.EncounterNodeState = meta_game.get_encounter_node_state(displayed_encounter.encounter_id)
	
	if display_status == MetaGame.EncounterNodeState.HIDDEN or display_status == MetaGame.EncounterNodeState.LOCKED:
		self.modulate.a = 0.5
	else:
		self.modulate.a = 1.0
		if not save_game_state.is_encounter_completed(displayed_encounter.encounter_id):
			green_highlight.visible = true
	if display_status == MetaGame.EncounterNodeState.HIDDEN:
		encounter_name.text = "[b] ? [/b]"
	else:
		encounter_name.text = "[b]"+displayed_encounter.get_encounter_name()+"[/b]"
	if save_game_state.is_encounter_completed(displayed_encounter.encounter_id):
		checkbox_container.visible = true
	_update_difficulty_stars(display_status)

func _forward_double_click_to_start_request() -> void:
	emit_signal("double_click_to_start_encounter_requested",displayed_encounter)

func _on_select_encounter_button_pressed() -> void:
	var display_status: MetaGame.EncounterNodeState = meta_game.get_encounter_node_state(displayed_encounter.encounter_id)
	if display_status == MetaGame.EncounterNodeState.HIDDEN:
		return
	emit_signal("request_displaying_encounter",self.displayed_encounter)


func _on_mouse_entered():
	_set_hover_tracking(true)
	call_deferred("emit_signal","tooltip_requested",_get_current_tooltip_id(),self)
	#emit_signal("tooltip_requested",tooltip_type,self)

func _on_mouse_exited():
	_set_hover_tracking(false)
	emit_signal("tooltip_cleared",self)


func _on_select_encounter_button_mouse_entered() -> void:
	_on_mouse_entered()
	pass # Replace with function body.


func _on_select_encounter_button_mouse_exited() -> void:
	_on_mouse_exited()
	pass # Replace with function body.
