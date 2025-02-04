##
## project/ui/tooltip_node2d.gd
##
## TooltipNode2D is a `Tooltip` class which anchors itself to a `Node2D` node.
##

class_name TooltipNode2D
extends Tooltip

# -- CONFIGURATION ------------------------------------------------------------------- #

## anchor is a path to the `Node2D` node to which this tooltip will be anchored.
@export var anchor: NodePath = ^".."

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _anchor: Node2D = get_node(anchor)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


## _get_target_canvas_item should be overridden to return a reference to the anchor
## node. Note that it must be a canvas item (i.e. `Node2D` or `Control`).
func _get_target_canvas_item() -> CanvasItem:
	assert(_anchor is Node2D, "invalid config; missing anchor node")
	return _anchor


## _get_target_global_rect returns the global bounding box for the node to which
## this tooltip should be attached.
func _get_target_global_rect() -> Rect2:
	assert(_anchor is Node2D, "invalid config; missing anchor node")
	return _anchor.get_global_rect()
