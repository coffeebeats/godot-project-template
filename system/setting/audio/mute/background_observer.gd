##
## system/setting/audio/mute/background_observer.gd
##
## BackgroundPropertyObserver is a `StdSettingsObserver` that handles muting the game in
## the background.
##

extends StdSettingsObserver

# -- DEFINITIONS --------------------------------------------------------------------- #


## PlayInBackground is a node which handles muting the game when the player focuses a
## different window. The 'enabled' property can be updated to toggle behavior.
class PlayInBackground:
	extends Node

	var bus: int = -1
	var enabled: bool = false

	var _is_dangling_mute: bool = false
	var _is_out: bool = false

	# NOTE: Some operating systems may produce 'NOTIFICATION_APPLICATION_FOCUS_OUT'
	# multiple times on the same focus loss event. As a result, the handler must be
	# idempotent.
	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_APPLICATION_FOCUS_IN:
				if not _is_out:
					return

				_is_out = false

				if _is_dangling_mute:
					print(
						"system/setting/audio/mute/background_observer.gd[",
						get_instance_id(),
						"]: unmuting sound",
					)

					_is_dangling_mute = false
					AudioServer.set_bus_mute(bus, false)

			NOTIFICATION_APPLICATION_FOCUS_OUT:
				if _is_out:
					return

				_is_out = true

				# If the game was already muted, we don't want to incorrectly
				# unmute when the game re-focuses.
				var is_muted: bool = AudioServer.is_bus_mute(bus)
				_is_dangling_mute = not is_muted

				if not is_muted and not enabled:
					print(
						"system/setting/audio/mute/background_observer.gd[",
						get_instance_id(),
						"]: muting sound in background",
					)

					AudioServer.set_bus_mute(bus, true)


# -- CONFIGURATION ------------------------------------------------------------------- #

## property is a `StdSettingsPropertyBool` defining the mute-in-background property to
## observe.
@export var property: StdSettingsPropertyBool = null

## bus is the name of the bus to mute.
@export var bus: StringName = "Master"

# -- INITIALIZATION ------------------------------------------------------------------ #

var _handler: PlayInBackground = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	assert(property is StdSettingsPropertyBool, "invalid config: missing property")
	return [property]


func _handle_value_change(
	_config: Config, _property: StdSettingsProperty, mute_in_background: bool
) -> void:
	assert(_handler is Node, "invalid state: missing handler node")
	if not _handler:
		return

	print(
		"system/setting/audio/mute/background_observer.gd[",
		get_instance_id(),
		"]: setting background mute status: ",
		mute_in_background,
	)

	_handler.enabled = not mute_in_background


func _mount_observer_node() -> Node:
	assert(not _handler, "invalid state: found dangling handler")
	_handler = _create_observer_node()
	return _handler


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _create_observer_node() -> PlayInBackground:
	assert(property is StdSettingsPropertyBool, "invalid config: missing property")

	var node := PlayInBackground.new()
	node.bus = AudioServer.get_bus_index(bus)
	node.enabled = property.default
	assert(node.bus != 1, "invalid config: missing bus")
	return node
