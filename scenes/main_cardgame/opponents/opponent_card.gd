extends Cardgame_UI_Element
class_name OpponentCard

@export var opponent_name: RichTextLabel
@export var opponent_type: RichTextLabel
@export var opponent_picture: TextureRect
@export var current_damage_container: Control

@export var active_player_action_pic: ActivePlayerActionPic
@export var action_mini_display: OpponentActionMiniDisplay
@export var container_for_status_displays: Container
@export var player_action_video: VideoStreamPlayer
@export var opponent_damage_label: RichTextLabel
@export var simple_pleasure_bar: SimplePleasureBar
@export var idle_picture: TextureRect
@export var video_panel_container: Container
@export var background_color: ColorRect
@export var opponent_action_mini_display: OpponentActionMiniDisplay
@export var current_healing_container: Control

var opponent_id: String
var displayed_opponent_instance: OpponentInstance
var displayed_opponent_type: OpponentType
var _drag_offset: Vector2 = Vector2.ZERO
var active_player_action_id: String = ""
var tracking_mouse_location: bool = false

var grid_position: Vector2i

var _is_mouse_inside: bool = false
var _currently_hovered_child: Control = null

var dragging_allowed: bool = true

@onready var status_mini_display_scene: PackedScene = load("res://scenes/main_cardgame/status_effects/status_effect_mini_display.tscn")
@onready var passive_effect_mini_display: PackedScene = load("res://scenes/main_cardgame/passive_effect_mini_display/passive_effect_mini_display.tscn")
@onready var action_card_scene: PackedScene = load("res://scenes/main_cardgame/player_actions/action_card.tscn")

signal action_card_dropped(represented_action_id: String, opponent_card: OpponentCard)
signal event_card_dropped(event_card_instance: EventCardInstance, opponent_id: String)
signal action_began_dragging(action_id: String,opponent_card: OpponentCard)
signal hovered(opponent_card:  OpponentCard)
signal unhovered(opponent_card:  OpponentCard)

const POP_SIGNIFICANCE: float = 1
const POP_SCALE: float = 1.2
const POP_DURATION: float = 0.5

func _process(_delta: float) -> void:
	if not _is_mouse_inside:
		return
	var mouse_pos: Vector2 = get_local_mouse_position()
	var newly_hovered_child: Control = _get_child_at_mouse_position()
	if newly_hovered_child == _currently_hovered_child:
		return
	if _currently_hovered_child != null:
		if _currently_hovered_child.has_method("_on_mouse_exited"):
			_currently_hovered_child._on_mouse_exited()
	_currently_hovered_child = newly_hovered_child
	if _currently_hovered_child != null:
		if _currently_hovered_child.has_method("_on_mouse_entered"):
			_currently_hovered_child._on_mouse_entered()

func _on_mouse_entered() -> void:
	_is_mouse_inside = true
	emit_signal("hovered",self)

func _on_mouse_exited() -> void:
	_is_mouse_inside = false
	if _currently_hovered_child != null:
		if _currently_hovered_child.has_method("_on_mouse_exited"):
			_currently_hovered_child._on_mouse_exited()
		_currently_hovered_child = null
	emit_signal("unhovered",self)

func _get_child_at_mouse_position() -> Control:
	var global_mouse: Vector2 = get_global_mouse_position()
	return _find_deepest_hoverable_node(self, global_mouse)

func _find_deepest_hoverable_node(node: Node, global_mouse: Vector2) -> Control:
	for child in node.get_children():
		if not child is Control:
			continue
		if not child.get_global_rect().has_point(global_mouse):
			continue
		# Recurse deeper first
		var deeper_result: Control = _find_deepest_hoverable_node(child, global_mouse)
		if deeper_result != null:
			return deeper_result
		# No deeper match found - check if this node itself is hoverable
		if child.has_method("_on_mouse_entered") and child.has_method("_on_mouse_exited"):
			#print("Found hoverable node: ", child.name, " at path: ", child.get_path())
			return child
	return null


func update_class_specific_displays(game_state:GameState) -> void:
	_clear_video_if_no_action_is_active(game_state)

func display_opponent(game_state: GameState,given_opponent_id: String) -> void:
	self.opponent_id =  given_opponent_id
	self.displayed_opponent_type = game_state.get_active_opponent_type(given_opponent_id)
	displayed_opponent_instance = game_state.get_opponent_instance(given_opponent_id)
	_show_opponent_type_info(displayed_opponent_type)
	_handle_player_action_card(game_state)
	_handle_upcoming_opponent_action(game_state,given_opponent_id)
	_handle_passive_effects(displayed_opponent_type)
	_handle_active_status_effects(game_state, given_opponent_id)
	_add_idle_picture_of_opponents_cock(displayed_opponent_type)
	_change_background_color(displayed_opponent_type)
	_register_self_as_node_representing_opponent_id(given_opponent_id)
	simple_pleasure_bar.initialize_values(displayed_opponent_type.max_damage)
	#simple_pleasure_bar.set_current_pleasure(displayed_opponent_instance.current_damage)
	#simple_pleasure_bar.animate_pleasure_bar_to_value(displayed_opponent_instance.current_damage,0)

func _add_idle_picture_of_opponents_cock(given_opponent_type: OpponentType) -> void:
	var idle_texture: Texture2D = given_opponent_type.get_cock_picture()
	idle_picture.texture = idle_texture
	
func _change_background_color(given_opponent_type: OpponentType) -> void:
	background_color.color = given_opponent_type.get_opponent_color()

func _register_self_as_node_representing_opponent_id(given_opponent_id: String) -> void:
	main_game.entity_registry.register_entity(given_opponent_id,self)

func free_and_unregister() -> void:
	if not main_game:
		return
	main_game.entity_registry.unregister_entity(opponent_id)
	self.queue_free()

func update_opponent_display(game_state: GameState) -> void:
	if not main_game.opponent_manager.opponent_id_is_valid(game_state,self.opponent_id):
		return
	var opponent_instance: OpponentInstance = game_state.get_opponent_instance(self.opponent_id)
	if opponent_instance == null:
		return
	opponent_picture.texture = opponent_instance.opponent_type.picture
	opponent_type.text = opponent_instance.opponent_type.opponent_type_name
	_handle_player_action_card(game_state)
	#_handle_upcoming_opponent_action(game_state,self.opponent_id)
	_handle_passive_effects(displayed_opponent_type)
	_handle_active_status_effects(game_state,self.opponent_id)

func _show_opponent_type_info(given_opponent_type: OpponentType) -> void:
	opponent_picture.texture = given_opponent_type.picture
	opponent_name.text = displayed_opponent_instance.opponent_name
	opponent_type.text = given_opponent_type.opponent_type_name


func display_opponent_as_tooltip(opponent_type_id: String) -> void:
	displayed_opponent_type = AutoloadDatabase.opponent_types[opponent_type_id]
	_show_opponent_type_info(displayed_opponent_type)
	_handle_passive_effects(displayed_opponent_type)
	

#region Check for action in use:
func _handle_player_action_card(game_state:GameState) -> void:
	var action_id: String = game_state.get_action_assigned_to_opponent(opponent_id)
	#print("Player action: Action ID = %s"%action_id)
	if action_id == active_player_action_id:
		return # no change required
	active_player_action_id = action_id
	var action = AutoloadDatabase.get_player_action_by_id(action_id)
	_display_active_player_action(action)
	#enable_dragging()


func _display_active_player_action(action: PlayerAction) -> void:
	_show_matching_video(action)
	if action == null:
		active_player_action_pic.texture = null
		active_player_action_pic.active_player_action = null
		idle_picture.visible = true
		return
	active_player_action_pic.texture = action.picture
	active_player_action_pic.active_player_action = action
	idle_picture.visible = false
	_pop_video_player()

func _pop_video_player() -> void:
	AnimationHelper_NodeFlasher._pop_node(video_panel_container,POP_SIGNIFICANCE,POP_SCALE,POP_DURATION)

func _show_matching_video(action: PlayerAction) -> void:
	if action == null:
		self.player_action_video.visible = false
		return
	if action.video_action_tags.is_empty():
		self.player_action_video.visible = false
		return
	var participant_type_tags: Array[VideoClip.ParticipantTags] = displayed_opponent_type.video_particpant_tags.duplicate(true)
	participant_type_tags.append_array(get_save_game_state().get_player_video_participant_tags())
	var clip: VideoClip = VideoPlayerSystem.get_video_by_tags(action.video_action_tags, participant_type_tags)
	if not clip:
		self.player_action_video.visible = false
		return
	self.player_action_video.visible = true
	self.player_action_video.stream = clip.video_file
	self.player_action_video.play()
	
#func _show_matching_video(action: PlayerAction) -> void:
	##print("Running _show_matching_video")
	#self.player_action_video.visible = true
	#if action == null:
		##print("null action")
		#self.player_action_video.visible = false
		#return
	#if action.video_action_tags.is_empty():
		##print("No video tags for action")
		#return
#
	#var participant_type_tags: Array[VideoClip.ParticipantTags] = displayed_opponent_type.video_particpant_tags
	#var clip: VideoClip = VideoPlayerSystem.get_video_by_tags(action.video_action_tags,participant_type_tags)
	##var clip: VideoClip = VideoPlayerSystem.get_video_by_tags(action.video_action_tags,[])
	#if not clip:
		#return
	#self.player_action_video.stream = clip.video_file
	#self.player_action_video.play()
#endregion

#region Check for opponents action:
func _handle_upcoming_opponent_action(game_state:GameState,_opponent_id:String) -> void:
	var opponent_instance: OpponentInstance = game_state.get_opponent_instance(_opponent_id)
	var upcoming_action: OpponentActionDefinition = opponent_instance.upcoming_action
	if upcoming_action == null:
		return
	update_displayed_action(upcoming_action)

func update_displayed_action(upcoming_action: OpponentActionDefinition) -> void:
	var action_damage: int = 0
	for effect in upcoming_action.effect_intents:
		if effect.effect_intent is DealDamageEffect:
			action_damage += effect.effect_intent.damage
		elif effect.effect_intent is RandomlyHealOrDealDamage:
			action_damage += effect.effect_intent.damage
	action_mini_display.display_action(upcoming_action)
	#print("Updating displayed action")
	_set_upcoming_damage_label_text(action_damage)

func _set_upcoming_damage_label_text(action_damage: int) -> void:
	#print("Setting damage label to: %s"%action_damage)
	if action_damage == 0:
		opponent_damage_label.visible = false
	else:
		opponent_damage_label.visible = true
		opponent_damage_label.text = str(action_damage)

func update_displayed_values_when_taking_damage(current_pleasure: int) -> void: #Called by animation handler for damage
	simple_pleasure_bar.set_current_pleasure(current_pleasure)
	
#endregion

#region Check for status effects
func _handle_passive_effects(given_opponent_type: OpponentType) -> void:
	for child in container_for_status_displays.get_children():
		if child is PassiveEffectMiniDisplay:
			child.queue_free()
	for passive_id in given_opponent_type.passive_effects:
		var passive: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions[passive_id]
		var new_mini_display: PassiveEffectMiniDisplay = passive_effect_mini_display.instantiate()
		new_mini_display.display_passive(passive)
		container_for_status_displays.add_child(new_mini_display)

func _handle_active_status_effects(game_state: GameState, _opponent_id: String) -> void:
	for child in container_for_status_displays.get_children():
		if child is StatusEffectMiniDisplay:
			child.queue_free()
	var active_statuses: Dictionary = game_state.get_opponent_instance(_opponent_id).status_effects
	for status_id in active_statuses.keys():
		var _status_display = add_new_status_display(status_id) # Child added inside "add_new_status_display"
		# This is to let animation call "add_new_status_display" and get the display for animations.

func add_new_status_display(status_id: String) -> StatusEffectMiniDisplay:
		var status_display: StatusEffectMiniDisplay = status_mini_display_scene.instantiate()
		container_for_status_displays.add_child(status_display)
		var opponent_instance: OpponentInstance = main_game.game_state.get_opponent_instance(opponent_id)
		if not opponent_instance:
			return null
		var status_info: Dictionary = main_game.game_state.get_opponent_instance(opponent_id).status_effects
		var status_definition: StatusEffectDefinition = AutoloadDatabase.status_effects_by_id[status_id]
		var status_duration: int = status_info[status_id]["duration"]
		var status_stacks: int = status_info[status_id]["stacks"]
		status_display.display_status(
			status_definition,
			status_duration,
			status_stacks
		)
		return status_display

func get_display_for_status(status_id: String) -> StatusEffectMiniDisplay:
	for status_display in container_for_status_displays.get_children():
		if status_display is StatusEffectMiniDisplay:
			if not status_display:
				return null
			if not status_display.represented_status_effect:
				return null
			if status_display.represented_status_effect.status_id == status_id:
				return status_display
	return null

#endregion 

#region Drag-and-drop functionality
#Things to accept: ActionCards and EventCards
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data:
		return false
	if data is ActionCard:
		return true
	if data is EventCard:
		return true
	return false
		
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is ActionCard:
		emit_signal("action_card_dropped",data.represented_action_id,self)
	if data is EventCard:
		emit_signal("event_card_dropped",data.event_card_instance,self.opponent_id)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if self.active_player_action_id == "":
		return
	if not main_game.it_is_the_players_turn():
		return
	if not _opponent_has_action():
		return
	if not dragging_allowed:
		return

	### Preview Visuals:
	var action_card: ActionCard = action_card_scene.instantiate()
	action_card.display_action(active_player_action_id)
	
	var preview_root := Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_card := action_card.duplicate(Control.DUPLICATE_USE_INSTANTIATION)
	preview_card.visible = true
	preview_card.modulate = Color.WHITE
	preview_card.scale = action_card.scale
	preview_card.size = action_card.size

	_drag_offset = -_at_position
	preview_card.position = -_at_position-_drag_offset

	preview_root.add_child(preview_card)
	set_drag_preview(preview_root)
	### Signal to container:
	emit_signal("action_began_dragging",self.active_player_action_id,self)
	
	return action_card

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		active_player_action_pic.modulate.a = 1.0

func _opponent_has_action() -> bool:
	return main_game.game_state.get_action_assigned_to_opponent(opponent_id) != ""
#endregion

func _clear_video_if_no_action_is_active(game_state: GameState) -> void:
	if ActionManager.get_action_assigned_to_opponent(game_state,self.opponent_id) == "":
		player_action_video.visible = false
	else:
		player_action_video.visible = true

func get_action_card_movement_location() -> Vector2: # global position
	return player_action_video.global_position

func get_pleasure_bar_location() -> Vector2:
	return current_damage_container.global_position+current_damage_container.size*0.5

#region Dragging stop:
func disable_dragging() -> void:
	dragging_allowed = false
func enable_dragging() -> void:
	dragging_allowed = true
