extends EffectDefinition
class_name StatusEffectDefinition

@export var status_id: String
@export var status_name: String
@export var status_description: String
@export var status_picture: Texture2D

enum StatusCategory {BUFF, DEBUFF}
@export var status_category: StatusCategory

enum StatusTag {
	BDSM
}
@export var status_tags: Array[StatusTag]


@export var status_effect_components: Array[StatusModifierComponent] 
@export var ticking_effect_components: Array[StatusTickComponent]
@export var triggered_effect_components: Array[StatusTriggeredComponent]

func get_effect_id() -> String:
	return status_id

func get_modifier_components() -> Array:
	return status_effect_components

func get_triggered_components() -> Array:
	return triggered_effect_components
