##
## project/settings/component/binding_prompt.gd
##
## BindingPrompt is a floating `Modal` which handles rebinding a configured input
## action. Only one is required in the scene and `Binding` nodes should delegate to this
## node when rebinding.
##

extends Modal

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_BINDING_PROMPT := &"project/settings:binding-prompt"

const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_UNKNOWN := StdInputDevice.DEVICE_TYPE_UNKNOWN

# -- INITIALIZATION ------------------------------------------------------------------ #

var _action_set: StdInputActionSet = null
var _action: StringName = &""
var _device: StdInputDevice = null
var _player: int = -1

@onready var _label_action: Label = %Action
@onready var _label_glyph: StdInputGlyph = %Glyph
@onready var _label_press: Label = %Press

# -- PUBLIC METHODS ------------------------------------------------------------------ #

## find_in_scene returns the `BindingPrompt` node within the scene, if it exists.
static func find_in_scene():
	return StdGroup.get_sole_member(GROUP_BINDING_PROMPT)

## start begins the rebinding process for the specified action and player, making the
## modal visible and listening for the appropriate input events.
func start(action_set: StdInputActionSet, action: StringName, player: int = 1) -> bool:
	_action_set = action_set
	_action = action
	_player = player

	var slot := StdInputSlot.for_player(player)
	if not slot:
		assert(false, "invalid state; missing input slot")
		return false

	_device = slot.get_active_device()
	if not _device:
		return false

	if Signals.connect_safe(slot.device_activated, _on_device_activated) != OK:
		return false

	assert(not is_processing_input(), "invalid state; already processing input")
	set_process_input(true)

	_update_prompt()
	visible = true

	return true


## stop terminates the rebinding process, halting input event listeners and closing the
## modal overlay.
func stop() -> void:
	visible = false

	set_process_input(false)

	var slot := StdInputSlot.for_player(_player)
	if not slot:
		assert(false, "invalid state; missing input slot")
		return

	Signals.disconnect_safe(slot.device_activated, _on_device_activated)

	_action_set = null
	_action = &""
	_device = null
	_player = -1

	_label_action.text = ""
	_label_press.text = ""


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _exit_tree() -> void:
	StdGroup.with_id(GROUP_BINDING_PROMPT).remove_member(self)

func _input(event: InputEvent) -> void:
	if not event.is_action_type() or not event.is_pressed():
		return

	if not _device:
		assert(false, "invalid state; missing device")
		stop()
		return

	# FIXME: This will block valid actions.
	if event is InputEventAction:
		get_viewport().set_input_as_handled()
		return

	# NOTE: Let this event through so that the other device can be activated.
	if not _device.is_matching_event_origin(event):
		return

	if event.is_action_pressed("ui_binding_stop"):
		get_viewport().set_input_as_handled()
		stop()
		return

	if not _action_set.is_matching_event_origin(_action, event):
		get_viewport().set_input_as_handled()
		return

	# TODO: Implement rebinding.

	stop()
	get_viewport().set_input_as_handled()

func _enter_tree() -> void:
	assert(
		StdGroup.is_empty(GROUP_BINDING_PROMPT),
		"invalid state; found dangling binding prompt",
	)
	StdGroup.with_id(GROUP_BINDING_PROMPT).add_member(self)

func _ready() -> void:
	super._ready() # gdlint:ignore=private-method-call
	set_process_input(false)

# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_prompt() -> void:
	_label_glyph.player_id = _player
	_label_glyph.update()

	_label_action.text = 'Bind "%s"' % _action
	_label_press.text = (
		"Press any key now or"
		if _device.device_type == DEVICE_TYPE_KEYBOARD
		else "Press any button now or"
	)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_device_activated(device: StdInputDevice) -> void:
	_device = device
	_update_prompt()
