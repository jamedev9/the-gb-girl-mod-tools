extends Cardgame_UI_Element
class_name DrawPile

@export var draw_pile_size: Label
@export var card_pile_visual: CardPileVisual

var pile_size: int

func set_card_width(card_width: float) -> void:
	card_pile_visual.set_card_width(card_width)

func update_class_specific_displays(game_state: GameState) -> void:
	pile_size = game_state.event_cards_deck.size() # Fetch to make visuals true
	_update_visuals_based_on_pile_size()

func _update_visuals_based_on_pile_size() -> void:
	draw_pile_size.text = str(pile_size)
	card_pile_visual.set_card_count(pile_size)

func update_visuals_when_a_card_is_drawn() -> void:
	pile_size -= 1
	_update_visuals_based_on_pile_size()

func _reset_visual_to_start_conditions_(new_game_state: GameState) -> void:
	pile_size = new_game_state.event_cards_deck.size()+new_game_state.event_cards_hand.size()
	_update_visuals_based_on_pile_size()

func _on_mouse_entered():
	emit_signal("tooltip_requested",TooltipId.DRAW_PILE,self)

func _on_mouse_exited():
	emit_signal("tooltip_cleared",self)
