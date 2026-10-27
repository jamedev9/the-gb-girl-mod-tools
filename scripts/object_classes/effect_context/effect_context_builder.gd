extends RefCounted
class_name EffectContextBuilder

### How an EffectAndTargetIntent becomes contexts: who it hits, and what a freshly made context inherits from the context
### that caused it. Shared by the real game (MainCardgame._handle_effect_and_target_intent()) and the live Pleasure previews
### (PleasurePreview), so a preview is always built exactly like the context the game will resolve.

### Who an intent hits. Empty = no target (the game then resolves one context without a target).
### RULE_BASED with a selector rule (OnlyOneOpponent, OpponentWithMostHealthRemaining) picks at random, so a preview must not
### call this for it (see PleasurePreview._get_preview_targets()).
static func find_targets(game_state: GameState, intent_context: EffectContext, effect_and_target_intent: EffectAndTargetIntent) -> Array:
	var targeting_mode: TargetingSystem.TargetingMode = effect_and_target_intent.targeting_intent
	var source: TargetEntity = intent_context.source
	match targeting_mode:
		TargetingSystem.TargetingMode.SINGLE_OPPONENT: ###This mode only counts for Event Cards dropped on opponents
			if not intent_context.dropped_on_opponent:
				return []
			return [OpponentEntity.new(intent_context.game_state,intent_context.dropped_on_opponent)]
		TargetingSystem.TargetingMode.PLAYER:
			if source is PlayerEntity:
				return [source]
			return [PlayerEntity.new(game_state)]
		TargetingSystem.TargetingMode.RULE_BASED:
			var opponents_targeted: Array[TargetEntity] = TargetingSystem.get_targets_matching_rules(game_state,effect_and_target_intent.targeting_rules,source)
			return opponents_targeted
		TargetingSystem.TargetingMode.ALL_OPPONENTS:
			var targets = []
			for opponent_id in game_state.get_currently_active_opponents():
				targets.append(OpponentEntity.new(game_state,opponent_id))
			return targets
		TargetingSystem.TargetingMode.SOURCE_OF_EFFECT:
			return [intent_context.source]
	return []

### Fills in a context an EffectIntent just made (create_intent_context()) with what it inherits from intent_context, the context
### that caused it. origin_override: see MainCardgame._handle_effect_and_target_intent().
static func stamp_new_context(
	game_state: GameState,
	effect_intent_context: EffectContext,
	intent_context: EffectContext,
	effect_and_target_intent: EffectAndTargetIntent,
	origin_override: PlayerAction = null) -> void:
	effect_intent_context.game_state = game_state
	if not effect_intent_context.source: ### Why was this here???
		effect_intent_context.source = intent_context.source
	if intent_context.event_card_causing_effect:
		effect_intent_context.event_card_causing_effect = intent_context.event_card_causing_effect
	### create_intent_context() returns a brand new EffectContext, which doesn't inherit
	### passive_sending_context/status_sending_context/status_placed_by from intent_context - carry
	### them forward the same way source/event_card_causing_effect are above, or a triggered
	### passive/status effect loses track of which passive/status it came from (see
	### Modifier_MultiplyDamageFromPassives, which depends on this surviving) - and a status tick
	### loses track of who placed it (see EffectContext.status_placed_by), reverting to the
	### "outgoing modifiers belong to whoever holds the status" bug that field exists to fix.
	if intent_context.passive_sending_context:
		effect_intent_context.passive_sending_context = intent_context.passive_sending_context
	if intent_context.status_sending_context:
		effect_intent_context.status_sending_context = intent_context.status_sending_context
	if intent_context.status_placed_by:
		effect_intent_context.status_placed_by = intent_context.status_placed_by
	### Same for the stack count of the status that sent this: carried forward, and the intent gets to scale
	### itself with it (opt-in, e.g. DealDamageEffect.scale_with_stacks). Only a status's own tick/reaction has more than 1.
	effect_intent_context.source_effect_stacks = intent_context.source_effect_stacks
	if intent_context.source_effect_stacks > 1:
		effect_and_target_intent.effect_intent.scale_context_by_stacks(effect_intent_context, intent_context.source_effect_stacks)
	effect_intent_context.id_of_effect_origin = effect_and_target_intent.effect_intent.intent_effect_id
	effect_intent_context.effect_origin = effect_and_target_intent.effect_intent
	if origin_override:
		effect_intent_context.id_of_effect_origin = origin_override.action_id
		effect_intent_context.effect_origin = origin_override
		### Which opponent the action is on: an intent that doesn't target that opponent (e.g. Pleasure the
		### action gives the player) still needs it, to animate from the action's art.
		effect_intent_context.dropped_on_opponent = intent_context.dropped_on_opponent
	if intent_context.damage_was_succesfully_done:
		effect_intent_context.damage_was_succesfully_done = true
		effect_intent_context.damage_that_was_done = intent_context.damage_that_was_done
