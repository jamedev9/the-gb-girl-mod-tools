extends StatusModifierComponent
class_name Status_ChangeCostOfPlayingEventCards

@export var all_cards: bool = false
@export var card_ids: Array[String]
@export var energy_delta: int = 0

func modify_context(_effect_context: EffectContext) -> void:
	pass

func get_list_of_cards() -> Array[String]:
	return card_ids
	
