##
## project/settings/menu.gd
##
## SettingsMenu is a full settings menu with the ability to read and write user/game
## preferences. This is intended to be opened in a separate `Modal` or `Container`.
##

extends PanelContainer

# -- INITIALIZATION ------------------------------------------------------------------ #

var _active: Control = null

@onready var _tab_bar: TabBar = %TabBar
@onready var _tab_contents: Control = %TabContents

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready():
	assert(not is_layout_rtl(), "invalid state: validate support for RTL")

	for child in _tab_contents.get_children():
		child.visible = false

	var err := _tab_bar.tab_changed.connect(_on_TabBar_tab_changed)
	assert(err == OK, "failed to connect to signal")

	_set_active_index(_tab_bar.current_tab)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_next"):
		_tab_bar.select_next_available()
	elif event.is_action_pressed(&"ui_tab_prev"):
		_tab_bar.select_previous_available()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


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


func _on_TabBar_tab_changed(index: int) -> void:
	_set_active_index(index)
