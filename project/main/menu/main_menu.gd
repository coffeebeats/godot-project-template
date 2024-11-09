##
## project/main/menu/main_menu.gd
##
## MainMenu implements a main menu for the game.
##

extends Control

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	var err: int = %Quit.pressed.connect(_on_Quit_pressed)
	assert(err == OK, "failed to connect to signal")

	err = %Options.pressed.connect(_on_Options_pressed)
	assert(err == OK, "failed to connect to signal")

	err = $Settings.closed.connect(_on_Settings_changed)
	assert(err == OK, "failed to connect to signal")

	err = $Settings.opened.connect(_on_Settings_changed)
	assert(err == OK, "failed to connect to signal")

	_set_initial_focus()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _set_initial_focus() -> void:
	# TODO: Only do this when using a controller.
	# %Play.grab_focus()
	pass


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_Options_pressed() -> void:
	$Settings.visible = true


func _on_Quit_pressed() -> void:
	Lifecycle.shutdown()


func _on_Settings_changed() -> void:
	if $Settings.visible:
		get_viewport().gui_release_focus()
	else:
		_set_initial_focus()
