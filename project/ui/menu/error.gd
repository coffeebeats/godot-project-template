##
## project/ui/menu/error.gd
##
## ErrorDialog is a modal error dialog that displays a ProjectError and requires the
## user to choose an explicit action. Configure the button roles via exports (or set
## them directly), then call `open()` to push the dialog; await `closed` for the result.
##

@tool
class_name ErrorDialog
extends Dialog

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Buttons")

## dismiss_label is the locale key for the dismiss button. Displayed as the left-most
## button and receives initial focus; responds to the `ui_cancel` action.
@export var dismiss_label: StringName = &""

## primary_label is the locale key for the primary button. Displayed as the right-most
## button. When empty, the button is hidden.
@export var primary_label: StringName = &""

## secondary_label is the locale key for the secondary button. Displayed as the middle
## button. When empty, the button is hidden.
@export var secondary_label: StringName = &""

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## open configures the dialog for the given error and pushes it onto the screen stack.
## Set labels before calling.
func open(error: ProjectError) -> bool:
	if not screen is StdScreen:
		assert(false, "invalid config; missing screen")
		return false

	if dismiss_label == &"":
		assert(false, "invalid config; missing dismiss label")
		return false

	_set_title(error.title)
	_set_message(error.message)
	_update_buttons()

	Main.screens().push(screen, self)
	return true


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_update_buttons()

	if Engine.is_editor_hint():
		return

	Signals.connect_safe(%Dismiss.pressed, _on_dismiss_pressed)
	Signals.connect_safe(%Secondary.pressed, _on_secondary_pressed)
	Signals.connect_safe(%Primary.pressed, _on_primary_pressed)
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
		Main.screens().pop(Action.DISMISS, true)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_buttons() -> void:
	%Dismiss.text = dismiss_label
	%Secondary.text = secondary_label
	%Secondary.visible = secondary_label != &""
	%Primary.text = primary_label
	%Primary.visible = primary_label != &""


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_dismiss_pressed() -> void:
	assert(
		Main.screens().is_current(screen),
		"invalid state; dialog screen is not topmost",
	)
	Main.screens().pop(Action.DISMISS, true)


func _on_primary_pressed() -> void:
	assert(
		Main.screens().is_current(screen),
		"invalid state; dialog screen is not topmost",
	)
	Main.screens().pop(Action.PRIMARY, true)


func _on_screen_popped(result: Variant) -> void:
	closed.emit(result)


func _on_secondary_pressed() -> void:
	assert(
		Main.screens().is_current(screen),
		"invalid state; dialog screen is not topmost",
	)
	Main.screens().pop(Action.SECONDARY, true)
