extends IndividualActionCardDisplay
class_name IndividualActionCardDisplay_mini

@export var mini_action_name_label: RichTextLabel
var active_player_action: PlayerAction ### for tooltip

var displayed_in_save_game: bool = false

### mini_action_name_label is a plain copy of action_card.action_type.text taken at display
### time, not a live binding - action_card refreshes its own label independently on locale
### change, but this copy needs to be re-taken explicitly, and NOTIFICATION_TRANSLATION_CHANGED
### propagates to this node before its action_card child, so re-reading action_card.action_type.text
### here would still see the pre-refresh value. Read straight from active_player_action instead.
func _refresh_text() -> void:
	super._refresh_text()
	if active_player_action:
		mini_action_name_label.text = active_player_action.get_action_name()

func update_when_save_game_changes(save_game_state: SaveGameState) -> void:
	if displayed_in_save_game:
		return
	super.update_when_save_game_changes(save_game_state)

func update_displayed_action_card(action_card_id: String,save_game_state: SaveGameState) -> void:
	super.update_displayed_action_card(action_card_id,save_game_state)
	mini_action_name_label.text = action_card.action_type.text
	active_player_action = AutoloadDatabase.get_player_action_by_id(action_card_id) 



func _on_event_card_selection_mouse_entered() -> void:
	var tooltip_type: Cardgame_UI_Element.TooltipId
	tooltip_type = Cardgame_UI_Element.TooltipId.EVENT_CARD_REWARD
	emit_signal("tooltip_requested",tooltip_type,self)

func _on_event_card_selection_mouse_exited() -> void:
	emit_signal("tooltip_cleared",self)

func _on_panel_container_mouse_entered() -> void:
	var tooltip_type: Cardgame_UI_Element.TooltipId = Cardgame_UI_Element.TooltipId.ACTIVE_PLAYER_ACTION
	emit_signal("tooltip_requested",tooltip_type,self)

func _on_panel_container_mouse_exited() -> void:
	emit_signal("tooltip_cleared",self)


func _on_event_card_selection_pressed() -> void:
	emit_signal("tooltip_cleared",self)

func _add_available_cards_to_dropdown_button(action_card_id: String, save_game_state: SaveGameState) -> void:
	if not save_game_state:
		return
	var available_rewards = save_game_state.get_reward_cards_for_action(action_card_id)
	add_cards_to_dropdown_button(available_rewards)
	_sync_dropdown_selection_to_current_reward()

func add_cards_to_dropdown_button(available_rewards: Array) -> void:
	event_card_selection.clear()
	event_card_selection.visible = true
	if available_rewards.is_empty():
		event_card_selection.visible = false
		return
	for card_id in available_rewards:
		var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
		#if not card_def:
			#continue
		var card_name: String = card_def.get_card_name()
		event_card_selection.add_item(card_name)
		available_reward_card_names[card_name] = card_id

func display_action_from_character_def(character_def: CharacterDefinition,action_card_id: String) -> void:
	self.displayed_in_save_game = true
	self.displayed_action_id = action_card_id
	action_card.display_action(action_card_id)
	mini_action_name_label.text = action_card.action_type.text
	active_player_action = AutoloadDatabase.get_player_action_by_id(action_card_id) 
	var availalble_rewards: Array = character_def.get_reward_cards_for_action(action_card_id)
	add_cards_to_dropdown_button(availalble_rewards)
	if not availalble_rewards.is_empty():
		current_reward_card_id = availalble_rewards[0]
