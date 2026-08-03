extends Node
class_name AnimationRouter

const GAME_TITLE: String = "The Gangbang Girl"
const DEVELOPER: String = "gb_girl_dev"
const COPYRIGHT: String = "2026"

@export var main_game: Node 

@export var handlers: Dictionary[String,AnimationHandler] = {} # message_key string -> AnimationHandler

func can_handle(fragment: LogFragment) -> bool:
	return handlers.has(fragment.message_key)
	
func play(fragment: LogFragment,animation_speed: float) -> void:
	if not can_handle(fragment):
		return
	await handlers[fragment.message_key].play_animation(fragment,main_game.entity_registry,animation_speed)
