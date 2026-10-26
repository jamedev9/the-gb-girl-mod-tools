extends Cardgame_UI_Element
class_name OpponentTypePanelWithTooltip

@export var name_label: RichTextLabel

var opponent_type_id: String
var opponent_type: OpponentType
var tooltip_type: TooltipId = TooltipId.OPPONENT_TYPE

func update_displayed_info(given_opponent_type_id: String) -> void:
	self.opponent_type_id = given_opponent_type_id
	var given_opponent_type: OpponentType = AutoloadDatabase.opponent_types[given_opponent_type_id]
	opponent_type = given_opponent_type
	_set_name_label_text()

func _set_name_label_text() -> void:
	if not is_instance_valid(opponent_type):
		return
	name_label.text = opponent_type.get_opponent_type_name()

func _refresh_text() -> void:
	### For localization
	_set_name_label_text()

func _on_mouse_entered():
	emit_signal("tooltip_requested",tooltip_type,self)

func _on_mouse_exited():
	emit_signal("tooltip_cleared",self)
