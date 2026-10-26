extends TooltipUI
class_name Tooltip_EventCard

@export var event_card_display: EventCard

var event_card_id: String

### Shows a card by id, for a card term in description text (see DescriptionSegment.card_id). permanence is how it looks:
### a CardInstance.CardPermanence value (permanent, temporary/combo, reward, problem, ...).
func show_card(card_id: String, permanence: int = CardInstance.CardPermanence.PERMANENT) -> void:
	var card_instance: EventCardInstance = EventCardInstance.new()
	card_instance.card_id = card_id
	card_instance.permanence = permanence as CardInstance.CardPermanence
	event_card_display.display_event_card(card_instance)

func update_tooltip_information(
	_game_state: GameState,
	tooltip_id: Cardgame_UI_Element.TooltipId,
	control_node: Control) -> void:
	
	var card_instance: EventCardInstance = EventCardInstance.new()
	if control_node is EventCardPanelWithTooltip:
		card_instance.card_id = control_node.id_of_displayed_card
	if control_node is IndividualActionCardDisplay_mini:
		card_instance.card_id = control_node.current_reward_card_id

			
	match tooltip_id:
		TooltipId.EVENT_CARD_PERMANENT:
			card_instance.permanence = CardInstance.CardPermanence.PERMANENT
		TooltipId.EVENT_CARD_REWARD:
			card_instance.permanence = CardInstance.CardPermanence.REWARD
		TooltipId.EVENT_CARD_COMBO:
			card_instance.permanence = CardInstance.CardPermanence.TEMPORARY
		TooltipId.EVENT_CARD_PROBLEM:
			card_instance.permanence = CardInstance.CardPermanence.PROBLEM
	
	event_card_display.display_event_card(card_instance)
	
