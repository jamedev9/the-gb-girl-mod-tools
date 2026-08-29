extends Button
class_name VideoTagButton

var represented_tag: VideoClip.ParticipantTags

signal tag_button_pressed(button: VideoTagButton)

#func _ready() -> void:
	#### test:
	#set_represented_tag(VideoClip.ParticipantTags.BLONDE)

func set_represented_tag(tag: VideoClip.ParticipantTags) -> void:
	self.represented_tag = tag
	self.text = VideoClip.ParticipantTags.keys()[tag].capitalize()


func _on_pressed() -> void:
	emit_signal("tag_button_pressed",self)
	pass # Replace with function body.
