##
## project/settings/input/binding.gd
##
## InputBinding is a button node which allows a user to rebind an action.
##

@tool
extends "res://ui/glyph/glyph.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Origin := preload("res://addons/std/input/origin.gd")
const BindingPrompt := preload("../component/binding_prompt.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const DeviceType := StdInputDevice.DeviceType

# -- CONFIGURATION ------------------------------------------------------------------- #

## binding_prompt is a reference to the `BindingPrompt` node used to execute the rebind.
@export var binding_prompt: Modal = null

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _button: Button = get_node("Prompt")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _exit_tree():
	super._exit_tree()

	Signals.disconnect_safe(_button.pressed, _on_button_pressed)

func _ready():
	super._ready()

	if Engine.is_editor_hint():
		return

	assert(binding_prompt is BindingPrompt, "invalid state; missing binding prompt")

	Signals.connect_safe(_button.pressed, _on_button_pressed)

# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _start_listening() -> bool:
	if not binding_prompt.start(action_set, action, _slot.player_id):
		return false

	_button.focus_mode = Control.FOCUS_ALL
	_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.grab_focus()

	return true

func _stop_listening() -> void:
	binding_prompt.stop()

	_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_button.focus_mode = (
		Control.FOCUS_NONE
		if _slot.cursor.get_is_visible()
		else Control.FOCUS_ALL
	)

	if _slot.cursor.get_is_visible():
		_button.release_focus()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_button_pressed() -> void:
	if _button.button_pressed:
		if not _start_listening():
			_stop_listening()
			_button.button_pressed = false
	else:
		_stop_listening()
