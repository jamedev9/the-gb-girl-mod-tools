extends Control
class_name PopupController

@onready var main_game: Node = get_tree().get_current_scene()

#region Popup nodes:

@export var tooltip_discard_pile: PackedScene = load("res://scenes/main_cardgame/event_cards/tooltip_discard_pile.tscn")
@export var tooltip_draw_pile: PackedScene = load("res://scenes/main_cardgame/event_cards/tooltip_draw_pile.tscn")
@export var tooltip_status_effect: PackedScene = load("res://scenes/main_cardgame/status_effects/tooltip_status_effect.tscn")
@export var tooltip_opponent_action: PackedScene = load("res://scenes/main_cardgame/popup_menus/tooltip_opponent_action.tscn")
@export var tooltip_active_player_action: PackedScene = load("res://scenes/main_cardgame/player_actions/action_card.tscn")
@export var tooltip_pleasure_dealt_icon: PackedScene = load("res://scenes/main_cardgame/reusable_components/tooltip_pleasure_dealt_icon.tscn")
@export var tooltip_current_pleasure_icon: PackedScene = load("res://scenes/main_cardgame/reusable_components/tooltip_current_pleasure_icon.tscn")
@export var tooltip_energy_icon: PackedScene = load("res://scenes/main_cardgame/reusable_components/tooltip_energy_icon.tscn")
@export var tooltip_passive_effect: PackedScene = load("res://scenes/main_cardgame/passive_effect_mini_display/tooltip_passive_effect.tscn")
@export var tooltip_event_card: PackedScene = load("res://scenes/main_cardgame/reusable_components/tooltip_event_card.tscn")
@export var tooltip_opponent_type: PackedScene = load("res://scenes/meta_game/components/opponent_type_display/opponent_type_display.tscn")
@export var tooltip_encounter_lock_explanation: PackedScene = load("res://scenes/meta_game/encounter_description_display/tooltip_explain_why_encounter_is_locked.tscn")
@export var tooltip_generic: PackedScene = load("res://scenes/main_cardgame/reusable_components/generic_tooltip.tscn")
const REWORK_TOOLTIP_PLAYER_ACTION_SCENE_PATH: String = "res://publishable_rework/cardgame_ui/action_cards/tooltip_player_action.tscn"
### The tooltip of a term (keyword, status, action, card, ...) in description-system text - see the layered
### tooltips region below.
@export var tooltip_description_term: PackedScene = load("res://scenes/main_cardgame/popup_menus/tooltip_description_term.tscn")


#endregion
const SLOW_FADE_IN_DELAY: float = 0.33
const MAP_TOOLTIP_FACE_DELAY: float = 0.75
### so it stays out of the way of grabbing and dragging the card. A tooltip that isn't there yet can't block anything.
const PLAYER_ACTION_TOOLTIP_DELAY: float = SLOW_FADE_IN_DELAY + 1.5

@export var fade_duration: float = 0.15

#region Layered tooltips
### Tooltips are kept as a stack of layers. Layer 0 is the tooltip a source (a card, an icon, ...) asked for with
### tooltip_requested, or the tooltip of a term in some label's text. A tooltip that contains description-system
### text (DescriptionLabel) is "interactive": it receives the mouse, and every term in its text is a link that
### opens the next layer on top of it - that tooltip's own terms are links again, and so on. A tooltip with no
### links behaves exactly as it always did: it is closed the moment its source says tooltip_cleared.
###
### An interactive layer stays open while the pointer is on it, on a deeper layer, or on the link that opened it,
### or while it is pinned (opened by a click/tap - touch screens have no hover). When none of that holds for a
### layer, it and everything above it close after ORPHAN_GRACE_SECONDS (so the pointer can cross the gap from a
### link to the tooltip it opened). A press that is not on a link closes the layers above the one it landed on, or
### all of them when it landed outside - that is how a pinned stack is dismissed on a touch screen.
const MAX_TOOLTIP_LAYERS: int = 4
const ORPHAN_GRACE_SECONDS: float = 0.2
const CHILD_FADE_IN_DELAY: float = 0.12
### A tooltip opened by a link starts this far from the pointer, so the link (or the card that spawned it) is
### still under the pointer and the next link stays reachable.
const LINK_TOOLTIP_POINTER_OFFSET: Vector2 = Vector2(14.0, 22.0)
const CHILD_TOOLTIP_GAP: float = 8.0
const CHILD_TOOLTIP_POINTER_Y_OFFSET: float = 16.0

class TooltipLayer extends RefCounted:
	var node: Control
	var interactive: bool = false
	### Set for the tooltip of a term: the term, and the label whose link opened it.
	var term: DescriptionSegment
	var opener_host: DescriptionLabel
	### A layer opened by a source control (not by a link): that source has said tooltip_cleared.
	var source_released: bool = false
	var pinned: bool = false

### Index 0 is the bottom layer.
var _layers: Array[TooltipLayer] = []
### The link the pointer is on right now, if any (set by the DescriptionLabel the link is in).
var _hovered_host: DescriptionLabel
var _hovered_term: DescriptionSegment
var _orphan_time: float = 0.0
#endregion

### The source of the delayed tooltip request that is still waiting (see PLAYER_ACTION_TOOLTIP_DELAY and
### Cardgame_UI_Element.get_tooltip_delay()), and a counter that every new request and every clear of that source bumps,
### so a waiting request can tell it is out of date.
var _waiting_request_source: Control
var _waiting_request_id: int = 0

func _handle_tooltip_request(tooltip_id: Cardgame_UI_Element.TooltipId,control_node: Control) -> void:
	if not is_instance_valid(control_node):
		return
	_waiting_request_id += 1
	var fade_in_delay: float = SLOW_FADE_IN_DELAY
	var wait_before_creating: float = 0.0
	if tooltip_id == Cardgame_UI_Element.TooltipId.PLAYER_ACTION_DESCRIPTION:
		wait_before_creating = PLAYER_ACTION_TOOLTIP_DELAY
		fade_in_delay = 0.0 ### The waiting already is the delay.
	else:
		var source_element: Cardgame_UI_Element = control_node as Cardgame_UI_Element
		if source_element:
			wait_before_creating = source_element.get_tooltip_delay()
	if wait_before_creating > 0.0:
		var request_id: int = _waiting_request_id
		_waiting_request_source = control_node
		await get_tree().create_timer(wait_before_creating).timeout
		if request_id != _waiting_request_id or not is_instance_valid(control_node):
			return ### The pointer left the source, or a card was picked up, before the delay was over.
		_waiting_request_source = null
	_close_layers_from(0)

	var new_tooltip_node: Control

	match tooltip_id:
		Cardgame_UI_Element.TooltipId.DISCARD_PILE:
			new_tooltip_node = tooltip_discard_pile.instantiate()
		Cardgame_UI_Element.TooltipId.DRAW_PILE:
			new_tooltip_node = tooltip_draw_pile.instantiate()
		Cardgame_UI_Element.TooltipId.STATUS_EFFECT:
			new_tooltip_node = tooltip_status_effect.instantiate()
		Cardgame_UI_Element.TooltipId.OPPONENT_ACTION:
			new_tooltip_node = tooltip_opponent_action.instantiate()
		Cardgame_UI_Element.TooltipId.ACTIVE_PLAYER_ACTION:
			new_tooltip_node = tooltip_active_player_action.instantiate()
		Cardgame_UI_Element.TooltipId.PLEASURE_DEALT_ICON:
			new_tooltip_node = tooltip_pleasure_dealt_icon.instantiate()
		Cardgame_UI_Element.TooltipId.CURRENT_PLEASURE_ICON:
			new_tooltip_node = tooltip_current_pleasure_icon.instantiate()
		Cardgame_UI_Element.TooltipId.ENERGY_ICON:
			new_tooltip_node = tooltip_energy_icon.instantiate()
		Cardgame_UI_Element.TooltipId.PASSIVE_EFFECT:
			new_tooltip_node = tooltip_passive_effect.instantiate()
		Cardgame_UI_Element.TooltipId.EVENT_CARD_PERMANENT:
			new_tooltip_node = tooltip_event_card.instantiate()
		Cardgame_UI_Element.TooltipId.EVENT_CARD_REWARD:
			new_tooltip_node = tooltip_event_card.instantiate()
		Cardgame_UI_Element.TooltipId.OPPONENT_TYPE:
			new_tooltip_node = tooltip_opponent_type.instantiate()
			new_tooltip_node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		Cardgame_UI_Element.TooltipId.ENCOUNTER_STATUS_EXPLANATION:
			new_tooltip_node = tooltip_encounter_lock_explanation.instantiate()
			fade_in_delay = MAP_TOOLTIP_FACE_DELAY
		Cardgame_UI_Element.TooltipId.GENERIC_TOOLTIP:
			new_tooltip_node = tooltip_generic.instantiate()
			new_tooltip_node.display_tooltip(control_node.tooltip_info)
		Cardgame_UI_Element.TooltipId.PLAYER_ACTION_DESCRIPTION:
			var tooltip_player_action_scene: PackedScene = load(REWORK_TOOLTIP_PLAYER_ACTION_SCENE_PATH)
			new_tooltip_node = tooltip_player_action_scene.instantiate()

	var new_layer: TooltipLayer = TooltipLayer.new()
	new_layer.node = new_tooltip_node
	_layers.append(new_layer)
	self.add_child(new_tooltip_node)
	new_tooltip_node.update_tooltip_information(main_game.game_state, tooltip_id, control_node)
	_make_layer_interactive_if_it_has_links(new_layer)
	_fade_in(new_tooltip_node, fade_in_delay)
	### A tooltip you can move the pointer onto must not open under the pointer, or it would take the
	### pointer away from the card/icon that asked for it.
	_move_tooltip_to_mouse_location(
		new_tooltip_node, LINK_TOOLTIP_POINTER_OFFSET if new_layer.interactive else Vector2.ZERO)


func _handle_clear_tooltip_request(control_node: Control) -> void:
	if not is_instance_valid(control_node):
		return
	if control_node == _waiting_request_source:
		_waiting_request_id += 1 ### Cancels the tooltip that was still waiting to appear.
		_waiting_request_source = null
	clear_tooltip(control_node)

### A source says its tooltip is no longer wanted (the pointer left it). A plain tooltip fades right away. One with
### links stays until the pointer has had ORPHAN_GRACE_SECONDS to reach it (see _process()).
func clear_tooltip(_source: Control) -> void:
	if _layers.is_empty():
		return
	var bottom_layer: TooltipLayer = _layers[0]
	if bottom_layer.opener_host:
		return ### Opened by a link, which has its own hover tracking.
	if bottom_layer.interactive:
		bottom_layer.source_released = true
	else:
		_close_layers_from(0)

#region Layered tooltips
### The three calls a DescriptionLabel makes about the links in its text.
func link_hover_started(host: DescriptionLabel, term: DescriptionSegment) -> void:
	_hovered_host = host
	_hovered_term = term
	_open_term_tooltip(host, term, false)

func link_hover_ended(host: DescriptionLabel) -> void:
	if _hovered_host == host:
		_hovered_host = null
		_hovered_term = null

### A click or tap. Pins the tooltip: it then stays until a press lands somewhere that is not a link.
func link_clicked(host: DescriptionLabel, term: DescriptionSegment) -> void:
	_hovered_host = host
	_hovered_term = term
	_open_term_tooltip(host, term, true)

### The label is leaving the tree (e.g. a log entry fading out): whatever it opened goes with it.
func link_host_removed(host: DescriptionLabel) -> void:
	if _hovered_host == host:
		_hovered_host = null
		_hovered_term = null
	for index in _layers.size():
		if _layers[index].opener_host == host:
			_close_layers_from(index)
			return

func _open_term_tooltip(host: DescriptionLabel, term: DescriptionSegment, pin: bool) -> void:
	var parent_index: int = _find_layer_index_containing(host) ### -1 if the label is not inside a tooltip
	var new_index: int = parent_index + 1
	if new_index < _layers.size():
		var existing_layer: TooltipLayer = _layers[new_index]
		if existing_layer.opener_host == host and existing_layer.term and _is_same_term(existing_layer.term, term):
			existing_layer.pinned = existing_layer.pinned or pin
			return ### Already showing this very link.
	_close_layers_from(new_index)
	if new_index >= MAX_TOOLTIP_LAYERS:
		return
	for lower_layer in _layers:
		if lower_layer.term and _is_same_term(lower_layer.term, term):
			return ### The same term is already open further down (a description that mentions itself).
	var term_tooltip: Control = _make_term_tooltip(term)
	var new_layer: TooltipLayer = TooltipLayer.new()
	new_layer.node = term_tooltip
	new_layer.term = term
	new_layer.opener_host = host
	new_layer.pinned = pin
	_layers.append(new_layer)
	add_child(term_tooltip)
	_fill_term_tooltip(term_tooltip, term)
	_make_layer_interactive_if_it_has_links(new_layer)
	if new_index == 0:
		_fade_in(term_tooltip, SLOW_FADE_IN_DELAY)
		_move_tooltip_to_mouse_location(term_tooltip, LINK_TOOLTIP_POINTER_OFFSET)
	else:
		_fade_in(term_tooltip, CHILD_FADE_IN_DELAY)
		_move_tooltip_next_to(term_tooltip, _layers[parent_index].node)

### An event card term (DescriptionSegment.card_id) shows the card itself, like the deck's card tooltips; every other term
### shows the text tooltip.
func _make_term_tooltip(term: DescriptionSegment) -> Control:
	if term.card_id.is_empty():
		return tooltip_description_term.instantiate()
	return tooltip_event_card.instantiate()

func _fill_term_tooltip(tooltip_node: Control, term: DescriptionSegment) -> void:
	var event_card_tooltip: Tooltip_EventCard = tooltip_node as Tooltip_EventCard
	if event_card_tooltip:
		event_card_tooltip.show_card(term.card_id, term.card_permanence)
		return
	(tooltip_node as Tooltip_DescriptionTerm).show_term(term)

### Lets a tooltip that has links in it receive the mouse (the tooltips' scenes switch it off), so its links can be
### hovered and the pointer can stay on it.
func _make_layer_interactive_if_it_has_links(layer: TooltipLayer) -> void:
	var tooltip: TooltipUI = layer.node as TooltipUI
	layer.interactive = tooltip != null and tooltip.is_interactive()
	if layer.interactive:
		layer.node.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
		layer.node.mouse_filter = Control.MOUSE_FILTER_STOP

### Closes the layer at `index` and every layer above it.
func _close_layers_from(index: int) -> void:
	for layer_index in range(_layers.size() - 1, index - 1, -1):
		_fade_out(_layers[layer_index].node)
		_layers.remove_at(layer_index)
	_orphan_time = 0.0

func _process(delta: float) -> void:
	if _layers.is_empty():
		_orphan_time = 0.0
		return
	var held_depth: int = _get_held_depth()
	if held_depth >= _layers.size() - 1:
		_orphan_time = 0.0
		return
	_orphan_time += delta
	if _orphan_time >= ORPHAN_GRACE_SECONDS:
		_close_layers_from(held_depth + 1)

### A press that is not on a link: closes the layers above the one it landed on, or all of them when it landed
### outside the tooltips. (On a link, meta_clicked decides what to open.) Only for stacks with interactive layers;
### a plain tooltip is never closed by a press.
func _input(event: InputEvent) -> void:
	if _layers.is_empty() or not _layers[0].interactive:
		return
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_button or not mouse_button.pressed or _hovered_term:
		return
	var deepest_layer_under_pointer: int = -1
	for index in _layers.size():
		if _pointer_is_over(_layers[index].node):
			deepest_layer_under_pointer = index
	_close_layers_from(deepest_layer_under_pointer + 1)

### The highest layer that is being held open; every layer below it is held with it. -1 if none is.
func _get_held_depth() -> int:
	for index in range(_layers.size() - 1, -1, -1):
		if _is_layer_held(_layers[index]):
			return index
	return -1

func _is_layer_held(layer: TooltipLayer) -> bool:
	if layer.pinned or _pointer_is_over(layer.node):
		return true
	if layer.opener_host:
		return _hovered_host == layer.opener_host and _hovered_term != null and _is_same_term(_hovered_term, layer.term)
	### Opened by a source control: held until the source says tooltip_cleared. A plain tooltip is only ever
	### closed by that, never by the pointer position.
	return not layer.source_released or not layer.interactive

func _pointer_is_over(node: Control) -> bool:
	if not is_instance_valid(node):
		return false
	var hovered: Control = get_viewport().gui_get_hovered_control()
	return hovered != null and (hovered == node or node.is_ancestor_of(hovered))

func _find_layer_index_containing(node: Node) -> int:
	for index in _layers.size():
		var layer_node: Control = _layers[index].node
		if layer_node == node or layer_node.is_ancestor_of(node):
			return index
	return -1

func _is_same_term(first: DescriptionSegment, second: DescriptionSegment) -> bool:
	return first.type == second.type and first.keyword_id == second.keyword_id and first.text == second.text \
		and first.card_id == second.card_id and first.card_permanence == second.card_permanence

### A tooltip opened from inside another one goes beside it (to the right, or to the left when there is no room),
### level with the pointer, so the text it was opened from stays readable.
func _move_tooltip_next_to(node: Control, parent_node: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(node) or not is_instance_valid(parent_node):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var parent_rect: Rect2 = parent_node.get_global_rect()
	var x: float = parent_rect.end.x + CHILD_TOOLTIP_GAP
	if x + node.size.x > viewport_size.x:
		x = parent_rect.position.x - node.size.x - CHILD_TOOLTIP_GAP
	x = clampf(x, 0.0, maxf(0.0, viewport_size.x - node.size.x))
	var y: float = clampf(
		get_global_mouse_position().y - CHILD_TOOLTIP_POINTER_Y_OFFSET, 0.0, maxf(0.0, viewport_size.y - node.size.y))
	node.set_global_position(Vector2(x, y))
#endregion

func _fade_in(node: Control,delay: float = 0.0,duration: float = fade_duration) -> void:
	node.visible = true
	node.modulate.a = 0.0
	var active_tween: Tween = null
	active_tween = create_tween()
	active_tween.tween_property(
		node,
		"modulate:a",
		1.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(delay)

### FOR POSTERITY:
### NEVER use lambda calls for tweens. This is HPRRENDOUS to debug.
### The error message does not reference where the error arrises from.
### The commented version below causes persistent lambda errors, the one below that works fine.
#func _fade_out(node: Control,delay: float = 0.0,duration: float = fade_duration) -> void:
	#push_error("Fade out:")
	#var active_tween: Tween = null
	#active_tween = create_tween()
	#active_tween.tween_property(
		#node,
		#"modulate:a",
		#0.0,
		#duration
	#).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(delay)
#
	#active_tween.finished.connect(func ():
		#if not is_instance_valid(node):
			#return
		#node.queue_free()
	#)

func _fade_out(node: Control, delay: float = 0.0, duration: float = fade_duration) -> void:
	### A fading tooltip must not keep catching the pointer (an interactive one receives the mouse).
	node.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	var active_tween: Tween = create_tween()
	active_tween.tween_property(
		node,
		"modulate:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(delay)
	_free_node_after_delay(node, delay + duration)

func _free_node_after_delay(node: Control, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()

func _update_status_effect_tooltip(status_effect_node: StatusEffectMiniDisplay) -> void:
	tooltip_status_effect._update_displayed_status_information(status_effect_node.represented_status_effect)
	

func _move_tooltip_to_mouse_location(node: Control, offset_from_pointer: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(node):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(node):
		return
	var mouse_pos: Vector2 = get_global_mouse_position() + offset_from_pointer
	var viewport_size: Vector2 = get_viewport_rect().size
	var node_size: Vector2 = node.size
	#print("mouse_pos: ", mouse_pos, " viewport_size: ", viewport_size, " node_size: ", node_size)
	#print("node anchors: L%s R%s T%s B%s" % [node.anchor_left, node.anchor_right, node.anchor_top, node.anchor_bottom])
	var clamped_x: float = clamp(mouse_pos.x, 0.0, viewport_size.x - node_size.x)
	var clamped_y: float = clamp(mouse_pos.y, 0.0, viewport_size.y - node_size.y)
	#print("clamped_pos: ", Vector2(clamped_x, clamped_y))
	node.set_global_position(Vector2(clamped_x, clamped_y))
	#await get_tree().process_frame
	#print("actual global_position after set: ", node.global_position, " actual size after set: ", node.size)
