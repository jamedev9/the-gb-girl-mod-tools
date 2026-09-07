@tool
extends MultiplyDamage
class_name MultiplyDamageIfUnderPlayerActions

@export var action_ids: Array[String]

func modify_context(context: EffectContext) -> void:
	if not context.damage_amount:
		return
	if not context.damage_phase == self.damage_phase:
		return
	if context.source is not OpponentEntity:
		return
	if action_ids.is_empty():
		return
	var opponent_id: String = context.source.get_opponent_id()
	var action_on_source: String = context.game_state.get_action_assigned_to_opponent(opponent_id)
	if action_on_source in action_ids:
		context.damage_multipliers.append(self.multiplier)

### Generic description support (see DescriptionBuilder). Reuses MultiplyDamage's own
### classification/wording (parent's get_description_segments()) and appends a condition clause
### naming which assigned action(s) gate the effect - "Cannot give Pleasure as long as X is
### active" rather than duplicating the blocked/increased/reduced/inverted branching here too.
func get_description_segments() -> Array[DescriptionSegment]:
	var base_segments: Array[DescriptionSegment] = super.get_description_segments()
	if action_ids.is_empty():
		return base_segments
	var agreement: String = _agreement_verb(action_ids.size(), "VERB_IS_SINGULAR", "VERB_IS_PLURAL")
	var suffix: Array[DescriptionSegment] = DescriptionBuilder.parse_template(
		tr("MULTIPLYDAMAGEIFUNDERPLAYERACTIONS_CONDITION_SUFFIX_TEMPLATE"),
		{"action_names": _action_names(action_ids), "agreement": agreement})
	base_segments.append(DescriptionSegment.text_segment(" "))
	base_segments.append_array(suffix)
	return base_segments
