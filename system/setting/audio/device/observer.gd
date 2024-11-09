##
## system/setting/audio/device/observer.gd
##
## AudioDeviceObserver is a `StdSettingsObserver` that handles changing the input and
## output devices.
##

extends StdSettingsObserver

# -- CONFIGURATION ------------------------------------------------------------------- #

## input_device is a `StdSettingsProperty` corresponding to the preferred input audio
## device.
@export var input_device: StdSettingsPropertyString = null

## output_device is a `SettingsProperty` corresponding to the preferred output audio
## device.
@export var output_device: StdSettingsPropertyString = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	var properties: Array[StdSettingsProperty] = []

	if input_device is StdSettingsPropertyString:
		assert(input_device != output_device, "invalid config: can't use same device")

		properties.append(input_device)
	if output_device is StdSettingsPropertyString:
		assert(input_device != output_device, "invalid config: can't use same device")

		properties.append(output_device)

	assert(properties, "invalid config: missing at least one property")

	return properties


# FIXME(https://github.com/godotengine/godot/issues/75603): This might not work.
func _handle_value_change(
	_config: Config, property: StdSettingsProperty, value: String
) -> void:
	assert(value is String and value != "", "invalid argument: missing value")

	if property == input_device:
		print(
			"system/setting/audio/device/observer.gd[",
			get_instance_id(),
			"]: setting input device to: ",
			value,
		)

		assert(
			value in AudioServer.get_input_device_list(),
			"invalid config: device not in list",
		)

		AudioServer.input_device = value

	if property == output_device:
		print(
			"system/setting/audio/device/observer.gd[",
			get_instance_id(),
			"]: setting output device to: ",
			value,
		)

		assert(
			value in AudioServer.get_output_device_list(),
			"invalid config: device not in list",
		)

		AudioServer.output_device = value
