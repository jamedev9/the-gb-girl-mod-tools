extends Cardgame_UI_Element
class_name EventCard

@export var event_card_type: Label
@export var event_card_name: Label
@export var event_card_picture: TextureRect
@export var event_card_energy_cost: Label
@export var event_card_description: Label
@export var full_container: PanelContainer
@export var action_disabled_overlay: PanelContainer
@export var shader_overlay: TextureRect
@export var duration_control: Control
@export var card_duration_value: Label

var all_actions_are_disabled: bool = false

@export var event_card_instance: EventCardInstance
@export var event_card_id: String

@export var temporary_card_style: StyleBoxFlat 
@export var reward_card_style: StyleBoxFlat
@export var problem_card_style: StyleBoxFlat
@export var orgasm_card_style: StyleBoxFlat
@export var once_per_game_card_style: StyleBoxFlat 

@export var once_per_game_shader: ShaderMaterial
@export var support_card_shader: ShaderMaterial


#var dragable: bool = true
var is_resolving: bool = false
var _original_position: Vector2

const CENTER_ALIGNMENT_THRESHOLD := 25

# Animation state: Where is the card?
enum AnimationState{
	NOT_DRAWN, DRAWING, IN_HAND, 
	DRAGGING, RESOLVING, RESOLVED,FAILED_TO_RESOLVE, DISCARDING,IN_DISCARD_PILE,
	DRAGGING_ARROW}
var animation_state: AnimationState = AnimationState.NOT_DRAWN
var invisible_states: Array[AnimationState] = [ # Animations states where the card should not be visible
	AnimationState.NOT_DRAWN,
	AnimationState.DRAGGING,
	AnimationState.IN_DISCARD_PILE
]

signal hovered(event_card: EventCard)
signal unhovered(event_card: EventCard)
signal animation_state_changed(event_card: EventCard)
signal drag_started(event_card: EventCard)

func _ready() -> void:
	super._ready()
	main_game.connect("event_card_durations_updated",Callable(self,"_update_duration_display"))

func update_class_specific_displays(game_state: GameState) -> void:
	show_if_disabled_by_status(game_state)
	update_energy_cost(game_state)
	_make_unavailable_during_opponents_turn(game_state)
	_make_unavailable_after_game_end(game_state)
	### Re-evaluates the picture override (see display_event_card) now that main_game/
	### meta_game/save_game_state are guaranteed valid - display_event_card() can run before
	### this node is added to the tree, when get_selected_character_id() can't resolve a real
	### character yet. Cheap and idempotent (card_id_already_shown skips the text work).
	if event_card_instance:
		display_event_card(event_card_instance)

func _update_duration_display() -> void:
	if not event_card_instance:
		return
	var turns_until_discard: int = event_card_instance.turns_until_discard
	duration_control.visible = turns_until_discard >= 0
	if turns_until_discard >= 0:
		card_duration_value.text = str(turns_until_discard)
		if turns_until_discard == 0:
			card_duration_value.modulate = SettingsManager.active_negative_color()
		else:
			card_duration_value.modulate = Color.WHITE

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()

func _refresh_text() -> void:
	if not event_card_instance:
		return
	var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[event_card_instance.card_id]
	event_card_name.text = event_card_def.get_card_name()
	event_card_description.text = event_card_def.get_card_description()

#func get_event_card_definition() -> EventCardDefinition

func _on_mouse_entered() -> void:
	if animation_state == AnimationState.DRAGGING:
		return
	emit_signal("hovered", self)

func _on_mouse_exited() -> void:
	if animation_state == AnimationState.DRAGGING:
		return
	emit_signal("unhovered", self)

func display_event_card(given_card_instance: EventCardInstance) -> void:
	### event_cards_by_id may still be loading in the background (see
	### AutoloadDatabase._ready()) - too many call sites across the codebase display
	### cards eagerly during initial scene setup to safely audit them all, so retry
	### here instead of crashing on a null EventCardDefinition lookup.
	if not AutoloadDatabase.is_content_loaded:
		AutoloadDatabase.run_when_content_loaded(Callable(self,"display_event_card").bind(given_card_instance))
		return
	### Skip re-shaping the name/description text (expensive for CJK locales, and Godot
	### can't share glyph-shaping across separate Label instances) when this exact card
	### is already what's displayed - callers re-invoke this on unrelated save updates.
	var card_id_already_shown: bool = self.event_card_id == given_card_instance.card_id
	self.event_card_instance = given_card_instance
	self.event_card_id =  given_card_instance.card_id
	var event_card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(given_card_instance.card_id)
	if not card_id_already_shown:
		var card_name_text: String = event_card_def.get_card_name()
		event_card_name.text = card_name_text
	var picture: Texture2D
	picture = ImageOverrideManager.get_override_texture(ImageOverrideManager.ReplacementType.EVENT_CARD_IMAGE,given_card_instance.card_id,get_selected_character_id())
	if not picture:
		picture = event_card_def.card_picture
	event_card_picture.texture = picture
	set_energy_cost_value(event_card_def.energy_cost)

	if not card_id_already_shown:
		var card_description_text: String = event_card_def.get_card_description()
		event_card_description.text = card_description_text

	match given_card_instance.permanence:
		CardInstance.CardPermanence.TEMPORARY:
			full_container.add_theme_stylebox_override("panel",temporary_card_style)
		CardInstance.CardPermanence.REWARD:
			full_container.add_theme_stylebox_override("panel",reward_card_style)
		CardInstance.CardPermanence.PROBLEM:
			full_container.add_theme_stylebox_override("panel",problem_card_style)
		CardInstance.CardPermanence.ONCE_PER_GAME:
			full_container.add_theme_stylebox_override("panel",once_per_game_card_style)
		CardInstance.CardPermanence.SUPPORT:
			full_container.add_theme_stylebox_override("panel",reward_card_style)
	
	### Unique features for Orgasm Cards - these are reward cards, but need a unique visual:
	if event_card_def is OrgasmEventCardDefinition:
		full_container.add_theme_stylebox_override("panel",orgasm_card_style)
	_set_material_for_card(given_card_instance)
	register_self_as_node_representing_event_card_instance(given_card_instance)
	_update_duration_display()
	call_deferred("update_alignment_of_textbox")

func _set_material_for_card(given_card_instance: EventCardInstance) -> void:
	match given_card_instance.permanence:
		CardInstance.CardPermanence.ONCE_PER_GAME:
			shader_overlay.visible = true
			shader_overlay.material = once_per_game_shader
		CardInstance.CardPermanence.SUPPORT:
			shader_overlay.visible = true
			shader_overlay.material = support_card_shader

func set_energy_cost_value(cost: int) -> void:
	### TODO: Make text red if higher than nornal, make green if lower than normal
	event_card_energy_cost.modulate = Color.WHITE
	event_card_energy_cost.text = str(cost)
	
	var baseline_cost: int = AutoloadDatabase.get_event_card_def_by_id(event_card_instance.card_id).energy_cost
	if cost > baseline_cost:
		event_card_energy_cost.modulate = SettingsManager.active_negative_color()
	if cost < baseline_cost:
		event_card_energy_cost.modulate = SettingsManager.active_positive_color()

func update_alignment_of_textbox() -> void:
	#print(event_card_description.get_minimum_size().x)
	if event_card_description.text.length() < CENTER_ALIGNMENT_THRESHOLD:
		event_card_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		event_card_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func register_self_as_node_representing_event_card_instance(given_card_instance: EventCardInstance) -> void:
	if not main_game:
		return
	main_game.entity_registry.register_entity(given_card_instance.entity_id,self)

func free_and_unregister() -> void:
	if not main_game:
		return
	main_game.entity_registry.unregister_entity(event_card_instance.entity_id,self)
	self.queue_free()

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

#region Testing new drag and drop:

var _drag_offset: Vector2  = Vector2(0,0)
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not main_game.game_state.player_can_input():
		return
	if animation_state == AnimationState.DRAGGING:
		return
	if event_card_instance.card_state != EventCardInstance.CardState.IN_HAND:
		return
	if all_actions_are_disabled:
		return
	if event_card_id == "none":
		print("Event card has no id")
		return null
		
	emit_signal("drag_started",self)
	_original_position = global_position
	
	if event_card_instance.card_requires_targeted_opponent():
		change_animation_state(AnimationState.DRAGGING_ARROW)
		return self ### Only dragging arrow, dont hide self.
	
	var preview_root := Control.new()
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_card := duplicate(Control.DUPLICATE_USE_INSTANTIATION)
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
	
	
#endregion
#region Disabled (visually) when event card is unable to be played.
func show_if_disabled_by_status(game_state: GameState) -> void:
	if not event_card_instance:
		return
	var event_card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(event_card_instance.card_id)
	action_disabled_overlay.visible = false
	all_actions_are_disabled = false
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if event_card_def.are_all_relevant_player_actions_disabled(game_state):
		self.mouse_filter = Control.MOUSE_FILTER_IGNORE
		self.action_disabled_overlay.visible = true
		all_actions_are_disabled = true

func update_energy_cost(game_state: GameState) -> void:
	if not event_card_instance:
		return
	var cost_of_card: int = EventCardDefinition.get_energy_cost_of_playing_card(game_state,self.event_card_instance.card_id)
	set_energy_cost_value(cost_of_card)
