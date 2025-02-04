##
## project/ui/tooltip_control.gd
##
## TooltipControl is a `Tooltip` class which anchors itself to a `Control` node.
##

class_name TooltipControl
extends Tooltip

# -- CONFIGURATION ------------------------------------------------------------------- #

## anchor is a path to the `Control` node to which this tooltip will be anchored.
@export var anchor: NodePath = ^".."

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _anchor: Control = get_node(anchor)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _get_target_canvas_item should be overridden to return a reference to the anchor
## node. Note that it must be a canvas item (i.e. `Node2D` or `Control`).
func _get_target_canvas_item() -> CanvasItem:
	assert(_anchor is Control, "invalid config; missing anchor node")
	return _anchor


## _get_target_global_rect returns the global bounding box for the node to which
## this tooltip should be attached.
func _get_target_global_rect() -> Rect2:
	assert(_anchor is Control, "invalid config; missing anchor node")
	return _anchor.get_global_rect()
