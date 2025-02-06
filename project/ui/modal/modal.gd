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

## clicked is emitted when the modal scrim receives a mouse button event.
##
## NOTE: This will be emitted prior to closing the modal if `scrim_click_to_close` is a
## match. Manually consuming the event will prevent an otherwise matching "close" click
## from being actioned on.
signal clicked(event: InputEvent)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## float_under reparents this `Modal` node under the node specified by this path.
@export var float_under: NodePath = ^""

@export_subgroup("Scrim")

## scrim_click_to_close is a bitfield of `MouseButtonMask` values which, when the scrim
## is clicked with one of the matching mouse buttons, will cause the `Modal` to close.
## If this is left empty, then clicks cannot close the `Modal`, causing the scrim to act
## as a modal barrier.
@export_flags("Left", "Right", "Middle") var scrim_click_to_close: int = 0

## scrim_click_consumes_input controls whether a mouse click that would close the scrim
## should be consumed. If set to `false`, the mouse click would continue to propagate
## through the scene tree.
##
## NOTE: This property is ignored if
@export var scrim_click_consumes_input: bool = true

## scrim_color controls the color of the modal background.
@export var scrim_color: Color = Color.TRANSPARENT

# -- INITIALIZATION ------------------------------------------------------------------ #

static var _logger := StdLogger.create(&"project/ui/modal")  # gdlint:ignore=class-definitions-order,max-line-length
static var _stack: Array[Modal] = []  # gdlint:ignore=class-definitions-order

var _is_open: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	_stack.erase(self)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	if event.is_pressed() and not event.is_echo():
		clicked.emit(event)

	if Input.get_mouse_button_mask() & scrim_click_to_close:
		visible = false

		if scrim_click_consumes_input:
			accept_event()


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
				closed.emit()
			elif not _is_open and visible:
				_on_modal_opened()
				opened.emit()

			_is_open = visible


func _ready() -> void:
	set_process_input(visible)

	mouse_filter = MOUSE_FILTER_STOP if visible else MOUSE_FILTER_IGNORE
	mouse_force_pass_scroll_events = false

	_is_open = visible
	if visible:
		_stack.append.call_deferred(self)

	var scrim := _create_scrim()
	add_child(scrim, false, INTERNAL_MODE_FRONT)

	if float_under:
		_reparent()


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

	parent_prev.remove_child.call_deferred(self)
	parent_next.add_child.call_deferred(self, false)

	Signals.connect_safe(parent_prev.tree_exiting, _cleanup, CONNECT_ONE_SHOT)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


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
	assert(not mouse_force_pass_scroll_events, "invalid state; scroll events passed")

	_stack.append(self)

	if float_under:
		move_to_front()
