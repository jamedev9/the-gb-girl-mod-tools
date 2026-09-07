extends Resource
class_name OpponentInstance

var opponent_type: OpponentType
var opponent_id: String
var opponent_name: String

var current_damage: int = 0
var orgasms_experienced: int = 0
var orgasms_restored: int = 0
var status_effects: Dictionary

var damage_tracking_index: int = 0
var damage_tracking_dict: Dictionary[int,Dictionary]

var upcoming_action: OpponentActionDefinition
var strategy_state: Dictionary = {}

func _init(_opponent_type: OpponentType) -> void:
	self.opponent_type = _opponent_type
	self.opponent_name = get_opponent_name_from_type(_opponent_type)

func choose_action(_context: EffectContext=null) -> OpponentActionDefinition:
	return opponent_type.action_strategy.choose_action(self, _context)

func get_opponent_name_from_type(_opponent_type: OpponentType) -> String:
	return _opponent_type.get_random_name()
	
func get_remaining_orgasms() -> int:
	### We subtract 1 from the count to make this work the same way as the players orgasm tracker:
	### Defeat occurs when you orgasm without any more in the "bank".
	return opponent_type.orgasms_before_defeat - orgasms_experienced + orgasms_restored - 1

func log_damage_taken(context: EffectContext,damage: int) -> void:
	damage_tracking_dict[damage_tracking_index] = {"context":context,"damage":damage}
	damage_tracking_index += 1

func get_context_of_last_damage_taken() -> EffectContext:
	var last_entry: Dictionary = damage_tracking_dict[damage_tracking_index-1]
	var context: EffectContext = last_entry["context"]
	return context

func get_participant_tags() -> Array[VideoClip.ParticipantTags]:
	return opponent_type.video_particpant_tags

func is_valid_target_for_event_card(event_card_instance: EventCardInstance, game_state: GameState) -> bool:
	if opponent_id not in game_state.currently_active_opponents:
		return false
	
	if _is_immune_to_event_card_targeting(event_card_instance, game_state):
		return false
	
	var event_card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(event_card_instance.card_id)
	
	if event_card_def.card_targets_opponent_with_action():
		var opponents_with_required_actions: Array[String] = event_card_instance.get_opponents_with_one_of_required_actions(game_state)
		if opponents_with_required_actions.is_empty():
			return false
	
	var source: TargetEntity = PlayerEntity.new(game_state)
	
	for effect_and_intent in event_card_def.effect_intents:
		if effect_and_intent.targeting_intent == TargetingSystem.TargetingMode.SINGLE_OPPONENT:
			for rule in effect_and_intent.targeting_rules:
				if rule is TargetCannotHaveTheseActionsAssigned:
					if not rule.is_target_valid(game_state, opponent_id):
						return false
		
		elif effect_and_intent.targeting_intent == TargetingSystem.TargetingMode.RULE_BASED:
			var matching_targets: Array[TargetEntity] = TargetingSystem.get_targets_matching_rules(
				game_state, effect_and_intent.targeting_rules, source)
			var matching_ids: Array = []
			for target in matching_targets:
				if target is OpponentEntity:
					matching_ids.append(target.opponent_id)
			matching_ids.erase(opponent_id) # a RULE_BASED requirement can't be satisfied by the same opponent being dropped on
			if matching_ids.is_empty():
				return false
	
	return true

func _is_immune_to_event_card_targeting(event_card_instance: EventCardInstance, game_state: GameState) -> bool:
	var target_entity: OpponentEntity = OpponentEntity.new(game_state, opponent_id)
	
	var preview_context: EffectContext = EffectContext.new()
	preview_context.game_state = game_state
	preview_context.target = target_entity
	preview_context.played_event_card = true
	preview_context.event_card_instance = event_card_instance
	preview_context.event_card_causing_effect = event_card_instance
	
	for component in target_entity.get_all_modifier_components():
		component.modify_context(preview_context)
	
	return preview_context.target_is_immune_to_event_card_targeting
