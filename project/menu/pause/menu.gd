##
## project/menu/pause/menu.gd
##
## PauseMenu is a modal pause menu shown during gameplay. It provides options to resume,
## open settings, return to the main menu, or quit the game.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const ConfirmQuit := preload("res://project/menu/pause/quit.tscn")
const ConfirmReturn := preload("res://project/menu/pause/return.tscn")

# -- CONFIGURATION ------------------------------------------------------------------- #

## settings_screen is the screen resource for the settings menu.
@export var settings_screen: StdScreen

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _options: Button = %Options
@onready var _quit: Button = %Quit
@onready var _resume: Button = %Resume
@onready var _return: Button = %Return

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	_handle_first_focused_sound_event_mute.call_deferred()

	Signals.connect_safe(_options.pressed, _on_options_pressed)
	Signals.connect_safe(_quit.pressed, _on_quit_pressed)
	Signals.connect_safe(_resume.pressed, _on_resume_pressed)
	Signals.connect_safe(_return.pressed, _on_return_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _handle_first_focused_sound_event_mute() -> void:
	var input := Systems.input()
	if not input.is_cursor_visible():
		input.mute_next_focus_sound_event()


func _push_confirm(scene: PackedScene, on_confirmed: Callable) -> void:
	var instance := scene.instantiate()
	var dialog: AlertDialog = instance.get_node("%AlertDialog")

	Signals.connect_safe(
		dialog.closed,
		func(accepted: bool):
			if accepted:
				on_confirmed.call()
			else:
				Main.screens().pop(),
		CONNECT_ONE_SHOT,
	)

	Main.screens().push(StdScreen.new(), instance)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_options_pressed() -> void:
	Main.screens().push(settings_screen)


func _on_quit_pressed() -> void:
	_push_confirm(ConfirmQuit, func(): Lifecycle.shutdown())


func _on_resume_pressed() -> void:
	Main.screens().pop()


func _on_return_pressed() -> void:
	_push_confirm(
		ConfirmReturn,
		func():
			Main.screens().pop()
			Main.go_to_main_menu(),
	)
