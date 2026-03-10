##
## project/ui/menu/dialog.gd
##
## Dialog is the base class for modal dialogs that manage their own screen lifecycle.
## Subclasses provide button layout, result signals, and input handling.
##

@tool
class_name Dialog
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## closed is emitted after the dialog's screen is popped, carrying which button role the
## user selected.
@warning_ignore("unused_signal")
signal closed(action: Dialog.Action)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## Action identifies which button role the user selected. The caller maps this to domain
## logic (e.g. `PRIMARY` to retry, `DISMISS` to quit).
enum Action { # gdlint:ignore=class-definitions-order
	DISMISS,
	PRIMARY,
	SECONDARY,
}

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
