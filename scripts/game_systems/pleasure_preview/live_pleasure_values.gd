extends RefCounted
class_name LivePleasureValues

### The live Pleasure numbers of one description (a tooltip). Each effect of the description's owner is previewed with PleasurePreview
### in the owner's real situation (the Action and the Partner it is on, the Move and its Partner, the status or passive and who has
### it), then apply_to() fills them into the description's LIVE_PLEASURE segments before it is shown. Text mode (resolve_targets off),
### like the numbers on the cards: a Partner that isn't known shows only the giver's side. A description shown without live values
### (linked terms, the overworld, outside an encounter) keeps its plain numbers. Built when the tooltip opens, like the tooltip.

var _hits_by_effect_intent: Dictionary = {} ### EffectIntent -> PleasurePreviewHit

#region Owners
### An Action, triggering on opponent_id ("" = not on a Partner), and its own triggers (their owner is the player, see
### EffectContextManager._trigger_active_player_actions()).
static func for_player_action(preview: PleasurePreview, action_id: String, opponent_id: String) -> LivePleasureValues:
	var values: LivePleasureValues = LivePleasureValues.new()
	if not preview.can_preview():
		return values
	values._add_hits(preview.preview_player_action(action_id, opponent_id, false))
	var action: PlayerAction = preview.get_effective_player_action(action_id)
	if not action:
		return values
	for component in action.triggered_components:
		var trigger_context: EffectContext = EffectContext.new()
		trigger_context.game_state = preview.game_state
		trigger_context.source = PlayerEntity.new(preview.game_state)
		values._add_hits(preview.preview_effect_intents(component.effect_intents, trigger_context, null, false))
	return values

### An event card's own Pleasure effects, as if dropped on dropped_on_opponent ("" = not over a Partner: only the player's side).
static func for_event_card(preview: PleasurePreview, card_instance: EventCardInstance, dropped_on_opponent: String) -> LivePleasureValues:
	var values: LivePleasureValues = LivePleasureValues.new()
	values._add_hits(preview.preview_event_card(card_instance, dropped_on_opponent, false))
	return values

static func for_opponent_move(preview: PleasurePreview, opponent_id: String, move: OpponentActionDefinition) -> LivePleasureValues:
	var values: LivePleasureValues = LivePleasureValues.new()
	values._add_hits(preview.preview_opponent_move(opponent_id, move, false))
	return values

### A status or passive that holder has: its ticks (even a passive tick whose conditions aren't met right now: the text describes it
### anyway) and its triggers (PleasurePreview.preview_effect_ticks() / preview_effect_triggers()).
static func for_effect_holder(preview: PleasurePreview, effect_def: EffectDefinition, holder: TargetEntity) -> LivePleasureValues:
	var values: LivePleasureValues = LivePleasureValues.new()
	values._add_hits(preview.preview_effect_ticks(effect_def, holder, false, false))
	values._add_hits(preview.preview_effect_triggers(effect_def, holder, false))
	return values

### Who a status/passive icon belongs to: the Partner whose card it is on, or the player when it is in the player's status display.
### null anywhere else (the statuses an Action card applies, an icon in a tooltip): those have no holder to preview.
static func find_holder_of_icon(icon: Node, game_state: GameState) -> TargetEntity:
	var node: Node = icon.get_parent()
	while is_instance_valid(node):
		if node is ActionCard:
			return null
		if node is OpponentCard:
			var opponent_id: String = node.get_opponent_id()
			if game_state.get_opponent_instance(opponent_id):
				return OpponentEntity.new(game_state, opponent_id)
			return null
		if node is PlayerStatusEffectsDisplay:
			return PlayerEntity.new(game_state)
		node = node.get_parent()
	return null

### The Partner card a node is on, null when it isn't on one.
static func find_opponent_card_of(given_node: Node) -> OpponentCard:
	var node: Node = given_node.get_parent()
	while is_instance_valid(node):
		if node is OpponentCard:
			return node as OpponentCard
		node = node.get_parent()
	return null
#endregion

### Fills the live amount and color into the LIVE_PLEASURE segments of segments (not into linked terms: those have no situation).
### A segment without a live value is emptied again, so segments can be filled over and over (an event card does every frame).
func apply_to(segments: Array[DescriptionSegment]) -> void:
	for segment in segments:
		if segment.type != DescriptionSegment.Type.LIVE_PLEASURE:
			continue
		segment.live_is_filled = false
		var hit: PleasurePreviewHit = _hits_by_effect_intent.get(segment.live_effect_intent, null)
		if not hit:
			continue
		segment.live_is_filled = true
		segment.live_amount = hit.per_unit_amount if segment.live_shows_per_unit else hit.amount
		var change: int = hit.get_change_for_player(segment.live_shows_per_unit)
		segment.live_color_html = ""
		if change != 0:
			segment.live_color_html = PleasurePreview.get_color_for_change_for_player(change).to_html(false)

### What the LIVE_PLEASURE segments of segments show right now, as one string: compare it with the last one to re-render a label
### only when a number or its color changed (re-shaping a label's text is slow, especially in Chinese).
static func get_live_signature(segments: Array[DescriptionSegment]) -> String:
	var signature: String = ""
	for segment in segments:
		if segment.type == DescriptionSegment.Type.LIVE_PLEASURE:
			signature += "%s:%d:%s;" % [segment.live_is_filled, segment.live_amount, segment.live_color_html]
	return signature

### Whether segments have any live Pleasure number (a description without one never needs refilling).
static func has_live_segments(segments: Array[DescriptionSegment]) -> bool:
	for segment in segments:
		if segment.type == DescriptionSegment.Type.LIVE_PLEASURE:
			return true
	return false

### The first hit of an effect wins: the owner's own effects are previewed first, and the same effect reached again (an Action
### that triggers itself) must not overwrite them.
func _add_hits(hits: Array[PleasurePreviewHit]) -> void:
	for hit in hits:
		var effect_intent: EffectIntent = hit.effect_and_target_intent.effect_intent
		if not _hits_by_effect_intent.has(effect_intent):
			_hits_by_effect_intent[effect_intent] = hit
