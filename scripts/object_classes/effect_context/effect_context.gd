extends Resource
class_name EffectContext

var game_state: GameState
enum ContextPhase {
	INTENT, #An effect wants to happen
	MODIFY, # Modifier to to the effect are applied
	VERIFY, # Check if the modified context is valid
	RESOLUTION, # Resolve the effects of the context
	REACTION # Tag for effects triggered by statuses and passives
}

#Source:
var source #Always single source TargetEntity
var id_of_effect_origin: String
var effect_origin
var context_phase: ContextPhase

#var targets: Array # Can have multiple targets that are affected.
var target: TargetEntity

# Optional system tags:
# Move action
var moving_player_action: bool
var player_action_id: String
var retract_actions: Array #String
var target_is_immune_to_action: bool = false

#Play event card
var played_event_card: bool
var event_card_instance: EventCardInstance
var dropped_on_opponent: String
var failed_to_resolve_info: Dictionary

var target_is_immune_to_event_card_targeting: bool = false

#Effect originating from event card
var event_card_causing_effect: EventCardInstance

# Damage system
var damage_phase: DamageSystem.DamagePhase
var damage_amount: int
#var damage_multiplier: float = 1.0
var damage_multipliers: Array[float] = []

var healing_amount: int
#var healing_multiplier: float = 1.0
var healing_multipliers: Array[float] = []

# For context sent out after damage:
var damage_was_succesfully_done: bool = false
var damage_that_was_done: int = 0

#Status system
var statuses_to_apply: Array[ApplyStatusEffect]
var status_sending_context: StatusEffectDefinition
var statuses_to_clear: Array[String]
#Structure: {"def":StatusEffectDefnition,"duration":int,"stacks": int}
var passive_sending_context: PassiveEffectDefinition

var target_is_immune_to_status_effects: bool = false

# entering triggers:
var added_pleasure_to_new_opponents: int

#Card flow system
var card_flow_effect: bool
var cards_to_draw: int
var discard_n_randomly: int
var shuffle_deck: bool
var add_cards_to_hand: Array[CardsToAddIntent] #card ID's
var add_cards_to_deck: Array[CardsToAddIntent] #card ID's

# Energy modification:
enum EnergyReason {
	MOVED_PLAYER_ACTION,
	RETRACTED_PLAYER_ACTION,
	PROGRESSED_PLAYER_ACTION,
	PLAYED_EVENT_CARD,
	EVENT_CARD_EFFECT
}
var energy_reason: EnergyReason
var energy_delta: int

var player_energy_reduction: int ### This is used for statuses that reduce available player energy.

# Opponent action:
var change_opponent_action_to: String #id of action

# Orgasms:
var restore_orgasms: int
var orgasms_to_trigger: int

# After orgasm has occurred:
var player_orgasmed: bool = false

# Defeating opponents:
var opponent_with_id_was_defeated: String = ""

# Removing statuses
var passive_to_remove_from_target: String
var passives_to_add_to_target: Array # array of passive IDs (string)

# Spawning opponents
var spawn_opponent: bool = false
var spawn_opponent_type: String
var spawned_opponent_is_unique: bool = false

# Spawning multiple opponents: This should trigger multiple of the above.
var spawn_multiple_opponents: Array[String] # string of opponent type IDs

# Once an opponent has spawned, a new context is sent with this variable:
var new_opponent_spawned: OpponentInstance

# Unlocking rewards:
var unlock_rewards_to_give_player: Array[String]

static func new_move_player_action_intent(
	_game_state: GameState,
	action_id: String,
	intent_source: TargetEntity,
	move_intent_origin,
	opponent_id: String = "",
	move_intent_origin_id: String = "player"
	) -> EffectContext:
	
	var move_intent: EffectContext = EffectContext.new()
	move_intent.game_state = _game_state
	move_intent.context_phase = ContextPhase.INTENT
	move_intent.moving_player_action = true
	move_intent.player_action_id = action_id
	move_intent.target_is_immune_to_action = false

	move_intent.effect_origin = move_intent_origin	
	move_intent.id_of_effect_origin = move_intent_origin_id
	
	move_intent.source = intent_source
	move_intent.target = null
	
	var player_action: PlayerAction = AutoloadDatabase.get_player_action_by_id(action_id)
	if opponent_id != "":
		move_intent.target = OpponentEntity.new(_game_state,opponent_id)
		move_intent.energy_delta = player_action.move_energy
		move_intent.energy_reason = EnergyReason.MOVED_PLAYER_ACTION
	else:
		move_intent.target = null
		move_intent.energy_delta = 0
		move_intent.energy_reason = EnergyReason.RETRACTED_PLAYER_ACTION
	
	return move_intent

static func new_player_action_damage_intent(
	_game_state:GameState,
	action_id: String,
	_target: TargetEntity) -> EffectContext:
	var damage_intent_context: EffectContext = EffectContext.new()
	damage_intent_context.game_state = _game_state
	damage_intent_context.context_phase = ContextPhase.INTENT
	damage_intent_context.id_of_effect_origin = action_id
	damage_intent_context.damage_phase = DamageSystem.DamagePhase.OUTGOING
	
	var action_def: PlayerAction = AutoloadDatabase.player_actions_by_id[action_id]
	damage_intent_context.damage_amount = action_def.base_damage
	damage_intent_context.source = PlayerEntity.new(_game_state)
	damage_intent_context.id_of_effect_origin = action_id
	damage_intent_context.effect_origin = action_def
	damage_intent_context.target = _target
	return damage_intent_context

static func new_opponent_action_damage_intent(_game_state: GameState,
	opponent_id: String,opponent_action:OpponentActionDefinition
	) -> EffectContext:
	var damage_intent_context: EffectContext = EffectContext.new()
	var action_id = opponent_action.opponent_action_id
	damage_intent_context.game_state = _game_state
	damage_intent_context.context_phase = ContextPhase.INTENT
	damage_intent_context.id_of_effect_origin = opponent_action.opponent_action_id
	damage_intent_context.damage_phase = DamageSystem.DamagePhase.OUTGOING
	
	damage_intent_context.damage_amount = opponent_action.base_damage
	damage_intent_context.source = OpponentEntity.new(_game_state,opponent_id)
	damage_intent_context.id_of_effect_origin = action_id
	damage_intent_context.effect_origin = opponent_action
	damage_intent_context.target = PlayerEntity.new(_game_state)
	return damage_intent_context
	
static func new_apply_statuses_intent(
	_game_state:GameState,_id_of_effect_origin: String,_effect_origin, _source: TargetEntity,_target: TargetEntity,_statuses_to_apply: Array[ApplyStatusEffect]) -> EffectContext:
	var apply_statuses_intent: EffectContext = EffectContext.new()
	apply_statuses_intent.game_state = _game_state
	apply_statuses_intent.context_phase = ContextPhase.INTENT
	apply_statuses_intent.id_of_effect_origin = _id_of_effect_origin
	apply_statuses_intent.effect_origin = _effect_origin
	apply_statuses_intent.game_state = _game_state
	apply_statuses_intent.source = _source
	apply_statuses_intent.target = _target
	apply_statuses_intent.statuses_to_apply = _statuses_to_apply
	return apply_statuses_intent

static func new_play_event_card_intent(
	_game_state:GameState,_event_card_instance: EventCardInstance,opponent_id: String = ""
) -> EffectContext:
	var play_event_card_intent: EffectContext = EffectContext.new()
	play_event_card_intent.context_phase = ContextPhase.INTENT
	play_event_card_intent.game_state= _game_state
	play_event_card_intent.played_event_card = true
	play_event_card_intent.effect_origin = _event_card_instance
	play_event_card_intent.event_card_instance = _event_card_instance
	#play_event_card_intent.event_card_id = _event_card_instance.card_id
	play_event_card_intent.source = PlayerEntity.new(_game_state)
	play_event_card_intent.target = null
	play_event_card_intent.event_card_causing_effect = _event_card_instance
	if opponent_id != "":
		play_event_card_intent.dropped_on_opponent = opponent_id
		play_event_card_intent.target = OpponentEntity.new(_game_state,opponent_id)
	
	#var event_card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[_event_card_instance.card_id]
	#play_event_card_intent.energy_delta = event_card_def.energy_cost
	play_event_card_intent.energy_delta = EventCardDefinition.get_energy_cost_of_playing_card(_game_state,_event_card_instance.card_id)
	play_event_card_intent.energy_reason = EnergyReason.PLAYED_EVENT_CARD
	return play_event_card_intent

static func new_retract_player_actions_intent(
	_game_state: GameState,
	action_ids: Array,
	move_intent_origin,
	move_intent_origin_id: String = "player",
	intent_source: TargetEntity = null
	) -> EffectContext:
	
	var move_intent: EffectContext = EffectContext.new()
	move_intent.game_state = _game_state
	move_intent.context_phase = ContextPhase.INTENT
	move_intent.retract_actions = action_ids

	move_intent.effect_origin = move_intent_origin	
	move_intent.id_of_effect_origin = move_intent_origin_id
	
	move_intent.source = intent_source
	move_intent.target = null
	
	return move_intent

static func new_capture_player_action_intent(
	_game_state: GameState,
	action_id: String) -> EffectContext:
	#print("Returnign new capture player action intent")
	
	var move_intent: EffectContext = EffectContext.new()
	move_intent.game_state = _game_state
	move_intent.context_phase = ContextPhase.INTENT
	move_intent.moving_player_action = true
	move_intent.player_action_id = action_id
	move_intent.target = move_intent.source
	
	return move_intent

static func new_change_opponent_action_intent(
	_game_state: GameState,
	opponent_action_id: String,
	intent_origin,
	intent_origin_id: String = "player",
	intent_source: TargetEntity = null
	) -> EffectContext:
	
	var change_action_intent: EffectContext = EffectContext.new()
	change_action_intent.game_state = _game_state
	change_action_intent.context_phase = ContextPhase.INTENT

	change_action_intent.effect_origin = intent_origin	
	change_action_intent.id_of_effect_origin = intent_origin_id
	
	change_action_intent.source = intent_source
	
	change_action_intent.change_opponent_action_to = opponent_action_id
	
	return change_action_intent

static func new_player_orgasm_context(_game_state: GameState) -> EffectContext:
	var orgasm_context: EffectContext = EffectContext.new()
	orgasm_context.player_orgasmed = true
	
	return orgasm_context
