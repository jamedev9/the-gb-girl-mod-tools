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

### Stack count of the status that SENT this context (its tick, or one of its triggered reactions), 1 for
### everything else. Set when that status's effect is built (see StatusEffectManager and
### MainCardgame._on_triggered_component_triggered()) and read by EffectIntent.scale_context_by_stacks().
var source_effect_stacks: int = 1
### Scratch field, like damage_phase: the stack count of the status whose modifier components are being run
### RIGHT NOW (MODIFY phase), set by EffectContextManager for each status in turn. A modifier that scales
### with stacks reads it inside modify_context(); outside that call it means nothing.
var modifier_effect_stacks: int = 1

### The entity that ORIGINALLY PLACED the status currently ticking - distinct from `source`
### above, which for a status's own ticking effect is instead the entity that HAS the status
### (so TargetingSystem.TargetingMode.SOURCE_OF_EFFECT can still resolve the tick's target to
### "whoever holds this status" - see StatusEffectManager._send_requests_for_ticking_status_effects()).
### Only EffectContextManager._modify_intent_context_with_passive_and_status_effects() reads this,
### to decide whose OUTGOING modifiers apply to the tick - the placer's, not the holder's own. A
### status the player put on an opponent (e.g. "gain 10 Pleasure every turn") was "given" by the
### player, so the player's outgoing modifiers should apply to it, and the holder's own
### OUTGOING-only debuffs (e.g. a "your Pleasure given is halved" status) should NOT - see the
### 2026 bugfix where a "half Pleasure given" debuff was incorrectly nerfing a Pleasure-per-turn
### status the debuffed opponent never actually "gave" to anyone. Left null (falls back to
### `source`) for anything that isn't a status tick - e.g. passive ticks, which aren't "placed" by
### another entity in this sense.
var status_placed_by: TargetEntity

var target_is_immune_to_status_effects: bool = false

# entering triggers:
var added_pleasure_to_new_opponents: int

#Card flow system
var card_flow_effect: bool
var cards_to_draw: int
var discard_n_randomly: int
var discard_hand: bool
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

# Turn cycle: the step the game has just entered (a TurnStepSystem.TurnStep value), NO_STEP for every other context.
var turn_step: int = TurnStepSystem.NO_STEP

# Ending the player's turn (the effect version of the End Turn button).
var end_player_turn: bool = false

# Setting the player's Pleasure to an exact value (not damage, not healing: no multipliers apply). -1 = not a set.
var set_player_pleasure_to: int = -1

# Edging: how much to move the player's edging threshold (share of max Pleasure, -0.1 = 10 points lower). 0 = no change.
var edging_threshold_change: float = 0.0

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

### The Pleasure this context gives once every multiplier the MODIFY step added is applied, rounded. The one rounding rule for
### damage, used by MainCardgame._deal_damage_from_effect() and the live previews (PleasurePreview).
func get_damage_after_multipliers() -> int:
	return _apply_multipliers(damage_amount, damage_multipliers)

### Same for the Pleasure this context takes away (MainCardgame._heal_from_effect()).
func get_healing_after_multipliers() -> int:
	return _apply_multipliers(healing_amount, healing_multipliers)

static func _apply_multipliers(amount: int, multipliers: Array[float]) -> int:
	var total_multiplier: float = 1
	for multiplier in multipliers:
		total_multiplier *= multiplier
	return int(round(float(amount) * total_multiplier))

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
