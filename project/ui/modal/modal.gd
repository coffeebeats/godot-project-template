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

## closed is emitted when the modal is closed, along with the reason it closed.
signal closed(reason: CloseReason)

## opened is emitted when the modal is opened.
signal opened

## scrim_clicked is emitted when the modal receives a mouse button event. The `closing`
## parameter denotes whether the event will trigger the modal to be closed. Because this
## is emitted prior to closure, observers can handle the event here to prevent the modal
## from acting on the close event.
signal scrim_clicked(event: InputEvent, closing: bool)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

## CloseReason is an enumeration of reasons for why the modal was hidden.
enum CloseReason {
	## CLOSED means the user closed the modal without confirming or canceling a request.
	## Scrim clicks which trigger modal closure will use this reason as well as pressing
	## the `close_button`.
	CLOSED,
	## CANCELED is used when the user presses the configured `cancel_button`.
	CANCELED,
	## CONFIRMED is used when the user presses the configured `confirm_button`.
	CONFIRMED,
}

const CLOSE_REASON_CLOSED := CloseReason.CLOSED
const CLOSE_REASON_CANCELED := CloseReason.CANCELED
const CLOSE_REASON_CONFIRMED := CloseReason.CONFIRMED

# -- CONFIGURATION ------------------------------------------------------------------- #

## float_under reparents this `Modal` node under the node specified by this path.
@export var float_under: NodePath = ^".."

@export_subgroup("Buttons")

## cancel_button is an optional button that, when pressed, will close the modal with the
## `CANCELED` reason.
@export var cancel_button: BaseButton = null

## confirm_button is an optional button that, when pressed, will close the modal with
## the `CONFIRMED` reason.
@export var confirm_button: BaseButton = null

## close_button is an optional button that, when pressed, will close the modal with the
## default `CLOSED` reason.
@export var close_button: BaseButton = null

@export_subgroup("Scrim")

## scrim_click_to_close is a bitfield of `MouseButtonMask` values which, when the modal
## is clicked with one of the matching mouse buttons, will cause the modal to close. If
## this is left empty, then clicks cannot close the `Modal`.
##
## NOTE: This property is dependent on the `Modal` receiving input (i.e. the
## `mouse_filter` property must not be `MOUSE_FILTER_IGNORE`).
@export_flags("Left:1", "Right:2", "Middle:4", "Extra1:128", "Extra2:256")
var scrim_click_to_close: int = 0

## scrim_color controls the color of the modal background.
@export var scrim_color: Color = Color.TRANSPARENT

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"project/ui/modal") # gdlint:ignore=class-definitions-order,max-line-length
static var _stack: Array[Modal] = [] # gdlint:ignore=class-definitions-order

var _reason: CloseReason = CLOSE_REASON_CLOSED
var _is_open: bool = false
var _last_focus: Control = null
var _mouse_filter: MouseFilter = MOUSE_FILTER_STOP

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## are_any_open returns whether any `Modal` nodes are currently visible.
static func are_any_open() -> bool:
	return not _stack.is_empty()


## is_head_modal returns whether this `Modal` instance is at the top of the visible
## stack.
func is_head_modal() -> bool:
	if not _stack:
		return false

	var head: Modal = _stack.back()
	return self == head

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	_stack.erase(self)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or get_viewport().is_input_handled():
		return

	var match := (
		(Input.get_mouse_button_mask() & scrim_click_to_close) and event.is_pressed()
	)
	scrim_clicked.emit(event, match)

	if match:
		visible = false


# NOTE: Prefer this over `_unhandled_input` because this needs to be handled prior to
# propagating through other input handling layers.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		hide()


func _notification(what) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_node_ready():
				return

			if _is_open and not visible:
				_on_modal_closed()

				var reason := _reason
				_reason = CLOSE_REASON_CLOSED

				closed.emit(reason)
			elif not _is_open and visible:
				assert(_reason == CLOSE_REASON_CLOSED, "found dangling close reason")
				_on_modal_opened()

				opened.emit()

			_is_open = visible


func _ready() -> void:
	Signals.connect_safe(get_viewport().gui_focus_changed, _on_gui_focus_changed)
	Signals.connect_safe(Systems.input().focus_root_changed, _on_focus_root_changed)

	if cancel_button is BaseButton:
		Signals.connect_safe(
			cancel_button.pressed,
			_on_button_pressed.bind(CLOSE_REASON_CANCELED),
		)
	if confirm_button is BaseButton:
		Signals.connect_safe(
			confirm_button.pressed,
			_on_button_pressed.bind(CLOSE_REASON_CONFIRMED),
		)
	if close_button is BaseButton:
		Signals.connect_safe(
			close_button.pressed,
			_on_button_pressed.bind(CLOSE_REASON_CLOSED),
		)


	set_process_input(visible)

	_is_open = visible
	_mouse_filter = mouse_filter
	mouse_filter = _mouse_filter if visible else MOUSE_FILTER_IGNORE

	if visible:
		_stack.append(self)

	var scrim := _create_scrim()
	add_child(scrim, false, INTERNAL_MODE_FRONT)

	_reparent.call_deferred()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _cleanup() -> void:
	if is_inside_tree():
		var parent := get_parent()
		assert(parent is Node, "invalid state; missing parent")

		parent.remove_child(self)

	queue_free()


func _create_scrim() -> ColorRect:
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scrim.color = scrim_color
	scrim.mouse_filter = MOUSE_FILTER_IGNORE
	return scrim


func _reparent() -> void:
	var parent_prev := get_parent()
	var parent_next := get_node(float_under)
	assert(parent_next is Node, "invalid config; missing parent node")

	if parent_next == parent_prev:
		return

	_logger.debug("Floating modal under new parent.", {&"parent": float_under})

	parent_prev.remove_child(self)
	parent_next.add_child(self, false)

	Signals.connect_safe(parent_prev.tree_exiting, _cleanup, CONNECT_ONE_SHOT)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_button_pressed(reason: CloseReason) -> void:
	_reason = reason
	visible = false

func _on_focus_root_changed(root: Control) -> void:
	if root != self:
		return

	if (
		not _last_focus
		or not is_instance_valid(_last_focus)
		or not _last_focus.is_visible_in_tree()
	):
		_last_focus = null
		return

	if not Systems.input().is_using_focus_ui_navigation():
		return

	_logger.debug("Restoring last focused element.", {&"path": _last_focus.get_path()})
	_last_focus.grab_focus()


func _on_gui_focus_changed(node: Control) -> void:
	if is_head_modal() and is_ancestor_of(node):
		_logger.debug("Storing last focused element.", {&"path": node.get_path()})
		_last_focus = node


func _on_modal_closed() -> void:
	assert(not visible, "invalid state; expected hidden modal")
	assert(self in _stack, "invalid state; is missing in modal stack")

	set_process_input(false)

	mouse_filter = MOUSE_FILTER_IGNORE

	_stack.erase(self)
	assert(self not in _stack, "invalid state; duplicated modal stack entry")

	var input := Systems.input()
	if not _stack:
		input.set_focus_root(null)
		return

	var head: Modal = _stack.back()
	input.set_focus_root(head)


func _on_modal_opened() -> void:
	assert(visible, "invalid state; expected visible modal")
	assert(self not in _stack, "invalid state; already in modal stack")

	Systems.input().set_focus_root(self)

	set_process_input(true)

	mouse_filter = MOUSE_FILTER_STOP

	_stack.append(self)
	move_to_front()
