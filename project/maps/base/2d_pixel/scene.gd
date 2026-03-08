##
## project/maps/base/pixel/scene.gd
##
## A base scene for 2D pixel art games which renders the game world in a `SubViewport`
## at low resolution with nearest-neighbor filtering and pixel snapping. A shader on the
## `SubViewportContainer` applies the sub-pixel camera remainder at native resolution,
## producing smooth scrolling without pixel shimmer.
##

@tool
class_name ProjectMapPixel2D
extends "res://project/maps/base/scene.gd"

# -- CONFIGURATION ------------------------------------------------------------------- #

## game_resolution is the `SubViewport`'s logical size in pixels; the `SubViewport`
## actually renders at this size + 2px border (hidden by the container's offset).
##
## NOTE: Choose a resolution that integer-divides into common display sizes.
@export var game_resolution := Vector2i(640, 360):
	set(value):
		game_resolution = value
		_apply_resolution()

# -- INITIALIZATION ------------------------------------------------------------------ #

var _shader_material: ShaderMaterial = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	super ()

	if not Engine.is_editor_hint():
		RenderingServer.frame_pre_draw.disconnect(_on_frame_pre_draw)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super ()

	if game_resolution.x <= 0 or game_resolution.y <= 0:
		warnings.append("'game_resolution' must be positive")

	return warnings


func _ready() -> void:
	# NOTE: Apply resolution *before* `super()` so the `SubViewport` is sized correctly
	# even if the base's save-data check fails and redirects to menu.
	_apply_resolution()

	var container := _get_container()
	if container:
		_shader_material = container.material as ShaderMaterial

	super ()

	if not Engine.is_editor_hint():
		RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _apply_resolution() -> void:
	if sub_viewport:
		sub_viewport.size = game_resolution + Vector2i(2, 2)


func _get_container() -> SubViewportContainer:
	return sub_viewport.get_parent() if sub_viewport else null


func _on_frame_pre_draw() -> void:
	if not sub_viewport or not _shader_material:
		return

	# NOTE: `canvas_transform` is a value type — the getter returns a copy.
	# The whole `Transform2D` must be reassigned, not just set `origin`.
	var transform := sub_viewport.canvas_transform
	var transform_rounded := transform.origin.round()
	var transform_remainder := transform.origin - transform_rounded
	transform.origin = transform_rounded
	sub_viewport.canvas_transform = transform

	# NOTE: `transform_remainder` is in `SubViewport` pixels; `vertex_offset` is in
	# container (screen) pixels. Scale the offset so 1 game pixel = N screen pixels.
	var container := _get_container()
	if not container:
		return

	var px_scale := container.size / Vector2(sub_viewport.size)
	_shader_material.set_shader_parameter(
		&"vertex_offset", transform_remainder * px_scale
	)
