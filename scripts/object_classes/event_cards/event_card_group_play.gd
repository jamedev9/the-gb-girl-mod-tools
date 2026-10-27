extends RefCounted
class_name EventCardGroupPlay

### A drag with Ctrl held: the dragged card plus the other cards of the same type in the hand (the ones lifted with it). Kept
### up to date by the hand (FloatingPlayerHand) during the drag, as Ctrl is pressed and released, on
### MainCardgame.event_card_group_play; when the dragged card is dropped and played, MainCardgame._event_card_dropped() plays the
### copies right after it, one by one.

var dragged_card: EventCardInstance
### The other cards of the dragged card's type, in the order they are played (left to right in the hand).
var copies: Array[EventCardInstance] = []
### Filled by the drop: the copies that really were played, in order. Stays empty when the dragged card wasn't played.
var played_copies: Array[EventCardInstance] = []
