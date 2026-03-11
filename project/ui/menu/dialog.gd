##
## project/ui/menu/dialog.gd
##
## Dialog is the base class for modal dialogs that manage their own screen lifecycle.
## Subclasses provide button layout, result signals, and input handling.
##

@tool
class_name Dialog
extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## screen is the screen resource used when this dialog is pushed. Configure transitions
## and dependencies on this resource.
@export var screen: StdScreen

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not screen is StdScreen:
		warnings.append("Dialog requires a StdScreen resource.")
	return warnings


func _ready() -> void:
	assert(%Title is Label, "invalid state; missing %%Title node")
	assert(%Message is Label, "invalid state; missing %%Message node")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _set_message sets the message label text and visibility.
func _set_message(message: String) -> void:
	%Message.text = message
	%Message.visible = message != ""


## _set_title sets the title label text and visibility.
func _set_title(title: String) -> void:
	%Title.text = title
	%Title.visible = title != ""
