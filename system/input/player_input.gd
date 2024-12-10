##
## system/input/player_input.gd
##
## `PlayerInput` is an auto-loaded singleton `Node` which contains all of the input-
## related behaviors for the game.
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

@export var default_action_set: StdInputActionSet = null

@export var default_action_set_layers: Array[StdInputActionSetLayer] = []


# -- INITIALIZATION ------------------------------------------------------------------ #

var _player1: StdInputSlot = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _ready() -> void:
	_player1 = StdInputSlot.for_player(1)
	assert(_player1 is StdInputSlot, "invalid state; missing input slot")

	_player1.device_activated.connect(func(d): print("device activated: %s (type=%d)" % [d, d.device_type]))
	_player1.device_connected.connect(func(d): print("device connected: %s (type=%d)" % [d, d.device_type]))
	_player1.device_disconnected.connect(func(d): print("device disconnected: %s (type=%d)" % [d, d.device_type]))

	for device in _player1.get_connected_devices():
		print("Connected device: ", device, " (%d)" % device.device_type)

	var active := _player1.get_active_device()
	print("active device: ", active, " (%d)" % active.device_type)

	_player1.load_action_set(default_action_set)

	for layer in default_action_set_layers:
		_player1.enable_action_set_layer(layer)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
