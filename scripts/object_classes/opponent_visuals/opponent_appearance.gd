@tool
extends Resource
class_name OpponentAppearance

@export var id: String

@export var parts: Array[ArtPart] = []

### Recolours the skin parts (ArtPart.use_skin_palette). Null = the art as drawn.
@export var skin_palette: SkinPalette

### Recolours the hair parts (ArtPart.use_hair_palette). Null = the art as drawn.
@export var hair_palette: HairPalette

const HAIR_CATEGORY_ID: String = "hair"

func has_hair() -> bool:
	for part in parts:
		if part != null and part.category != null and part.category.id == HAIR_CATEGORY_ID:
			return true
	return false
