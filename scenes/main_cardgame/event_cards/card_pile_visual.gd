extends Control
class_name CardPileVisual

@export var cardback_scene: PackedScene
@export var max_visible_cards: int = 12
@export var max_horizontal_offset: float = 30.0
@export var taper_exponent: float = 0.6
@export var max_vertical_offset: float = 11.0

@export var parent_node: Control
### Width of each card back. The UI sets it to match the cards in the player's hand (see CardGameUI).
@export var card_width: float = 160.0

### The card back art is 2:3, so its height follows from the width. It is not stretched to the shape
### of the event cards, so the two can have different aspect ratios as long as the widths match.
const CARD_HEIGHT_PER_WIDTH: float = 1.5

var card_count: int = 0
var cardback_nodes: Array[Control] = []

func set_card_count(count: int) -> void:
	card_count = max(count, 0)
	_update_visuals()

func set_card_width(new_card_width: float) -> void:
	card_width = new_card_width
	for node in cardback_nodes:
		_apply_card_size(node)
	_update_visuals() # the stack's horizontal offset depends on the card width

func _apply_card_size(node: Control) -> void:
	var card_size := Vector2(card_width, card_width * CARD_HEIGHT_PER_WIDTH)
	node.custom_minimum_size = card_size
	node.size = card_size

func _ensure_nodes():
	if cardback_scene == null:
		return
	
	while cardback_nodes.size() < max_visible_cards:
		var node: Control = cardback_scene.instantiate()
		add_child(node)
		_apply_card_size(node)

		cardback_nodes.append(node)

func _update_visuals():
	_ensure_nodes()
	
	var visible_cards : int = min(card_count, max_visible_cards)
	
	# Hide all first
	for node in cardback_nodes:
		node.visible = false
	
	if visible_cards == 0:
		return
	
	for i in visible_cards:
		var node: Control = cardback_nodes[i]
		node.visible = true

		var t := 0.0
		if max_visible_cards > 1:
			t = float(i) / float(max_visible_cards - 1)

		var horizontal_offset : float = pow(t, taper_exponent) * max_horizontal_offset
		var vertical_offset : float = t * max_vertical_offset

		node.position = Vector2(horizontal_offset, vertical_offset)
		node.position -= Vector2(0.5*node.size.x,0)
