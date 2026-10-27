@tool
extends ModExportable
class_name OpponentActionStrategy

### How a Partner picks its next Move from OpponentType.get_available_actions(). Embedded in its opponent type; mod types
### write it through the generic JSON ("_class" + its own settings), so every strategy class must be in ModdableResourceRegistry.

func choose_action(_opponent: OpponentInstance, _context: EffectContext) -> OpponentActionDefinition:
	return null
