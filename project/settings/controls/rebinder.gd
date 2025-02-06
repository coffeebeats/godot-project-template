##
## project/settings/rebinder.gd
##
## Rebinder is a floating `Modal` which handles rebinding a configured input action.
## Only one is required in the scene and `Binding` nodes should delegate to this node
## when rebinding.
##

extends Modal

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("res://addons/std/input/godot/binding.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_REBINDER := &"project/settings:rebinder"

const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_UNKNOWN := StdInputDevice.DEVICE_TYPE_UNKNOWN

const MSGCTXT_REBINDER_KEYBOARD := &"keyboard"
const MSGCTXT_REBINDER_GAMEPAD := &"gamepad"
const MSGID_REBINDER_TITLE := &"options_controls_rebinder_title"
const MSGID_REBINDER_INSTRUCTIONS := &"options_controls_rebinder_bind_or_exit"

# -- CONFIGURATION ------------------------------------------------------------------- #

## scope is a settings scope which contains input origin bindings for game actions.
@export var scope: StdSettingsScope = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _action_set: StdInputActionSet = null
var _action: StringName = &""
var _binding_index: StdInputDeviceActions.BindingIndex = (
	StdInputDeviceActions.BINDING_INDEX_PRIMARY
)
var _device: StdInputDevice = null
var _player: int = -1

@onready var _label_action: Label = %Action
@onready var _label_glyph: StdInputGlyph = %Glyph
@onready var _label_instructions_pre: Label = %InstructionsPre
@onready var _label_instructions_post: Label = %InstructionsPost

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## find_in_scene returns the `BindingPrompt` node within the scene, if it exists.
static func find_in_scene():
	return StdGroup.get_sole_member(GROUP_REBINDER)


## start begins the rebinding process for the specified action and player, making the
## modal visible and listening for the appropriate input events.
func start(
	action_set: StdInputActionSet,
	action: StringName,
	binding_index: StdInputDeviceActions.BindingIndex = (
		StdInputDeviceActions.BINDING_INDEX_PRIMARY
	),
	player: int = 1,
) -> bool:
	_action_set = action_set
	_action = action
	_binding_index = binding_index
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

	(
		_logger
		. debug(
			"Starting listening for new key binding.",
			(
				{&"action_set": _action_set.name, &"action": _action}
				if _action_set
				else {}
			),
		)
	)

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

	(
		_logger
		. debug(
			"Stopped listening for key bindings.",
			(
				{&"action_set": _action_set.name, &"action": _action}
				if _action_set
				else {}
			),
		)
	)

	Signals.disconnect_safe(slot.device_activated, _on_device_activated)

	_action_set = null
	_action = &""
	_binding_index = StdInputDeviceActions.BINDING_INDEX_PRIMARY
	_device = null
	_player = -1


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_REBINDER).remove_member(self)


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

	(
		Bindings
		. bind_action(
			scope,
			_action_set,
			_action,
			event,
			_device.device_category,
			_binding_index,
		)
	)

	stop()
	get_viewport().set_input_as_handled()


func _enter_tree() -> void:
	assert(
		StdGroup.is_empty(GROUP_REBINDER),
		"invalid state; found dangling binding prompt",
	)
	StdGroup.with_id(GROUP_REBINDER).add_member(self)


func _ready() -> void:
	super._ready()  # gdlint:ignore=private-method-call
	set_process_input(false)

	_logger = _logger.named(&"project/settings/rebind")


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_prompt() -> void:
	_label_glyph.player_id = _player
	_label_glyph.update()

	_label_action.text = tr(MSGID_REBINDER_TITLE) % _action

	var instructions_template := tr(
		MSGID_REBINDER_INSTRUCTIONS,
		(
			MSGCTXT_REBINDER_KEYBOARD
			if _device.device_type == DEVICE_TYPE_KEYBOARD
			else MSGCTXT_REBINDER_GAMEPAD
		),
	)

	var parts := instructions_template.split("%s", true, 1)
	assert(parts.size() == 2, "invalid state; unrecognized template")

	_label_instructions_pre.text = parts[0] if not parts.is_empty() else ""
	_label_instructions_post.text = parts[1] if not parts.is_empty() else ""


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_device_activated(device: StdInputDevice) -> void:
	_device = device
	_update_prompt()
