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
@onready var _save: Button = %Save
@onready var _settings_menu: Modal = %SettingsMenu

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _input(event: InputEvent) -> void:
	if not event.is_action_type():
		return

	if event.is_action_pressed(&"ui_toggle_settings"):
		get_viewport().set_input_as_handled()

		if not Modal.are_any_open():
			_settings_menu.visible = true
		elif _settings_menu.is_head_modal():
			_settings_menu.visible = false


func _ready():
	assert(scene_handle is SceneHandle, "invalid config; missing scene handle")

	var saves := Systems.saves()
	_save_data = saves.create_new_save_data()

	saves.activate_slot(0)

	if not saves.get_save_data(_save_data):
		if not Feature.is_editor_build():
			scene_handle.transition_to(^"Main/Transition")
			return

		var success := saves.activate_slot(0)
		assert(success, "failed to load save data")

		success = await saves.load_save_data(_save_data)
		assert(success, "failed to load save data")

	Signals.connect_safe(_increment.pressed, _on_increment_pressed)
	Signals.connect_safe(_reset.pressed, _on_reset_pressed)
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

	if await Systems.saves().store_save_data(_save_data):
		_update_counter_label()

	_save.disabled = false
