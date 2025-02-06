##
## system/input/input.gd
##
## SystemInput is the global singleton scene for handling user input via action binding.
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _cursor: StdInputCursor = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


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


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_INPUT_SHIM).remove_member(self)


func _ready() -> void:
	assert(action_set_default is StdInputActionSet, "invalid state; missing action set")

	_cursor = StdGroup.get_sole_member(StdInputCursor.GROUP_INPUT_CURSOR)
	assert(_cursor is StdInputCursor, "invalid state; missing input cursor")

	# Forward the focus root change events.
	Signals.connect_safe(_cursor.focus_root_changed, focus_root_changed.emit)

	for slot in StdInputSlot.all():
		slot.load_action_set(action_set_default)
