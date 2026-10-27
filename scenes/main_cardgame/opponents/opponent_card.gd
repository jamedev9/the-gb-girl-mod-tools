@tool
extends Cardgame_UI_Element
class_name OpponentCard

@export var opponent_name: RichTextLabel
@export var opponent_type: RichTextLabel
@export var opponent_picture: TextureRect
@export var current_damage_container: Control

@export var active_player_action_pic: ActivePlayerActionPic
@export var action_mini_display: OpponentActionMiniDisplay
@export var container_for_status_displays: Container
@export var player_action_video: VideoPlayback
@export var opponent_damage_label: RichTextLabel
@export var simple_pleasure_bar: SimplePleasureBar
@export var idle_picture: TextureRect

## Walks up from the currently hovered control (if any) to find an OpponentCard
## ancestor - shared by anything that needs to know which opponent, if any, is
## under the cursor right now (e.g. while dragging an action card).
static func find_hovered_opponent_card(viewport: Viewport) -> OpponentCard:
	var node: Node = viewport.gui_get_hovered_control()
	while is_instance_valid(node):
		if node is OpponentCard:
			return node
		node = node.get_parent()
	return null
@export var video_panel_container: Container
@export var background_color: ColorRect
@export var opponent_action_mini_display: OpponentActionMiniDisplay
@export var current_healing_container: Control
@export var video_and_idle_pic: Control
@export var orgasm_panel: Control
@export var orgasm_icon: OrgasmIcon
@export var orgasm_remaining_label: Label
@export var orgasms_so_far_label: Label

const ORGASMS_SO_FAR_KEY: String = "UI_PLAYER_STAT_ORGASMS_SO_FAR_LABEL"

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()
	if what == NOTIFICATION_DRAG_END:
		if not active_player_action_pic:
			#push_warning("active_player_action_pic is not set for opponent card")
			return
		active_player_action_pic.modulate.a = 1.0

func _refresh_text() -> void:
	if not displayed_opponent_type:
		return
	_display_opponent_type_name(displayed_opponent_type)
	refresh_orgasm_display()


func _process(_delta: float) -> void:
	### This script is @tool, but everything below is for a running game: in the editor the pleasure bar is a placeholder
	### (its script isn't @tool), so calling it errors every frame.
	if Engine.is_editor_hint():
		return
	_update_upcoming_damage_label()
	_update_pleasure_preview()
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

func get_opponent_id() -> String:
	return opponent_id
func get_opponent_instance() -> OpponentInstance:
	return displayed_opponent_instance
func get_opponent_type() -> OpponentType:
	return displayed_opponent_type


func update_class_specific_displays(game_state:GameState) -> void:
	_clear_video_if_no_action_is_active(game_state)
	### Re-evaluates the picture override now that main_game/meta_game/save_game_state are
	### guaranteed valid - display_opponent()/_show_opponent_type_info() can run before this
	### node is added to the tree, when get_selected_character_id() can't resolve a real
	### character yet. _set_opponent_picture_from_type() is side-effect-free, safe to re-run.
	if displayed_opponent_type:
		_set_opponent_picture_from_type(displayed_opponent_type)

func display_opponent(game_state: GameState,given_opponent_id: String) -> void:
	self.opponent_id =  given_opponent_id
	self.displayed_opponent_type = game_state.get_active_opponent_type(given_opponent_id)
	displayed_opponent_instance = game_state.get_opponent_instance(given_opponent_id)
	_read_player_blindness(game_state)
	_show_opponent_type_info(displayed_opponent_type)
	_handle_player_action_card(game_state)
	_handle_upcoming_opponent_action(game_state,given_opponent_id)
	_handle_passive_effects(displayed_opponent_type)
	_handle_active_status_effects(game_state, given_opponent_id)
	_add_idle_picture_of_opponents_cock(displayed_opponent_type)
	_change_background_color(displayed_opponent_type)
	_register_self_as_node_representing_opponent_id(given_opponent_id)
	simple_pleasure_bar.initialize_values(displayed_opponent_type.max_damage)
	refresh_orgasm_display()
	_apply_player_blindness_to_displays()


func _add_idle_picture_of_opponents_cock(given_opponent_type: OpponentType) -> void:
	if not idle_picture:
		#push_warning("idle_picture not set for opponent card")
		return
	var idle_texture: Texture2D = given_opponent_type.get_cock_picture()
	idle_picture.texture = idle_texture
	
func _change_background_color(given_opponent_type: OpponentType) -> void:
	background_color.color = _get_displayed_background_color(given_opponent_type)

func _register_self_as_node_representing_opponent_id(given_opponent_id: String) -> void:
	main_game.entity_registry.register_entity(given_opponent_id,self)

func free_and_unregister() -> void:
	if not main_game:
		return
	main_game.entity_registry.unregister_entity(opponent_id,self)
	self.queue_free()

func update_opponent_display(game_state: GameState) -> void:
	if not main_game.opponent_manager.opponent_id_is_valid(game_state,self.opponent_id):
		return
	var opponent_instance: OpponentInstance = game_state.get_opponent_instance(self.opponent_id)
	if opponent_instance == null:
		return

	_read_player_blindness(game_state)
	_set_opponent_picture_from_type(opponent_instance.opponent_type)
	_display_opponent_type_name(opponent_instance.opponent_type)
	_handle_player_action_card(game_state)
	#_handle_upcoming_opponent_action(game_state,self.opponent_id)
	_handle_passive_effects(displayed_opponent_type)
	_handle_active_status_effects(game_state,self.opponent_id)
	refresh_orgasm_display()
	_apply_player_blindness_to_displays()

func _show_opponent_type_info(given_opponent_type: OpponentType) -> void:
	_set_opponent_picture_from_type(given_opponent_type)
	_display_opponent_name()
	_display_opponent_type_name(given_opponent_type)

func _display_opponent_name() -> void:
	if not opponent_name or not displayed_opponent_instance:
		return
	if _player_cant_see_name:
		opponent_name.text = tr(HIDDEN_INFO_TEXT_KEY)
	else:
		opponent_name.text = displayed_opponent_instance.opponent_name

func _display_opponent_type_name(given_opponent_type: OpponentType) -> void:
	if _player_cant_see_type:
		opponent_type.text = tr(HIDDEN_INFO_TEXT_KEY)
	else:
		opponent_type.text = given_opponent_type.get_opponent_type_name()

#region Player blindness (Status_BlindPlayer)
const HIDDEN_INFO_TEXT_KEY: String = "UI_OPPONENT_INFO_HIDDEN"

var _player_cant_see_pleasure: bool = false
var _player_cant_see_type: bool = false
var _player_cant_see_visuals: bool = false
var _player_cant_see_name: bool = false
var _player_cant_see_upcoming_action: bool = false
var _player_cant_see_passives: bool = false

### Shown instead of the partner type's colour while the visuals are hidden (alpha is kept).
const BLINDED_BACKGROUND_GRAY: float = 0.5

### Remembers what the player can't see right now. Kept apart from applying it, because the name, type
### and picture are also set by other functions (and by translation changes) in between.
func _read_player_blindness(game_state: GameState) -> void:
	_player_cant_see_pleasure = game_state.is_opponent_info_hidden(Status_BlindPlayer.HiddenInfo.PLEASURE)
	_player_cant_see_type = game_state.is_opponent_info_hidden(Status_BlindPlayer.HiddenInfo.OPPONENT_TYPE)
	_player_cant_see_visuals = game_state.is_opponent_info_hidden(Status_BlindPlayer.HiddenInfo.OPPONENT_VISUALS)
	_player_cant_see_name = game_state.is_opponent_info_hidden(Status_BlindPlayer.HiddenInfo.OPPONENT_NAME)
	_player_cant_see_upcoming_action = game_state.is_opponent_info_hidden(Status_BlindPlayer.HiddenInfo.UPCOMING_ACTION)
	_player_cant_see_passives = game_state.is_opponent_info_hidden(Status_BlindPlayer.HiddenInfo.PASSIVES)

### Re-reads and applies what the player can't see, without touching anything else on the card. Called
### directly (OpponentsContainer.refresh_player_blindness) so blinding/unblinding does not depend on the
### full update_opponent_display() chain, which can be skipped while cards are moving (see
### MainCardgame.refresh_player_blindness_displays()).
func refresh_player_blindness(game_state: GameState) -> void:
	if not displayed_opponent_type or not displayed_opponent_instance:
		return
	var passives_were_hidden: bool = _player_cant_see_passives
	_read_player_blindness(game_state)
	if _player_cant_see_passives != passives_were_hidden:
		_handle_passive_effects(displayed_opponent_type)
	_apply_player_blindness_to_displays()

func _apply_player_blindness_to_displays() -> void:
	_display_opponent_name()
	if displayed_opponent_type:
		_display_opponent_type_name(displayed_opponent_type)
		_change_background_color(displayed_opponent_type)
	if simple_pleasure_bar:
		simple_pleasure_bar.set_pleasure_hidden(_player_cant_see_pleasure)
	_set_opponent_visuals_hidden(_player_cant_see_visuals)
	_show_upcoming_action()

### The colour the card's background should have: the partner type's own, or neutral gray while the
### visuals are hidden (the colour would give the type away).
func _get_displayed_background_color(given_opponent_type: OpponentType) -> Color:
	var type_color: Color = given_opponent_type.get_opponent_color()
	if _player_cant_see_visuals:
		return Color(BLINDED_BACKGROUND_GRAY, BLINDED_BACKGROUND_GRAY, BLINDED_BACKGROUND_GRAY, type_color.a)
	return type_color

### The picture is made see-through instead of hidden, so the card layout stays the same. Subclasses
### with other visuals (the rework card's figure) extend this.
func _set_opponent_visuals_hidden(hidden: bool) -> void:
	if not opponent_picture:
		return
	opponent_picture.self_modulate.a = 0.0 if hidden else 1.0
#endregion

func _set_opponent_picture_from_type(given_opponent_type: OpponentType) -> void:
	if not opponent_picture:
		#push_warning("Opponent picture node is not set!")
		return
	var picture: Texture2D
	picture = ImageOverrideManager.get_override_texture(ImageOverrideManager.ReplacementType.OPPONENT_TYPE_IMAGE,given_opponent_type.opponent_type_id,get_selected_character_id())
	if not picture:
		picture = given_opponent_type.picture
	opponent_picture.texture = picture

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


func _display_active_player_action(action: PlayerAction) -> void:
	if not active_player_action_pic:
		#push_warning("active_player_action_pic is not set for opponent card")
		return
	if not idle_picture:
		#push_warning("idle_picture not set for opponent card")
		return
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
	if not video_panel_container:
		#push_warning("video_panel_container not set for opponent card")
		return
	AnimationHelper_NodeFlasher._pop_node(video_panel_container,POP_SIGNIFICANCE,POP_SCALE,POP_DURATION)

func _show_matching_video(action: PlayerAction) -> void:
	if not player_action_video:
		#push_warning("player_action_video not set for opponent card")
		return
	if not main_game.settings_manager.get_videos_on_opponents_setting():
		_hide_and_stop_video()
		_expand_static_action_image(action)
		return
	if action == null:
		_hide_and_stop_video()
		return
	if action.video_action_tags.is_empty():
		_hide_and_stop_video()
		return
	var participant_type_tags: Array[VideoClip.ParticipantTags] = displayed_opponent_type.video_particpant_tags.duplicate(true)
	participant_type_tags.append_array(get_save_game_state().get_player_video_participant_tags())
	var clip: VideoClip = VideoPlayerSystem.get_video_by_tags(action.video_action_tags, participant_type_tags)
	if not clip:
		_hide_and_stop_video()
		return
	self.player_action_video.visible = true
	self.player_action_video.set_video_path(clip.video_file) ### auto-plays: enable_auto_play=true in the scene
	VideoPlayerSystem.register_clip_as_seen(clip)
	CombatProfiler.note_video_started(opponent_id)
	CombatProfiler.log_event("VIDEO", "opponent %s started video for action %s" % [opponent_id, action.action_id])
	_shrink_static_action_image()

func _expand_static_action_image(action: PlayerAction) -> void:
	if not active_player_action_pic:
		#push_warning("active_player_action_pic is not set for opponent card")
		return
	if not video_and_idle_pic:
		#push_warning("video_and_idle_pic not set for opponent card")
		return
	video_and_idle_pic.visible = false
	var action_pic_panel: Control = active_player_action_pic.get_parent()
	action_pic_panel.visible = (action != null)
	action_pic_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_pic_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_player_action_pic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_player_action_pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_player_action_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _shrink_static_action_image() -> void:
	if not active_player_action_pic:
		#push_warning("active_player_action_pic is not set for opponent card")
		return
	if not video_and_idle_pic:
		#push_warning("video_and_idle_pic not set for opponent card")
		return
	video_and_idle_pic.visible = true
	var action_pic_panel: Control = active_player_action_pic.get_parent()
	action_pic_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_pic_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	active_player_action_pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	active_player_action_pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER


#endregion

#region Check for opponents action:
func _handle_upcoming_opponent_action(game_state:GameState,_opponent_id:String) -> void:
	var opponent_instance: OpponentInstance = game_state.get_opponent_instance(_opponent_id)
	var upcoming_action: OpponentActionDefinition = opponent_instance.upcoming_action
	if upcoming_action == null:
		return
	update_displayed_action(upcoming_action)

func update_displayed_action(upcoming_action: OpponentActionDefinition) -> void:
	_real_upcoming_action = upcoming_action
	_show_upcoming_action()

### The Move the partner will really do next, kept so the display can switch between it and the "?"
### Move when the player is blinded/unblinded without the game announcing the Move again.
var _real_upcoming_action: OpponentActionDefinition

func _show_upcoming_action() -> void:
	if not _real_upcoming_action:
		return
	var shown_action: OpponentActionDefinition = _real_upcoming_action
	if _player_cant_see_upcoming_action:
		shown_action = UnknownOpponentAction.get_shared()
	action_mini_display.display_action(shown_action)
	#print("Updating displayed action")
	_update_upcoming_damage_label()

### Live: the Pleasure the shown Move gives with every status and passive that changes it (PleasurePreview), polled every frame
### like the Action cards' numbers and colored when the modifiers change it. Which Move is shown still only changes when the game
### announces it (update_displayed_action()). The plain number when there is nothing to preview (no encounter, a tooltip card, a
### Partner the game state no longer has while its card is still shown).
func _update_upcoming_damage_label() -> void:
	if not _real_upcoming_action:
		return
	if _player_cant_see_upcoming_action:
		_set_upcoming_damage_label_text(0)
		return
	var preview: PleasurePreview = PleasurePreview.for_main_game(main_game)
	if not preview.can_preview() or not main_game.game_state.get_opponent_instance(opponent_id):
		_set_upcoming_damage_label_text(EffectAndTargetIntent.sum_displayed_damage(_real_upcoming_action.effect_intents))
		return
	var hits: Array[PleasurePreviewHit] = PleasurePreview.get_displayed_hits(
		preview.preview_opponent_move(opponent_id, _real_upcoming_action, false), true)
	_set_upcoming_damage_label_text(PleasurePreview.sum_amounts(hits), PleasurePreview.get_live_number_color(hits))

### The upcoming Move while the player hovers it (this card tracks its hovered child itself, see _process()), null otherwise and
### while the player can't see it (blinded).
func get_hovered_upcoming_move() -> OpponentActionDefinition:
	if _player_cant_see_upcoming_action:
		return null
	if _currently_hovered_child is not OpponentActionMiniDisplay:
		return null
	return _real_upcoming_action

### "+X" and a shaded region on this Partner's bar: what the Actions on the Partners and whatever is under the mouse will give them
### (PleasureBarPreviews).
func _update_pleasure_preview() -> void:
	if not is_instance_valid(simple_pleasure_bar):
		return
	var change: int = PleasureBarPreviews.get_change_for_opponent(main_game, opponent_id)
	simple_pleasure_bar.set_pleasure_preview(change, PleasureBarPreviews.get_color_for_change(change, false))

func _set_upcoming_damage_label_text(action_damage: int, color: Color = Color.WHITE) -> void:
	#print("Setting damage label to: %s"%action_damage)
	if action_damage == 0:
		opponent_damage_label.visible = false
	else:
		opponent_damage_label.visible = true
		var damage_text: String = str(action_damage)
		if opponent_damage_label.text != damage_text: ### A RichTextLabel re-parses its text on every assignment.
			opponent_damage_label.text = damage_text
		opponent_damage_label.modulate = color

func update_displayed_values_when_taking_damage(current_pleasure: int) -> void: #Called by animation handler for damage
	simple_pleasure_bar.set_current_pleasure(current_pleasure)

func drain_pleasure_bar(duration: float) -> void: #Called by the orgasm animation handler, mirrors PlayerCombatStatDisplay
	await simple_pleasure_bar.animate_pleasure_bar_to_value(0,duration)

func animate_pleasure_bar_to_value(pleasure_after_orgasm: int,duration: float) -> void: #Mirrors PlayerCombatStatDisplay
	await simple_pleasure_bar.animate_pleasure_bar_to_value(pleasure_after_orgasm,duration)

func get_orgasm_counter() -> Control: #Called by animation handler, mirrors PlayerCombatStatDisplay
	return orgasm_icon

func refresh_orgasm_display() -> void: #Called on display/update and by the orgasm animation handler
	if not displayed_opponent_instance:
		return
	var multi_orgasm: bool = displayed_opponent_instance.opponent_type.orgasms_before_defeat > 1
	orgasm_panel.visible = multi_orgasm
	if not multi_orgasm:
		return
	orgasm_remaining_label.text = str(displayed_opponent_instance.get_remaining_orgasms())
	orgasms_so_far_label.text = tr(ORGASMS_SO_FAR_KEY) % displayed_opponent_instance.orgasms_experienced

#endregion

#region Check for status effects
func _handle_passive_effects(given_opponent_type: OpponentType) -> void:
	var timer_id: String = "passive_rebuild_%s" % opponent_id
	CombatProfiler.begin_timer(timer_id)
	var freed_count: int = 0
	for child in container_for_status_displays.get_children():
		if child is PassiveEffectMiniDisplay:
			child.queue_free()
			freed_count += 1
	var passives_to_display: Array[PassiveEffectDefinition] = []
	if _player_cant_see_passives:
		### The whole list collapses to one "?" Passive, so the player can't tell how many (or if any) there are.
		passives_to_display.append(UnknownPassiveEffect.get_shared())
	else:
		for passive_id in given_opponent_type.passive_effects:
			passives_to_display.append(AutoloadDatabase.passive_effect_definitions[passive_id])
	for passive in passives_to_display:
		var new_mini_display: PassiveEffectMiniDisplay = passive_effect_mini_display.instantiate()
		new_mini_display.display_passive(passive)
		container_for_status_displays.add_child(new_mini_display)
	CombatProfiler.end_timer(timer_id, "UI_REBUILD",
		"freed=%d instantiated=%d" % [freed_count, passives_to_display.size()])

### Diffs against game_state instead of wiping and rebuilding every status display, so this
### doesn't fight with animation_status_effect_applied_to_target.gd/refresh_status_on_target.gd,
### which add/update a status's display directly the moment its animation plays (well before
### this runs - game_state_changed only fires once that action's whole animation queue has
### drained). Update-in-place if already displayed (regardless of whether the animation path or
### this same function added it), add only if genuinely missing (a safety net for anything that
### doesn't go through the normal animated-apply path), remove only what's no longer in
### game_state (this is also the only place status removal ever happens - there's no dedicated
### removal animation).
func _handle_active_status_effects(game_state: GameState, _opponent_id: String) -> void:
	var timer_id: String = "status_rebuild_%s" % opponent_id
	CombatProfiler.begin_timer(timer_id)
	var active_statuses: Dictionary = game_state.get_opponent_instance(_opponent_id).status_effects
	var freed_count: int = 0
	var added_count: int = 0
	for child in container_for_status_displays.get_children():
		if child is StatusEffectMiniDisplay:
			if not child.represented_status_effect or not active_statuses.has(child.represented_status_effect.status_id):
				child.queue_free()
				freed_count += 1
	for status_id in active_statuses.keys():
		var existing_display: StatusEffectMiniDisplay = get_display_for_status(status_id)
		if existing_display:
			existing_display.set_displayed_duration(active_statuses[status_id]["duration"])
			existing_display.set_displayed_stacks(active_statuses[status_id]["stacks"])
			continue
		add_new_status_display(status_id) # Child added inside "add_new_status_display"
		added_count += 1
	CombatProfiler.end_timer(timer_id, "UI_REBUILD",
		"freed=%d instantiated=%d" % [freed_count, added_count])

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
	### So its energy cost and Pleasure follow the Partner under the cursor, like a card dragged from the hand.
	(preview_card as ActionCard)._is_drag_preview_clone = true
	preview_card.visible = true
	preview_card.modulate = Color.WHITE
	preview_card.scale = action_card.scale
	preview_card.size = action_card.size

	_drag_offset = -_at_position
	preview_card.position = -_at_position-_drag_offset

	preview_root.add_child(preview_card)
	_prepare_drag_preview(preview_root)
	set_drag_preview(preview_root)
	### Signal to container:
	emit_signal("action_began_dragging",self.active_player_action_id,self)

	return action_card

### Hook for subclasses to adjust the drag preview before it is handed to set_drag_preview().
func _prepare_drag_preview(_preview_root: Control) -> void:
	pass


func _opponent_has_action() -> bool:
	return main_game.game_state.get_action_assigned_to_opponent(opponent_id) != ""
#endregion

func _clear_video_if_no_action_is_active(game_state: GameState) -> void:
	if not player_action_video:
		#push_warning("player_action_video not set for opponent card")
		return
	if ActionManager.get_action_assigned_to_opponent(game_state,self.opponent_id) == "":
		_hide_and_stop_video()
	else:
		player_action_video.visible = true

## Hides the video AND actually stops decoding it. VideoPlayback's _process() only keeps
## decoding while is_playing is true, so pause() genuinely halts the work (unlike Godot's
## built-in VideoStreamPlayer, which kept decoding in the background regardless of
## visibility - see git history for that bug and the CombatProfiler work that caught it).
func _hide_and_stop_video() -> void:
	if not player_action_video:
		#push_warning("player_action_video not set for opponent card")
		return
	if player_action_video.is_playing:
		CombatProfiler.note_video_still_playing_while_hidden(opponent_id)
	player_action_video.visible = false
	player_action_video.pause()
	CombatProfiler.note_video_stopped(opponent_id)

func get_action_card_movement_location() -> Vector2: # global position
	if not player_action_video:
		#push_warning("player_action_video not set for opponent card")
		return self.global_position ### This needs to be changed once we have the reworked card finished
	return player_action_video.global_position

func get_action_source_node() -> Control: # node that player action effects (damage, healing) animate from
	return player_action_video

func get_action_source_position() -> Vector2: # global position
	return global_position + 0.5*size

func get_pleasure_bar_location() -> Vector2:
	return current_damage_container.global_position+current_damage_container.size*0.5

func hide_player_action_video() -> void:
	if not player_action_video:
		return
	player_action_video.visible = false
func clear_active_player_action_id() -> void:
	if not active_player_action_id:
		return
	active_player_action_id = ""



#region Dragging stop:
func disable_dragging() -> void:
	dragging_allowed = false
func enable_dragging() -> void:
	dragging_allowed = true
