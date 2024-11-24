##
## system/setting/video/window_observer.gd
##
## WindowObserver is a `StdSettingsObserver` which handles changing the window mode and
## display resolution.
##

extends StdSettingsObserver

# -- DEPENDENCIES -------------------------------------------------------------------- #

const StdSettingsPropertyResolution := preload("resolution_property.gd")
# const Feature := preload("res://platform/feature.gd")

# -- DEFINITIONS --------------------------------------------------------------------- #

static var window_modes_allowed: Array[DisplayServer.WindowMode] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]

# -- CONFIGURATION ------------------------------------------------------------------- #

## window_mode_property is a settings property defining the window mode property to
## observe.
@export var window_mode_property: StdSettingsPropertyInt = null

## resolution_property is a settings property defining the target resolution.
@export var resolution_property: StdSettingsPropertyResolution = null

## resolution_options_property is a settings property defining the list of supported
## target resolutions.
@export var resolution_options_property: StdSettingsPropertyVector2List = null

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

# -- INITIALIZATION ------------------------------------------------------------------ #

# FIXME(https://github.com/godotengine/godot/issues/94551): Remove this option.
## disable_resize_when_windowed adds a temporary workaround for
## https://github.com/godotengine/godot/issues/94551. Note that this workaround in turn
## suffers from https://github.com/godotengine/godot/issues/81640.
var _is_resize_enabled: bool = ProjectSettings.get_setting_with_override(&"display/window/size/resizable")

var _elapsed: float = 0.0

# -- PUBLIC METHODS ------------------------------------------------------------------ #


func set_resolution(resolution: Vector2, should_center: bool = false) -> void:
	assert(resolution_property, "invalid state: missing resolution property")

	var window := get_window()

	# NOTE: Fullscreen always matches window size to screen size.
	if _is_fullscreen(window.get_window_id()):
		return

	var window_size := window.size
	var window_size_target := Vector2i(resolution)

	if window_size_target != window_size:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: updating window resolution: %s" % window_size_target,
		)

		window.size = window_size_target

	# var screen := DisplayServer.get_display_safe_area().size
	# if resolution == Vector2(screen.x, screen.y) and window.mode != Window.MODE_MAXIMIZED:
	# 	window.mode = Window.MODE_MAXIMIZED

	if should_center:
		_center_window(window.get_window_id())


func set_window_mode(mode: DisplayServer.WindowMode) -> void:
	var window := get_window()
	var window_id := window.get_window_id()

	var was_fullscreen := _is_fullscreen(window_id)

	if DisplayServer.window_get_mode(window_id) != mode:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: updating window mode: %d" % mode,
		)

		DisplayServer.window_set_mode(mode, window_id)

	# _update_resolution_options()

	var is_fullscreen := _is_fullscreen(window_id)

	if was_fullscreen and not is_fullscreen:
		_disable_fullscreen_effects()
		# resolution_property.select_midpoint(true)

	# if not was_fullscreen and is_fullscreen:
	# 	# Fullscreen mode forces the resolution to match the screen size. Update the
	# 	# selected resolution to match this
	# 	var size := DisplayServer.window_get_size_with_decorations()
	# 	if not resolution_property.set_value(Vector2(size.x, size.y)):
	# 		_update_resolution()
	# 	return

	# FIXME(https://github.com/godotengine/godot/issues/94551): Remove this and disable
	# window resizing in project settings.
	var is_resizable := not (
		DisplayServer
		.window_get_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			window_id,
		)
	)
	if not _is_resize_enabled and not is_fullscreen and is_resizable:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: disabling window resize capability",
		)

		(
		DisplayServer
		.window_set_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			true,
			window_id,
		)
	)

	
# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _ready() -> void:
	super._ready()

	set_process(false)

	var window := get_window()

	var err := window.titlebar_changed.connect(_on_Window_titlebar_changed)
	assert(err == OK, "failed to connect to signal")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 2:
		_watch_window_mode_stop()

	_update_window_mode()

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [window_mode_property, resolution_property]


func _handle_value_change(property: StdSettingsProperty, value) -> void:
	if property == window_mode_property:
		return set_window_mode(value)

	if property == resolution_property:
		var resolution := Vector2i(value)
		assert(
			resolution <= DisplayServer.screen_get_size(),
			"invalid argument: resolution larger than screen",
		)

		_save_resolution(resolution)

		var is_windowed: bool = (
			window_mode_property.get_value() == DisplayServer.WINDOW_MODE_WINDOWED
		)
		return set_resolution(value, is_windowed)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _center_window(window_id: int) -> void:
	var size_screen := DisplayServer.screen_get_size()
	var size_window := DisplayServer.window_get_size_with_decorations(window_id)
	var size_title := DisplayServer.window_get_title_size("Godot", window_id)

	DisplayServer.window_set_position(
		(size_screen / 2 - size_window / 2) + Vector2i(0, size_title.y), window_id
	)

func _disable_fullscreen_effects(window_id: int = 0) -> void:
	print(
		"system/setting/video/window_observer.gd[",
		get_instance_id(),
		"]: disabling fullscreen effects",
	)

	(
		DisplayServer
		.window_set_flag(
			DisplayServer.WINDOW_FLAG_BORDERLESS,
			false,
			window_id,
		)
	)

	# FIXME: Upon first loading a game in fullscreen mode, assuming the window is
	# resizable, resizing via code *after* changing to windowed mode fails if window 
	# resize is enabled. Therefore, manually disable it here, then conditionally
	# enable it after resizing the window.
	(
	DisplayServer
		.window_set_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			true,
			window_id,
		)
	)

	if _is_resize_enabled:
		(
		DisplayServer
			.window_set_flag(
				DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
				false,
				window_id,
			)
		)

func _is_fullscreen(window_id: int) -> bool:
	var mode := DisplayServer.window_get_mode(window_id)

	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)

func _handle_window_mode_change(was_fullscreen: bool, window_id: int = 0) -> void:
	_update_resolution_options()

	var is_fullscreen := _is_fullscreen(window_id)

	if was_fullscreen and not is_fullscreen:
		_disable_fullscreen_effects()
		resolution_property.select_midpoint(true)


	if not was_fullscreen and is_fullscreen:
		# Fullscreen mode forces the resolution to match the screen size. Update the
		# selected resolution to match this
		var size := DisplayServer.window_get_size_with_decorations()
		if not resolution_property.set_value(Vector2(size.x, size.y)):
			_update_resolution()
		return

	# FIXME(https://github.com/godotengine/godot/issues/94551): Remove this and disable
	# window resizing in project settings.
	var is_resizable := not (
		DisplayServer
		.window_get_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			window_id,
		)
	)
	if not _is_resize_enabled and not is_fullscreen and is_resizable:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: disabling window resize capability",
		)

		(
		DisplayServer
		.window_set_flag(
			DisplayServer.WINDOW_FLAG_RESIZE_DISABLED,
			true,
			window_id,
		)
	)

func _save_resolution(size: Vector2i) -> void:
	window_height_property.set_value(size.y)
	window_width_property.set_value(size.x)

func _update_resolution() -> void:
	var resolution: Vector2 = resolution_property.get_value()
	resolution_property.value_changed.emit(resolution)


func _update_resolution_options() -> void:
	var resolution_options: PackedVector2Array = resolution_options_property.get_value()
	print("NEW OPTIONS: %s" % str(resolution_options))
	resolution_options_property.value_changed.emit(resolution_options)


func _update_window_mode() -> void:
	var window := get_window()
	var window_mode := window.mode
	var window_mode_target: Window.Mode = window_mode_property.get_value()

	if window_mode_target != window_mode:
		print(
			"system/setting/video/window_observer.gd[",
			get_instance_id(),
			"]: window mode update required: %d" % window_mode,
		)

		if window_mode == Window.MODE_MAXIMIZED:
			window_mode = Window.MODE_WINDOWED

		if window_mode in window_modes_allowed:
			window_mode_property.set_value(window_mode)

			_update_resolution_options()

			if window_mode >= Window.MODE_FULLSCREEN:
				var size := DisplayServer.window_get_size_with_decorations()
				if not resolution_property.set_value(Vector2(size.x, size.y)):
					_update_resolution()
				return
			else:
				_update_resolution()
			# if window_mode < Window.MODE_FULLSCREEN:
			# 	_disable_fullscreen_effects()

			# call_deferred(&"_update_resolution_options")
			# call_deferred(&"_update_resolution")

		call_deferred(&"_watch_window_mode_stop")


func _watch_window_mode_start() -> void:
	_elapsed = 0.0
	if not is_processing():
		set_process(true)
		print("STARTING WINDOW MODE WATCHER")

func _watch_window_mode_stop() -> void:
	_elapsed = 0.0
	if is_processing():
		set_process(false)
		print("STOPPING WINDOW MODE WATCHER")

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_Window_titlebar_changed() -> void:
	call_deferred(&"_watch_window_mode_start")
