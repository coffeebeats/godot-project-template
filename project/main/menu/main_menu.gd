##
## project/main/menu/main_menu.gd
##
## MainMenu implements a main menu for the game.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _options: Button = %Options
@onready var _play: Button = %Play
@onready var _quit: Button = %Quit
@onready var _save_slots: Modal = $SaveSlots
@onready var _settings: Modal = $Settings

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	Signals.connect_safe(_quit.pressed, _on_quit_pressed)
	Signals.connect_safe(_play.pressed, _on_play_pressed)
	Signals.connect_safe(_options.pressed, _on_options_pressed)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_options_pressed() -> void:
	_settings.visible = true


func _on_play_pressed() -> void:
	_save_slots.visible = true


func _on_quit_pressed() -> void:
	Lifecycle.shutdown()
