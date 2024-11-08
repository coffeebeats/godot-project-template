##
## system/setting/property/video/resolution_options_property.gd
##
## `VideoResolutionOptions` is a read-only settings property that provides a list of
## display resolution options based on various video preferences.
##

extends StdSettingsPropertyVector2List

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(_config: Config) -> Variant:
	var resolutions := PackedVector2Array([Vector2(1920, 1080)])

	return resolutions
