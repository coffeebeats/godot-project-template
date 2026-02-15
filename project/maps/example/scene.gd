##
## project/maps/example/scene.gd
##
## ExampleScene is a demo scene demonstrating how to interact with the save data system.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _save_data: ProjectSaveData = null

@onready var _counter: Label = %Counter
@onready var _increment: Button = %Increment
@onready var _reset: Button = %Reset
@onready var _return: Button = %Return
@onready var _save: Button = %Save

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready():
	_save_data = Main.get_active_save_data()
	if not _save_data:
		Main.go_to_main_menu()
		return

	Main.connect_saved(_on_game_saved)

	Signals.connect_safe(_increment.pressed, _on_increment_pressed)
	Signals.connect_safe(_reset.pressed, _on_reset_pressed)
	Signals.connect_safe(_return.pressed, _on_return_pressed)
	Signals.connect_safe(_save.pressed, _on_save_pressed)

	_update_counter_label()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_counter_label() -> void:
	_counter.text = str(_save_data.example.count)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_increment_pressed() -> void:
	_save_data.example.count += 1
	_update_counter_label()


func _on_reset_pressed() -> void:
	_save_data.example.count = 0
	_update_counter_label()


func _on_return_pressed() -> void:
	Main.go_to_main_menu()


func _on_game_saved(_slot: int, error: Error) -> void:
	_save.disabled = false
	if error != OK:
		return
	_update_counter_label()


func _on_save_pressed() -> void:
	_save.disabled = true
	Main.save_game()
