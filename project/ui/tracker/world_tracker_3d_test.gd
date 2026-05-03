##
## project/ui/tracker/world_tracker_3d_test.gd
##
## Unit tests for `WorldTracker3D` — verifies the tracker drives its parent Control
## to follow a Node3D inside a ProjectMap3D's SubViewport, that misconfigurations
## fire startup assertions, and that behind-camera projections leave the host
## position unchanged.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ProjectMap3DScript := preload("res://project/maps/base/3d/scene.gd")
const WorldTracker3DScript := preload("res://project/ui/tracker/world_tracker_3d.gd")

const TOLERANCE := Vector2(1.0, 1.0)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _root: Control = null
var _map: ProjectMap3D = null
var _container: SubViewportContainer = null
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _target: Node3D = null
var _hud: Control = null
var _host: Control = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_positions_host_at_projection() -> void:
	# Given: A target at world origin and a camera at (0, 0, 5) looking down -Z.
	_target.global_position = Vector3.ZERO
	_attach_tracker(_host)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: Host position equals the projected world position.
	assert_almost_eq(
		_host.global_position,
		_map.world_to_hud_3d(_target.global_position),
		TOLERANCE,
	)


func test_offset_is_applied() -> void:
	# Given: A non-zero offset and a target at world origin.
	_target.global_position = Vector3.ZERO
	var tracker := _attach_tracker(_host)
	tracker.offset = Vector2(7, -13)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: Host position equals projection + offset.
	assert_almost_eq(
		_host.global_position,
		_map.world_to_hud_3d(_target.global_position) + Vector2(7, -13),
		TOLERANCE,
	)


func test_follows_target_movement() -> void:
	# Given: A target at world origin.
	_target.global_position = Vector3.ZERO
	_attach_tracker(_host)
	await wait_process_frames(1)
	var before := _host.global_position
	# When: The target moves to (1, 0, 0).
	_target.global_position = Vector3(1, 0, 0)
	await wait_process_frames(1)
	# Then: The host position shifts (along screen X, since camera is on +Z).
	assert_ne(_host.global_position, before)
	assert_true(_host.global_position.is_finite())


func test_no_op_when_target_freed() -> void:
	# Given: A tracker with a target.
	_target.global_position = Vector3.ZERO
	_attach_tracker(_host)
	await wait_process_frames(1)
	var last := _host.global_position
	# When: The target is freed.
	_target.free()
	await wait_process_frames(1)
	# Then: The tracker doesn't crash; host stays at its last position.
	assert_almost_eq(_host.global_position, last, TOLERANCE)


func test_no_op_when_behind_camera() -> void:
	# Given: A tracker with a target IN FRONT of the camera; first frame projects.
	_target.global_position = Vector3.ZERO
	_attach_tracker(_host)
	await wait_process_frames(1)
	var last := _host.global_position
	assert_true(last.is_finite(), "precondition: front-of-camera projects to finite")
	# When: The target moves behind the camera (further +Z than camera at z=5).
	_target.global_position = Vector3(0, 0, 10)
	await wait_process_frames(1)
	# Then: The host position is unchanged (NOT INF) — tracker skipped the update.
	assert_almost_eq(_host.global_position, last, TOLERANCE)


func test_parent_must_be_control_asserts() -> void:
	# Given: A tracker whose parent is a plain Node, not a Control.
	var bare_parent := Node.new()
	_root.add_child(bare_parent)
	# When: The tracker is added to that bare Node.
	_attach_tracker(bare_parent)
	await wait_process_frames(1)
	# Then: A startup assertion fires identifying the Control requirement.
	assert_engine_error("Control")


func test_target_outside_subviewport_asserts() -> void:
	# Given: A target node placed in the HUD subtree (NOT inside the SubViewport).
	var stray := Node3D.new()
	_hud.add_child(stray)
	_target = stray
	# When: A tracker is created pointing at that stray target.
	_attach_tracker(_host)
	await wait_process_frames(1)
	# Then: A startup assertion fires identifying the SubViewport requirement.
	assert_engine_error("sub_viewport")


func test_tree_order_invariant_asserts() -> void:
	# Given: HUD is moved BEFORE the SubViewportContainer in the map's children, so
	# the tracker (inside HUD) traverses earlier than the SubViewport.
	_map.move_child(_hud, 0)
	# When: A tracker is attached to the host inside the (now earlier) HUD subtree.
	_attach_tracker(_host)
	await wait_process_frames(1)
	# Then: A startup assertion fires identifying the tree-order requirement.
	assert_engine_error("later than")


# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)


func before_each() -> void:
	_root = Control.new()
	_root.size = Vector2(1920, 1080)
	add_child_autofree(_root)

	_map = partial_double(ProjectMap3DScript).new()
	stub(_map, "_ready").to_do_nothing()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_map)

	_container = SubViewportContainer.new()
	_container.stretch = false
	_container.size = Vector2(640, 360)
	_map.add_child(_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_container.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_viewport.add_child(_camera)
	_camera.global_transform = Transform3D(Basis(), Vector3(0, 0, 5))

	_target = Node3D.new()
	_viewport.add_child(_target)

	_map.sub_viewport = _viewport

	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.add_child(_hud)

	_host = Control.new()
	_hud.add_child(_host)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _attach_tracker(parent: Node) -> WorldTracker3D:
	var tracker := WorldTracker3DScript.new()
	tracker.map = _map
	tracker.target = _target
	parent.add_child(tracker)
	return tracker
