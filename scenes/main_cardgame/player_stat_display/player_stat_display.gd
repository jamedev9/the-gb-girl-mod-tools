extends Cardgame_UI_Element
class_name PlayerCombatStatDisplay

@export var HPvalue: Label
#@export var Damagevalue: Label
#@export var Maxdamagevalue: Label
@export var Energyvalue: Label

@export var energy_next_round: Label
@export var pleasure_bar: SimplePleasureBar
@export var orgasm_icon: OrgasmIcon
@export var orgasms_so_far_label: Label
@export var profile_pic: TextureRect
@export var energy_delta_label: Label

#@export var damage_container: Container
@export var current_energy_container: Container
@export var energy_next_turn_container: Container

@export var cum_overlay: ColorRect
@export var cum_texture: Texture2D
@export var layer_overlap: float = 0.7
@export var shader_material: ShaderMaterial
@export_range(1,5) var contrast: float = 1
@export var max_cumshot_number: int = 5
var nr_of_cumshots_received: int = 0 ### ZZZ - stopped here
var max_energy_value: int
var last_noted_energy_next_turn: int = 0
var orgasm_counter: int = 0
const ORGASMS_SO_FAR_KEY: String = "UI_PLAYER_STAT_ORGASMS_SO_FAR_LABEL"

const CUM_INTENSITY_TWEEN_DURATION: float = 0.3

signal event_card_dropped(event_card: EventCard, empty_string: String)

func _process(_delta: float) -> void:
	_update_displayed_energy_next_round()
	_update_energy_delta_label()

### Shows the energy cost of whatever's currently being dragged - an Action Card
### (cost depends on whichever opponent is under the cursor) or an Event Card
### (cost is player-only, so it shows for the whole drag). Hidden whenever nothing
### is being dragged. Polled every frame to match the live cost preview on the
### dragged card itself (see ActionCard/EventCard).
func _update_energy_delta_label() -> void:
	var viewport: Viewport = get_viewport()
	if not viewport.gui_is_dragging():
		energy_delta_label.hide()
		return
	var drag_data: Variant = viewport.gui_get_drag_data()
	var cost: int
	if drag_data is ActionCard:
		var hovered_opponent: OpponentCard = OpponentCard.find_hovered_opponent_card(viewport)
		if not hovered_opponent:
			energy_delta_label.hide()
			return
		cost = main_game.action_manager.get_current_move_cost(
			drag_data.represented_action_id, hovered_opponent.get_opponent_id())
	elif drag_data is EventCard:
		cost = EventCardDefinition.get_energy_cost_of_playing_card(
			main_game.game_state, drag_data.event_card_instance.card_id)
	else:
		energy_delta_label.hide()
		return
	energy_delta_label.text = "-%s" % cost
	energy_delta_label.modulate = SettingsManager.active_positive_color() if cost <= 0 else SettingsManager.active_negative_color()
	energy_delta_label.show()

func _ready() -> void:
	super._ready()
	shader_material.set_shader_parameter("cum_texture",cum_texture)
	shader_material.set_shader_parameter("damage_intensity",0.0)
	shader_material.set_shader_parameter("layer_overlap", layer_overlap)
	shader_material.set_shader_parameter("contrast", contrast)
	cum_overlay.material = shader_material
	energy_delta_label.hide()
	main_game.meta_game.connect("save_game_state_changed",Callable(self,"update_when_save_game_changes"))
	#orgasms_so_far_label.text = "0"+orgasm_counter_text
	reset_orgasm_counter()

func update_when_save_game_changes(save_game_state: SaveGameState) -> void:
	_load_profile_picture_from_save_game(save_game_state)

func _load_profile_picture_from_save_game(save_game_state: SaveGameState) -> void:
	profile_pic.texture = save_game_state.get_character_portrait()

func update_class_specific_displays(game_state: GameState) -> void:
	if game_state.player.is_empty():
		return
	#HPvalue.text = str(int(game_state.player.get("hp")))
	Energyvalue.text = str(int(game_state.player.get("current_energy")))
	max_energy_value = int(game_state.player.get("max_energy"))
	energy_next_round.text = str(int(PlayerStatsManager.get_player_energy_next_round(game_state)))

func set_starting_values(game_state: GameState) -> void:
	pleasure_bar.initialize_values(game_state.player.get("damage_threshold"))
	HPvalue.text = str(int(game_state.player.get("hp")))
	nr_of_cumshots_received = 0
	_update_cum_intensity(0)
	reset_orgasm_counter() 

func reset_orgasm_counter() -> void:
	orgasm_counter = 0
	orgasms_so_far_label.text = tr(ORGASMS_SO_FAR_KEY) % 0

func get_displayed_player_damage() -> int:
	return pleasure_bar.get_current_pleasure()

func update_displayed_values_when_taking_damage(health_after_damage: int,_orgasms_after_damage: int) -> void:
	pleasure_bar.set_current_pleasure(health_after_damage)
	#HPvalue.text = str(orgasms_after_damage)

func update_displayed_values_when_healing(health_after_healing: int) -> void:
	pleasure_bar.set_current_pleasure(health_after_healing)

func get_damage_display_node() -> Node:
	return pleasure_bar

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is EventCard:
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is EventCard:
		emit_signal("event_card_dropped",data.event_card_instance,"")

func increment_number_of_times_cummed_on() -> void: ### Called by defeated opponent animation
	#print("Running increment_number_of_times_cummed_on")
	nr_of_cumshots_received += 1
	_update_cum_intensity(nr_of_cumshots_received)

func _update_cum_intensity(cum_number: int) -> void:
	#print("Running _update_cum_intensity")
	var intensity: float = float(cum_number) / float(max_cumshot_number)
	#print("Intensity: %s"%intensity)
	var tween = create_tween()
	tween.tween_method(
		func(value: float): shader_material.set_shader_parameter("damage_intensity", value),
		shader_material.get_shader_parameter("damage_intensity"),
		intensity,CUM_INTENSITY_TWEEN_DURATION
	)

func get_orgasm_counter() -> Control:
	return orgasm_icon

func decrement_hp_value() -> void:
	var current_value: int = int(HPvalue.text)
	var new_value: int = current_value - 1
	HPvalue.text = str(new_value)

func increment_orgasm_counter() -> void:
	orgasm_counter += 1
	orgasms_so_far_label.text = tr(ORGASMS_SO_FAR_KEY) % orgasm_counter
	AnimationHelper_NodeFlasher._flash_nodes_green(
		[orgasms_so_far_label],1,1,0.2)

func drain_pleasure_bar() -> void:
	await pleasure_bar.drain_pleasure_bar()

func animate_pleasure_bar_to_value(pleasure_after_orgasm:int,duration: float) -> void:
	await pleasure_bar.animate_pleasure_bar_to_value(pleasure_after_orgasm,duration)

func increase_orgasm_counter(restore_orgasms: int) -> void:
	var current_value: int = int(HPvalue.text)
	var new_value: int = current_value + restore_orgasms
	HPvalue.text = str(new_value)
	
func _update_displayed_energy_next_round() -> void:
	var energy_next_round_based_on_visuals: int = find_visual_energy_next_round()
	energy_next_round.text = str(energy_next_round_based_on_visuals)
	if energy_next_round_based_on_visuals != last_noted_energy_next_turn:
		var energy_delta = last_noted_energy_next_turn - energy_next_round_based_on_visuals
		AnimationHelper_NodeFlasher.alert_player_of_value_change(
			[energy_next_turn_container],energy_delta,1,1.05,0.2)
	last_noted_energy_next_turn = energy_next_round_based_on_visuals

func find_visual_energy_next_round() -> int:
	#var energy_upkeep_from_visuals: int = main_game.opponents_container.get_energy_upkeep_for_visuals()
	var energy_upkeep_from_visuals: int = main_game.get_energy_upkeep_for_visuals()
	var energy_from_statuses: int = get_energy_drain_from_statuses()
	var displayed_energy: int = max_energy_value - energy_upkeep_from_visuals - energy_from_statuses
	return displayed_energy

func get_energy_drain_from_statuses() -> int:
	#var drain: int = main_game.player_status_effects_display.get_energy_drain_from_displayed_statuses()
	var drain: int = main_game.get_energy_drain_from_displayed_statuses()
	return drain
