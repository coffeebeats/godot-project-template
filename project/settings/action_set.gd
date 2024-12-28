##
## project/settings/component/action_set.gd
##
## ActionSet is a subclass of a settings group component which creates a setting per
## action included in the specified `StdInputActionSet`.
##

@tool
extends "group.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const BindingScene := preload("res://project/ui/input/binding.tscn")
const Setting := preload("setting.gd")
const SettingScene := preload("setting.tscn")

# -- CONFIGURATION ------------------------------------------------------------------- #

## action_set is an input action set which defines the configured action.
@export var action_set: StdInputActionSet = null:
	set(value):
		action_set = value

		if not value:
			_clear_settings()
			return

		label = action_set.name
		_generate_settings()

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1:
	set(value):
		player_id = value

		for node in get_children():
			if not node is Setting:
				continue

			node.get_child(1).player_id = value

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	action_set = action_set
	player_id = player_id


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _clear_settings() -> void:
	for node in get_children():
		if not node is Setting:
			continue

		remove_child(node)
		node.queue_free()


func _generate_settings() -> void:
	assert(action_set is StdInputActionSet, "invalid state; missing action set")

	_clear_settings()

	for action in (
		([action_set.action_absolute_mouse] if action_set.action_absolute_mouse else [])
		+ action_set.actions_analog_2d
		+ action_set.actions_analog_1d
		+ action_set.actions_digital
	):
		var binding := BindingScene.instantiate()
		binding.action_set = action_set
		binding.action = action
		binding.player_id = player_id

		var setting := SettingScene.instantiate()

		setting.label = action
		setting.add_child(binding)

		add_child(setting)
