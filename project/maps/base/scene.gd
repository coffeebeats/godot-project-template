##
## project/maps/base/scene.gd
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
##   ├── SubViewportContainer     (full-rect or scaled)
##   │   └── SubViewport          (export: 'sub_viewport')
##   │       └── [game world]
##   └── UI                       (Control, full-rect; optional, native resolution)
##
## NOTE: `StdScreen.pause_when_covered` disables the entire SubViewport subtree.
## Godot #79665: paused SubViewport descendants won't receive input, even with
## `process_mode = ALWAYS`.
##
## NOTE: Godot #100755: changing scenes while a SubViewport shares the main viewport's
## `World2D` can crash. Null `SubViewport.world_2d` in `_exit_tree()` if sharing.
##

@tool
class_name ProjectMap
extends Control

# -- CONFIGURATION ------------------------------------------------------------------- #

## sub_viewport is a `SubViewport` that renders the game world at a specific resolution.
@export var sub_viewport: SubViewport = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _save_data: ProjectSaveData = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_save_data = null

	# NOTE: Godot #100755 - null `world_2d` to prevent crash when changing scenes while
	# a `SubViewport` shares the main viewport's `World2D`.
	if sub_viewport and sub_viewport.world_2d == get_viewport().world_2d:
		sub_viewport.world_2d = null


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
		Main.go_to_main_menu()  # TODO: Add better error handling.
		return


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_screen_rect returns the screen-space rect that the `SubViewport`'s contents
## occupy.
func get_screen_rect() -> Rect2:
	var container := _get_container()
	return container.get_global_rect() if container else Rect2()


## viewport_to_screen projects a `SubViewport`-local position to screen-space
## coordinates by applying any stretch-mode visual scale, then the
## `SubViewportContainer`'s global transform.
func viewport_to_screen(p: Vector2) -> Vector2:
	var container := _get_container()
	if not container:
		return p

	return container.get_global_transform() * (p * _get_visual_scale())


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _get_visual_scale returns the per-axis scale factor applied between `SubViewport`-
## local pixels and `SubViewportContainer`-local pixels.
func _get_visual_scale() -> Vector2:
	var container := _get_container()

	if not container or not sub_viewport:
		return Vector2.ONE
	if not container.stretch:
		return Vector2.ONE

	if sub_viewport.size.x <= 0 or sub_viewport.size.y <= 0:
		return Vector2.ONE

	return container.size / Vector2(sub_viewport.size)


func _get_container() -> SubViewportContainer:
	return sub_viewport.get_parent() as SubViewportContainer if sub_viewport else null
