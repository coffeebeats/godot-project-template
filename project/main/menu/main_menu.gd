##
## project/main/menu/main_menu.gd
##
## MainMenu implements a main menu for the game.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	Signals.connect_safe(%Quit.pressed, _on_quit_pressed)
	Signals.connect_safe(%Play.pressed, _on_play_pressed)
	Signals.connect_safe($SaveSlots.opened, _on_save_slots_changed)
	Signals.connect_safe($SaveSlots.closed, _on_save_slots_changed)
	Signals.connect_safe(%Options.pressed, _on_options_pressed)
	Signals.connect_safe($Settings.closed, _on_settings_changed)
	Signals.connect_safe($Settings.opened, _on_settings_changed)


# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_options_pressed() -> void:
	$Settings.visible = true


func _on_play_pressed() -> void:
	$SaveSlots.visible = true


func _on_quit_pressed() -> void:
	Lifecycle.shutdown()


func _on_save_slots_changed() -> void:
	# TODO: Replace this with proper navigation stack.
	if $SaveSlots.visible:
		get_viewport().gui_release_focus()


func _on_settings_changed() -> void:
	# TODO: Replace this with proper navigation stack.
	if $Settings.visible:
		get_viewport().gui_release_focus()
