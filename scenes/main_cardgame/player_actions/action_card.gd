extends Cardgame_UI_Element
class_name ActionCard

#region Child nodes
@export var action_type: RichTextLabel
@export var move_energy: Label
@export var energy_per_round: Label
@export var move_damage: Label
@export var action_picture: TextureRect
@export var status_pics_container: Container
@export var action_disabled_overlay: PanelContainer
#endregion

@export var represented_action_id: String
var represented_action: PlayerAction
var action_is_disabled: bool = false

#@export var status_mini_pic_scene: PackedScene = preload("res://scenes/main_cardgame/status_effects/status_effect_mini_display.tscn")
@export var status_mini_pic_scene: PackedScene

var _original_position: Vector2
var _drag_offset: Vector2  = Vector2(0,0)

### True only on the floating duplicate created by set_drag_preview() in
### _get_drag_data() - the duplicate is a live ActionCard with its own _process(),
### distinguished from the real hand card so only the preview reflects a hovered
### opponent's cost modifiers (e.g. the "Lubed" status) while dragging.
var _is_drag_preview_clone: bool = false

enum AnimationState {IN_HAND,DRAGGING,RESOLVING,FAILED_TO_RESOLVE}
var animation_state: AnimationState = AnimationState.IN_HAND
var invisible_states: Array[AnimationState] = [AnimationState.DRAGGING]

signal hovered(action_card: ActionCard)
signal unhovered(action_card: ActionCard)
signal _relay_another_action_card_dropped(action_card:ActionCard)
signal drag_started(action_card: ActionCard)
signal animation_state_changed(action_card: ActionCard)
signal returned_to_hand

#PLAYERACTION_ANAL_ACTION_NAME,
func _refresh_text() -> void:
	if not represented_action:
		return
	_set_action_name_text(represented_action)


func _process(delta: float) -> void:
	show_if_disabled_by_status(main_game.game_state)
	_update_move_energy_display()

### Polled every frame rather than event-driven - the number of live action cards is
### small, and the cost depends on ambient state (player statuses/passives, and while
### dragging, whichever opponent is currently hovered) that doesn't have a single
### signal to hook.
func _update_move_energy_display() -> void:
	if represented_action_id == "":
		return
	var opponent_id: String = ""
	if _is_drag_preview_clone:
		var hovered_opponent: OpponentCard = OpponentCard.find_hovered_opponent_card(get_viewport())
		if hovered_opponent:
			opponent_id = hovered_opponent.get_opponent_id()
	var base_cost: int = main_game.action_manager.get_action_base_move_cost(represented_action_id)
	var current_cost: int = main_game.action_manager.get_current_move_cost(represented_action_id, opponent_id)
	move_energy.text = str(current_cost)
	move_energy.modulate = Color.WHITE
	if current_cost < base_cost:
		move_energy.modulate = SettingsManager.active_positive_color()
	elif current_cost > base_cost:
		move_energy.modulate = SettingsManager.active_negative_color()

func update_class_specific_displays(game_state: GameState) -> void:
	_make_unavailable_during_opponents_turn(game_state)
	_make_unavailable_after_game_end(game_state)
	show_if_disabled_by_status(game_state)

func show_if_disabled_by_status(game_state: GameState) -> void:
	### Single source of truth for "which actions are currently disabled" - matches
	### GameState.get_disabled_player_actions(), which also covers allowed_action_ids
	### -based components (e.g. "only vaginal is allowed") and passives, neither of
	### which the old hand-rolled status-only check here accounted for.
	action_is_disabled = represented_action_id in game_state.get_disabled_player_actions()
	action_disabled_overlay.visible = action_is_disabled
	self.mouse_filter = Control.MOUSE_FILTER_PASS if action_is_disabled else Control.MOUSE_FILTER_STOP

func display_action(action_id:String) -> void:
	### player_actions_by_id may still be loading in the background (see
	### AutoloadDatabase._ready()) - retry once ready instead of silently no-op'ing
	### below (represented_action would come back null).
	if not AutoloadDatabase.is_content_loaded:
		AutoloadDatabase.run_when_content_loaded(Callable(self,"display_action").bind(action_id))
		return
	self.represented_action_id = action_id
	self.represented_action = AutoloadDatabase.get_player_action_by_id(action_id)
	
	if not represented_action:
		return
	_set_action_name_text(represented_action)
	#action_type.text = represented_action.action_name
	move_energy.text = str(represented_action.move_energy)
	energy_per_round.text = str(represented_action.energy_per_round)
	move_damage.text = str(represented_action.base_damage)
	for status_effect in represented_action.statuses_to_apply:
		var new_status_pic: StatusEffectMiniDisplay = status_mini_pic_scene.instantiate()
		new_status_pic.display_status(
			status_effect.status_definition,
			status_effect.status_duration,
			status_effect.number_of_stacks)
		status_pics_container.add_child(new_status_pic)
	
	var picture: Texture2D
	picture = ImageOverrideManager.get_override_texture(ImageOverrideManager.ReplacementType.ACTION_CARD_IMAGE,action_id)
	if not picture:
		picture = represented_action.picture
		
	action_picture.texture = picture

func _set_action_name_text(given_action_type: PlayerAction) -> void:
	action_type.text = given_action_type.get_action_name()

	
	
	

func register_card_in_entity_registry() -> void:
	if not main_game:
		return
	main_game.entity_registry.register_entity(represented_action_id,self)

func free_and_unregister() -> void:
	if not main_game:
		return
	main_game.entity_registry.unregister_entity(represented_action_id)
	#print("FREE:", represented_action_id, " ", get_instance_id())
	self.queue_free()

#endregion

#region Drag and drop functionality:
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data:
		return false
	if data is ActionCard:
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is ActionCard:
		emit_signal("_relay_another_action_card_dropped",data)


func is_action_disabled() -> bool:
	if action_is_disabled:
		return true
	
	return represented_action_id in main_game.game_state.get_disabled_player_actions()
	#if main_game.action_disable
	

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not main_game.game_state.player_can_input():
		return
	if is_action_disabled():
		return
	emit_signal("drag_started",self)
	_original_position = global_position

	var preview_root := Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_card := duplicate(Control.DUPLICATE_USE_INSTANTIATION)
	(preview_card as ActionCard)._is_drag_preview_clone = true
	preview_card.visible = true
	preview_card.modulate = Color.WHITE
	preview_card.scale = scale
	preview_card.size = size

	_drag_offset = -_at_position
	preview_card.position = -_at_position

	preview_root.add_child(preview_card)
	set_drag_preview(preview_root)
	change_animation_state(AnimationState.DRAGGING)
	return self
	
func change_animation_state(new_state: AnimationState) -> void:
	### Public function called by Animation Handlers and the Event Card Hand to alert that the card is changing state
	self.animation_state = new_state
	if new_state in invisible_states:
		self.visible = false
	else:
		self.visible = true
	emit_animation_state_changed()

func emit_animation_state_changed() -> void:
	emit_signal("animation_state_changed",self)

#endregion

func _on_mouse_entered() -> void:
	if is_action_disabled():
		return
	emit_signal("hovered",self)

func _on_mouse_exited() -> void:
	if is_action_disabled():
		return
	emit_signal("unhovered",self)

#region When displayed as a tooltip:
func update_tooltip_information(_game_state: GameState,_tooltip_id: TooltipUI.TooltipId,control_node:Control) -> void:
	var player_action: PlayerAction = control_node.active_player_action
	if not player_action:
		return
	display_action(player_action.action_id)
	
#region When retracted:
#func request_signal_when_returned_to_position(rest_position: Vector2) -> void:
	#while self.global_position != rest_position:
		#var timer: Timer = Timer.new()
		#add_child(timer)
		#timer.autostart = true
		#timer.start(0.01)
		#await timer.timeout
		#
	#emit_signal("returned_to_hand")

func request_signal_when_returned_to_position(rest_position: Vector2, max_wait: float = 2.0) -> void:
	var elapsed: float = 0.0
	var poll_interval: float = 0.05
	while is_instance_valid(self) and self.global_position.distance_to(rest_position) > 1.0:
		await get_tree().create_timer(poll_interval).timeout
		elapsed += poll_interval
		if elapsed >= max_wait:
			break
	if is_instance_valid(self):
		emit_signal("returned_to_hand")
