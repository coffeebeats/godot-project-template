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

# -- SIGNALS ------------------------------------------------------------------------- #

## saved is emitted after a fire-and-forget save completes.
signal saved(slot: int, error: Error)

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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _manager: StdScreenManager = null
var _preload_results: Dictionary = {}
var _save_data: ProjectSaveData = null
var _save_in_progress: bool = false

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# Screen navigation


## screens returns the `StdScreenManager` instance.
static func screens() -> StdScreenManager:
	return _get_main()._manager


# Save data


## connect_saved connects the given callback to the `saved` signal.
static func connect_saved(callback: Callable, flags: int = 0) -> void:
	Signals.connect_safe(_get_main().saved, callback, flags)


## disconnect_saved disconnects the given callback from the
## `saved` signal.
static func disconnect_saved(callback: Callable) -> void:
	Signals.disconnect_safe(_get_main().saved, callback)


## get_active_save_data returns the currently loaded save data, or null.
static func get_active_save_data() -> ProjectSaveData:
	return _get_main()._save_data


## save_game initiates a fire-and-forget save of the provided data (or the currently
## active save data if `null`) to the active save slot. Returns `OK` if the save was
## started, `ERR_UNCONFIGURED` if no slot is active, or `ERR_BUSY` if a save is already
## in progress.
static func save_game(data: StdSaveData = null) -> Error:
	return _get_main()._save_game_impl(data)


# Game flow


## go_to_main_menu clears game state and resets the screen stack to the initial screen.
static func go_to_main_menu() -> void:
	var main := _get_main()
	main._save_data = null
	Systems.saves().clear_active_slot()
	main._manager.reset(main.initial)


## load_game activates the given save slot, loads its data, and navigates to the map.
static func load_game(slot: int) -> void:
	_get_main()._load_game(slot)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	StdGroup.with_id(GROUP_MAIN).add_member(self)

	if Engine.is_editor_hint():
		Signals.connect_safe(ProjectSettings.settings_changed, _update_color)

	_update_color()


func _exit_tree() -> void:
	StdGroup.with_id(GROUP_MAIN).remove_member(self)

	if Engine.is_editor_hint():
		Signals.disconnect_safe(ProjectSettings.settings_changed, _update_color)


func _ready() -> void:
	_manager = %"ScreenManager"
	assert(_manager is StdScreenManager, "invalid state; missing node")

	if Engine.is_editor_hint():
		return

	_preload_results = _manager.load_screen(initial)

	if not splash.is_empty():
		_push_splash(0)
		return

	_finish_boot(_manager.push)


# -- PRIVATE METHODS ----------------------------------------------------------------- #

# Singleton


static func _get_main() -> Main:
	return StdGroup.get_sole_member(GROUP_MAIN)


# Boot sequence


func _await_initial_loaded() -> void:
	for result in _preload_results.values():
		if not result.is_done():
			await result.done


func _finish_boot(navigate: Callable) -> void:
	var saves := Systems.saves()

	if _is_initial_loaded() and saves.are_slots_loaded():
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


# Save operations


func _do_save(data: StdSaveData) -> void:
	var slot := Systems.saves().get_active_save_slot()
	var ok := await Systems.saves().store_save_data(data)
	_save_in_progress = false
	saved.emit(slot, OK if ok else FAILED)


func _load_game(slot: int) -> void:
	var saves := Systems.saves()

	if not saves.activate_slot(slot):
		return

	_manager.reset(loading)
	if not _manager.is_current(loading):
		await _manager.screen_entered

	_save_data = saves.create_new_save_data()

	if not await saves.load_save_data(_save_data):
		_save_data = null
		_manager.reset(initial)
		return

	_manager.replace(game)


func _save_game_impl(data: StdSaveData = null) -> Error:
	if data == null:
		data = _save_data
	if not data is StdSaveData:
		saved.emit.call_deferred(-1, FAILED)
		return OK

	if Systems.saves().get_active_save_slot() < 0:
		return ERR_UNCONFIGURED

	if _save_in_progress:
		return ERR_BUSY

	_save_in_progress = true
	_do_save(data)

	return OK


# Editor


func _update_color() -> void:
	color = ProjectSettings.get_setting_with_override(PROJECT_SETTING_BG_COLOR)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_splash_complete() -> void:
	_finish_boot(_manager.replace)


func _on_splash_entering(scene: Node, idx: int) -> void:
	assert(scene is Splash, "invalid state; expected Splash scene")

	if idx < splash.size() - 1:
		scene.advanced.connect(_push_splash.bind(idx + 1), CONNECT_ONE_SHOT)
	else:
		scene.advanced.connect(_on_splash_complete, CONNECT_ONE_SHOT)
