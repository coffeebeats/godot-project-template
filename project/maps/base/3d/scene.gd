##
## project/maps/base/3d/scene.gd
##
## Base scene for 3D games. Renders the game world in a `SubViewport` with Forward+
## rendering. Settings observers on the scene apply render quality and anti-aliasing
## configuration to the viewport.
##

@tool
class_name ProjectMap3D
extends "res://project/maps/base/scene.gd"

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## world_to_hud_3d projects a 3D world position to HUD-space coordinates. If `camera` is
## null, the SubViewport's active camera is used.
##
## Returns `Vector2.INF` (check via `pos.is_finite()`) when the position cannot be
## projected: no SubViewport, no active or supplied camera, or the position is behind the
## camera. Off-frustum positions to the sides/above/below the view still project to
## finite (off-screen) HUD coords; this is intentional, so off-screen-indicator widgets
## can clamp them to viewport edges.
func world_to_hud_3d(
	world_pos: Vector3,
	camera: Camera3D = null,
) -> Vector2:
	if not sub_viewport:
		return Vector2.INF

	if not camera:
		camera = sub_viewport.get_camera_3d()
	if not camera:
		return Vector2.INF

	if camera.is_position_behind(world_pos):
		return Vector2.INF

	var viewport_pos := camera.unproject_position(world_pos)
	return viewport_to_hud(viewport_pos)
