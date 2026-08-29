extends PanelContainer
class_name UnlockRequirementPanel

@export var description: RichTextLabel
@export var condition_met_box: TextureRect

func display_condition_status(reward_id: String, condition: UnlockCondition,save_game_state: SaveGameState) -> void:
	if not condition:
		return
	var is_condition_met: bool = condition.is_condition_met(save_game_state,null)
	if is_condition_met or save_game_state.is_reward_unlocked(reward_id):
		condition_met_box.visible = true
		
	description.text = ""
	
	var condition_type: Script = condition.get_script()
	match condition_type:
		Condition_LifetimeOrgasmCount:
			var count: int = condition.required_count
			description.text = tr("UI_UNLOCK_CONDITION_LIFETIME_ORGASMS") %count
		Condition_HasPlayedCardNTimes:
			var card_id: String = condition.event_card_id
			var required_nr_of_plays: int = condition.required_nr_of_plays
			var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
			var card_name: String = card_def.card_name
			description.text = tr("UI_UNLOCK_CONDITION_PLAYED_CARD_N_TIMES")%[card_name,required_nr_of_plays]
			pass
		Condition_HasDefeatedXOpponents:
			var no_to_defeat: int = condition.required_number
			var current_number: int = save_game_state.get_nr_of_defeated_opponents()
			description.text = tr("UI_UNLOCK_CONDITION_DEFEATED_X_OPPONENTS")%[no_to_defeat,current_number,no_to_defeat]
		Condition_IsEncounterCleared:
			var encounter_name: String = AutoloadDatabase.encounter_definitions[condition.encounter_id].encounter_display_name
			var formatted_encounter_name: String = "[b][i]"+encounter_name+"[/i]"
			description.text = tr("UI_UNLOCK_CONDITION_ENCOUNTER_CLEARED")%formatted_encounter_name
		Condition_OnlyUseCertainActionsForGivenEncounter:
			var encounter_name: String = AutoloadDatabase.encounter_definitions[condition.encounter_id].encounter_display_name
			var start_string: String = tr("UI_UNLOCK_CONDITION_ONLY_USE_ACTIONS_TEMPLATE")%encounter_name
			var replacement_actions_list: String = ""
			for action_id in condition.action_ids:
				var action_name: String = AutoloadDatabase.player_actions_by_id[action_id].action_name
				replacement_actions_list += "[b]"+action_name+"[/b]"
				if condition.action_ids.find(action_id) < condition.action_ids.size()-1:
					if condition.action_ids.size()> 2:
						replacement_actions_list += ", "
					else:
						replacement_actions_list += " "
				if condition.action_ids.find(action_id) == condition.action_ids.size()-2:
					replacement_actions_list += tr("UI_UNLOCK_CONDITION_AND_LABEL")
			var final_string: String = start_string + replacement_actions_list
			description.text = final_string
			### Check description if it is there
			if condition.action_ids.is_empty():
				description.text = tr("UI_UNLOCK_CONDITION_NO_ACTIONS_USED")
			
		Condition_RewardIsUnlocked:
			var required_reward: RewardDefinition = AutoloadDatabase.get_unlock_reward_definition(condition.reward_id)
			var reward_name: String = required_reward.reward_name
			var text: String = tr("UI_UNLOCK_CONDITION_REWARD_UNLOCKED")%reward_name
			description.text = text
		Condition_DefeatNOppsWithActions:
			var action_names: Array[String]
			var current_number: int = 0
			for action_id in condition.action_ids:
				action_names.append(AutoloadDatabase.player_actions_by_id[action_id].action_name)
				current_number += save_game_state.get_opponents_defeated_by_action(action_id)
			var number_to_beat: String = str(condition.number_to_defeat)
			var action_name_list: String = ""
			for action_id in condition.action_ids:
				var action_name: String = AutoloadDatabase.player_actions_by_id[action_id].action_name
				action_name_list += action_name
				if condition.action_ids.find(action_id) < condition.action_ids.size()-2:
					action_name_list += ", "
				if condition.action_ids.find(action_id) == condition.action_ids.size()-2:
					action_name_list += tr("UI_UNLOCK_CONDITION_OR_LABEL")
			description.text = tr("UI_UNLOCK_CONDITION_DEFEAT_WITH_ACTIONS")%[number_to_beat,action_name_list,current_number,number_to_beat]
		Condition_ClearGivenEncounterWithoutUsingSpecifiedActions:
			var action_names: Array[String]
			var encounter_name: String = AutoloadDatabase.encounter_definitions[condition.encounter_id].encounter_display_name
			for action_id in condition.action_ids:
				action_names.append(AutoloadDatabase.player_actions_by_id[action_id].action_name)
			var action_name_list: String = ""
			for action_id in condition.action_ids:
				var action_name: String = AutoloadDatabase.player_actions_by_id[action_id].action_name
				action_name_list += action_name
				if condition.action_ids.find(action_id) < condition.action_ids.size()-2:
					action_name_list += ", "
				if condition.action_ids.find(action_id) == condition.action_ids.size()-2:
					action_name_list += tr("UI_UNLOCK_CONDITION_AND_LABEL_SPACED")
			description.text = tr("UI_UNLOCK_CONDITION_CLEAR_WITHOUT_ACTIONS")%[encounter_name,action_name_list]
		Condition_MakeGuysCumWIthActivePassive_Resetable:
			var passive_id: String = condition.passive_id
			var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
			var passive_name: String = passive_def.passive_name
			var needed_count: int = condition.count
			var current_count: int = 0
			if condition.unlock_condition_id in save_game_state.condition_tracking.keys():
					current_count = save_game_state.condition_tracking[condition.unlock_condition_id]
	
			description.text = tr("UI_UNLOCK_CONDITION_CUM_WITH_PASSIVE")%[
				needed_count,passive_name,current_count,needed_count
			]
		Condition_DefeatNOpponentsWithPassive:
			var passive_id: String = condition.passive_id
			var count: int = save_game_state.get_defeated_opponents_with_passive(passive_id)
			var max_count: int = condition.number_to_defeat
			description.text = condition.description + tr("UI_UNLOCK_CONDITION_PROGRESS_SUFFIX")%[count,max_count]
		Condition_MakeNGuysCumInOneTurn:
			var nr_to_make_cum: int = condition.required_count
			description.text = tr("UI_UNLOCK_CONDITION_CUM_ONE_TURN_ANY") %nr_to_make_cum
		Condition_SimultaneousCumInGivenEncounter:
			var nr_to_make_cum: int = condition.required_count
			var encounter_id: String = condition.encounter_id
			var encounter_def: EncounterDefinition = AutoloadDatabase.get_encounter_def_by_id(encounter_id)
			var encounter_name: String = encounter_def.encounter_display_name
			description.text = tr("UI_UNLOCK_CONDITION_CUM_ONE_TURN_ENCOUNTER")%[
				nr_to_make_cum,encounter_name]
		Condition_WinEncounterWithActivePassive:
			var encounter_id: String = condition.encounter_id
			var encounter_def: EncounterDefinition = AutoloadDatabase.get_encounter_def_by_id(encounter_id)
			var encounter_name: String = encounter_def.encounter_display_name
			
			var passive_id: String = condition.passive_id
			var passive_def: PassiveEffectDefinition = AutoloadDatabase.get_passive_effect_def(passive_id)
			var passive_name: String = passive_def.passive_name
			description.text = tr("UI_UNLOCK_CONDITION_WIN_WITH_PASSIVE")%[encounter_name,passive_name]

		Condition_WinByTurnN:
			var turn: int = condition.turn_to_win_by
			var encounter_id: String = condition.encounter_id
			var encounter_def: EncounterDefinition = AutoloadDatabase.get_encounter_def_by_id(encounter_id)
			var encounter_name: String = encounter_def.encounter_display_name
			description.text = tr("UI_UNLOCK_CONDITION_WIN_BY_TURN")%[encounter_name,turn]
		Condition_OrgasmNTimesAndWinEncounter:
			var orgasms_needed: int = condition.required_count
			var encounter_id: String = condition.encounter_id
			var encounter_def: EncounterDefinition = AutoloadDatabase.get_encounter_def_by_id(encounter_id)
			var encounter_name: String = encounter_def.encounter_display_name
			description.text = tr("UI_UNLOCK_CONDITION_ORGASM_AND_WIN") %[orgasms_needed,encounter_name]
		Condition_PlayCardsGivenTimeInEncounter:
			var encounter_id: String = condition.encounter_id
			var encounter_def: EncounterDefinition = AutoloadDatabase.get_encounter_def_by_id(encounter_id)
			var encounter_name: String = encounter_def.encounter_display_name
			var cards_needed: Dictionary[String,int] = condition.cards_to_play
			var cards_to_play_string: String = tr("UI_UNLOCK_CONDITION_PLAY_CARDS_TEMPLATE")%encounter_name
			var size_of_dict: int = cards_needed.keys().size()
			var count: int = 1
			for card_id in cards_needed.keys():
				var card_def: EventCardDefinition = AutoloadDatabase.get_event_card_def_by_id(card_id)
				var card_name: String = card_def.card_name
				var card_count: int = cards_needed[card_id]
				var card_string: String = "[b][i]"+card_name+ "[/i] ("+str(card_count)+")[/b]"
				if count < size_of_dict:
					card_string +=", "
				count += 1
				cards_to_play_string += card_string
			
			description.text = cards_to_play_string
		
		
	if description.text == "":
		description.text = condition.description
