extends EventCardPanelWithTooltip
class_name DecklistCardPanel

@export var card_count_label: RichTextLabel
@export var remove_one_button: Button
@export var add_one_button: Button

signal request_to_change_card_count(deck_list_panel: DecklistCardPanel,change: int)


func display_event_card(card_id: String,count: int) -> void:
	update_card_info(card_id,CardInstance.CardPermanence.PERMANENT)
	card_count_label.text = str(count)

#func _on_deck_state_changed(save_game_state: SaveGameState) -> void:

func change_theme_of_card(card_category: EventCardDefinition.CardCategory) -> void:
	
	pass


func _on_mouse_entered_decklist_panel() -> void:
	super._on_mouse_entered()

func _on_mouse_exited_decklist_panel() -> void:
	super._on_mouse_exited()


func _on_remove_one_pressed() -> void:
	emit_signal("request_to_change_card_count",self,-1)


func _on_add_one_pressed() -> void:
	emit_signal("request_to_change_card_count",self,1)
