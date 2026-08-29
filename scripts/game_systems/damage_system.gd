extends GameSystem
class_name DamageSystem


const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

enum DamagePhase {
	OUTGOING,
	INCOMING
}

#func go_from_outgoing_to_incoming(effect_context: EffectContext) -> void:
	#if effect_context.damage_phase == DamagePhase.OUTGOING:
		#effect_context.damage_phase = DamagePhase.INCOMING
		#return
	##effect_context.damage_phase = DamagePhase.INCOMING
	#push_error("DamageSystem: go_from_outgoing_to_incoming was passed effect_context without DamagePhase.OUTGOING")


#func apply_source_and_target_damage_modifications(context: EffectContext,
	#source: TargetEntity, target: TargetEntity, original_damage: int) -> int:
	#var damage_modified_by_source: float = float(original_damage)
	#if context.damage_phase == DamageSystem.DamagePhase.OUTGOING:
		#damage_modified_by_source *= StatusSystem.get_outgoing_damage_multiplier(context)
	#go_from_outgoing_to_incoming(context)
	#var damage_modified_by_target = damage_modified_by_source*StatusSystem.get_incoming_damage_multiplier(context,target)
	#if damage_modified_by_source != original_damage or damage_modified_by_target != original_damage:
		#var fragment: LogFragment = LogFragment.make_new_log_fragment(
			#"DamageSystem_modified_damage_in_context_based_on_statuses",
			#{"source":source,
			#"target":target,
			#"origial_damage":original_damage,
			#"damage_modified_by_source":damage_modified_by_source,
			#"damage_modified_by_target":damage_modified_by_target},
			#[LogFragment.LogTags.DAMAGE_SYSTEM_MODIFIED_DAMAGE],
			#context
		#)
		#main_game.request_adding_fragment_to_log(fragment)
	#return int(damage_modified_by_target)
