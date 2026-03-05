##
## project/menu/pause/menu.gd
##
## PauseMenu is a modal pause menu shown during gameplay. It provides options to resume,
## open settings, return to the main menu, or quit the game.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## confirm_quit_scene is the confirmation dialog shown before quitting the application.
@export var confirm_quit_scene: PackedScene

## confirm_return_scene is the confirmation dialog shown before returning to the main
## menu.
@export var confirm_return_scene: PackedScene

## settings_screen is the screen resource for the settings menu.
@export var settings_screen: StdScreen

# -- INITIALIZATION ------------------------------------------------------------------ #

var _confirm_quit: AlertDialog
var _confirm_return: AlertDialog

@onready var _options: Button = %Options
@onready var _quit: Button = %Quit
@onready var _resume: Button = %Resume
@onready var _return: Button = %Return

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(_confirm_quit):
			_confirm_quit.free()
			_confirm_quit = null
		if is_instance_valid(_confirm_return):
			_confirm_return.free()
			_confirm_return = null


func _ready() -> void:
	_confirm_quit = confirm_quit_scene.instantiate()
	_confirm_return = confirm_return_scene.instantiate()

	Signals.connect_safe(_options.pressed, _on_options_pressed)
	Signals.connect_safe(_quit.pressed, _on_quit_pressed)
	Signals.connect_safe(_resume.pressed, _on_resume_pressed)
	Signals.connect_safe(_return.pressed, _on_return_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_options_pressed() -> void:
	Main.screens().push(settings_screen)


func _on_quit_pressed() -> void:
	_confirm_quit.open()
	var accepted: bool = await _confirm_quit.closed
	if accepted:
		Lifecycle.shutdown()


func _on_resume_pressed() -> void:
	assert(
		Main.screens().get_scene() == self,
		"invalid state; this scene is not topmost",
	)
	Main.screens().pop()


func _on_return_pressed() -> void:
	_confirm_return.open()
	var accepted: bool = await _confirm_return.closed
	if accepted:
		assert(
			Main.screens().get_scene() == self,
			"invalid state; this scene is not topmost",
		)
		Main.screens().pop()
		Main.go_to_main_menu()
