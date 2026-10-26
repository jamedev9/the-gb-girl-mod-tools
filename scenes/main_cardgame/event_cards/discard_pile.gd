extends Cardgame_UI_Element
class_name DiscardPile

@export var discard_pile_size: Label
@export var card_pile_visual: CardPileVisual

var pile_size: int

func _ready():
	super._ready()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_card_width(card_width: float) -> void:
	card_pile_visual.set_card_width(card_width)

func update_class_specific_displays(game_state: GameState) -> void:
	pile_size = game_state.event_cards_discard.size() # Fetch to make visuals true
	_update_visuals_based_on_pile_size()

func _update_visuals_based_on_pile_size() -> void:
	discard_pile_size.text = str(pile_size)
	card_pile_visual.set_card_count(pile_size)

func update_visuals_when_a_card_is_discarded() -> void:
	pile_size += 1
	_update_visuals_based_on_pile_size()

func _on_mouse_entered():
	emit_signal("tooltip_requested",TooltipId.DISCARD_PILE,self)

func _on_mouse_exited():
	emit_signal("tooltip_cleared",self)
