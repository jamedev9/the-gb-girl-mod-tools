@tool
extends TriggerCondition
class_name TriggerCondition_OwnerOfTriggerIsTargeted


func is_condition_met(
	input_context: EffectContext,_game_state: GameState,_save_game_state: SaveGameState,owner_of_trigger: TargetEntity) -> bool:

	return input_context.target.get_data() == owner_of_trigger.get_data()

### Subjectless ("targeted", not "you are targeted") - whoever owns this trigger could be the
### player or an opponent, see PassiveEffectDefinition's note on ownership-agnostic wording.
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_OWNEROFTRIGGERISTARGETED_TEMPLATE"))
