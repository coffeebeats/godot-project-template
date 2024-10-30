##
## project/main/menu/main_menu.gd
##
## MainMenu implements a main menu for the game.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Lifecycle := preload("res://project/main/lifecycle.gd")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	var err: int = %Quit.pressed.connect(_on_Quit_pressed)
	assert(err == OK, "failed to connect to signal")

	%Play.grab_focus()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Quit_pressed():
	Lifecycle.shutdown(self)
