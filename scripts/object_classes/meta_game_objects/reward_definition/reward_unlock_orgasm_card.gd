@tool
extends RewardDefinition
class_name Reward_UnlockOrgasmCard

@export var orgasm_card_id: String

func get_referenced_content_ids() -> Dictionary:
	return {"cards": [orgasm_card_id]}

func apply_reward(save_game_state:SaveGameState) -> void:
	save_game_state.unlock_orgasm_card(orgasm_card_id)

### Shown as a reward card, like the orgasm card picker does; EventCard adds the Orgasm Card look itself (OrgasmEventCardDefinition).
func get_card_permanence_hints() -> Dictionary:
	return {orgasm_card_id: CardInstance.CardPermanence.REWARD}
