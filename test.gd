##
## Insert class description here.
##

extends Control

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

@export var action_set: StdInputActionSet = null
@export var action_set_layer: StdInputActionSetLayer = null


# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _slot: StdInputSlot = StdInputSlot.for_player(1)

@onready var _label_action_set := get_node("HBoxContainer/VBoxContainer3/ActionSet")
@onready var _label_action_set_layer := get_node("HBoxContainer/VBoxContainer3/ActionSetLayer")
@onready var _label_fps := get_node("HBoxContainer/VBoxContainer3/FPS")

@onready var _label_active := % "ActiveDevice"
@onready var _label_connected := % "ConnectedDevices"


# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _ready() -> void:
	$"HBoxContainer/VBoxContainer2/PrintLayers".pressed.connect(_on_print_layers_pressed)
	$"HBoxContainer/VBoxContainer2/LoadActionSet".pressed.connect(_on_load_action_set_pressed)
	$"HBoxContainer/VBoxContainer2/EnableActionSetLayer".pressed.connect(_on_enable_action_set_layer_pressed)
	$"HBoxContainer/VBoxContainer2/DeactivateActionSetLayer".pressed.connect(_on_disable_action_set_layer_pressed)
	
	# _slot.load_action_set(action_set)


func _input(event):
	if event is InputEventAction:
		print(event.device, " ", event)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_down"):
		print("!!!!!!!!!!!!!")

	_label_fps.text = "fps: %d" % Engine.get_frames_per_second()

	if not _slot:
		return

	var active := _slot.get_active_device()
	if not active:
		_label_active.text = "No active device"
	else:
		_label_active.text = "Active device: %d (type=%s)" % [active.device_id, _pretty_device_type(active.device_type)]

	var connected := _slot.get_connected_devices()
	if not connected:
		_label_connected.text = "No connected devices"
	else:
		var formatted := connected.map(func(d): return "%d (type=%s)" % [d.device_id, _pretty_device_type(d.device_type)])
		_label_connected.text = "Connected devices: %s" % str(",".join(formatted))

	var current := _slot.actions.get_action_set(_slot.device_id)
	if not current:
		_label_action_set.text = "No action set"
	else:
		_label_action_set.text = "action set: %s" % current.name

	var layers := _slot.actions.list_action_set_layers(_slot.device_id)
	if not layers:
		_label_action_set_layer.text = "No action set layers"
	else:
		_label_action_set_layer.text = "Action set layers: %s" % ",".join(layers.map(func(l): return l.resource_path.get_file()))

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #

func _pretty_device_type(dt: StdInputDevice.DeviceType) -> String:
	match dt:
		StdInputDevice.DEVICE_TYPE_GENERIC:
			return "GENERIC"
		StdInputDevice.DEVICE_TYPE_KEYBOARD:
			return "KBM"
		StdInputDevice.DEVICE_TYPE_PS_4:
			return "PS4"
		StdInputDevice.DEVICE_TYPE_PS_5:
			return "PS5"
		StdInputDevice.DEVICE_TYPE_STEAM_CONTROLLER:
			return "STEAM CONTROLLER"
		StdInputDevice.DEVICE_TYPE_STEAM_DECK:
			return ""
		StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_PAIR:
			return ""
		StdInputDevice.DEVICE_TYPE_SWITCH_JOY_CON_SINGLE:
			return ""
		StdInputDevice.DEVICE_TYPE_SWITCH_PRO:
			return "SWITCH PRO"
		StdInputDevice.DEVICE_TYPE_TOUCH:
			return ""
		StdInputDevice.DEVICE_TYPE_XBOX_360:
			return ""
		StdInputDevice.DEVICE_TYPE_XBOX_ONE:
			return ""
	
	return "UNKNOWN"

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_print_layers_pressed() -> void:
	var devices := _slot.get_connected_devices(false)
	if not devices:
		return

	print("# DEVICES: ", devices.map(func(d): return "%d (type=%d)" % [d.device_id, d.device_type]))
	print("# LAYERS:")
	for device in devices:
		print("	# %d: %s" % [device.device_id, _slot.actions_joy.list_action_set_layers(device.device_id)])
	
func _on_load_action_set_pressed() -> void:
	if not _slot:
		return

	_slot.load_action_set(action_set)

func _on_enable_action_set_layer_pressed() -> void:
	if not _slot:
		return

	_slot.enable_action_set_layer(action_set_layer)
	_on_print_layers_pressed()

func _on_disable_action_set_layer_pressed() -> void:
	if not _slot:
		return

	_slot.disable_action_set_layer(action_set_layer)
	_on_print_layers_pressed()

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
