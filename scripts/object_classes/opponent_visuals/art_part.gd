@tool
extends Resource
class_name ArtPart

@export var category: ArtCategory
@export var texture: Texture2D

### Added to the sprite's own offset. Sprites are drawn centred, so art exported on a taller or wider
### canvas than the 1640x2654 one (e.g. the 2948-high hair styles) must be shifted by half the size
### difference to line up with the body and face: (0, -147) for 2948.
@export var offset: Vector2 = Vector2.ZERO

@export var use_skin_palette: bool = false
@export var use_hair_palette: bool = false
