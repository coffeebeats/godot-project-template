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
const Splash := preload("res://addons/kit/ui/splash/splash.gd")

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

@export_group("Dialogs")

## error_dialog_scene is the alert scene `show_error` opens, kit's `alert.tscn`.
@export var error_dialog_scene: PackedScene = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create(&"project/main")

var _error_dialog_busy: bool = false
var _error_dialog: KitAlertDialog = null
var _initial_preparation: StdScreenManager.Preparation = null
var _is_loading: bool = false
var _load_failed: StdScreen = null
var _manager: StdScreenManager = null
var _play_start_ticks: int = -1
var _save_data: ProjectSaveData = null

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# Screen navigation


## screens returns the `StdScreenManager` instance.
static func screens() -> StdScreenManager:
	return _get_main()._manager


# Save data


## get_active_save_data returns the currently loaded save data, or null.
static func get_active_save_data() -> ProjectSaveData:
	var main := _get_main()
	return main._save_data if main else null


## save_game asynchronously stores the current (or provided) save data to the active
## slot and returns whether the save succeeded.
static func save_game(data: ProjectSaveData = null) -> bool:
	var saves := KitSystems.saves()
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

	return await saves.store_save_data(main._save_data)


## request_save triggers an event-driven save (fire-and-forget). Skips if a save is
## already in-flight or data is not dirty. Game scenes should call this at meaningful
## state transitions.
static func request_save() -> void:
	var saves := KitSystems.saves()
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
	var main := _get_main()
	if not main:
		return

	await main._unload_game()


## load_game activates the given save slot, loads its data, and opens the game screen.
## Returns whether the load succeeded. This method is awaitable.
static func load_game(slot: int) -> bool:
	return await _get_main()._load_game(slot)


## show_error displays a modal error dialog and returns the chosen action. Every label
## is set on each call, so an omitted `secondary_label` clears the previous one rather
## than leaving it in place.
static func show_error(
	error: KitError,
	primary_label: StringName,
	secondary_label: StringName = &"",
) -> KitAlertDialog.Action:
	if Lifecycle.is_shutting_down():
		return KitAlertDialog.Action.DISMISS

	var main := _get_main()
	assert(
		main._error_dialog is KitAlertDialog,
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

	main._error_dialog.open(main._manager)
	var action: KitAlertDialog.Action = await main._error_dialog.closed
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

	KitPauseMenu.return_to_main_menu = Callable()

	if Engine.is_editor_hint():
		Signals.disconnect_safe(ProjectSettings.settings_changed, _update_color)
	else:
		Signals.disconnect_safe(Lifecycle.shutdown_requested, _on_shutdown_requested)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if (
			is_instance_valid(_error_dialog)
			and not _error_dialog.is_queued_for_deletion()
		):
			_error_dialog.free()
			_error_dialog = null


func _ready() -> void:
	_manager = %"ScreenManager"
	assert(_manager is StdScreenManager, "invalid state; missing node")

	if Engine.is_editor_hint():
		return

	assert(error_dialog_scene is PackedScene, "invalid state; missing error dialog")
	_error_dialog = error_dialog_scene.instantiate()

	# NOTE: The audio system lives in the `System` autoload, where no `NodePath` can
	# reach this scene's screen manager, so it is handed over here.
	KitSystems.audio().screens = _manager

	KitPauseMenu.return_to_main_menu = go_to_main_menu

	var input := KitSystems.input()
	for signal_shown: Signal in [_manager.screen_entered, _manager.screen_uncovered]:
		Signals.connect_safe(
			signal_shown,
			func(_s: StdScreen, _n: Node) -> void: input.mute_next_focus_sound(),
		)

	Signals.connect_safe(_manager.screen_load_failed, _on_screen_load_failed)

	_boot()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _get_main() -> Main:
	# NOTE: A game scene run on its own has no `Main`; checking first keeps that
	# case quiet instead of tripping the assert in `get_sole_member`.
	if StdGroup.is_empty(GROUP_MAIN):
		return null

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


## _await_settled waits until the screen manager has run every call made so far, which
## includes waiting for the loads each one needs.
func _await_settled() -> void:
	if not _manager.is_settled():
		await _manager.settled


## _boot shows any startup errors, then the splash screens and the initial screen.
func _boot() -> void:
	# NOTE: A kit module only logs its own failure. The game needs every module that
	# registered, so the first that failed ends the boot through the drain below.
	for id in KitModule.get_module_ids():
		if KitModule.get_status(id) == KitModule.Status.FAILED:
			var error := (
				KitError
				. new(
					"error_startup_failed_title",
					"error_startup_failed_message",
					KitError.Severity.CRITICAL,
				)
			)
			KitError.enqueue(error)
			break

	# Drain errors enqueued before the UI existed (e.g. Steam init failure). `loading`
	# is pushed beneath the dialog because `pop` asserts a stack depth above one.
	var errors := KitError.drain_pending()
	errors.sort_custom(
		func(a: KitError, b: KitError) -> bool: return a.severity > b.severity
	)

	var had_pending := false
	for error in errors:
		if error.severity == KitError.Severity.WARNING:
			_logger.warn(error.title, {&"message": error.message})
			continue

		if not had_pending:
			had_pending = true
			_manager.push(loading)
			await _await_settled()

			# NOTE: A dialog closes onto `loading`, so without it the game logs the errors
			# it cannot show and quits.
			if not _manager.is_current(loading):
				for pending in errors:
					if pending.severity != KitError.Severity.WARNING:
						_logger.error(pending.title, {&"message": pending.message})

				if not Lifecycle.is_shutting_down():
					Lifecycle.shutdown.call_deferred(1)
				return

		if error.severity == KitError.Severity.CRITICAL:
			await show_error(error, &"alert_quit")
			if not Lifecycle.is_shutting_down():
				Lifecycle.shutdown.call_deferred(1)
			return

		await show_error(error, &"alert_continue")

		# NOTE: The player can close the game while a dialog is open.
		if Lifecycle.is_shutting_down():
			return

	_initial_preparation = _manager.load_screen(initial)

	_push_splash(0)


## _finish_boot opens the initial screen, behind the loading screen unless it and the
## save slots are already loaded.
func _finish_boot() -> void:
	var saves := KitSystems.saves()

	if _initial_preparation.is_done() and saves.are_slots_loaded():
		await _open_initial()
		return

	_open_in_place(loading)

	# NOTE: A call made during the loading screen's transition would cut it short, so
	# wait for it first. Opening the initial screen then waits for its own loads.
	await _await_settled()

	# NOTE: A shutdown's teardown emits `settled` too, so the boot stops here.
	if Lifecycle.is_shutting_down():
		return

	if not saves.are_slots_loaded():
		await saves.slots_loaded

	# NOTE: A shutdown can begin while the slots load, so the boot stops here rather
	# than open the initial screen in the frame left before the quit.
	if Lifecycle.is_shutting_down():
		return

	await _open_initial()


## _get_debug_state reports app-level state to the debug bridge, which knows nothing
## about screens and reads none of this for itself. `booted` is the field every
## other command waits on.
##
## NOTE: Nothing in a shipped build calls this; the bridge finds it by method name.
func _get_debug_state() -> Dictionary:
	var screen := _manager.get_current_screen() if _manager else null

	return {
		&"booted": _is_booted(),
		&"settled": _manager.is_settled() if _manager else false,
		&"loading": _is_loading,
		&"screen": screen.resource_path if screen else "",
		&"depth": _manager.get_depth() if _manager else 0,
		&"slot": KitSystems.saves().get_active_save_slot(),
	}


## _is_booted returns whether the app has reached a screen worth acting on.
func _is_booted() -> bool:
	if not _manager or not _manager.is_settled() or _is_loading or _error_dialog_busy:
		return false

	# NOTE: The loading screen and each splash screen settle too, and a client that
	# latches onto one drives a dead scene.
	var screen := _manager.get_current_screen()
	if not screen or screen == loading:
		return false

	return screen not in splash


func _load_game(slot: int) -> bool:
	var saves := KitSystems.saves()

	assert(not _is_loading, "invalid state; load/unload in progress")
	assert(not saves.is_saving(), "invalid state; save in progress")

	if not saves.activate_slot(slot):
		return false

	_is_loading = true

	_manager.reset(loading)
	await _await_settled()

	# NOTE: A shutdown's teardown emits `settled` too, so the load stops here rather
	# than read the save data during the quit.
	if Lifecycle.is_shutting_down():
		_is_loading = false
		return false

	_save_data = saves.create_new_save_data()

	var loaded := await saves.load_save_data(_save_data)

	# NOTE: A shutdown can begin while the save data loads, so the load stops here
	# rather than navigate in the frame left before the quit.
	if Lifecycle.is_shutting_down():
		return false

	if not loaded:
		var error := (
			KitError
			. new(
				"error_load_failed_title",
				"error_load_failed_message",
				KitError.Severity.ERROR,
			)
		)
		await show_error(error, &"alert_return_to_menu")

		_save_data = null
		_is_loading = false
		_manager.reset(initial)
		return false

	_play_start_ticks = Time.get_ticks_msec()

	_load_failed = null
	_manager.replace(game)
	await _await_settled()

	# NOTE: This reads the failure std reports rather than `is_current`, since a game
	# can push a screen of its own as it enters.
	if _load_failed == game:
		var error := (
			KitError
			. new(
				"error_screen_load_failed_title",
				"error_screen_load_failed_message",
				KitError.Severity.ERROR,
			)
		)
		await show_error(error, &"alert_return_to_menu")

		_play_start_ticks = -1
		_save_data = null
		_is_loading = false
		_manager.reset(initial)
		return false

	_is_loading = false
	return true


## _open_in_place opens `screen` in place of the topmost screen, or as the first screen
## on an empty stack, such as after the first screen of the boot failed to load.
func _open_in_place(screen: StdScreen) -> void:
	if _manager.get_depth() == 0:
		_manager.push(screen)
	else:
		_manager.replace(screen)


## _open_initial opens the initial screen at the end of the boot. The game has nowhere
## to go without it, so if its scene fails to load, the game shows an error and quits.
func _open_initial() -> void:
	_load_failed = null
	_open_in_place(initial)
	await _await_settled()

	if _load_failed != initial or Lifecycle.is_shutting_down():
		return

	var error := (
		KitError
		. new(
			"error_screen_load_failed_title",
			"error_screen_load_failed_message",
			KitError.Severity.CRITICAL,
		)
	)
	await show_error(error, &"alert_quit")
	if not Lifecycle.is_shutting_down():
		Lifecycle.shutdown.call_deferred(1)


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
		await _await_settled()

		# NOTE: A shutdown's teardown emits `settled` too, and `_on_shutdown_requested`
		# has already flushed the save data, so the unload stops here.
		if Lifecycle.is_shutting_down():
			return

		await _save_with_retry()

	_play_start_ticks = -1
	_save_data = null
	_is_loading = false

	# NOTE: A shutdown can begin while the game saves, so the unload stops here rather
	# than navigate in the frame left before the quit.
	if Lifecycle.is_shutting_down():
		return

	# NOTE: `loading` covers the game while it saves, unless its scene failed to load.
	if _manager.is_current(loading):
		_manager.replace(initial)
	else:
		_manager.reset(initial)


## _push_splash opens the splash screen at `index`, or finishes the boot after the last.
func _push_splash(index: int) -> void:
	if index >= len(splash):
		_finish_boot()
		return

	var screen := splash[index]

	# Connect before navigation so both sync and async emissions are caught.
	screen.entering.connect(_on_splash_entering.bind(index), CONNECT_ONE_SHOT)

	_open_in_place(screen)


func _save_with_retry() -> bool:
	_accumulate_play_time()
	_play_start_ticks = -1

	while true:
		if await save_game():
			return true

		var error := (
			KitError
			. new(
				"error_save_failed_title",
				"error_save_failed_message",
				KitError.Severity.ERROR,
			)
		)
		var action := await show_error(error, &"alert_retry", &"alert_continue")

		if action != KitAlertDialog.Action.PRIMARY:
			return false

	return false  # gdlint:ignore=max-returns,unreachable-code


func _update_color() -> void:
	color = ProjectSettings.get_setting_with_override(PROJECT_SETTING_BG_COLOR)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_screen_load_failed(screen: StdScreen) -> void:
	# NOTE: Main handles a failure of the screens it opens where it waits for them, and
	# goes on without a loading or splash screen that failed.
	_load_failed = screen
	if screen in [initial, loading, game]:
		return

	var index := splash.find(screen)
	if index != -1:
		Signals.disconnect_safe(screen.entering, _on_splash_entering.bind(index))
		_push_splash(index + 1)
		return

	if Lifecycle.is_shutting_down():
		return

	var error := (
		KitError
		. new(
			"error_screen_load_failed_title",
			"error_screen_load_failed_message",
			KitError.Severity.ERROR,
		)
	)
	show_error(error, &"alert_continue")


func _on_shutdown_requested(_exit_code: int) -> void:
	if is_instance_valid(_error_dialog) and not _error_dialog.is_inside_tree():
		_error_dialog.free()
		_error_dialog = null

	if not _save_data is ProjectSaveData:
		return

	# NOTE: A shutdown can't be cancelled, so the clock stops here and a later save adds
	# no play time to what the flush stores.
	_accumulate_play_time()
	_play_start_ticks = -1

	KitSystems.saves().flush_save_data(_save_data)


func _on_splash_entering(scene: Node, idx: int) -> void:
	assert(scene is Splash, "invalid state; expected Splash scene")

	scene.advanced.connect(_push_splash.bind(idx + 1), CONNECT_ONE_SHOT)
