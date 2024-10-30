##
## Modal is a 'Control' node which renders child nodes over a "scrim", preventing
## GUI interactions with all elements below it. It can open and close in response to a
## specific toggle action.
##
## NOTE: This node does not actually render a scrim, as there isn't a universal
## implementation. Instead, users can simply add a scrim as the first child.
##

class_name Modal
extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

## closed is emitted when the modal is closed.
signal closed

## opened is emitted when the modal is opened.
signal opened

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_toggle is the name of an input action which will toggle the modal open and
## closed. If empty, the 'Modal' must be manually closed by toggling 'visible'.
##
## NOTE: The modal will only detect shortcuts (i.e. keys and joypad buttons).
@export var action_toggle: StringName = "ui_cancel"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_open: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if _is_open and not visible:
				closed.emit()
			elif not _is_open and visible:
				opened.emit()

			_is_open = visible


func _ready() -> void:
	# TODO: Validate action is supported type for shortcuts.
	assert(InputMap.has_action(action_toggle), "invalid action: %s" % action_toggle)

	mouse_filter = MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false

	_is_open = visible


func _shortcut_input(event: InputEvent) -> void:
	if event.is_action_pressed(action_toggle):
		assert(_is_open == visible, "state mismatch")

		get_viewport().set_input_as_handled()

		if _is_open:
			visible = false
		else:
			visible = true
