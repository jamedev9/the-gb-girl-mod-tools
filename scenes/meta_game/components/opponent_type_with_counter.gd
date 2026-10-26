extends PanelContainer
class_name OpponentTypeWithCounter

@export var opponent_type_with_tooltip: OpponentTypePanelWithTooltip
@export var counter_label: RichTextLabel


func show_opponent_type_with_counter_value(opponent_type: OpponentType,counter_value: String) -> void:
	counter_label.text = counter_value
	opponent_type_with_tooltip.update_displayed_info(opponent_type.opponent_type_id)
