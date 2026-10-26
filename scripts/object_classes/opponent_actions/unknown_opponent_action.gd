extends OpponentActionDefinition
class_name UnknownOpponentAction

### Dummy Move shown instead of a partner's real upcoming Move while the player can't see it (see
### Status_BlindPlayer, hide_upcoming_action). It has no effects and is never registered in
### AutoloadDatabase or chosen by any partner, so it only ever exists as a display. Built in code on
### purpose: the base game must not depend on a file in a content pack. Its "?" picture is drawn by
### UnknownMark (picture stays null), and its texts are plain UI strings in game.csv.

static var _shared_instance: UnknownOpponentAction

static func get_shared() -> UnknownOpponentAction:
	if not _shared_instance:
		_shared_instance = UnknownOpponentAction.new()
		_shared_instance.opponent_action_id = "unknown_action_while_blinded"
	return _shared_instance

func get_action_name() -> String:
	return tr("UI_UNKNOWN_OPPONENT_ACTION_NAME")

func get_action_description() -> String:
	return tr("UI_UNKNOWN_OPPONENT_ACTION_DESCRIPTION")

func get_translation_entries() -> Array[Dictionary]:
	return []
