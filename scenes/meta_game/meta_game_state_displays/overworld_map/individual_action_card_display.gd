extends Metagame_UI_Element
class_name IndividualActionCardDisplay

@export var action_card: ActionCard
@export var yes_no_button: Button
@export var button_panel: PanelContainer
@export var reward_card_container: Container
@export var reward_card_panel: EventCardPanelWithTooltip
@export var event_card_selection: OptionButton
@export var unlock_rewards_margin: MarginContainer
@export var unlock_reward_display: UnlockRewardDisplay
@export var next_unlock_label: RichTextLabel

@export var reward_related_nodes: Array[Control]

var displayed_action_id: String

var available_reward_card_names: Dictionary[String,String] # Card Name, card ID
var current_reward_card_id: String = ""

@export var yes_style: StyleBoxFlat
@export var no_style: StyleBoxFlat

signal request_change_putting_out(action_id: String)
signal request_changing_reward_card(action_id: String,card_id: String)

func _refresh_text() -> void:
	### For localization
	if not action_card:
		return
	if not main_game:
		return
	_add_available_cards_to_dropdown_button(action_card.represented_action_id,main_game.meta_game.save_game_state)
	if displayed_action_id != "":
		_show_next_unlock_reward(main_game.meta_game.save_game_state)


func update_displayed_action_card(action_card_id: String,save_game_state: SaveGameState) -> void:
	self.displayed_action_id = action_card_id
	action_card.display_action(action_card_id)
	_show_reward_cards(action_card_id,save_game_state)

func _show_reward_cards(action_card_id:String,save_game_state: SaveGameState) -> void:
	if action_card_id not in save_game_state.reward_cards_from_actions.keys():
		_hide_reward_nodes()
		#reward_card_container.visible = false
		return
	current_reward_card_id = save_game_state.reward_cards_from_actions[action_card_id]
	_show_reward_nodes()
	#reward_card_container.visible = true
	reward_card_panel.update_card_info(current_reward_card_id,CardInstance.CardPermanence.REWARD)
	_sync_dropdown_selection_to_current_reward()

func _hide_reward_nodes() -> void:
	for node in reward_related_nodes:
		node.hide()

func _show_reward_nodes() -> void:
	for node in reward_related_nodes:
		node.show()

func update_when_save_game_changes(save_game_state: SaveGameState) -> void:
	if displayed_action_id not in save_game_state.owned_player_actions:
		self.queue_free()
		return
	### action_card is a Cardgame_UI_Element, which refreshes its own picture override on
	### game_state_changed - a combat-turn signal that never fires while just browsing the
	### meta-game, so display_action()'s initial (possibly-too-early) picture never
	### self-corrects here otherwise. save_game_state_changed (which drives this function)
	### is the reliable equivalent in this context.
	if action_card:
		action_card.refresh_picture_override()
	if displayed_action_id in save_game_state.currently_used_player_actions:
		yes_no_button.text = "Yes"
		button_panel.add_theme_stylebox_override("panel",yes_style)
	else:
		yes_no_button.text = "No"
		button_panel.add_theme_stylebox_override("panel",no_style)
	_show_reward_cards(displayed_action_id,save_game_state)
	_add_available_cards_to_dropdown_button(displayed_action_id,save_game_state)
	_show_next_unlock_reward(save_game_state)

	
func _add_available_cards_to_dropdown_button(action_card_id: String, save_game_state: SaveGameState) -> void:
	event_card_selection.clear()
	var available_rewards = save_game_state.get_reward_cards_for_action(action_card_id)
	event_card_selection.visible = true
	if available_rewards.size() <= 1:
		event_card_selection.visible = false
		return

	for card_id in available_rewards:
		var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
		var card_name: String = card_def.get_card_name()
		event_card_selection.add_item(card_name)
		available_reward_card_names[card_name] = card_id

	_sync_dropdown_selection_to_current_reward()


func _sync_dropdown_selection_to_current_reward() -> void:
	for i in event_card_selection.item_count:
		var item_text: String = event_card_selection.get_item_text(i)
		if available_reward_card_names.get(item_text) == current_reward_card_id:
			if event_card_selection.selected != i:
				event_card_selection.select(i)
			break
	
func _on_yes_no_button_pressed() -> void:
	emit_signal("request_change_putting_out",displayed_action_id)


func _on_event_card_selection_item_selected(index: int) -> void:
	var card_name: String = event_card_selection.get_item_text(index)
	var card_id: String = available_reward_card_names[card_name]
	self.current_reward_card_id = card_id
	emit_signal("request_changing_reward_card",displayed_action_id,card_id)

#region Unlock rewards:
func _show_next_unlock_reward(save_game_state: SaveGameState) -> void:
	if not unlock_rewards_margin:
		return ### For inheritor classes that dont use this part
	unlock_rewards_margin.show()
	var next_reward_unlock_id: String = save_game_state.get_next_reward_id_for_action(displayed_action_id)
	if next_reward_unlock_id == "":
		unlock_rewards_margin.hide()
		return
	var guys_needed_for_next_reward: int = AutoloadDatabase.get_guys_needed_for_reward(displayed_action_id,next_reward_unlock_id)
	var current_count: int = save_game_state.get_opponents_defeated_for_next_reward_for_action(displayed_action_id)
	var reward_def: RewardDefinition = AutoloadDatabase.get_unlock_reward_definition(next_reward_unlock_id)
	if not reward_def:
		unlock_rewards_margin.hide()
		return
	unlock_reward_display.display_reward_information(null,reward_def)
	var action_progression: ActionProgressionDefinition = AutoloadDatabase.get_action_progression_def(displayed_action_id)
	var formatted_text: String = _get_formated_string_for_action_text(action_progression.action_ids,current_count,guys_needed_for_next_reward)
	next_unlock_label.text = formatted_text
	
func _get_formated_string_for_action_text(
	action_ids: Array[String],current_count: int,guys_needed_for_next_reward:int) -> String:
	var start_string: String = tr("UI_ACTION_PROGRESSION_NEXT_UNLOCK_TEMPLATE") %[current_count,guys_needed_for_next_reward]
	var replacement_actions_list: String = ""
	for action_id in action_ids:
		var action_name: String = AutoloadDatabase.player_actions_by_id[action_id].action_name
		replacement_actions_list += "[b]"+action_name+"[/b]"
		if action_ids.find(action_id) < action_ids.size()-1:
			if action_ids.size()> 2:
				replacement_actions_list += ", "
			else:
				replacement_actions_list += " "
		if action_ids.find(action_id) == action_ids.size()-2:
			replacement_actions_list += tr("UI_ACTION_PROGRESSION_OR_LABEL")
	var final_string: String = start_string + replacement_actions_list+"."
	return final_string

#endregion
