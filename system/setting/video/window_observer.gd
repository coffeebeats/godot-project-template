##
## system/setting/video/window_observer.gd
##
## WindowObserver is a `StdSettingsObserver` which handles changing the window mode and
## display resolution.
##

extends StdSettingsObserver

# -- CONFIGURATION ------------------------------------------------------------------- #

## window_mode_property is a settings property defining the window mode property to
## observe.
@export var window_mode_property: StdSettingsPropertyInt = null

## resolution_property is a settings property defining the target resolution.
@export var resolution_property: StdSettingsPropertyVector2 = null

@export_category("Window size")

## window_height_property is a settings property for the project's window height
## override value.
##
## NOTE: This must be synced to project settings to work.
@export var window_height_property: StdSettingsPropertyInt = null

## window_width_property is a settings property for the project's window width
## override value.
##
## NOTE: This must be synced to project settings to work.
@export var window_width_property: StdSettingsPropertyInt = null

# FIXME(https://github.com/godotengine/godot/issues/94551): Remove this option.
## disable_resize_when_windowed adds a temporary workaround for
## https://github.com/godotengine/godot/issues/94551. Note that this workaround in turn
## suffers from https://github.com/godotengine/godot/issues/81640.
@export var disable_resize_when_windowed: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #


func set_resolution(resolution: Vector2, should_center: bool = false) -> void:
	assert(resolution_property, "invalid state: missing resolution property")

	var window_id := get_window().get_window_id()

	# NOTE: Fullscreen always matches window size to screen size.
	if _is_fullscreen(window_id):
		return

	var target := Vector2i(resolution)

	if target == get_window().size:
		return

	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: updating window resolution: %s" % target,
	)

	get_window().size = target

	if should_center:
		_center_window(window_id)

	_save_resolution(target)


func set_window_mode(mode: DisplayServer.WindowMode, resolution: Vector2) -> void:
	var window_id := get_window().get_window_id()

	var was_fullscreen := _is_fullscreen(window_id)

	if DisplayServer.window_get_mode(window_id) != mode:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: updating window mode: %d" % mode,
		)

		DisplayServer.window_set_mode(mode, window_id)

	var is_fullscreen := _is_fullscreen(window_id)

	if was_fullscreen and not is_fullscreen:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: disabling fullscreen",
		)

		(
			DisplayServer
			. window_set_flag(
				DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
				true,
				window_id,
			)
		)
		(
			DisplayServer
			. window_set_flag(
				DisplayServer.WINDOW_FLAG_BORDERLESS,
				false,
				window_id,
			)
		)

		return call_deferred(&"set_resolution", resolution, true)

	if not was_fullscreen and is_fullscreen:
		# Fullscreen mode forces the resolution to match the screen size. Update the
		# selected resolution to match this
		var size := DisplayServer.screen_get_size()
		return resolution_property.set_value(Vector2(size.x, size.y))

	# FIXME(https://github.com/godotengine/godot/issues/94551): Remove this and disable
	# window resizing in project settings.
	var is_resizable := not (
		DisplayServer
		. window_get_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			window_id,
		)
	)
	if disable_resize_when_windowed and not is_fullscreen and is_resizable:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: disabling window resize capability",
		)

		call_deferred(&"_disable_resize", resolution, window_id)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [window_mode_property, resolution_property]


func _handle_value_change(property: StdSettingsProperty, value) -> void:
	if property == window_mode_property:
		var resolution: Vector2 = resolution_property.get_value()
		return set_window_mode(value, resolution)

	if property == resolution_property:
		var resolution := Vector2i(value)
		assert(
			resolution <= DisplayServer.screen_get_size(),
			"invalid argument: resolution larger than screen",
		)

		return set_resolution(value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _center_window(window_id: int) -> void:
	var size_screen := DisplayServer.screen_get_size()
	var size_window := DisplayServer.window_get_size(window_id)
	var size_title := DisplayServer.window_get_title_size("Godot", window_id)

	DisplayServer.window_set_position(
		(size_screen / 2 - size_window / 2) + Vector2i(0, size_title.y), window_id
	)


func _disable_resize(resolution: Vector2, window_id: int) -> void:
	(
		DisplayServer
		. window_set_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			true,
			window_id,
		)
	)

	set_resolution(resolution)


func _is_fullscreen(window_id: int) -> bool:
	var mode := DisplayServer.window_get_mode(window_id)

	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func _save_resolution(size: Vector2i) -> void:
	window_height_property.set_value(size.y)
	window_width_property.set_value(size.x)
