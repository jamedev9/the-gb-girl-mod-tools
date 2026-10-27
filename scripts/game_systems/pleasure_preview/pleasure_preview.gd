extends RefCounted
class_name PleasurePreview

### The Pleasure effects would give or take away right now, with every status and passive that changes it: the live numbers on
### Action cards, Moves, card texts and tooltips, and the previews on the pleasure bars. Nothing in the game changes. Every effect
### gets a throwaway context, built like the real one (EffectContextBuilder), that only goes through the MODIFY step and is then
### rounded the way the game rounds (EffectContext.get_damage_after_multipliers()). The same idea as
### ActionManager.get_current_move_cost() for energy, and cheap enough to run every frame.
###
### Targets: with resolve_targets on, a hit names the target the real game would pick (each Partner an "all Partners" card hits,
### the Partner a "Trigger Blowjob" intent finds). An intent that picks a Partner at random (a selector targeting rule with more
### than one candidate) or needs a Partner that isn't known yet (SINGLE_OPPONENT before the card is dropped) gives one hit with no
### target, which only has the giver's own modifiers. With resolve_targets off, only targets that are fixed without looking at the
### Partners are used (the player, the Partner the card is dropped on); everything else is a hit with no target. That is what a
### card's text shows.
###
### Not modelled: the VERIFY step (an effect the game would refuse still shows), and anything the effects change for each other
### (Pleasure from the first effect of a card that would set off a reaction before the second one resolves).

### "Trigger X" inside a triggered Action inside ...: stop following it after this many levels.
const MAX_NESTED_TRIGGERS: int = 5

var game_state: GameState
var effect_context_manager: EffectContextManager
var save_game_state: SaveGameState

var _nested_trigger_depth: int = 0

func _init(given_game_state: GameState, given_effect_context_manager: EffectContextManager, given_save_game_state: SaveGameState) -> void:
	game_state = given_game_state
	effect_context_manager = given_effect_context_manager
	save_game_state = given_save_game_state

### main_game: the running MainCardgame.
static func for_main_game(main_game: Node) -> PleasurePreview:
	var given_save_game_state: SaveGameState = null
	if main_game.meta_game:
		given_save_game_state = main_game.meta_game.save_game_state
	return PleasurePreview.new(main_game.game_state, main_game.effect_context_manager, given_save_game_state)

### False outside an encounter, where there are no player stats to read modifiers from: show the plain numbers then.
### Same check as ActionManager.get_current_move_cost().
func can_preview() -> bool:
	if not game_state or not effect_context_manager or not game_state.current_encounter:
		return false
	return "passive_effects" in game_state.player.keys()

#region What to preview
### Everything an event card would give or take away if it were played now. dropped_on_opponent: the Partner it is (or would be)
### dropped on, "" for none. Built like EffectContext.new_play_event_card_intent(), the context
### MainCardgame._resolve_effect_of_event_card() hands every intent of the card.
func preview_event_card(card_instance: EventCardInstance, dropped_on_opponent: String = "", resolve_targets: bool = true) -> Array[PleasurePreviewHit]:
	var hits: Array[PleasurePreviewHit] = []
	if not card_instance or not can_preview():
		return hits
	var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_instance.card_id)
	if not card_def:
		return hits
	var card_context: EffectContext = EffectContext.new()
	card_context.game_state = game_state
	card_context.played_event_card = true
	card_context.effect_origin = card_instance
	card_context.event_card_instance = card_instance
	card_context.event_card_causing_effect = card_instance
	card_context.source = PlayerEntity.new(game_state)
	if dropped_on_opponent != "":
		card_context.dropped_on_opponent = dropped_on_opponent
		card_context.target = OpponentEntity.new(game_state, dropped_on_opponent)
	_preview_intents_into(card_def.effect_intents, card_context, null, resolve_targets, null, hits)
	return hits

### What an Action gives each time it triggers on opponent_id ("" = not on a Partner: hits without a target). The save's own
### version of the Action, like MainCardgame._resolve_effects_of_player_action().
func preview_player_action(action_id: String, opponent_id: String = "", resolve_targets: bool = true) -> Array[PleasurePreviewHit]:
	var hits: Array[PleasurePreviewHit] = []
	if not can_preview():
		return hits
	var action: PlayerAction = get_effective_player_action(action_id)
	if not action:
		return hits
	var action_context: EffectContext = _make_action_context(null, opponent_id)
	_preview_intents_into(action.effect_intents, action_context, action, resolve_targets, null, hits)
	return hits

### What a Partner's Move gives when that Partner does it. Built like OpponentActionManager._perform_action_for_opponent().
func preview_opponent_move(opponent_id: String, move: OpponentActionDefinition, resolve_targets: bool = true) -> Array[PleasurePreviewHit]:
	var hits: Array[PleasurePreviewHit] = []
	if not move or not can_preview() or not game_state.get_opponent_instance(opponent_id):
		return hits
	var move_context: EffectContext = EffectContext.new()
	move_context.game_state = game_state
	move_context.source = OpponentEntity.new(game_state, opponent_id)
	_preview_intents_into(move.effect_intents, move_context, null, resolve_targets, null, hits)
	return hits

### What a status or passive that holder has gives each time it ticks, built like StatusEffectManager's tick contexts (who placed a
### status gives its outgoing modifiers, its stacks scale it). skip_unmet_conditions: leave out passive ticks whose conditions aren't
### met now, like MainCardgame._tick_passives_on_entity() (statuses tick unconditionally).
func preview_effect_ticks(
	effect_def: EffectDefinition, holder: TargetEntity, resolve_targets: bool = true, skip_unmet_conditions: bool = true) -> Array[PleasurePreviewHit]:
	var hits: Array[PleasurePreviewHit] = []
	if not can_preview() or not holder:
		return hits
	var tick_context: EffectContext = _make_effect_holder_context(effect_def, holder)
	tick_context.effect_origin = effect_def
	if effect_def is StatusEffectDefinition:
		var status_def: StatusEffectDefinition = effect_def as StatusEffectDefinition
		tick_context.id_of_effect_origin = status_def.status_id
		tick_context.status_placed_by = _get_still_valid_placer(holder, status_def.status_id)
		for component in status_def.ticking_effect_components:
			_preview_intents_into(component.effect_intents, tick_context, null, resolve_targets, null, hits)
	elif effect_def is PassiveEffectDefinition:
		var passive_def: PassiveEffectDefinition = effect_def as PassiveEffectDefinition
		tick_context.id_of_effect_origin = passive_def.passive_id
		for component in passive_def.ticking_effect_components:
			if skip_unmet_conditions and not component.are_ticking_conditions_met(game_state):
				continue
			_preview_intents_into(component.effect_intents, tick_context, null, resolve_targets, null, hits)
	return hits

### What the triggers of a status or passive that holder has give, built like MainCardgame._on_triggered_component_triggered() (the
### holder is their source). Whether a trigger would fire isn't known in advance: every one is previewed.
func preview_effect_triggers(effect_def: EffectDefinition, holder: TargetEntity, resolve_targets: bool = true) -> Array[PleasurePreviewHit]:
	var hits: Array[PleasurePreviewHit] = []
	if not can_preview() or not holder:
		return hits
	for component in effect_def.get_triggered_components():
		var trigger_context: EffectContext = _make_effect_holder_context(effect_def, holder)
		_preview_intents_into(component.effect_intents, trigger_context, null, resolve_targets, null, hits)
	return hits

### Any list of intents, from a context set up like the one the game would hand them. origin_override: see
### MainCardgame._handle_effect_and_target_intent().
func preview_effect_intents(
	intents: Array[EffectAndTargetIntent],
	source_context: EffectContext,
	origin_override: PlayerAction = null,
	resolve_targets: bool = true) -> Array[PleasurePreviewHit]:
	var hits: Array[PleasurePreviewHit] = []
	if not can_preview():
		return hits
	_preview_intents_into(intents, source_context, origin_override, resolve_targets, null, hits)
	return hits
#endregion

#region Reading the hits
### What the hits do to one Partner's Pleasure, added up (negative = takes Pleasure away).
static func get_total_change_for_opponent(hits: Array[PleasurePreviewHit], opponent_id: String) -> int:
	var total: int = 0
	for hit in hits:
		if hit.get_opponent_id() == opponent_id:
			total += hit.get_pleasure_change()
	return total

### What the hits do to the player's Pleasure, added up (negative = takes Pleasure away).
static func get_total_change_for_player(hits: Array[PleasurePreviewHit]) -> int:
	var total: int = 0
	for hit in hits:
		if hit.is_on_player():
			total += hit.get_pleasure_change()
	return total

### The hits a live number on a card or a Move counts: Pleasure given (Pleasure taken away is left out, as on the static numbers,
### EffectAndTargetIntent.sum_displayed_damage()). include_player: also the Pleasure the player gets (a Move's number); without
### it, only what others get (an Action card's number, PlayerAction.get_displayed_damage()).
static func get_displayed_hits(hits: Array[PleasurePreviewHit], include_player: bool) -> Array[PleasurePreviewHit]:
	var displayed_hits: Array[PleasurePreviewHit] = []
	for hit in hits:
		if hit.is_healing:
			continue
		if hit.is_on_player() and not include_player:
			continue
		displayed_hits.append(hit)
	return displayed_hits

### Every hit count times (PleasurePreviewHit.multiply()): what count copies of the same card give, played one after another.
### Returns the same (changed) array.
static func multiply_hits(hits: Array[PleasurePreviewHit], count: int) -> Array[PleasurePreviewHit]:
	if count == 1:
		return hits
	for hit in hits:
		hit.multiply(count)
	return hits

### The hits' amounts after modifiers, added up.
static func sum_amounts(hits: Array[PleasurePreviewHit]) -> int:
	var total: int = 0
	for hit in hits:
		total += hit.amount
	return total

### How the modifiers change the hits, seen from the player: above 0 = better for the player (Partners get more Pleasure, the player
### less), below 0 = worse, 0 = no change (PleasurePreviewHit.get_change_for_player()).
static func get_change_for_player(hits: Array[PleasurePreviewHit]) -> int:
	var change: int = 0
	for hit in hits:
		change += hit.get_change_for_player()
	return change

### The color of a live number: the positive/negative color of the colorblind settings when the modifiers make it better/worse for
### the player (get_change_for_player()), white when they change nothing.
static func get_live_number_color(hits: Array[PleasurePreviewHit]) -> Color:
	return get_color_for_change_for_player(get_change_for_player(hits))

### The positive/negative color for a change seen from the player (above 0 better), white for none.
static func get_color_for_change_for_player(change: int) -> Color:
	if change > 0:
		return SettingsManager.active_positive_color()
	if change < 0:
		return SettingsManager.active_negative_color()
	return Color.WHITE

### The Partners the hits name, each once.
static func get_opponent_ids(hits: Array[PleasurePreviewHit]) -> Array[String]:
	var opponent_ids: Array[String] = []
	for hit in hits:
		var opponent_id: String = hit.get_opponent_id()
		if opponent_id != "" and opponent_id not in opponent_ids:
			opponent_ids.append(opponent_id)
	return opponent_ids
#endregion

#region Building the hits
func _preview_intents_into(
	intents: Array[EffectAndTargetIntent],
	source_context: EffectContext,
	origin_override: PlayerAction,
	resolve_targets: bool,
	trigger_intent: EffectAndTargetIntent,
	hits: Array[PleasurePreviewHit]) -> void:
	for intent in intents:
		if intent == null or intent.effect_intent == null:
			continue
		if intent.effect_intent is ApplyEffectOfPlayerAction:
			_preview_triggered_action(intent, source_context, resolve_targets, hits)
		else:
			_preview_pleasure_intent(intent, source_context, origin_override, resolve_targets, trigger_intent, hits)

func _preview_pleasure_intent(
	intent: EffectAndTargetIntent,
	source_context: EffectContext,
	origin_override: PlayerAction,
	resolve_targets: bool,
	trigger_intent: EffectAndTargetIntent,
	hits: Array[PleasurePreviewHit]) -> void:
	for target in _get_preview_targets(intent, source_context, resolve_targets):
		var context: EffectContext = intent.effect_intent.create_pleasure_preview_context(game_state, source_context)
		if context == null:
			return ### This intent never changes Pleasure.
		EffectContextBuilder.stamp_new_context(game_state, context, source_context, intent, origin_override)
		context.target = target
		var hit: PleasurePreviewHit = PleasurePreviewHit.new()
		hit.target = target
		hit.is_healing = context.healing_amount != 0
		hit.base_amount = context.healing_amount if hit.is_healing else context.damage_amount
		hit.effect_and_target_intent = intent
		hit.trigger_intent = trigger_intent
		var unit_context: EffectContext = null
		if intent.effect_intent.is_pleasure_counted():
			unit_context = _make_one_unit_context(context, intent.effect_intent.get_described_pleasure_amount(), hit.is_healing)
		context.context_phase = EffectContext.ContextPhase.MODIFY
		effect_context_manager._modify_intent_context_with_passive_and_status_effects(context, false)
		hit.amount = context.get_healing_after_multipliers() if hit.is_healing else context.get_damage_after_multipliers()
		hit.per_unit_amount = hit.amount
		hit.per_unit_base_amount = hit.base_amount
		if unit_context:
			effect_context_manager._modify_intent_context_with_passive_and_status_effects(unit_context, false)
			hit.per_unit_amount = unit_context.get_healing_after_multipliers() if hit.is_healing else unit_context.get_damage_after_multipliers()
			hit.per_unit_base_amount = intent.effect_intent.get_described_pleasure_amount()
		hits.append(hit)

### A copy of a counted effect's context (same giver, target, origin ...) for ONE unit: what "5 Pleasure per Energy" makes of a
### single 5, for a card text that shows the per-unit number live. Made before the MODIFY step, so it starts without multipliers.
func _make_one_unit_context(context: EffectContext, unit_amount: int, is_healing: bool) -> EffectContext:
	var unit_context: EffectContext = EffectContext.new()
	unit_context.game_state = context.game_state
	unit_context.source = context.source
	unit_context.target = context.target
	unit_context.effect_origin = context.effect_origin
	unit_context.id_of_effect_origin = context.id_of_effect_origin
	unit_context.event_card_causing_effect = context.event_card_causing_effect
	unit_context.passive_sending_context = context.passive_sending_context
	unit_context.status_sending_context = context.status_sending_context
	unit_context.status_placed_by = context.status_placed_by
	unit_context.dropped_on_opponent = context.dropped_on_opponent
	if is_healing:
		unit_context.healing_amount = unit_amount
	else:
		unit_context.damage_amount = unit_amount
	unit_context.context_phase = EffectContext.ContextPhase.MODIFY
	return unit_context

### "Trigger X": the Action's own effects, against each Partner the intent finds. Like the real hand-off (ApplyEffectOfPlayerAction ->
### MainCardgame._resolve_effects_of_player_action()), so the hits carry the Action as their origin and still know the card that
### caused them: modifiers for Action Pleasure and for card Pleasure both apply, as in the game.
func _preview_triggered_action(
	intent: EffectAndTargetIntent,
	source_context: EffectContext,
	resolve_targets: bool,
	hits: Array[PleasurePreviewHit]) -> void:
	if _nested_trigger_depth >= MAX_NESTED_TRIGGERS:
		return
	var action: PlayerAction = get_effective_player_action(intent.effect_intent.player_action_id)
	if not action:
		return
	_nested_trigger_depth += 1
	for target in _get_preview_targets(intent, source_context, resolve_targets):
		var opponent_id: String = target.opponent_id if target is OpponentEntity else ""
		var action_context: EffectContext = _make_action_context(source_context, opponent_id)
		_preview_intents_into(action.effect_intents, action_context, action, resolve_targets, intent, hits)
	_nested_trigger_depth -= 1

### The context an Action's intents are resolved from (MainCardgame._resolve_effects_of_player_action()). The trigger's source is
### the player (ApplyEffectOfPlayerAction.create_intent_context()); trigger_source_context: the card's (or other) context that
### triggered it, null for the Action's routine trigger at the end of the turn.
func _make_action_context(trigger_source_context: EffectContext, opponent_id: String) -> EffectContext:
	var action_context: EffectContext = EffectContext.new()
	action_context.game_state = game_state
	action_context.source = PlayerEntity.new(game_state)
	if trigger_source_context and trigger_source_context.event_card_causing_effect:
		action_context.event_card_causing_effect = trigger_source_context.event_card_causing_effect
	action_context.dropped_on_opponent = opponent_id
	return action_context

### The targets to preview an intent on. A null in the list = one hit without a target.
func _get_preview_targets(intent: EffectAndTargetIntent, source_context: EffectContext, resolve_targets: bool) -> Array:
	match intent.targeting_intent:
		TargetingSystem.TargetingMode.PLAYER, TargetingSystem.TargetingMode.SOURCE_OF_EFFECT:
			return EffectContextBuilder.find_targets(game_state, source_context, intent)
		TargetingSystem.TargetingMode.SINGLE_OPPONENT:
			var targets: Array = EffectContextBuilder.find_targets(game_state, source_context, intent)
			if targets.is_empty():
				return [null]
			return targets
		TargetingSystem.TargetingMode.ALL_OPPONENTS:
			if not resolve_targets:
				return [null]
			return EffectContextBuilder.find_targets(game_state, source_context, intent)
		TargetingSystem.TargetingMode.RULE_BASED:
			if not resolve_targets:
				return [null]
			if TargetingSystem.has_selector_rule(intent.targeting_rules):
				### Picks at random (EffectContextBuilder.find_targets() would roll): known only when one candidate is left.
				var candidates: Array[TargetEntity] = TargetingSystem.get_targets_matching_rules(
					game_state, intent.targeting_rules, source_context.source, true)
				if candidates.size() == 1:
					return candidates
				if candidates.is_empty():
					return []
				return [null]
			return EffectContextBuilder.find_targets(game_state, source_context, intent)
	### NO_TARGET: the game resolves it without a target, which changes no one's Pleasure.
	return []

### The context a status's or passive's effects start from: the holder is the source, the effect is named as the sender (and a
### status's stacks are carried, so effects that scale with them do).
func _make_effect_holder_context(effect_def: EffectDefinition, holder: TargetEntity) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.game_state = game_state
	context.source = holder
	if effect_def is StatusEffectDefinition:
		var status_def: StatusEffectDefinition = effect_def as StatusEffectDefinition
		context.status_sending_context = status_def
		context.source_effect_stacks = maxi(holder.get_status_stacks(status_def.status_id), 1)
	elif effect_def is PassiveEffectDefinition:
		context.passive_sending_context = effect_def as PassiveEffectDefinition
	return context

### Like StatusEffectManager._get_still_valid_placer(): who placed the status, while they are still in the encounter.
static func _get_still_valid_placer(holder: TargetEntity, status_id: String) -> TargetEntity:
	var status_instance: Dictionary = holder.get_status_effects().get(status_id, {})
	var placer: TargetEntity = status_instance.get("source")
	if placer and placer.is_still_in_encounter():
		return placer
	return null

### The save's own version of the Action (its progressed effects), or the template without a save.
func get_effective_player_action(action_id: String) -> PlayerAction:
	if save_game_state:
		return save_game_state.get_effective_player_action(action_id)
	return AutoloadDatabase.get_player_action_by_id(action_id)
#endregion
