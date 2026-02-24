##
## project/main/menu/main_menu.gd
##
## MainMenu implements a main menu for the game.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## saves_screen is the StdScreen resource for the save slot menu.
@export var saves_screen: StdScreen = null

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _continue: Button = %Continue
@onready var _options: Button = %Options
@onready var _play: Button = %Play
@onready var _quit: Button = %Quit

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_handle_first_focused_sound_event_mute.call_deferred()

	Signals.connect_safe(_continue.pressed, _on_continue_pressed)
	Signals.connect_safe(_options.pressed, _on_options_pressed)
	Signals.connect_safe(_play.pressed, _on_play_pressed)
	Signals.connect_safe(_quit.pressed, _on_quit_pressed)

	var saves := Systems.saves()
	Signals.connect_safe(saves.slot_activated, _on_slot_activated)
	Signals.connect_safe(saves.slot_deactivated, _on_slot_deactivated)

	_setup_continue_button()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _handle_first_focused_sound_event_mute() -> void:
	var input := Systems.input()
	if not input.is_cursor_visible():
		input.mute_next_focus_sound_event()


func _setup_continue_button() -> void:
	var saves := Systems.saves()
	var slot := saves.get_active_save_slot()

	if slot > -1 and saves.get_save_slot(slot).status == SaveSlot.STATUS_OK:
		_continue.visible = true
		_continue.focus_neighbor_top = _continue.get_path_to(_quit)
		_quit.focus_neighbor_bottom = _quit.get_path_to(_continue)
		_play.focus_neighbor_top = _play.get_path_to(_continue)
	else:
		_continue.visible = false
		_play.focus_neighbor_top = _play.get_path_to(_quit)
		_quit.focus_neighbor_bottom = _quit.get_path_to(_play)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_continue_pressed() -> void:
	Main.load_game(Systems.saves().get_active_save_slot())


func _on_options_pressed() -> void:
	StdInputEvent.trigger_action(&"ui_toggle_menu")


func _on_play_pressed() -> void:
	Main.screens().push(saves_screen)


func _on_quit_pressed() -> void:
	Lifecycle.shutdown()


func _on_slot_activated(_index: int) -> void:
	_setup_continue_button()


func _on_slot_deactivated(_index: int) -> void:
	_setup_continue_button()
