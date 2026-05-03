##
## project/maps/base/3d/scene_test.gd
##
## Unit tests for the `ProjectMap3D` `world_to_hud_3d` projection method.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ProjectMap3DScript := preload("res://project/maps/base/3d/scene.gd")

const TOLERANCE := Vector2(1.0, 1.0)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _map: ProjectMap3D = null
var _container: SubViewportContainer = null
var _viewport: SubViewport = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_in_front_returns_finite() -> void:
	# Given: A camera at (0, 0, 5) looking at the origin.
	_install_camera(Vector3(0, 0, 5))
	# When: The world origin is projected.
	var hud := _map.world_to_hud_3d(Vector3.ZERO)
	# Then: The result is finite (i.e. not the INF sentinel).
	assert_true(hud.is_finite(), "expected finite HUD position; got %s" % hud)


func test_behind_camera_returns_inf() -> void:
	# Given: A camera at (0, 0, 5) looking down -Z.
	_install_camera(Vector3(0, 0, 5))
	# When: A position behind the camera (further +Z) is projected.
	var hud := _map.world_to_hud_3d(Vector3(0, 0, 10))
	# Then: The result is `Vector2.INF`.
	assert_false(hud.is_finite(), "expected INF for behind-camera position")


func test_no_camera_returns_inf() -> void:
	# Given: A SubViewport with no Camera3D.
	# When: A world position is projected.
	var hud := _map.world_to_hud_3d(Vector3.ZERO)
	# Then: The result is `Vector2.INF`.
	assert_false(hud.is_finite(), "expected INF when no camera is active")


func test_no_subviewport_returns_inf() -> void:
	# Given: A map with no SubViewport reference.
	_map.sub_viewport = null
	# When: A world position is projected.
	var hud := _map.world_to_hud_3d(Vector3.ZERO)
	# Then: The result is `Vector2.INF`.
	assert_false(hud.is_finite(), "expected INF when sub_viewport is null")


func test_explicit_camera_arg_used() -> void:
	# Given: An active camera at (0, 0, 5) AND a non-active camera at (10, 0, 5).
	var active := _install_camera(Vector3(0, 0, 5))
	var explicit := Camera3D.new()
	explicit.current = false
	_viewport.add_child(explicit)
	explicit.global_transform = Transform3D(Basis(), Vector3(10, 0, 5))
	# When: The world origin is projected through the explicit camera.
	var hud_explicit := _map.world_to_hud_3d(Vector3.ZERO, explicit)
	# And: Through the active camera.
	var hud_active := _map.world_to_hud_3d(Vector3.ZERO, active)
	# Then: Both are finite, and the explicit-camera projection differs (camera offset
	# shifts the projected x-coordinate).
	assert_true(hud_explicit.is_finite())
	assert_true(hud_active.is_finite())
	assert_ne(
		hud_explicit.x, hud_active.x, "explicit camera should produce a different x"
	)


func test_off_frustum_returns_finite() -> void:
	# Given: A camera at (0, 0, 5) looking at the origin.
	_install_camera(Vector3(0, 0, 5))
	# When: A point well above the frustum (but still in front of the camera) is
	# projected. Tests the documented contract that off-screen-indicator widgets get
	# finite (clampable) coords rather than INF.
	var hud := _map.world_to_hud_3d(Vector3(0, 1000, 0))
	# Then: The result is finite (off-screen, but not INF).
	assert_true(
		hud.is_finite(), "off-frustum-but-in-front should be finite; got %s" % hud
	)


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_each() -> void:
	var root := Control.new()
	root.size = Vector2(1920, 1080)
	add_child_autofree(root)

	_map = partial_double(ProjectMap3DScript).new()
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


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _install_camera(at: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	camera.current = true
	_viewport.add_child(camera)
	camera.global_transform = Transform3D(Basis(), at)
	return camera
