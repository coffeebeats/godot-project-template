##
## project/main/load/loading.gd
##
## Loading implements a loading screen scene.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const AdvanceEvent := preload("res://addons/std/scene/event/advance.gd")
const SceneHandle := preload("res://addons/std/scene/handle.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## scene_handle is a node path to a 'godot-plugin-std' scene handle used to emit
## transition events to the main scene state machine.
@export var scene_handle: SceneHandle = null

## scene_path_failed is the scene state to navigate to if loading fails.
@export var scene_path_failed: NodePath = ^"Main/Transition"

## scene_path_success is the scene state to navigate to if loading succeeds.
@export var scene_path_success: NodePath = ^"Core/Map/Transition"

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(scene_handle is SceneHandle, "invalid config; missing scene handle")

	_load_scene()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _load_scene() -> void:
	var saves := Systems.saves()
	var data := saves.create_new_save_data()

	if not await saves.load_save_data(data):
		scene_handle.transition_to(scene_path_failed)
		return

	# TODO: Add behavior to load the necessary resources and set game system state.

	scene_handle.transition_to(scene_path_success, data)
