##
## project/ui/hud/anchor_3d.gd
##
## HudAnchor3D binds a `Node3D` entity to a HUD group. See `HudAnchor` for the behavior;
## this adds the 3D-typed target.
##
## Expected scene layout:
##
##   Enemy                    (Node3D, inside a ProjectMap3D's SubViewport)
##   └── HudAnchor3D          group_scene = enemy_hud.tscn
##
## NOTE: `WorldTracker.offset` is screen-space, so a group does not hold a fixed height
## above a model as it recedes. Point `target` at a `Marker3D` above the entity when
## that matters.
##

@tool
class_name HudAnchor3D
extends HudAnchor

# -- CONFIGURATION ------------------------------------------------------------------- #

## target is the `Node3D` the group follows. When unset the anchor's parent is used,
## which is the common case; set it to follow a `Marker3D` offset from the entity.
@export var target: Node3D = null

# -- PUBLIC METHODS (OVERRIDES) ------------------------------------------------------ #


func get_world_position() -> Variant:
	var node := get_target() as Node3D
	return node.global_position if node else null


func get_target() -> Node:
	return target if target else get_parent() as Node3D
