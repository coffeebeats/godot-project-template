##
## project/ui/menu/alert.gd
##
## AlertDialog is a reusable confirmation or acknowledgment modal that manages its own
## screen lifecycle. Call `open()` to push the dialog onto the screen stack and await
## `closed` for the result.
##

@tool
class_name AlertDialog
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## closed is emitted after the dialog's screen is popped. `accepted` is true if the
## confirm button was pressed, false otherwise.
signal closed(accepted: bool)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## Mode controls which buttons are displayed.
enum Mode {  # gdlint:ignore=class-definitions-order
	## CONFIRM_CANCEL shows both confirm and cancel buttons.
	CONFIRM_CANCEL,
	## OK_ONLY shows a single confirm/acknowledge button.
	OK_ONLY,
}

const MODE_CONFIRM_CANCEL := Mode.CONFIRM_CANCEL
const MODE_OK_ONLY := Mode.OK_ONLY

# -- CONFIGURATION ------------------------------------------------------------------- #

## screen is the screen resource used when this dialog is pushed. Configure transitions
## and dependencies on this resource.
@export var screen: StdScreen

## mode controls the button layout of the dialog.
@export var mode: Mode = Mode.CONFIRM_CANCEL:
	set(value):
		mode = value
		if is_node_ready():
			_update_mode()

## title_text is the locale key for the title label. Hidden when empty.
@export var title_text: String = "":
	set(value):
		title_text = value
		if is_node_ready():
			_update_title()

## message_text is the locale key for the message label. Hidden when empty.
@export var message_text: String = "":
	set(value):
		message_text = value
		if is_node_ready():
			_update_message()

## confirm_label is the locale key for the confirm button.
@export var confirm_label: String = "confirm_dialog_confirm":
	set(value):
		confirm_label = value
		if is_node_ready():
			%Confirm.text = confirm_label

## cancel_label is the locale key for the cancel button.
@export var cancel_label: String = "confirm_dialog_cancel":
	set(value):
		cancel_label = value
		if is_node_ready():
			%Cancel.text = cancel_label

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## open pushes this dialog onto the screen stack.
func open() -> void:
	assert(screen is StdScreen, "invalid config; missing screen")
	Main.screens().push(screen, self)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not screen is StdScreen:
		warnings.append("AlertDialog requires a StdScreen resource.")
	return warnings


func _ready() -> void:
	_update_title()
	_update_message()
	_update_mode()

	%Confirm.text = confirm_label
	%Cancel.text = cancel_label

	if Engine.is_editor_hint():
		return

	Signals.connect_safe(%Confirm.pressed, _on_confirm_pressed)
	Signals.connect_safe(%Cancel.pressed, _on_cancel_pressed)
	Signals.connect_safe(screen.popped, _on_screen_popped)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		assert(
			Main.screens().is_current(screen),
			"invalid state; dialog screen is not topmost",
		)
		Main.screens().pop(mode == Mode.OK_ONLY, true)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_message() -> void:
	%Message.text = message_text
	%Message.visible = message_text != ""


func _update_mode() -> void:
	%Cancel.visible = mode == Mode.CONFIRM_CANCEL


func _update_title() -> void:
	%Title.text = title_text
	%Title.visible = title_text != ""


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_cancel_pressed() -> void:
	assert(
		Main.screens().is_current(screen),
		"invalid state; dialog screen is not topmost",
	)
	Main.screens().pop(false, true)


func _on_confirm_pressed() -> void:
	assert(
		Main.screens().is_current(screen),
		"invalid state; dialog screen is not topmost",
	)
	Main.screens().pop(true, true)


func _on_screen_popped(result: Variant) -> void:
	closed.emit(result == true)
