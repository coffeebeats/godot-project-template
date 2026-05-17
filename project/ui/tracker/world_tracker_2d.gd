##
## project/ui/tracker/world_tracker_2d.gd
##
## WorldTracker2D drives its parent `Control` to follow a `Node2D` living inside a
## `ProjectMap2D`'s `SubViewport`. Attach as a child of any screen-space `Control` to
## make that `Control` track a world-space entity (e.g. health bars, damage numbers,
## name plates, tooltips, off-screen indicators).
##
## Expected scene layout:
##
##   ProjectMap2D                            (referenced via the `map` export)
##   ├── SubViewportContainer
##   │   └── SubViewport
##   │       └── ... game world ...
##   │           └── Node2D                  (target)
##   └── UI                                  (later subtree than SubViewport)
##       └── HealthBar / Tooltip / etc.      (Control; tracker's parent)
##           └── WorldTracker2D
##

class_name WorldTracker2D
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## map is the `ProjectMap2D` whose `SubViewport` hosts `target`.
@export var map: ProjectMap2D = null

## target is the `Node2D` whose world position the parent `Control` will follow. Must
## live inside `map.sub_viewport`. Reassigning at runtime resumes tracking.
@export var target: Node2D = null:
	set(value):
		target = value
		# Re-arm processing; `_process` disables itself once `target`/`map` go invalid.
		if is_instance_valid(value):
			set_process(true)

## offset is added to the projected screen position each frame (in screen-space pixels).
@export var offset: Vector2 = Vector2.ZERO

# -- INITIALIZATION ------------------------------------------------------------------ #

var _host: Control = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float) -> void:
	if not _host or not is_instance_valid(map) or not is_instance_valid(target):
		# Stop polling: these states are terminal. Reassigning `target` re-arms.
		set_process(false)
		return

	_host.global_position = map.world_to_screen(target.global_position) + offset


func _ready() -> void:
	assert(map, "invalid config; missing 'map'")
	assert(map.sub_viewport, "invalid config; 'map' has no SubViewport")
	assert(target, "invalid config; missing 'target'")

	_host = get_parent() as Control
	assert(_host, "invalid config; WorldTracker2D's parent must be a Control")

	# Validate scene topology and tree ordering.
	assert(
		target.get_viewport() == map.sub_viewport,
		"invalid config; 'target' must live inside 'map.sub_viewport'",
	)

	# NOTE: The tracker reads `canvas_transform` in `_process`, which the camera writes
	# during its own. Godot runs `_process` in depth-first tree order, so a tracker
	# placed before the `SubViewport` reads a stale transform and lags by a frame.
	assert(
		is_greater_than(map.sub_viewport),
		(
			"invalid config; WorldTracker2D must be in a subtree later than"
			+ " 'map.sub_viewport' (typically inside a UI layer that is a later"
			+ " sibling of the SubViewportContainer)"
		),
	)
