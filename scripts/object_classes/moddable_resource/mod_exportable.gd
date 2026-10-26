@tool
extends Resource
class_name ModExportable

func get_mod_export_subfolder() -> String:
	push_error("get_mod_export_subfolder() not implemented")
	return ""

## Built-in Resource properties that carry PROPERTY_USAGE_STORAGE but aren't script-declared
## data - never part of a serialized payload. Mirrors the equivalent list in
## tools/localization/export_resource_strings_to_tr_keys.gd (kept as a separate copy rather than
## a shared constant, since that tool's reflection walk is solving an unrelated problem and
## shouldn't be coupled to this one).
const _INTERNAL_RESOURCE_FIELDS: Array[String] = [
	"script", "resource_path", "resource_name",
	"resource_local_to_scene", "resource_scene_unique_id",
]

## Generic reflection-based serializer, used by EffectAndTargetIntent/EffectIntent/TargetingRule
## and any other ModExportable subclass that doesn't need bespoke handling. Walks every
## @export'd field via get_property_list() and writes a "_class" discriminator so the payload can
## be reconstructed via ModdableResourceRegistry.instantiate() without the reader needing to know
## the concrete type up front (needed for polymorphic arrays like
## EffectAndTargetIntent.targeting_rules, which can mix any of TargetingRule's subclasses).
## Content refers to registered content (statuses, cards, ...) by an id String field (see
## ApplyStatusEffect.status_id), which this walk writes as-is. A subclass with a field that can't be
## written as-is overrides this and lists the field in _get_fields_excluded_from_generic_json().
func to_json_dict() -> Dictionary:
	var result: Dictionary = {"_class": get_script().get_global_name()}
	var excluded_fields: Array[String] = _get_fields_excluded_from_generic_json()
	for property in get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		if _INTERNAL_RESOURCE_FIELDS.has(property.name) or property.name.begins_with("metadata/"):
			continue
		if excluded_fields.has(property.name):
			continue
		result[property.name] = _serialize_value(get(property.name), property.name)
	return result

### Fields a subclass writes/reads itself and the generic walk must not
### touch at all - not even to serialize and discard, which would hit _serialize_value()'s
### non-ModExportable error for any field holding e.g. a StatusEffectDefinition.
func _get_fields_excluded_from_generic_json() -> Array[String]:
	return []

func _serialize_value(value, field_name: String = ""):
	match typeof(value):
		TYPE_ARRAY:
			var out: Array = []
			for element in (value as Array):
				out.append(_serialize_value(element, field_name))
			return out
		TYPE_DICTIONARY:
			var dict_value: Dictionary = value
			var all_string_keys: bool = true
			for key in dict_value.keys():
				if typeof(key) != TYPE_STRING:
					all_string_keys = false
					break
			if all_string_keys:
				var out: Dictionary = {}
				for key in dict_value.keys():
					out[key] = _serialize_value(dict_value[key], field_name)
				return out
			### Dictionary keys must round-trip through JSON too (e.g.
			### Intent_AddCardsFromListOfCardsToHand.cards_and_weights: Dictionary[CardsToAddIntent, float])
			### - JSON object keys can only be strings, so a dict with non-string keys is written as
			### an explicit list of {key, value} pairs instead of a native JSON object.
			var pairs: Array = []
			for key in dict_value.keys():
				pairs.append({"key": _serialize_value(key, field_name), "value": _serialize_value(dict_value[key], field_name)})
			return {"_dict_pairs": pairs}
		TYPE_OBJECT:
			if value == null:
				return null
			if value.has_method("to_json_dict"):
				return value.to_json_dict()
			push_error("ModExportable: cannot generically serialize field '%s' on %s (a non-ModExportable %s) - give the owning class a to_json_dict()/populate_from_json_dict() override and list the field in _get_fields_excluded_from_generic_json()." % [
				field_name, get_script().get_global_name(), value.get_class()])
			return null
		_:
			return value

## Generic reflection-based deserializer, the inverse of to_json_dict() above. Called on a fresh
## instance (see ModdableResourceRegistry.instantiate()) - populates every @export'd field found
## in `data` by name, leaving fields absent from `data` at whatever default the fresh instance
## already has (matching the save-system-wide `.get(key, default)` forward/backward-compatibility
## convention documented in CLAUDE.md).
func populate_from_json_dict(data: Dictionary) -> void:
	var excluded_fields: Array[String] = _get_fields_excluded_from_generic_json()
	for property in get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		if _INTERNAL_RESOURCE_FIELDS.has(property.name) or property.name.begins_with("metadata/"):
			continue
		if excluded_fields.has(property.name):
			continue
		if not data.has(property.name):
			continue
		set(property.name, _deserialize_value(data[property.name], get(property.name)))

## `current_value` is whatever the property already holds on the fresh instance - for
## Array/Dictionary-typed properties this is an already-correctly-typed empty container (Godot
## carries an Array/Dictionary's element type with the value itself, independent of where it's
## stored), so appending into it (rather than building a new plain container and assigning that)
## is what makes a deserialized Array[TargetingRule] actually satisfy that typed-array contract
## instead of erroring as a plain untyped Array on assignment.
func _deserialize_value(raw_value, current_value):
	if raw_value == null:
		return null
	if typeof(raw_value) == TYPE_DICTIONARY and (raw_value as Dictionary).has("_class"):
		return ModdableResourceRegistry.instantiate(raw_value)
	if typeof(raw_value) == TYPE_DICTIONARY and (raw_value as Dictionary).has("_dict_pairs"):
		var out_dict: Dictionary = current_value if typeof(current_value) == TYPE_DICTIONARY else {}
		out_dict.clear()
		for pair in (raw_value as Dictionary)["_dict_pairs"]:
			out_dict[_deserialize_value(pair["key"], null)] = _deserialize_value(pair["value"], null)
		return out_dict
	if typeof(raw_value) == TYPE_ARRAY:
		var out_array: Array = current_value if typeof(current_value) == TYPE_ARRAY else []
		out_array.clear()
		for element in (raw_value as Array):
			out_array.append(_deserialize_value(element, null))
		return out_array
	if typeof(raw_value) == TYPE_DICTIONARY:
		var out_dict: Dictionary = current_value if typeof(current_value) == TYPE_DICTIONARY else {}
		out_dict.clear()
		for key in (raw_value as Dictionary).keys():
			out_dict[key] = _deserialize_value((raw_value as Dictionary)[key], null)
		return out_dict
	match typeof(current_value):
		TYPE_INT:
			return int(raw_value)
		TYPE_FLOAT:
			return float(raw_value)
		TYPE_BOOL:
			return bool(raw_value)
		TYPE_STRING:
			return String(raw_value)
		_:
			return raw_value

## Flat field -> subfolder, for single file-reference fields
func get_file_reference_fields() -> Dictionary:
	return {}

## Array field name -> {file_key, subfolder}, for arrays of dicts that each hold a file reference
func get_array_file_reference_fields() -> Dictionary:
	return {}

### used_by: the file of the resource the path belongs to, named in the warning so it can be found.
static func resolve_to_res_path(path: String, used_by: String = "") -> String:
	if path.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid)
		push_warning("Could not resolve uid path: %s%s" % [path, (" (used by %s)" % used_by) if used_by != "" else ""])
		return ""
	return path

static func find_case_insensitive_enum_key(enum_keys: Array, tag_name: String) -> String:
	for enum_key in enum_keys:
		if enum_key.to_upper() == tag_name.to_upper():
			return enum_key
	return ""
