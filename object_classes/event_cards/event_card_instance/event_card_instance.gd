extends CardInstance
class_name EventCardInstance

var card_id: String
var permanence: CardPermanence
var entity_id: String

### Cardstate: Where in the resolution pipeline is the card instance?
### This is purely data. Visual state is controlled by the EventCard node
enum CardState {
	IN_DRAW_PILE,
	SPAWNED, #Reward and award cards
	IN_HAND,
	RESOLVING,
	IN_DISCARD_PILE,
	EXILED # Removed from the game
}
var card_state: CardState
var previous_hand_index: int

func card_requires_targeted_opponent() -> bool:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	return card_def.card_requires_targeted_opponent()

func card_cant_target_opponent_with_action(action_id: String) -> bool:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	for effect_intent in card_def.effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.RULE_BASED:
			for rule in effect_intent.targeting_rules:
				if rule.get_script() == TargetsHaveOneOfSeveralActionsAssigned:
					return true
	return false

func card_targets_opponent_with_action() -> bool:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	for effect_intent in card_def.effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.RULE_BASED:
			for rule in effect_intent.targeting_rules:
				if rule.get_script() == TargetsHaveOneOfSeveralActionsAssigned:
					return true
	return false

func required_actions_are_active_on_opponents(game_state: GameState) -> bool:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	for effect_intent in card_def.effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.RULE_BASED:
			for rule in effect_intent.targeting_rules:
				if rule is TargetsHaveOneOfSeveralActionsAssigned:	
					var action_ids = rule.action_ids
					for action in action_ids:
						if action not in game_state.actions_assigned_to_opponents.keys():
							return false
	return true
#
func get_opponents_with_one_of_required_actions(game_state: GameState) -> Array[String]:
	var opponents_with_actions: Array[String] = []
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	for effect_intent in card_def.effect_intents:
		if effect_intent.targeting_intent == TargetingSystem.TargetingMode.RULE_BASED:
			for rule in effect_intent.targeting_rules:
				if rule is TargetsHaveOneOfSeveralActionsAssigned:	
					var action_ids = rule.action_ids
					for action in action_ids:
						var opponent_id: String = game_state.get_opponent_with_action(action)
						if opponent_id != "":
							opponents_with_actions.append(opponent_id)
	return opponents_with_actions

func get_effect_intents() -> Array[EffectAndTargetIntent]:
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	return card_def.effect_intents
