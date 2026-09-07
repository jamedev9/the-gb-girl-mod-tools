@tool
extends StatusTickComponent
class_name DamageOverTime

#@export var damage_each_turn: int

#func apply_effect_to_context(effect_context: EffectContext) -> void:
	#if not effect_context.damage_phase == DamageSystem.DamagePhase.INCOMING:
		#return
	#if not effect_context.damage_amount:
		#effect_context.damage_amount = 0
	#effect_context.damage_amount += damage_each_turn
	#return effect_context

#func create_tick_intent_context() -> EffectContext:
	#var ctx: EffectContext = EffectContext.new()
	#ctx.damage_amount = damage_each_turn
	#return ctx
