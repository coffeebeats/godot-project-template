##
## system/input/input.gd
##
## SystemInput is the global singleton scene for handling user input via action binding.
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## cursor_visibility_changed is emitted when the visibility of the application's cursor
## changes.
signal cursor_visibility_changed(visible: bool)

## focus_root_changed is emitted when the focus root changes. Note that `root` may be
## `null` if the root focus was cleared.
signal focus_root_changed(root: Control)

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_INPUT_SHIM := &"system/input:shim"

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_set_default is a default action set that will be loaded after starting up.
@export var action_set_default: StdInputActionSet = null

## ui_navigation_cooldown is a wait period after inputting a UI navigation action that
## must elapse prior to another one being accepted.
@export var ui_navigation_cooldown: float = 0.08

# -- INITIALIZATION ------------------------------------------------------------------ #

var _cursor: StdInputCursor = null
var _ui_navigation_cooldown: float = 0.0

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## is_cursor_visible returns whether the cursor is currently visible. This can be used
## to check whether focus-based navigation is in effect.
func is_cursor_visible() -> bool:
	return _cursor.get_is_visible()


## is_using_focus_ui_navigation returns whether the game is currently using focus-based
## UI navigation (i.e. the mouse cursor is hidden).
func is_using_focus_ui_navigation() -> bool:
	return not _cursor.get_is_visible()


## set_focus_root restricts UI focus to be under the scene subtree rooted at `root`.
## Call this with `null` to unset the focus root.
func set_focus_root(root: Control = null) -> void:
	_cursor.set_focus_root(root)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	assert(StdGroup.is_empty(GROUP_INPUT_SHIM), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_INPUT_SHIM).add_member(self)

	set_process(false)


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_INPUT_SHIM).remove_member(self)

func _input(event: InputEvent) -> void:
	if not event.is_action_type():
		return

	if (
		event.is_action_pressed(&"ui_up", true)
		or event.is_action_pressed(&"ui_right", true)
		or event.is_action_pressed(&"ui_down", true)
		or event.is_action_pressed(&"ui_left", true)
	):
		if is_processing():
			get_viewport().set_input_as_handled()
			return

		_ui_navigation_cooldown = ui_navigation_cooldown
		set_process(true)


func _process(delta: float) -> void:
	# Try to normalize the rate of UI inputs by treating anything below one frame
	# as successfully completed.
	if _ui_navigation_cooldown < (1.0 / Engine.get_frames_per_second() / 2.0):
		set_process(false)
		return

	_ui_navigation_cooldown -= delta

func _ready() -> void:
	assert(action_set_default is StdInputActionSet, "invalid state; missing action set")

	_cursor = StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR)
	assert(_cursor is StdInputCursor, "invalid state; missing input cursor")

	# Forward the `StdInputCursor` events.
	Signals.connect_safe(_cursor.cursor_visibility_changed, cursor_visibility_changed.emit)
	Signals.connect_safe(_cursor.focus_root_changed, focus_root_changed.emit)

	for slot in StdInputSlot.all():
		slot.load_action_set(action_set_default)
