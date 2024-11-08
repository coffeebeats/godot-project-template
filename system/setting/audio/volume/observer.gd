##
## system/setting/audio/volume/observer.gd
##
## VolumeObserver is a `StdSettingsObserver` that applies the volume changes configured
## within a settings scope.
##

extends StdSettingsObserver

# -- DEPENDENCIES -------------------------------------------------------------------- #

const PropertyVolumeMaster := preload("master_property.tres")
const PropertyVolumeMusic := preload("music_property.tres")
const PropertyVolumeSoundEffects := preload("sound_effects_property.tres")

# -- CONFIGURATION ------------------------------------------------------------------- #

## bus is the name of the audio bus to modify. This should correspond to the property
## being observed.
@export var bus: StringName = ""

## property is a `StdSettingsPropertyFloatRange` defining the volume property to
## observe. Note that the value should be a linear value, not exponential (e.g. dB).
@export var property: StdSettingsPropertyFloatRange = null

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [property]


func _handle_value_change(_property: StdSettingsProperty, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus)
	assert(bus_index != -1, "invalid config: missing audio bus")
	if bus_index == -1:
		return # Nothing to do in this case.

	var volume := linear_to_db(
		clampf((value - property.minimum) / (property.maximum - property.minimum), 0, 1))

	AudioServer.set_bus_volume_db(bus_index, volume)

	print(bus, " volume adjusted to: %f" % AudioServer.get_bus_volume_db(bus_index))