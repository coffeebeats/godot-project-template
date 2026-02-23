##
## project/ui/menu/alert.gd
##
## AlertDialog is a reusable confirmation dialog body panel with confirm and cancel
## buttons. Default focus lands on the cancel button to prevent accidental confirmation.
##

@tool
class_name AlertDialog
extends PanelContainer

# -- SIGNALS ------------------------------------------------------------------------- #

## confirmed is emitted when the confirm button is pressed.
signal confirmed

## cancelled is emitted when the cancel button or `ui_cancel` is pressed.
signal cancelled

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

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

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_update_title()
	_update_message()

	%Confirm.text = confirm_label
	%Cancel.text = cancel_label

	if Engine.is_editor_hint():
		return

	Signals.connect_safe(%Confirm.pressed, _on_confirm_pressed)
	Signals.connect_safe(%Cancel.pressed, _on_cancel_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_message() -> void:
	%Message.text = message_text
	%Message.visible = message_text != ""


func _update_title() -> void:
	%Title.text = title_text
	%Title.visible = title_text != ""


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_cancel_pressed() -> void:
	cancelled.emit()


func _on_confirm_pressed() -> void:
	confirmed.emit()
