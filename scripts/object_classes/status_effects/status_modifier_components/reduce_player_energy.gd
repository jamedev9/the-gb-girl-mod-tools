extends StatusModifierComponent
class_name Status_ReducePlayerEnergy

@export var energy_reduction: int
	
func modify_context(context: EffectContext) -> void:
	context.player_energy_reduction = self.energy_reduction
