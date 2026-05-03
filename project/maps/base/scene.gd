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
##   └── HUD                      (Control, full-rect; optional, native resolution)
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

	var container := _get_container()
	if container and container.stretch and container.stretch_shrink <= 0:
		warnings.append(
			"SubViewportContainer.stretch_shrink must be >= 1 when stretching"
		)

	return warnings


func _ready():
	if Engine.is_editor_hint():
		return

	_save_data = Main.get_active_save_data()
	if not _save_data:
		Main.go_to_main_menu()  # TODO: Add better error handling.
		return


# -- PUBLIC METHODS ------------------------------------------------------------------ #


## viewport_to_hud projects a SubViewport-local position to HUD-space coordinates by
## applying any stretch-mode visual scale, then the SubViewportContainer's global
## transform.
func viewport_to_hud(viewport_pos: Vector2) -> Vector2:
	var container := _get_container()
	if not container:
		return viewport_pos
	return container.get_global_transform() * (viewport_pos * _container_visual_scale())


## world_to_hud_2d projects a 2D world position to HUD-space coordinates.
func world_to_hud_2d(world_pos: Vector2) -> Vector2:
	return viewport_to_hud(_world_to_viewport_2d(world_pos))


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _world_to_viewport_2d converts a world-space position to SubViewport-local coordinates.
## Override for custom camera behavior.
##
## NOTE: This is invoked from `_process` callers, which read the un-rounded
## `canvas_transform`. The 2D pixel base mutates `canvas_transform` during
## `frame_pre_draw`; callers/overrides must not invoke this after that signal has fired
## or HUD widgets will misalign from rendered world content.
func _world_to_viewport_2d(world_pos: Vector2) -> Vector2:
	if not sub_viewport:
		return world_pos
	return sub_viewport.canvas_transform * world_pos


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _container_visual_scale returns the per-axis scale factor applied between
## SubViewport-local pixels and SubViewportContainer-local pixels. Returns `Vector2.ONE`
## when the container is not stretching its viewport (`stretch == false`); in that case
## the visual scale is captured by `container.global_transform` instead.
func _container_visual_scale() -> Vector2:
	var container := _get_container()
	if not container or not sub_viewport:
		return Vector2.ONE
	if not container.stretch:
		return Vector2.ONE
	var v_size := Vector2(sub_viewport.size)
	if v_size.x <= 0 or v_size.y <= 0:
		return Vector2.ONE
	return container.size / v_size


func _get_container() -> SubViewportContainer:
	if not sub_viewport:
		return null
	return sub_viewport.get_parent() as SubViewportContainer
