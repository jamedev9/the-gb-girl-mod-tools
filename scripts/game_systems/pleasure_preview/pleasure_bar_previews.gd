extends RefCounted
class_name PleasureBarPreviews

### What every pleasure bar previews (SimplePleasureBar.set_pleasure_preview(): "+X" and a shaded region), worked out with
### PleasurePreview once per frame for all bars together and read by each bar's owner (OpponentCard, PlayerCombatStatDisplay):
### - A Partner's bar always shows what the Actions on the Partners give them when they trigger at the end of this turn.
### - Every bar (the player's too, added 2026-10-27) always shows what the statuses and passives that tick each turn give or take away
###   at their next tick, whoever has them (e.g. Dirty Talk, `burn`, on a Partner).
### - Added to that, while one is under the mouse: an event card in the hand (hovered, or dragged: as if dropped on the Partner
###   under the cursor; with Ctrl, times the copies the drop would play, FloatingPlayerHand.get_play_count()), an Action card dragged
###   over a Partner (what it gives each time it triggers there), or a Partner's upcoming
###   Move (hovered). An Action being dragged no longer counts where it is now (it is being moved), only where it is hovered.
### - The player's bar shows no Actions' lasting part (decided 2026-10-27), only the ticks and what is under the mouse.
### A bar shows the total (decided 2026-10-27): an Action's +10 and a hovered card's +15 on the same Partner show as +25.
### A hit without a known target (a random Partner, a card not yet dropped) shows on no bar.

static var _computed_frame: int = -1
static var _opponent_changes: Dictionary = {} ### opponent id -> whole Pleasure
static var _player_change: int = 0

### main_game: the running MainCardgame.
static func get_change_for_opponent(main_game: Node, opponent_id: String) -> int:
	_update_for_this_frame(main_game)
	return int(_opponent_changes.get(opponent_id, 0))

static func get_change_for_player(main_game: Node) -> int:
	_update_for_this_frame(main_game)
	return _player_change

### The tint of a bar's preview, from the colorblind settings: good for the player = positive (a Partner gaining Pleasure, the player
### losing it), bad = negative.
static func get_color_for_change(change: int, is_player_bar: bool) -> Color:
	var good_for_player: bool = change < 0 if is_player_bar else change > 0
	if good_for_player:
		return SettingsManager.active_positive_color()
	return SettingsManager.active_negative_color()

static func _update_for_this_frame(main_game: Node) -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _computed_frame:
		return
	_computed_frame = frame
	_opponent_changes = {}
	_player_change = 0
	var preview: PleasurePreview = PleasurePreview.for_main_game(main_game)
	if not preview.can_preview():
		return
	var game_state: GameState = main_game.game_state
	var dragged_action_id: String = _get_dragged_action_id(main_game.get_viewport())
	for action_id in game_state.actions_assigned_to_opponents.keys():
		if action_id == dragged_action_id:
			continue
		var action_hits: Array[PleasurePreviewHit] = preview.preview_player_action(
			action_id, game_state.get_opponent_with_action(action_id))
		_add_hits(action_hits, false)
	_add_hits(_get_tick_hits(preview, game_state), true)
	_add_hits(_get_hits_under_mouse(preview, main_game), true)

### The next tick of every status and passive the player and the Partners have.
static func _get_tick_hits(preview: PleasurePreview, game_state: GameState) -> Array[PleasurePreviewHit]:
	var hits: Array[PleasurePreviewHit] = []
	var holders: Array[TargetEntity] = [PlayerEntity.new(game_state)]
	for opponent_id in game_state.get_currently_active_opponents().keys():
		holders.append(OpponentEntity.new(game_state, opponent_id))
	for holder in holders:
		for status_id in holder.get_status_effects().keys():
			var status_def: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(status_id)
			if status_def and not status_def.ticking_effect_components.is_empty():
				hits.append_array(preview.preview_effect_ticks(status_def, holder))
		for passive_id in holder.get_passive_effects():
			var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
			if passive_def and not passive_def.ticking_effect_components.is_empty():
				hits.append_array(preview.preview_effect_ticks(passive_def, holder))
	return hits

static func _add_hits(hits: Array[PleasurePreviewHit], include_player: bool) -> void:
	for hit in hits:
		if hit.is_on_player():
			if include_player:
				_player_change += hit.get_pleasure_change()
			continue
		var opponent_id: String = hit.get_opponent_id()
		if opponent_id == "":
			continue
		_opponent_changes[opponent_id] = int(_opponent_changes.get(opponent_id, 0)) + hit.get_pleasure_change()

static func _get_hits_under_mouse(preview: PleasurePreview, main_game: Node) -> Array[PleasurePreviewHit]:
	var no_hits: Array[PleasurePreviewHit] = []
	var viewport: Viewport = main_game.get_viewport()
	if viewport.gui_is_dragging():
		var drag_data: Variant = viewport.gui_get_drag_data()
		var hovered_opponent: OpponentCard = OpponentCard.find_hovered_opponent_card(viewport)
		var hovered_opponent_id: String = hovered_opponent.get_opponent_id() if hovered_opponent else ""
		if drag_data is EventCard and drag_data.event_card_instance:
			return _preview_event_card_with_copies(main_game, preview, drag_data.event_card_instance, hovered_opponent_id)
		if drag_data is ActionCard and hovered_opponent_id != "":
			return preview.preview_player_action(drag_data.represented_action_id, hovered_opponent_id)
		return no_hits
	var hovered_card: EventCard = EventCard.find_hovered_hand_card(viewport)
	if hovered_card:
		return _preview_event_card_with_copies(main_game, preview, hovered_card.event_card_instance)
	var opponent_card: OpponentCard = OpponentCard.find_hovered_opponent_card(viewport)
	if opponent_card:
		var hovered_move: OpponentActionDefinition = opponent_card.get_hovered_upcoming_move()
		if hovered_move:
			return preview.preview_opponent_move(opponent_card.get_opponent_id(), hovered_move)
	return no_hits

### An event card, times the number of copies a drop would play with it (Ctrl, FloatingPlayerHand.get_play_count()).
static func _preview_event_card_with_copies(
	main_game: Node, preview: PleasurePreview, card_instance: EventCardInstance, dropped_on_opponent: String = "") -> Array[PleasurePreviewHit]:
	var play_count: int = FloatingPlayerHand.get_play_count_in_game(main_game, card_instance)
	return PleasurePreview.multiply_hits(preview.preview_event_card(card_instance, dropped_on_opponent), play_count)

### The Action card being dragged (from the hand or off a Partner), "" when none is.
static func _get_dragged_action_id(viewport: Viewport) -> String:
	if not viewport.gui_is_dragging():
		return ""
	var drag_data: Variant = viewport.gui_get_drag_data()
	if drag_data is ActionCard:
		return drag_data.represented_action_id
	return ""
