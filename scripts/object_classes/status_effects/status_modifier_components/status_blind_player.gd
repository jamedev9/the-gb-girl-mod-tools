@tool
extends StatusModifierComponent
class_name Status_BlindPlayer

### Hides information about the partners (opponents) from the player ("blindfolded"). It changes nothing
### in the rules, only what the displays show. Put it on a status or passive of the player; every display
### asks GameState (is_opponent_info_hidden() / is_player_background_dimmed()) instead of looking for this
### class itself, so other content (e.g. a gloryhole encounter) blinds the player just by giving them a
### status or passive with this component. Each flag covers one thing, so a status can blind only part of
### it; several blinding statuses add up (anything hidden/dimmed by one of them stays that way).

enum HiddenInfo {
	PLEASURE, ### the partners' current and max Pleasure
	OPPONENT_TYPE, ### the partner type's name
	OPPONENT_VISUALS, ### the picture(s) representing the partner, and the card's type colour (shown as neutral gray)
	OPPONENT_NAME, ### the partner's own name
	UPCOMING_ACTION, ### the Move the partner will do next (replaced by a "?" Move)
	PASSIVES, ### the partner's Passives (the list collapses to one "?" Passive)
}

@export var hide_pleasure: bool = true
@export var hide_opponent_type: bool = true
@export var hide_opponent_visuals: bool = true
@export var hide_opponent_name: bool = true
@export var hide_upcoming_action: bool = true
@export var hide_passives: bool = true
### Dims the encounter background picture while this is active.
@export var dim_background: bool = true

func hides(info: HiddenInfo) -> bool:
	match info:
		HiddenInfo.PLEASURE:
			return hide_pleasure
		HiddenInfo.OPPONENT_TYPE:
			return hide_opponent_type
		HiddenInfo.OPPONENT_VISUALS:
			return hide_opponent_visuals
		HiddenInfo.OPPONENT_NAME:
			return hide_opponent_name
		HiddenInfo.UPCOMING_ACTION:
			return hide_upcoming_action
		HiddenInfo.PASSIVES:
			return hide_passives
	return false

func get_description_segments() -> Array[DescriptionSegment]:
	var hidden_info_names: Array[String] = []
	if hide_pleasure:
		hidden_info_names.append(tr("STATUS_BLINDPLAYER_INFO_PLEASURE"))
	if hide_opponent_type:
		hidden_info_names.append(tr("STATUS_BLINDPLAYER_INFO_TYPE"))
	if hide_opponent_visuals:
		hidden_info_names.append(tr("STATUS_BLINDPLAYER_INFO_VISUALS"))
	if hide_opponent_name:
		hidden_info_names.append(tr("STATUS_BLINDPLAYER_INFO_NAME"))
	if hide_upcoming_action:
		hidden_info_names.append(tr("STATUS_BLINDPLAYER_INFO_UPCOMING_ACTION"))
	if hide_passives:
		hidden_info_names.append(tr("STATUS_BLINDPLAYER_INFO_PASSIVES"))
	if hidden_info_names.is_empty():
		return []
	return DescriptionBuilder.parse_template(
		tr("STATUS_BLINDPLAYER_TEMPLATE"), {"hidden_info": DescriptionBuilder.join_with_and(hidden_info_names)})
