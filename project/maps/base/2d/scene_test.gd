##
## project/maps/base/2d/scene_test.gd
##
## Unit tests for the `ProjectMap2D` projection methods that bridge SubViewport-local
## coordinates with HUD-space coordinates.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const TOLERANCE := Vector2(0.001, 0.001)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _map: ProjectMap2D = null
var _container: SubViewportContainer = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_world_to_hud_identity_default_transforms() -> void:
	# Given: Default transforms (no scale, position, or canvas offset).
	# When: A world position is projected.
	var hud := _map.world_to_hud_2d(Vector2(10, 20))
	# Then: The HUD position equals the world position.
	assert_almost_eq(hud, Vector2(10, 20), TOLERANCE)


func test_world_to_hud_with_container_position() -> void:
	# Given: The container is positioned at (100, 50).
	_container.position = Vector2(100, 50)
	# When: World origin is projected.
	var hud := _map.world_to_hud_2d(Vector2.ZERO)
	# Then: HUD position reflects the container offset.
	assert_almost_eq(hud, Vector2(100, 50), TOLERANCE)


func test_world_to_hud_with_container_scale() -> void:
	# Given: The container is scaled (2, 2).
	_container.scale = Vector2(2, 2)
	# When: World (10, 5) is projected.
	var hud := _map.world_to_hud_2d(Vector2(10, 5))
	# Then: HUD position is doubled in both axes.
	assert_almost_eq(hud, Vector2(20, 10), TOLERANCE)


func test_world_to_hud_with_canvas_transform() -> void:
	# Given: A camera-style canvas_transform offset.
	_viewport.canvas_transform = Transform2D(0.0, Vector2(-50, -25))
	# When: World origin is projected.
	var hud := _map.world_to_hud_2d(Vector2.ZERO)
	# Then: HUD reflects the canvas offset.
	assert_almost_eq(hud, Vector2(-50, -25), TOLERANCE)


func test_world_to_hud_combined_transforms() -> void:
	# Given: Non-trivial scale, container position, and canvas offset.
	_container.scale = Vector2(2, 3)
	_container.position = Vector2(100, 50)
	_viewport.canvas_transform = Transform2D(0.0, Vector2(-10, -20))
	# When: World (5, 5) is projected.
	# Then: viewport = world + canvas_offset = (-5, -15);
	#       hud = container_pos + scale * viewport = (100 + 2*-5, 50 + 3*-15) = (90, 5).
	var hud := _map.world_to_hud_2d(Vector2(5, 5))
	assert_almost_eq(hud, Vector2(90, 5), TOLERANCE)


func test_world_to_hud_stretch_with_shrink_2() -> void:
	# Given: A stretching container with `stretch_shrink = 2`. The container will
	# auto-resize the SubViewport to `container.size / 2` once the next frame ticks.
	_container.stretch = true
	_container.stretch_shrink = 2
	await wait_process_frames(1)
	# When: World (10, 5) is projected.
	var hud := _map.world_to_hud_2d(Vector2(10, 5))
	# Then: Visual scale is 2x (640/320 = 2).
	assert_almost_eq(hud, Vector2(20, 10), TOLERANCE)


func test_world_to_hud_stretch_with_canvas_transform() -> void:
	# Given: A stretching container (shrink=2) AND a translated canvas_transform.
	_container.stretch = true
	_container.stretch_shrink = 2
	await wait_process_frames(1)
	_viewport.canvas_transform = Transform2D(0.0, Vector2(-10, -20))
	# When: World (15, 25) is projected.
	# Then: viewport = (5, 5); visual scale = 2; HUD = (10, 10).
	var hud := _map.world_to_hud_2d(Vector2(15, 25))
	assert_almost_eq(hud, Vector2(10, 10), TOLERANCE)


func test_world_to_hud_stretch_with_container_scale() -> void:
	# Given: A stretching container (shrink=2) AND a container scale of 3x.
	_container.stretch = true
	_container.stretch_shrink = 2
	_container.scale = Vector2(3, 3)
	await wait_process_frames(1)
	# When: World (10, 5) is projected.
	# Then: visual scale = 2 (stretch); container scale = 3; total = 6.
	var hud := _map.world_to_hud_2d(Vector2(10, 5))
	assert_almost_eq(hud, Vector2(60, 30), TOLERANCE)


func test_no_subviewport_passthrough() -> void:
	# Given: A map with no SubViewport.
	_map.sub_viewport = null
	# When: Bridge methods are called.
	var v := Vector2(42, 84)
	# Then: Input is returned unchanged.
	assert_almost_eq(_map.viewport_to_hud(v), v, TOLERANCE)
	assert_almost_eq(_map.world_to_hud_2d(v), v, TOLERANCE)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	add_child_autofree(root)

	_map = partial_double(ProjectMap2D).new()
	stub(_map, "_ready").to_do_nothing()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_map)

	_container = SubViewportContainer.new()
	_container.stretch = false
	_container.size = Vector2(640, 360)
	_map.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_container.add_child(_viewport)

	_map.sub_viewport = _viewport
