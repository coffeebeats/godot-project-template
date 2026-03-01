##
## project/maps/scene.gd
##
## Base `@tool` script for game map scenes. Renders the game world in a `SubViewport`
## at a controlled resolution while UI stays at native resolution.
##
## Expected scene tree:
##
##   Scene (Control, full-rect)
##   ├── PausePusher              (StdScreenPusher; optional)
##   ├── StdInputActionSetLoader  (optional)
##   ├── StdSoundEmitter          (BGM; optional)
##   └── SubViewportContainer     (full-rect, stretch)
##       └── SubViewport          (export: 'sub_viewport')
##           └── [game world]
##
## NOTE: `StdScreen.pause_when_covered` disables the entire SubViewport subtree.
## Godot #79665: paused SubViewport descendants won't receive input, even with
## `process_mode = ALWAYS`.
##
## NOTE: Godot #100755: changing scenes while a SubViewport shares the main viewport's
## `World2D` can crash. Null `SubViewport.world_2d` in `_exit_tree()` if sharing.
##

@tool
extends Control

# -- CONFIGURATION ------------------------------------------------------------------- #

## sub_viewport is the `SubViewport` that renders the game world at a controlled
## resolution. Assign this in the scene editor.
@export var sub_viewport: SubViewport = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _save_data: ProjectSaveData = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_save_data = null

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not sub_viewport:
		warnings.append("Missing property: 'sub_viewport'")
	elif sub_viewport.get_child_count() == 0:
		warnings.append("SubViewport has no game world content")

	return warnings


func _ready():
	if Engine.is_editor_hint():
		return

	_save_data = Main.get_active_save_data()
	if not _save_data:
		Main.go_to_main_menu()
		return
