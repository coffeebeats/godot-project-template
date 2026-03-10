##
## project/ui/menu/alert.gd
##
## AlertDialog is a reusable confirmation or acknowledgment modal that manages its own
## screen lifecycle. Call `open()` to push the dialog onto the screen stack and await
## `closed` for the result.
##

@tool
class_name AlertDialog
extends Dialog

# -- CONFIGURATION ------------------------------------------------------------------- #

## title_text is the locale key for the title label. Hidden when empty.
@export var title_text: String = "":
	set(value):
		title_text = value
		if is_node_ready():
			_set_title(title_text)

## message_text is the locale key for the message label. Hidden when empty.
@export var message_text: String = "":
	set(value):
		message_text = value
		if is_node_ready():
			_set_message(message_text)

@export_group("Buttons")

@export_subgroup("Dismiss")

## dismiss_label is the locale key for the dismiss/cancel button. When empty, the dismiss
## button is hidden and `ui_cancel` pops with PRIMARY instead.
@export var dismiss_label: String = "confirm_dialog_cancel":
	set(value):
		dismiss_label = value
		if is_node_ready():
			%Cancel.text = dismiss_label
			%Cancel.visible = dismiss_label != ""

@export_subgroup("Primary")

## primary_label is the locale key for the primary/confirm button.
@export var primary_label: String = "confirm_dialog_confirm":
	set(value):
		primary_label = value
		if is_node_ready():
			%Confirm.text = primary_label

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## open pushes this dialog onto the screen stack.
func open() -> void:
	assert(screen is StdScreen, "invalid config; missing screen")
	Main.screens().push(screen, self)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_set_title(title_text)
	_set_message(message_text)

	%Confirm.text = primary_label
	%Cancel.text = dismiss_label
	%Cancel.visible = dismiss_label != ""

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

		if dismiss_label == "":
			Main.screens().pop(Action.PRIMARY, true)
		else:
			Main.screens().pop(Action.DISMISS, true)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_cancel_pressed() -> void:
	assert(
		Main.screens().is_current(screen),
		"invalid state; dialog screen is not topmost",
	)
	Main.screens().pop(Action.DISMISS, true)


func _on_confirm_pressed() -> void:
	assert(
		Main.screens().is_current(screen),
		"invalid state; dialog screen is not topmost",
	)
	Main.screens().pop(Action.PRIMARY, true)


func _on_screen_popped(result: Variant) -> void:
	closed.emit(result)
