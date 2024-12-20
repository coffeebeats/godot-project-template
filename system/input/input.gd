##
## system/input/input.gd
##
## SystemInput is the global singleton scene for handling user input via action binding.
##

extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_set_default is a default action set that will be loaded after starting up.
@export var action_set_default: StdInputActionSet = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(action_set_default is StdInputActionSet, "invalid state; missing action set")

	for slot in StdInputSlot.all():
		slot.load_action_set(action_set_default)
