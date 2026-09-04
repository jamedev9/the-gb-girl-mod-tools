@tool
extends ModExportable
class_name EffectDefinition

func get_effect_id() -> String:
	push_error("get_effect_id() not implemented")
	return ""

func get_modifier_components() -> Array:
	push_error("get_modifier_components() not implemented")
	return []

func get_triggered_components() -> Array:
	push_error("get_triggered_components() not implemented")
	return []

func get_effect_name() -> String:
	return ""

func get_effect_description() -> String:
	return ""

### Overridden by subclasses that have translatable text - see AutoloadDatabase's
### auto-localization check, which calls this (if present) on every registered resource.
func get_translation_entries() -> Array[Dictionary]:
	return []
