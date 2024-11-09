##
## system/setting/property/video/resolution_options_property.gd
##
## `VideoResolutionOptions` is a read-only settings property that provides a list of
## display resolution options based on various video preferences.
##

extends StdSettingsPropertyVector2List

# -- INITIALIZATION ------------------------------------------------------------------ #

static var RESOLUTIONS := PackedVector2Array([
	# 4:3
	Vector2(800, 600),
	Vector2(1024, 768),
	Vector2(2048, 1536),
	# 5:4
	Vector2(1280, 1024),
	# 16:9
	Vector2(1280, 720),
	Vector2(1360, 768),
	Vector2(1366, 768),
	Vector2(1600, 900),
	Vector2(1920, 1080),
	Vector2(2048, 1152),
	Vector2(2560, 1440),
	Vector2(3840, 2160),
	Vector2(7680, 4320),
	# 16:10
	Vector2(960, 600),
	Vector2(1280, 800),
	Vector2(1440, 900),
	Vector2(1680, 1050),
	Vector2(1920, 1200),
	Vector2(2560, 1600),
	Vector2(2880, 1800),
	# 21:9
	Vector2(2560, 1080),
	Vector2(3440, 1440)
])

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_value_from_config(_config: Config) -> Variant:
	var resolutions := PackedVector2Array()

	var screen := DisplayServer.screen_get_size()

	var has_screen_resolution: bool = false
	for resolution in RESOLUTIONS:
		if resolution.aspect() != screen.aspect():
			continue

		if resolution.x <= screen.x and resolution.y <= screen.y:
			resolutions.append(resolution)

			if Vector2i(round(resolution.x), round(resolution.y)) == screen:
				has_screen_resolution = true

	# If no resolutions match the screen's aspect ratio, just provide all resolutions
	# and let the user decide.
	if resolutions.is_empty():
		resolutions.append_array(RESOLUTIONS)

	if not has_screen_resolution:
		resolutions.append(screen)

	
	resolutions.sort()

	return resolutions
