extends Resource
class_name TutorialStage

@export var stage_id: String ### The action that was performed to get you here.
@export var prompt_text: String = ""
@export var completion_action: String ### The action that needs to be completed.
@export var timeout_seconds: float = 0.0
@export var hint_delay: float = 1.0
@export var prompt_global_location: Vector2 = Vector2(100,100)

@export var highlighed_nodes: Array[String] = []
