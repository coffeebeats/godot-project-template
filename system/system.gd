##
## system/system.gd
##
## A shared library for ...
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

class_name Systems
extends Object

# -- DEPENDENCIES -------------------------------------------------------------------- #

const InputSystem := preload("res://system/input/input.gd")
const SavesSystem := preload("res://system/save/saves.gd")

# -- PUBLIC METHODS ------------------------------------------------------------------ #

static func input() -> InputSystem:
	return StdGroup.get_sole_member(InputSystem.GROUP_INPUT_SHIM)

static func saves() -> SavesSystem:
	return StdGroup.get_sole_member(SavesSystem.GROUP_SAVES_SHIM)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
