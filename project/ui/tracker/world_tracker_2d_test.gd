##
## project/ui/tracker/world_tracker_2d_test.gd
##
## Unit tests for `WorldTracker2D` — verifies the tracker drives its parent Control
## to follow a Node2D inside a ProjectMap's SubViewport, and that misconfigurations
## fire startup assertions instead of degrading silently.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

const ProjectMapScript := preload("res://project/maps/base/scene.gd")
const WorldTracker2DScript := preload("res://project/ui/tracker/world_tracker_2d.gd")

const TOLERANCE := Vector2(0.001, 0.001)

# -- INITIALIZATION ------------------------------------------------------------------ #

var _root: Control = null
var _map: ProjectMap = null
var _container: SubViewportContainer = null
var _viewport: SubViewport = null
var _target: Node2D = null
var _hud: Control = null
var _host: Control = null

# -- TEST METHODS -------------------------------------------------------------------- #


func test_positions_host_at_projection() -> void:
	# Given: A target at world (10, 20) with default canvas_transform.
	_target.global_position = Vector2(10, 20)
	_attach_tracker(_host)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: Host position equals the projected world position.
	assert_almost_eq(
		_host.global_position,
		_map.world_to_hud_2d(_target.global_position),
		TOLERANCE,
	)


func test_offset_is_applied() -> void:
	# Given: A non-zero offset.
	_target.global_position = Vector2(10, 20)
	var tracker := _attach_tracker(_host)
	tracker.offset = Vector2(7, -13)
	# When: A frame is processed.
	await wait_process_frames(1)
	# Then: Host position equals projection + offset.
	assert_almost_eq(
		_host.global_position,
		_map.world_to_hud_2d(_target.global_position) + Vector2(7, -13),
		TOLERANCE,
	)


func test_follows_camera_pan() -> void:
	# Given: A tracker following a target at (50, 50).
	_target.global_position = Vector2(50, 50)
	_attach_tracker(_host)
	await wait_process_frames(1)
	var before := _host.global_position
	# When: The canvas_transform shifts (simulating a camera pan).
	_viewport.canvas_transform = Transform2D(0.0, Vector2(-30, 0))
	await wait_process_frames(1)
	# Then: The host position shifts by the same amount.
	assert_almost_eq(_host.global_position - before, Vector2(-30, 0), TOLERANCE)


func test_follows_target_movement() -> void:
	# Given: A tracker following a target at (50, 50).
	_target.global_position = Vector2(50, 50)
	_attach_tracker(_host)
	await wait_process_frames(1)
	var before := _host.global_position
	# When: The target moves by (20, 0).
	_target.global_position = Vector2(70, 50)
	await wait_process_frames(1)
	# Then: The host position shifts by the same amount.
	assert_almost_eq(_host.global_position - before, Vector2(20, 0), TOLERANCE)


func test_no_op_when_target_freed() -> void:
	# Given: A tracker with a target.
	_target.global_position = Vector2(10, 20)
	_attach_tracker(_host)
	await wait_process_frames(1)
	var last := _host.global_position
	# When: The target is freed.
	_target.free()
	await wait_process_frames(1)
	# Then: The tracker doesn't crash; host stays at its last position.
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
	var stray := Node2D.new()
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

	_map = partial_double(ProjectMapScript).new()
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

	_target = Node2D.new()
	_viewport.add_child(_target)

	_map.sub_viewport = _viewport

	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.add_child(_hud)

	_host = Control.new()
	_hud.add_child(_host)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _attach_tracker(parent: Node) -> WorldTracker2D:
	var tracker := WorldTracker2DScript.new()
	tracker.map = _map
	tracker.target = _target
	parent.add_child(tracker)
	return tracker
