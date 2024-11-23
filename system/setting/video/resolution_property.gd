##
## system/setting/property/video/resolution_options_property.gd
##
## `VideoResolution` is a settings property that specifies a display resolution.
##

extends StdSettingsPropertyVector2

# -- CONFIGURATION ------------------------------------------------------------------- #

## resolution_options_property is a settings property defining the list of supported
## target resolutions.
@export var resolution_options_property: StdSettingsPropertyVector2List = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## select_midpoint can be used to select the midpoint value from the list of supported
## resolution options.
func select_midpoint(force_notify: bool = false) -> bool:
	var options: PackedVector2Array = resolution_options_property.get_value()
	assert(not options.is_empty(), "invalid state; missing resolution options")

	@warning_ignore("integer_division")
	var value: Vector2 = options[len(options) / 2] if options else get_value()

	if set_value(value):
		return true

	if force_notify:
		value_changed.emit(value)

	return false


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(config: Config) -> Variant:
	var options: PackedVector2Array = resolution_options_property.get_value()
	assert(not options.is_empty(), "invalid state; missing resolution options")

	var value := config.get_vector2(category, name, default)
	if value in options:
		return value

	if default in options:
		return default

	@warning_ignore("integer_division")
	return options[len(options) / 2]  # Choose the midpoint option.


func _set_value_on_config(config: Config, value: Vector2) -> bool:
	if value == default:
		return config.erase(category, name)

	return config.set_vector2(category, name, value)
