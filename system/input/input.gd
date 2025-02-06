##
## system/input/input.gd
##
## SystemInput is the global singleton scene for handling user input via action binding.
##

extends Node

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_INPUT_SHIM := &"system/input:shim"

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_set_default is a default action set that will be loaded after starting up.
@export var action_set_default: StdInputActionSet = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(StdGroup.is_empty(GROUP_INPUT_SHIM), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_INPUT_SHIM).add_member(self)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_INPUT_SHIM).remove_member(self)


func _ready() -> void:
	assert(action_set_default is StdInputActionSet, "invalid state; missing action set")

	for slot in StdInputSlot.all():
		slot.load_action_set(action_set_default)
