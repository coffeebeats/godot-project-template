##
## project/main/menu/main_menu.gd
##
## MainMenu implements a main menu for the game.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## music_sound_event is a sound event for the main menu background music.
@export var music_sound_event: StdSoundEvent1D = null

## music_filter_param is a sound parameter which toggles a filter that reduces
## the intensity of main menu music when the settings menu is open.
@export var music_filter_param: StdSoundParamAudioEffect = null

## toggle_settings_action_prompt is an optional action prompt to open the settings menu.
@export var toggle_settings_action_prompt: InputActionPrompt = null

## saves_screen is the StdScreen resource for the save slot menu.
@export var saves_screen: StdScreen = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _music_sound_instance: StdSoundInstance = null

@onready var _continue: Button = %Continue
@onready var _options: Button = %Options
@onready var _play: Button = %Play
@onready var _quit: Button = %Quit

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if _music_sound_instance:
		# NOTE: The fade-out duration should match the scene fade transition length.
		var fade_out := StdTweenCurve.new()
		fade_out.duration = 0.6
		fade_out.transition_type = Tween.TRANS_LINEAR
		_music_sound_instance.stop(fade_out)


func _ready() -> void:
	if toggle_settings_action_prompt:
		(
			Signals
			. connect_safe(
				toggle_settings_action_prompt.pressed,
				_on_settings_prompt_pressed,
			)
		)

	_handle_first_focused_sound_event_mute.call_deferred()

	Signals.connect_safe(_continue.pressed, _on_continue_pressed)
	Signals.connect_safe(_options.pressed, _on_options_pressed)
	Signals.connect_safe(_play.pressed, _on_play_pressed)
	Signals.connect_safe(_quit.pressed, _on_quit_pressed)

	var saves := Systems.saves()
	Signals.connect_safe(saves.slot_activated, _on_slot_activated)
	Signals.connect_safe(saves.slot_deactivated, _on_slot_deactivated)

	if music_sound_event:
		var audio := Systems.audio()
		var fade_in := StdTweenCurve.new()
		fade_in.duration = 2
		fade_in.transition_type = Tween.TRANS_LINEAR
		_music_sound_instance = audio.play(music_sound_event, fade_in)

	Signals.connect_safe(
		Lifecycle.shutdown_requested,
		func(_exit_code: int):
			if _music_sound_instance:
				_music_sound_instance.stop(),
		CONNECT_ONE_SHOT
	)

	_setup_continue_button()
	_connect_screen_signals.call_deferred()


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _connect_screen_signals() -> void:
	var screen := Main.screens().get_current_screen()
	if screen:
		Signals.connect_safe(screen.covered, _on_covered)
		Signals.connect_safe(screen.uncovered, _on_uncovered)


func _handle_first_focused_sound_event_mute() -> void:
	var input := Systems.input()
	if not input.is_cursor_visible():
		input.mute_next_focus_sound_event()


func _setup_continue_button() -> void:
	var saves := Systems.saves()
	var slot := saves.get_active_save_slot()

	if slot > -1 and saves.get_save_slot(slot).status == SaveSlot.STATUS_OK:
		_continue.visible = true
		_continue.focus_neighbor_top = _continue.get_path_to(_quit)
		_quit.focus_neighbor_bottom = _quit.get_path_to(_continue)
		_play.focus_neighbor_top = _play.get_path_to(_continue)
	else:
		_continue.visible = false
		_play.focus_neighbor_top = _play.get_path_to(_quit)
		_quit.focus_neighbor_bottom = _quit.get_path_to(_play)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_continue_pressed() -> void:
	Main.load_game(Systems.saves().get_active_save_slot())


func _on_covered(_scene: Node) -> void:
	if music_filter_param:
		music_filter_param.enabled = true


func _on_uncovered(_scene: Node) -> void:
	if music_filter_param:
		music_filter_param.enabled = false


func _on_options_pressed() -> void:
	Main.open_settings()


func _on_play_pressed() -> void:
	Main.screens().push(saves_screen)


func _on_quit_pressed() -> void:
	Lifecycle.shutdown()


func _on_settings_prompt_pressed() -> void:
	Main.open_settings()


func _on_slot_activated(_index: int) -> void:
	_setup_continue_button()


func _on_slot_deactivated(_index: int) -> void:
	_setup_continue_button()
