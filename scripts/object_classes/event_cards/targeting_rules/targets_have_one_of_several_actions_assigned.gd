@tool
extends TargetingRule
class_name TargetsHaveOneOfSeveralActionsAssigned

@export var action_ids: Array[String]

### Despite the class name, this targets EVERY opponent matching ANY of action_ids, not a
### single either/or pick - e.g. Spitroast hits both whoever has Blowjob assigned and whoever
### has Vaginal assigned, not one or the other. So the list reads "your Blowjob and Vaginal
### Action", not "...or...". And since a single opponent can only ever have one action
### assigned at a time, more than one action_id necessarily means potentially multiple
### DIFFERENT opponents match - "the Partners with your Blowjob and Vaginal Actions", plural,
### not "the Partner...Action", singular. See TargetingRule.targets_potentially_multiple().
func targets_potentially_multiple() -> bool:
	return action_ids.size() > 1

func get_description_segments() -> Array[DescriptionSegment]:
	var action_names: Array[String] = []
	for id in action_ids:
		var action_def: PlayerAction = AutoloadDatabase.get_player_action_by_id(id)
		action_names.append(action_def.get_action_name() if action_def else "?")
	var key: String = ("TARGETINGRULE_TARGETSHAVEONEOFSEVERALACTIONSASSIGNED_TEMPLATE_PLURAL"
		if targets_potentially_multiple() else "TARGETINGRULE_TARGETSHAVEONEOFSEVERALACTIONSASSIGNED_TEMPLATE")
	return DescriptionBuilder.parse_template(
		tr(key), {"action_names": DescriptionBuilder.join_with_and(action_names)})
