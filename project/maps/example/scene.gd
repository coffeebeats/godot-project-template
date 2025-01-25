##
## project/maps/example/scene.gd
##
## ExampleScene is a demo scene demonstrating how to interact with the save data system.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const SceneHandle := preload("res://addons/std/scene/handle.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene_handle is a scene handle used to navigate back to the main menu.
@export var scene_handle: SceneHandle = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _save_data: ProjectSaveData = null

@onready var _counter: Label = %Counter
@onready var _increment: Button = %Increment
@onready var _reset: Button = %Reset
@onready var _return: Button = %Return
@onready var _save: Button = %Save

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready():
	assert(scene_handle is SceneHandle, "invalid config; missing scene handle")

	_save_data = System.saves.create_new_save_data()

	if not System.saves.get_save_data(_save_data):
		# TODO: Return back to the main menu.
		assert(false, "invalid state; missing save data")

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
	scene_handle.transition_to(^"Main/Transition")


func _on_save_pressed() -> void:
	_save.disabled = true

	if await System.saves.store_save_data(_save_data):
		_update_counter_label()

	_save.disabled = false
