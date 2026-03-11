##
## project/main/main.gd
##
## Main is the top-level node responsible for orchestrating all systems and scenes. It
## registers itself via `StdGroup` and exposes static accessors for screen navigation
## and game state.
##

@tool
class_name Main
extends ColorRect

# -- DEFINITIONS --------------------------------------------------------------------- #

## GROUP_MAIN is the StdGroup identifier for the Main singleton.
const GROUP_MAIN := &"main:shim"

## PROJECT_SETTING_BG_COLOR is the project setting name for the game's background color.
const PROJECT_SETTING_BG_COLOR := &"application/boot_splash/bg_color"

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")
const Splash := preload("./splash/splash.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export_group("Screens")

## initial is the screen shown after splash completes (e.g. main menu).
@export var initial: StdScreen

## loading is the screen shown while loading game data.
@export var loading: StdScreen

## splash is the ordered list of splash screens shown during boot.
@export var splash: Array[StdScreen] = []

## game is the gameplay screen navigated to after save data loads.
@export var game: StdScreen

@export_group("Error handling")

## error_dialog is the packed scene for the global error dialog.
@export var error_dialog: PackedScene

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create(&"project/main")

var _error_dialog_busy: bool = false
var _error_dialog: AlertDialog = null
var _is_loading: bool = false
var _manager: StdScreenManager = null
var _play_start_ticks: int = -1
var _preload_results: Dictionary = {}
var _save_data: ProjectSaveData = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# Screen navigation


## screens returns the `StdScreenManager` instance.
static func screens() -> StdScreenManager:
	return _get_main()._manager


# Save data


## get_active_save_data returns the currently loaded save data, or null.
static func get_active_save_data() -> ProjectSaveData:
	return _get_main()._save_data


## save_game asynchronously stores the current (or provided) save data to the active
## slot and returns whether the save succeeded.
static func save_game(data: ProjectSaveData = null) -> bool:
	var saves := Systems.saves()
	if saves.get_active_save_slot() < 0:
		return false

	var main := _get_main()

	if data != null:
		main._save_data = data

	if not main._save_data is ProjectSaveData:
		return false

	if saves.is_saving():
		await saves.slot_saved

	main._accumulate_play_time()

	var ok := await saves.store_save_data(main._save_data)
	if ok:
		main._save_data.clear_dirty()

	return ok


## request_save triggers an event-driven save (fire-and-forget). Skips if a save is
## already in-flight or data is not dirty. Game scenes should call this at meaningful
## state transitions.
static func request_save() -> void:
	var saves := Systems.saves()
	if saves.get_active_save_slot() < 0:
		return

	var main := _get_main()
	if not main._save_data is ProjectSaveData:
		return

	if saves.is_saving():
		return

	if not main._save_data.is_dirty() and not main._save_data.is_critical():
		return

	save_game()


# Game flow


## go_to_main_menu saves (if needed), clears game state, and navigates to the initial
## screen. Awaitable; callers that don't need the result can fire-and-forget.
static func go_to_main_menu() -> void:
	await _get_main()._unload_game()


## load_game activates the given save slot, loads its data, and navigates to the map.
## Returns whether the load succeeded. This method is awaitable.
static func load_game(slot: int) -> bool:
	return await _get_main()._load_game(slot)


## show_error displays a modal error dialog and returns the chosen action.
## Always sets all labels explicitly to prevent stale state between calls.
static func show_error(
	error: ProjectError,
	primary_label: StringName,
	secondary_label: StringName = &"",
) -> AlertDialog.Action:
	var main := _get_main()
	assert(
		main._error_dialog is AlertDialog,
		"invalid state; missing error dialog",
	)

	while main._error_dialog_busy:
		await main._error_dialog.closed

	main._error_dialog_busy = true

	main._error_dialog.title = error.title
	main._error_dialog.message = error.message
	main._error_dialog.primary_label = primary_label
	main._error_dialog.secondary_label = secondary_label
	main._error_dialog.dismissable = false

	main._error_dialog.open()
	var action: AlertDialog.Action = await main._error_dialog.closed
	main._error_dialog_busy = false
	return action


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	StdGroup.with_id(GROUP_MAIN).add_member(self)

	if Engine.is_editor_hint():
		Signals.connect_safe(ProjectSettings.settings_changed, _update_color)
	else:
		Signals.connect_safe(Lifecycle.shutdown_requested, _on_shutdown_requested)

	_update_color()


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_MAIN).remove_member(self)

	if Engine.is_editor_hint():
		Signals.disconnect_safe(ProjectSettings.settings_changed, _update_color)
	else:
		Signals.disconnect_safe(Lifecycle.shutdown_requested, _on_shutdown_requested)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(_error_dialog):
			_error_dialog.free()
			_error_dialog = null


func _ready() -> void:
	_manager = %"ScreenManager"
	assert(_manager is StdScreenManager, "invalid state; missing node")

	if Engine.is_editor_hint():
		return

	assert(
		error_dialog is PackedScene,
		"invalid config; missing error dialog scene",
	)
	_error_dialog = error_dialog.instantiate()

	var input := Systems.input()
	Signals.connect_safe(
		_manager.screen_entered,
		func(_s: StdScreen, _n: Node) -> void: input.mute_next_focus_sound(),
	)
	Signals.connect_safe(
		_manager.screen_uncovered,
		func(_s: StdScreen, _n: Node) -> void: input.mute_next_focus_sound(),
	)

	# Drain errors enqueued before the UI existed (e.g. Steam init failure).
	# Warnings are logged; errors and above get a dialog. Critical errors
	# force shutdown. Push loading as a base screen so the error dialog has
	# something beneath it when popped (pop asserts stack.size > 1).
	var errors := ProjectError.drain_pending()
	errors.sort_custom(
		func(a: ProjectError, b: ProjectError) -> bool: return a.severity > b.severity
	)

	var had_pending := false
	for error in errors:
		if error.severity == ProjectError.Severity.WARNING:
			_logger.warn(error.title, {&"message": error.message})
			continue

		if not had_pending:
			had_pending = true
			_manager.push(loading)

		if error.severity == ProjectError.Severity.CRITICAL:
			await show_error(error, &"alert_quit")
			Lifecycle.shutdown(1)
			return

		await show_error(error, &"alert_continue")

	_preload_results = _manager.load_screen(initial)

	if not splash.is_empty():
		if had_pending:
			var entering := splash[0].entering
			entering.connect(_on_splash_entering.bind(0), CONNECT_ONE_SHOT)
			_manager.replace(splash[0])
		else:
			_push_splash(0)
		return

	if had_pending:
		_finish_boot(_manager.replace)
	else:
		_finish_boot(_manager.push)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _get_main() -> Main:
	return StdGroup.get_sole_member(GROUP_MAIN)


func _accumulate_play_time() -> void:
	if _play_start_ticks < 0 or not _save_data is ProjectSaveData:
		return

	var now := Time.get_ticks_msec()
	var elapsed_sec := (now - _play_start_ticks) / 1000.0

	var summary := _save_data.summary
	if summary is ProjectSaveSummary:
		summary.play_time_seconds += elapsed_sec

	_play_start_ticks = now


func _await_initial_loaded() -> void:
	for result in _preload_results.values():
		if not result.is_done():
			await result.done


func _finish_boot(navigate: Callable) -> void:
	var saves := Systems.saves()

	if _is_initial_loaded() and Systems.saves().are_slots_loaded():
		navigate.call(initial)
		return

	navigate.call(loading)

	if not _manager.is_current(loading):
		await _manager.screen_entered

	if not _is_initial_loaded():
		await _await_initial_loaded()

	if not saves.are_slots_loaded():
		await saves.slots_loaded

	_manager.replace(initial)


func _is_initial_loaded() -> bool:
	for result in _preload_results.values():
		if not result.is_done():
			return false

	return true


func _load_game(slot: int) -> bool:
	var saves := Systems.saves()

	assert(not _is_loading, "invalid state; load/unload in progress")
	assert(not saves.is_saving(), "invalid state; save in progress")

	if not saves.activate_slot(slot):
		return false

	_is_loading = true

	_manager.reset(loading)
	if not _manager.is_current(loading):
		await _manager.screen_entered

	_save_data = saves.create_new_save_data()

	if not await saves.load_save_data(_save_data):
		_save_data = null
		_is_loading = false
		_manager.reset(initial)
		return false

	_play_start_ticks = Time.get_ticks_msec()
	_is_loading = false

	_manager.replace(game)
	return true


func _unload_game() -> void:
	assert(not _is_loading, "invalid state; load/unload in progress")

	var needs_save := (
		_save_data is ProjectSaveData
		and (
			_play_start_ticks >= 0 or _save_data.is_dirty() or _save_data.is_critical()
		)
	)

	if needs_save:
		_is_loading = true

		_manager.reset(loading)
		if not _manager.is_current(loading):
			await _manager.screen_entered

		await save_game()

	_play_start_ticks = -1
	_save_data = null
	_is_loading = false

	if needs_save:
		_manager.replace(initial)
	else:
		_manager.reset(initial)


func _push_splash(index: int) -> void:
	if index >= len(splash):
		return

	var screen := splash[index]

	# Connect before navigation so both sync and async emission is caught.
	screen.entering.connect(_on_splash_entering.bind(index), CONNECT_ONE_SHOT)

	if index == 0:
		_manager.push(screen)
	else:
		_manager.replace(screen)


func _update_color() -> void:
	color = ProjectSettings.get_setting_with_override(PROJECT_SETTING_BG_COLOR)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_shutdown_requested(_exit_code: int) -> void:
	if not _save_data is ProjectSaveData:
		return

	_accumulate_play_time()
	Systems.saves().flush_save_data(_save_data)


func _on_splash_complete() -> void:
	_finish_boot(_manager.replace)


func _on_splash_entering(scene: Node, idx: int) -> void:
	assert(scene is Splash, "invalid state; expected Splash scene")

	if idx < splash.size() - 1:
		scene.advanced.connect(_push_splash.bind(idx + 1), CONNECT_ONE_SHOT)
	else:
		scene.advanced.connect(_on_splash_complete, CONNECT_ONE_SHOT)
