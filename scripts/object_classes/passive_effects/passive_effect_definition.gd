extends EffectDefinition
class_name PassiveEffectDefinition

@export var passive_id: String
@export var passive_name: String
@export var passive_description: String
@export var picture: Texture2D

@export var hidden_from_player: bool = false
@export var hidden_during_combat: bool = false
@export var toggleable_by_player: bool = false

#@export var trigger_phases: Array[EffectContext.ContextPhase]
@export var modifier_components: Array[StatusModifierComponent]
@export var ticking_effect_components: Array[StatusTickComponent]
@export var triggered_components: Array[StatusTriggeredComponent]

func get_effect_id() -> String:
	return passive_id

func get_modifier_components() -> Array:
	return modifier_components

func get_triggered_components() -> Array:
	return triggered_components

func get_effect_name() -> String:
	return tr("PASSIVEEFFECTDEFINITION_"+passive_id.to_upper()+"_PASSIVE_NAME")

func get_effect_description() -> String:
	return tr("PASSIVEEFFECTDEFINITION_"+passive_id.to_upper()+"_PASSIVE_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	var prefix: String = "PASSIVEEFFECTDEFINITION_"+passive_id.to_upper()
	return [
		{"key": prefix+"_PASSIVE_NAME", "text": passive_name},
		{"key": prefix+"_PASSIVE_DESCRIPTION", "text": passive_description},
	]
