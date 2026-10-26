@tool
extends StatusModifierComponent
class_name Status_PreventPlayerOrgasm

### While a status or passive of the player has this, the player cannot orgasm. They still receive Pleasure as normal, and it keeps
### building past their max (350 / 100); when the effect is gone, everything held back is released at once (350 of 100 = 3 orgasms and
### 50 left). An effect that forces an orgasm does nothing meanwhile. Nothing needs to run on a context: GameState.player_cannot_orgasm()
### finds the component by scanning the player's statuses and passives, like Status_DisablePlayerActions and Status_BlindPlayer.
### MainCardgame checks again every time a status or passive leaves the player (_check_for_pending_player_orgasms()).

### Generic description support (see DescriptionBuilder): "Cannot Orgasm".
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("STATUS_PREVENTPLAYERORGASM_TEMPLATE"))
