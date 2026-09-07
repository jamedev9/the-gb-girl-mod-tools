@tool
extends Status_ChangeCostOfPlayingEventCards
class_name Status_ChangeCostOfCardsUsingActions

@export var action_ids: Array[String] = []

func get_list_of_cards() -> Array[String]:
	var available_cards: Dictionary[String,EventCardDefinition] = AutoloadDatabase.get_all_event_cards()
	var cards_matching_actions: Array[String] = []
	
	for card_id in available_cards:
		var actions_triggered = available_cards[card_id].get_actions_triggered_by_card()
		for triggered_action in actions_triggered:
			if triggered_action in action_ids:
				if card_id in cards_matching_actions:
					continue
				cards_matching_actions.append(card_id)
	
	return cards_matching_actions

func _cost_subject() -> String:
	return tr("STATUS_CHANGECOSTOFPLAYINGEVENTCARDS_SUBJECT_BY_ACTION_TEMPLATE").format({"action_names": _action_names(action_ids)})
