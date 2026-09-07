extends Control
class_name Metagame_UI_Element

@onready var main_game: Node = get_tree().get_current_scene()
@onready var meta_game: Node = main_game.meta_game

signal tooltip_requested(tooltip_id: Cardgame_UI_Element.TooltipId ,source_node: Control)
signal tooltip_cleared(source_node: Control)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#meta_game.connect("new_save_state_initialized",Callable(self,"connect_to_new_save_state"))
	meta_game.connect("save_game_state_changed",Callable(self,"update_when_save_game_changes"))
	#meta_game.connect("save_game_state_changed",Callable(self,"_update_when_save_game_changes_and_print_duration"))
	meta_game.connect("meta_game_enter_finished", Callable(self,"update_on_meta_game_enter_finished"))
	connect("tooltip_requested",Callable(main_game.popup_controller,"_handle_tooltip_request"))
	connect("tooltip_cleared",Callable(main_game.popup_controller,"_handle_clear_tooltip_request"))

func _update_when_save_game_changes_and_print_duration(_save_game_state: SaveGameState) -> void:
	var label: String = self.get_script().get_global_name()
	var p = Profiler.new(label)
	update_when_save_game_changes(_save_game_state)
	p.stop()
	

func update_when_save_game_changes(_save_game_state: SaveGameState) -> void:
	#overwritten by child classes
	pass


func update_on_meta_game_enter_finished(_save_game_state: SaveGameState) -> void:
	### overwritteing by child classes
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()

func _refresh_text() -> void:
	### For localization
	pass
