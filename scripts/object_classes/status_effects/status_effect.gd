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

func get_ticking_components() -> Array:
	return ticking_effect_components

func get_effect_name() -> String:
	return tr("STATUSEFFECTDEFINITION_"+status_id.to_upper()+"_STATUS_NAME")

func get_effect_description() -> String:
	return tr("STATUSEFFECTDEFINITION_"+status_id.to_upper()+"_STATUS_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	var prefix: String = "STATUSEFFECTDEFINITION_"+status_id.to_upper()
	return [
		{"key": prefix+"_STATUS_NAME", "text": status_name},
		{"key": prefix+"_STATUS_DESCRIPTION", "text": status_description},
	]

### Generic description support (see DescriptionBuilder) - used when something (currently
### ApplyStatusEffect) wants to nest-reference this status. Reuses the full Modifiers/Triggers
### tooltip (get_tooltip_description_segments()) - status_effect_components (e.g. MultiplyDamage)
### now describe themselves too, not just ticking_effect_components - falling back to the
### hand-written status_description if there's nothing generated at all.
func get_description_segments() -> Array[DescriptionSegment]:
	var tooltip: Array[DescriptionSegment] = get_tooltip_description_segments()
	if tooltip.is_empty():
		return [DescriptionSegment.text_segment(get_effect_description())]
	return tooltip


#STATUSEFFECTDEFINITION_AT_PEASE_STATUS_NAME,At Peace,安宁
#STATUSEFFECTDEFINITION_AT_PEASE_STATUS_DESCRIPTION,Target cannot give or receive pleasure.,目标无法给予或获得快乐。
