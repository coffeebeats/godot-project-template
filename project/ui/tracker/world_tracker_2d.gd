##
## project/ui/tracker/world_tracker_2d.gd
##
## WorldTracker2D drives its parent `Control` to follow a `Node2D` living inside a
## `ProjectMap`'s `SubViewport`. Attach as a child of any HUD `Control` to make that
## `Control` track a world-space entity (health bars, damage numbers, name plates,
## tooltips, off-screen indicators).
##
## Expected scene layout:
##
##   ProjectMap                              (referenced via the `map` export)
##   ├── SubViewportContainer
##   │   └── SubViewport
##   │       └── ... game world ...
##   │           └── Node2D                  (target)
##   └── HUD                                 (later subtree than SubViewport)
##       └── HealthBar / Tooltip / etc.      (Control; tracker's parent)
##           └── WorldTracker2D
##

class_name WorldTracker2D
extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## map is the `ProjectMap` whose `SubViewport` hosts `target`.
@export var map: ProjectMap = null

## target is the `Node2D` whose world position the parent `Control` will follow. Must
## live inside `map.sub_viewport`.
@export var target: Node2D = null

## offset is added to the projected HUD position each frame (in HUD-space pixels).
@export var offset: Vector2 = Vector2.ZERO

# -- INITIALIZATION ------------------------------------------------------------------ #

var _host: Control = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _process(_delta: float) -> void:
	if not _host or not is_instance_valid(map) or not is_instance_valid(target):
		return
	_host.global_position = map.world_to_hud_2d(target.global_position) + offset


func _ready() -> void:
	_host = get_parent() as Control

	# Validate that all required references exist. Subsequent invariants will
	# dereference them, so bail out together if any are missing.
	assert(_host, "invalid config; WorldTracker2D's parent must be a Control")
	assert(map, "invalid config; missing 'map'")
	assert(target, "invalid config; missing 'target'")
	if not _host or not is_instance_valid(map) or not is_instance_valid(target):
		return
	assert(map.sub_viewport, "invalid config; 'map' has no SubViewport")
	if not map.sub_viewport:
		return

	# Validate scene topology and tree ordering.
	assert(
		target.get_viewport() == map.sub_viewport,
		"invalid config; 'target' must live inside 'map.sub_viewport'",
	)
	# NOTE: The tracker reads `canvas_transform` in `_process`, which the camera
	# writes during its own `_process`. Godot traverses `_process` callbacks in
	# depth-first tree order, so the tracker MUST be in a subtree that comes after
	# the SubViewport — otherwise it reads stale `canvas_transform` and HUD widgets
	# visibly lag world content by one frame. Asserting tree order here surfaces
	# the misconfiguration loudly at startup rather than as subtle pixel-shimmer
	# at runtime.
	assert(
		is_greater_than(map.sub_viewport),
		(
			"invalid config; WorldTracker2D must be in a subtree later than"
			+ " 'map.sub_viewport' (typically inside a HUD that is a later sibling"
			+ " of the SubViewportContainer)"
		),
	)
