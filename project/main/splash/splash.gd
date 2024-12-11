##
## project/main/splash/splash.gd
##
## Splash implements a splash screen scene.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const AdvanceEvent := preload("res://addons/std/scene/event/advance.gd")
const SceneHandle := preload("res://addons/std/scene/handle.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene_handle is a node path to a 'godot-plugin-std' scene handle used to emit
## transition events to the main scene state machine.
@export_node_path var scene_handle := NodePath()

## actions_advance is the list of action names which, when activated, will advance the
## splash screen to the next scene state.
@export var actions_advance := PackedStringArray(["ui_accept", "ui_cancel"])

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _scene_handle: SceneHandle = get_node_or_null(scene_handle)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		accept_event()
		_scene_handle.advance()


func _input(event: InputEvent) -> void:
	if (
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
		or Array(actions_advance).any(func(a): return event.is_action_pressed(a))
	):
		get_viewport().set_input_as_handled()
		_scene_handle.advance()


func _ready() -> void:
	assert(_scene_handle, "invalid config; missing scene handle")
