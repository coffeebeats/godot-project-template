##
## project/settings/component/action_set.gd
##
## ActionSet is a subclass of a settings group component which creates a setting per
## action included in the specified `StdInputActionSet`.
##

extends "group.gd"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("res://addons/std/input/godot/binding.gd")
const BindingScene := preload("binding.tscn")
const Reset := preload("reset.gd")
const ResetScene := preload("reset.tscn")
const Setting := preload("setting.gd")
const SettingScene := preload("setting.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

const LOCALE_MSGID_ACTION_PREFIX := &"actions_"
const LOCALE_MSGID_ACTION_SET_PREFIX := &"options_controls_"


# -- CONFIGURATION ------------------------------------------------------------------- #

@export_subgroup("Action")

## action_set is an input action set which defines the configured action.
@export var action_set: StdInputActionSet = null:
	set(value):
		action_set = value

		if value is StdInputActionSet:
			label = LOCALE_MSGID_ACTION_SET_PREFIX + value.name

@export_subgroup("Binding")

## scope is the settings scope in which binding overrides will be stored.
@export var scope: StdSettingsScope = null

@export_subgroup("Player")

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

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _reset: Reset = %Reset

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	_clear_settings()


func _ready() -> void:
	assert(action_set is StdInputActionSet, "invalid config; missing action set")
	action_set = action_set # Trigger 'label' update.

	_reset.action_set = action_set
	_reset.player_id = player_id

	_generate_settings()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _clear_settings() -> void:
	for node in get_children():
		if not node is Setting:
			continue

		remove_child(node)
		node.queue_free()


func _generate_settings() -> void:
	if not action_set is StdInputActionSet:
		assert(Engine.is_editor_hint(), "invalid state; missing action set")
		return

	_clear_settings()

	for action in action_set.list_action_names():
		var primary := BindingScene.instantiate()
		primary.action = action
		primary.action_set = action_set
		primary.binding_index = StdInputDeviceActions.BINDING_INDEX_PRIMARY
		primary.player_id = player_id
		primary.scope = scope

		var secondary := BindingScene.instantiate()
		secondary.action = action
		secondary.action_set = action_set
		secondary.binding_index = StdInputDeviceActions.BINDING_INDEX_SECONDARY
		secondary.player_id = player_id
		secondary.scope = scope

		var reset := ResetScene.instantiate()
		reset.scope = scope
		reset.bindings.append_array([primary, secondary])

		var setting := SettingScene.instantiate()
		setting.label = tr(action, LOCALE_MSGID_ACTION_PREFIX + action_set.name)
		setting.add_child(reset)
		setting.add_child(primary)
		setting.add_child(secondary)

		add_child(setting)
