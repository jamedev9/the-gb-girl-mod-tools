extends Cardgame_UI_Element
class_name EventCardPanelWithTooltip

@export var card_name_label: Label
@export var card_picture: TextureRect

@export var id_of_displayed_card: String
@export var card_permanence: CardInstance.CardPermanence

var displayed_card: EventCardDefinition

func _ready() -> void:
	super._ready()
	main_game.meta_game.connect("deck_state_changed",Callable(self,"_on_deck_state_changed"))

func _refresh_text() -> void:
	### For localization
	if not displayed_card:
		return
	_set_card_name(displayed_card)

func update_card_info(card_id: String, given_card_permanence: CardInstance.CardPermanence) -> void:
	### Skip re-shaping the name text (expensive for CJK locales) when this exact card is
	### already what's displayed - callers re-invoke this on unrelated save updates.
	var card_id_already_shown: bool = id_of_displayed_card == card_id
	id_of_displayed_card = card_id
	card_permanence = given_card_permanence
	var card_def: EventCardDefinition = AutoloadDatabase.event_cards_by_id[card_id]
	displayed_card = card_def
	if not card_id_already_shown:
		_set_card_name(card_def)
	if card_picture:
		card_picture.texture = card_def.card_picture

func _set_card_name(card_def: EventCardDefinition) -> void:
	var name_text: String = card_def.get_card_name()
	card_name_label.text = name_text

func _on_mouse_entered():
	#print("Mous entered card panel")
	var tooltip_type: TooltipId
	match card_permanence:
		CardInstance.CardPermanence.PERMANENT:
			tooltip_type = TooltipId.EVENT_CARD_PERMANENT
		CardInstance.CardPermanence.REWARD:
			tooltip_type = TooltipId.EVENT_CARD_REWARD
		CardInstance.CardPermanence.TEMPORARY:
			tooltip_type = TooltipId.EVENT_CARD_COMBO
		CardInstance.CardPermanence.PROBLEM:
			tooltip_type = TooltipId.EVENT_CARD_PROBLEM
	emit_signal("tooltip_requested",tooltip_type,self)

func _on_mouse_exited():
	#print("Mouse exited card panel")
	emit_signal("tooltip_cleared",self)
