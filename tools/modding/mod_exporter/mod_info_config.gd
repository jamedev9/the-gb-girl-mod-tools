@tool
extends EditorScript

const MOD_NAME: String = "YourModNameHere"  ### edit these two lines, then run once
const AUTHOR: String = "ModAuhorName"
const MOD_VERSION: String = "1.0.0"

func _run() -> void:
	ModConfig.save(MOD_NAME, AUTHOR, MOD_VERSION)
	print("Mod config saved to user://. You can re-run this anytime to update the name/author.")
