extends PassiveEffectDefinition
class_name UnknownPassiveEffect

### Dummy Passive shown instead of a partner's real passives while the player can't see them (see
### Status_BlindPlayer, hide_passives). It has no effects and is never registered in AutoloadDatabase or
### given to anyone, so it only ever exists as a display. Built in code on purpose: the base game must
### not depend on a file in a content pack. Its "?" picture is drawn by UnknownMark (picture stays null),
### and its texts are plain UI strings in game.csv.

static var _shared_instance: UnknownPassiveEffect

static func get_shared() -> UnknownPassiveEffect:
	if not _shared_instance:
		_shared_instance = UnknownPassiveEffect.new()
		_shared_instance.passive_id = "unknown_passive_while_blinded"
		_shared_instance.has_secret_description = true
	return _shared_instance

func get_effect_name() -> String:
	return tr("UI_UNKNOWN_PASSIVE_NAME")

func get_effect_description() -> String:
	return tr("UI_UNKNOWN_PASSIVE_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	return []
