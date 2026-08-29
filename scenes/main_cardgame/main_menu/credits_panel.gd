extends PanelContainer
class_name CreditsPanel


func _on_close_saved_games_button_pressed() -> void:
	hide_credits()


func hide_credits() -> void:
	self.hide()

func open_credits() -> void:
	self.show()
