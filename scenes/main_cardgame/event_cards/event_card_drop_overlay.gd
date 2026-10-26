extends Control
class_name EventCardDropOverlay

### Full-screen drop target that exists only while a NON-targeted Event Card is being dragged, so
### such a card can be dropped anywhere on screen without every UI node having to accept drops.
### It lives in a high CanvasLayer (see MainCardgame._setup_event_card_drop_overlay), above every
### other control, so nothing can block the drop. Targeted cards (drag arrow) never activate it.
### Dropping over cancel_area (the card hand) is refused, so the card just returns to the hand.

signal event_card_dropped(event_card_instance: EventCardInstance, opponent_id: String)

### Set on a dragged card released over the cancel area, so the hand returns it without the red
### "failed to resolve" flash. The hand removes it again (see FloatingPlayerHand).
const CANCELLED_META: String = "drop_cancelled"

var cancel_area: Control

var _dragged_event_card: EventCard = null

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_on_drag_begin()
	elif what == NOTIFICATION_DRAG_END:
		_on_drag_end()

func _on_drag_begin() -> void:
	var drag_data: Variant = get_viewport().gui_get_drag_data()
	if not _is_non_targeted_event_card(drag_data):
		return
	_dragged_event_card = drag_data
	mouse_filter = Control.MOUSE_FILTER_STOP

func _on_drag_end() -> void:
	if is_instance_valid(_dragged_event_card) and _is_mouse_over_cancel_area():
		_dragged_event_card.set_meta(CANCELLED_META, true)
	_dragged_event_card = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _is_non_targeted_event_card(data):
		return false
	return not _is_mouse_over_cancel_area()

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _is_non_targeted_event_card(data):
		return
	event_card_dropped.emit(data.event_card_instance, "")

func _is_non_targeted_event_card(data: Variant) -> bool:
	if data is not EventCard:
		return false
	if not data.event_card_instance:
		return false
	return not data.event_card_instance.card_requires_targeted_opponent()

func _is_mouse_over_cancel_area() -> bool:
	if not is_instance_valid(cancel_area):
		return false
	return cancel_area.get_global_rect().has_point(cancel_area.get_global_mouse_position())
