##
## project/settings/menu.gd
##
## SettingsMenu is a full settings menu with the ability to read and write user/game
## preferences. Designed as a standalone Control pushed via StdScreenManager.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Feedback")

## tab_switch_sound_event is a sound event which will be played when switching tabs.
@export var tab_switch_sound_event: StdSoundEvent1D = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _active: Control = null
var _cursor_visible: bool = false
var _tab_bar_default_index: int = 0
var _tab_bar_focus_mode: FocusMode = FOCUS_NONE
var _tab_bar_mouse_filter: MouseFilter = MOUSE_FILTER_IGNORE
var _tab_switch_muted: bool = false

@onready var _tab_bar: TabBar = %TabBar
@onready var _tab_contents: Control = %TabContents

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if not is_node_ready():
		return  # First enter; _ready() handles initial state.

	# Re-entry (cached instance pushed again):
	_tab_switch_muted = true
	_tab_bar.current_tab = _tab_bar_default_index
	(func(): _tab_switch_muted = false).call_deferred()
	_maybe_mute_next_focus_sound_event()


func _ready():
	assert(not is_layout_rtl(), "invalid state: validate support for RTL")

	_tab_bar_default_index = _tab_bar.current_tab
	_tab_bar_focus_mode = _tab_bar.focus_mode
	_tab_bar_mouse_filter = _tab_bar.mouse_filter

	var input := Systems.input()
	Signals.connect_safe(input.cursor_visibility_changed, _on_cursor_visibility_changed)
	_cursor_visible = input.is_cursor_visible()

	for child in _tab_contents.get_children():
		child.visible = false

	Signals.connect_safe(_tab_bar.tab_changed, _on_tabbar_tab_changed)
	_set_active_index(_tab_bar.current_tab)

	%Close.pressed.connect(_on_close_pressed)
	_maybe_mute_next_focus_sound_event()


func _shortcut_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_next"):
		_tab_bar.select_next_available()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_tab_prev"):
		_tab_bar.select_previous_available()
		get_viewport().set_input_as_handled()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _maybe_mute_next_focus_sound_event() -> void:
	var input := Systems.input()
	if not input.is_cursor_visible():
		input.mute_next_focus_sound_event()


func _set_active_index(index: int) -> void:
	assert(
		index >= 0 and index < _tab_contents.get_child_count(),
		"invalid argument: index out of range",
	)

	var current := _active

	_active = _tab_contents.get_child(index)
	_active.visible = true

	if current != null:
		current.visible = false


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_close_pressed() -> void:
	StdInputEvent.trigger_action(&"ui_cancel")


# TODO: Consider unifying this with `StdInputCursorFocusHandler`'s use of this code.
# FIXME: Switching to focus-mode while hovering a tab leaves the tab in the hovered
# state. Switch to a custom tab bar to better handle this shortcoming.
func _on_cursor_visibility_changed(cursor_visible: bool) -> void:
	_cursor_visible = cursor_visible

	# NOTE: In order to stop a hidden cursor from hovering a UI element, disable its
	# mouse filter property; see https://github.com/godotengine/godot/issues/56783.
	if not cursor_visible:
		_tab_bar.mouse_filter = MOUSE_FILTER_IGNORE
		_tab_bar.focus_mode = _tab_bar_focus_mode
	else:
		_tab_bar.mouse_filter = _tab_bar_mouse_filter
		_tab_bar.focus_mode = FOCUS_NONE


func _on_tabbar_tab_changed(index: int) -> void:
	if not _cursor_visible:
		Systems.input().mute_next_focus_sound_event()

	_set_active_index(index)

	if not _tab_switch_muted and tab_switch_sound_event:
		Systems.audio().play(tab_switch_sound_event)
