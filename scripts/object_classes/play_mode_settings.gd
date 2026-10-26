class_name PlayModeSettings

### Which track the game is running as. Set once, before anything reads it, by the root scene
### i.e. before any child's _ready). Read it wherever the two tracks must behave differently.
### Static rather than an autoload: it has no behaviour, only a value.

enum Mode {
	DEFAULT, ## The prototype: loads all current content, legacy slot-numbered saves.
	FULL_REWORK, ## The rework track: unique-id saves (and, later, only carried-over content).
}

static var current: Mode = Mode.DEFAULT

### set's art (opponent appearances, action art parts, replacement art, keyword icons), so the prototype
### here, so it does nothing when those files aren't shipped.
static var include_rework_content_in_default: bool = false

static func uses_rework_content() -> bool:
	return current == Mode.FULL_REWORK or include_rework_content_in_default
