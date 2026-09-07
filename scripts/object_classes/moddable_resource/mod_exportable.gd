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
## A subclass with a field that shouldn't be embedded as-is (e.g. a reference to a stable,
## AutoloadDatabase-registered content resource like StatusEffectDefinition, which should
## serialize as an id string instead) overrides this - see ApplyStatusEffect.
func to_json_dict() -> Dictionary:
	var result: Dictionary = {"_class": get_script().get_global_name()}
	for property in get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		if _INTERNAL_RESOURCE_FIELDS.has(property.name) or property.name.begins_with("metadata/"):
			continue
		result[property.name] = _serialize_value(get(property.name))
	return result

func _serialize_value(value):
	match typeof(value):
		TYPE_ARRAY:
			var out: Array = []
			for element in (value as Array):
				out.append(_serialize_value(element))
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
					out[key] = _serialize_value(dict_value[key])
				return out
			### Dictionary keys must round-trip through JSON too (e.g.
			### Intent_AddCardsFromListOfCardsToHand.cards_and_weights: Dictionary[CardsToAddIntent, float])
			### - JSON object keys can only be strings, so a dict with non-string keys is written as
			### an explicit list of {key, value} pairs instead of a native JSON object.
			var pairs: Array = []
			for key in dict_value.keys():
				pairs.append({"key": _serialize_value(key), "value": _serialize_value(dict_value[key])})
			return {"_dict_pairs": pairs}
		TYPE_OBJECT:
			if value == null:
				return null
			if value.has_method("to_json_dict"):
				return value.to_json_dict()
			push_error("ModExportable: cannot generically serialize non-ModExportable Object field of type %s - give the owning class a to_json_dict()/populate_from_json_dict() override." % value.get_class())
			return null
		_:
			return value

## Generic reflection-based deserializer, the inverse of to_json_dict() above. Called on a fresh
## instance (see ModdableResourceRegistry.instantiate()) - populates every @export'd field found
## in `data` by name, leaving fields absent from `data` at whatever default the fresh instance
## already has (matching the save-system-wide `.get(key, default)` forward/backward-compatibility
## convention documented in CLAUDE.md).
func populate_from_json_dict(data: Dictionary) -> void:
	for property in get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		if _INTERNAL_RESOURCE_FIELDS.has(property.name) or property.name.begins_with("metadata/"):
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

static func resolve_to_res_path(path: String) -> String:
	if path.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(path)
		if ResourceUID.has_id(uid):
			return ResourceUID.get_id_path(uid)
		push_warning("Could not resolve uid path: %s" % path)
		return ""
	return path

static func find_case_insensitive_enum_key(enum_keys: Array, tag_name: String) -> String:
	for enum_key in enum_keys:
		if enum_key.to_upper() == tag_name.to_upper():
			return enum_key
	return ""
