extends Resource
class_name CardInstance

enum CardPermanence{
	PERMANENT, # Always in the deck.
	TEMPORARY, # Deleted when moved out of players hand.
	REWARD, # 
	PROBLEM, # Added by opponents/encounters to make things difficult
	ONCE_PER_GAME # Permanent, but only playable once. Deleted from deck once resolved.
}
