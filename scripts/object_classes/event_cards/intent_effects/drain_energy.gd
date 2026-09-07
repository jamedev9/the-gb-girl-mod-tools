@tool
extends EffectIntent
class_name DrainPlayerEnergy

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	var player: PlayerEntity = PlayerEntity.new(game_state)
	var energy_to_drain: int = player.get_player_energy()
	
	context.energy_delta = energy_to_drain
	context.energy_reason = EffectContext.EnergyReason.EVENT_CARD_EFFECT

	return context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("EFFECTINTENT_DRAINPLAYERENERGY_TEMPLATE"))

func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
