##
## project/settings/rebinder.gd
##
## Rebinder is a floating overlay which handles rebinding a configured input action.
## Uses a static instance pushed via `StdScreenManager`. Binding nodes delegate to
## `Rebinder.start_rebinding()` to initiate a rebind.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Bindings := preload("res://addons/std/input/godot/binding.gd")
const Signals := preload("res://addons/std/event/signal.gd")
const Rebinder := preload("rebinder.gd")
const RebinderScene := preload("rebinder.tscn")

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_REBINDER := &"project/settings:rebinder"

const DEVICE_TYPE_KEYBOARD := StdInputDevice.DEVICE_TYPE_KEYBOARD
const DEVICE_TYPE_UNKNOWN := StdInputDevice.DEVICE_TYPE_UNKNOWN

const MSGCTXT_REBINDER_KEYBOARD := &"keyboard"
const MSGCTXT_REBINDER_GAMEPAD := &"gamepad"
const MSGID_REBINDER_TITLE := &"options_controls_rebinder_title"
const MSGID_REBINDER_INSTRUCTIONS := &"options_controls_rebinder_bind_or_exit"

# -- CONFIGURATION ------------------------------------------------------------------- #

## screen is the `StdScreen` describing how the `Rebinder` is pushed/popped from the
## screen stack.
@export var screen: StdScreen = null

# -- INITIALIZATION ------------------------------------------------------------------ #

# FIXME: This instance needs to be freed on game exit.
static var _instance: Rebinder = null  # gdlint:ignore=class-definitions-order
static var _logger := StdLogger.create(&"project/settings/rebind")  # gdlint:ignore=class-definitions-order,max-line-length

var _action_set: StdInputActionSet = null
var _action: StringName = &""
var _binding_index := StdInputDeviceActions.BINDING_INDEX_PRIMARY
var _cursor_was_visible: bool = false
var _device: StdInputDevice = null
var _player: int = -1
var _scope: StdSettingsScope = null

@onready var _label_action: Label = %Action
@onready var _label_glyph: StdInputGlyph = %Glyph
@onready var _label_instructions_pre: Label = %InstructionsPre
@onready var _label_instructions_post: Label = %InstructionsPost

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## find_in_scene returns the `BindingPrompt` node within the scene, if it exists.
static func find_in_scene():
	return StdGroup.get_sole_member(GROUP_REBINDER)


## start_rebinding begins the rebinding process for the specified action and player,
## pushing the rebinder screen onto the screen stack.
static func start_rebinding(
	scope: StdSettingsScope,
	action_set: StdInputActionSet,
	action: StringName,
	binding_index: StdInputDeviceActions.BindingIndex = (
		StdInputDeviceActions.BINDING_INDEX_PRIMARY
	),
	player: int = 1,
) -> bool:
	var slot := StdInputSlot.for_player(player)
	if not slot:
		assert(false, "invalid state; missing input slot")
		return false

	var device := slot.get_active_device()
	if not device:
		return false

	if not _instance:
		_instance = RebinderScene.instantiate()

	_instance._cursor_was_visible = Systems.input().is_cursor_visible()

	_instance._scope = scope
	_instance._action_set = action_set
	_instance._action = action
	_instance._binding_index = binding_index
	_instance._player = player
	_instance._device = device

	Signals.connect_safe(slot.device_activated, _instance._on_device_activated)

	Main.screens().push(_instance.screen, _instance)
	_instance._activate()

	return true


## stop terminates the rebinding process, halting input event listeners and popping the
## rebinder screen.
func stop() -> void:
	# NOTE: Restore cursor visibility *before* popping the screen. The rebind key press
	# may have triggered cursor hiding (the cursor's '_input' processes key events as
	# hide actions). Restoring here prevents focus mode from activating during the
	# screen close sequence.
	if _cursor_was_visible:
		Systems.input().show_cursor()

	set_process_input(false)

	var slot := StdInputSlot.for_player(_player)
	if not slot:
		assert(false, "invalid state; missing input slot")
		return

	(
		_logger
		. debug(
			"Stopped listening for key bindings.",
			{
				&"action": _action,
				&"action_set": _action_set.name if _action_set else &""
			},
		)
	)

	Signals.disconnect_safe(slot.device_activated, _on_device_activated)

	_scope = null
	_action_set = null
	_action = &""
	_binding_index = StdInputDeviceActions.BINDING_INDEX_PRIMARY
	_cursor_was_visible = false
	_device = null
	_player = -1

	Main.screens().pop()


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
			_scope,
			_action_set,
			_action,
			event,
			_device.device_category,
			_binding_index,
		)
	)

	get_viewport().set_input_as_handled()
	stop()


func _enter_tree() -> void:
	assert(
		StdGroup.is_empty(GROUP_REBINDER),
		"invalid state; found dangling binding prompt",
	)
	StdGroup.with_id(GROUP_REBINDER).add_member(self)


func _ready() -> void:
	assert(screen is StdScreen, "invalid config; missing screen")

	set_process_input(false)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _activate enables input processing and updates the prompt UI. Must be called after
## the node is in the tree (so children are ready).
func _activate() -> void:
	assert(not is_processing_input(), "invalid state; already processing input")
	set_process_input(true)

	_update_prompt()

	(
		_logger
		. debug(
			"Starting listening for new key binding.",
			{
				&"action": _action,
				&"action_set": _action_set.name if _action_set else &""
			},
		)
	)


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
