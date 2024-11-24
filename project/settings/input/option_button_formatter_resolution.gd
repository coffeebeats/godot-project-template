##
## std/setting/option_button_formatter_resolution.gd
##
## `OptionButtonFormatterResolution` is a type which describes how to format the
## `Vector2` resolution items.
##

extends StdSettingsControllerOptionButtonFormatter

# -- INITIALIZATION ------------------------------------------------------------------ #

static var resolution_4_3 := Vector2i(4, 3)
static var resolution_5_4 := Vector2i(5, 4)
static var resolution_14_9 := Vector2i(14, 9)
static var resolution_16_9 := Vector2i(16, 9)
static var resolution_16_10 := Vector2i(16, 10)
static var resolution_21_9 := Vector2i(21, 9)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _format_option(value: Variant) -> String:
	var resolution: Vector2 = value
	var aspect := _get_aspect_ratio(value)

	if aspect == Vector2i():
		return "%d x %d" % [resolution.x, resolution.y]

	return "%d x %d (%d:%d)" % [resolution.x, resolution.y, aspect.x, aspect.y]

# -- PRIVATE METHODS ----------------------------------------------------------------- #

func _get_aspect_ratio(value: Vector2) -> Vector2i:
	if abs(value.aspect() - resolution_16_9.aspect()) <= 0.02:
		return resolution_16_9
	if abs(value.aspect() - resolution_16_10.aspect()) <= 0.02:
		return resolution_16_10
	if abs(value.aspect() - resolution_21_9.aspect()) <= 0.02:
		return resolution_21_9
	if abs(value.aspect() - resolution_14_9.aspect()) <= 0.02:
		return resolution_14_9
	if abs(value.aspect() - resolution_5_4.aspect()) <= 0.02:
		return resolution_5_4
	if abs(value.aspect() - resolution_4_3.aspect()) <= 0.02:
		return resolution_4_3

	return Vector2i()
