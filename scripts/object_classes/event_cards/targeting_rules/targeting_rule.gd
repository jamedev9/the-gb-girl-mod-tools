@tool
extends Resource
class_name TargetingRule

func is_target_valid(game_state: GameState, opponent_id: String) -> bool:
	return false

func to_json_dict() -> Dictionary:
	return {"type": "TargetingRule"}

static func from_json_dict(data: Dictionary) -> TargetingRule:
	match data.get("type", ""):
		"OnlyOneOpponent":
			return OnlyOneOpponent.from_json_dict(data)
		"OpponentCantTargetSelf":
			return OpponentCantTargetSelf.from_json_dict(data)
		"TargetCantBeAlly":
			return TargetCantBeAlly.from_json_dict(data)
		"OpponentOfDifferentType":
			return OpponentOfDifferentType.from_json_dict(data)
		"TargetSpecificOpponentId":
			return TargetSpecificOpponentId.from_json_dict(data)
		"TargetMustBeSpecificOpponentType":
			return TargetMustBeSpecificOpponentType.from_json_dict(data)
		_:
			push_warning("Unsupported/unknown targeting_rule type in mod data: %s" % data.get("type", ""))
			return null
