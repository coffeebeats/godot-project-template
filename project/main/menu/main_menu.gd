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

# -- INITIALIZATION ------------------------------------------------------------------ #

var _music_sound_instance: StdSoundInstance = null

@onready var _options: Button = %Options
@onready var _play: Button = %Play
@onready var _quit: Button = %Quit
@onready var _saves: Modal = $SaveMenu
@onready var _settings: Modal = $SettingsMenu

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _exit_tree() -> void:
	if _music_sound_instance:
		# NOTE: The fade-out duration should match the scene fade transition length.
		_music_sound_instance.stop(0.6, Tween.TRANS_LINEAR)


func _input(event: InputEvent) -> void:
	if not event.is_action_type():
		return

	if event.is_action_pressed(&"ui_toggle_settings"):
		get_viewport().set_input_as_handled()

		if not Modal.are_any_open():
			_settings.visible = true
		elif _settings.is_head_modal():
			_settings.visible = false


func _ready() -> void:
	if toggle_settings_action_prompt:
		(
			Signals
			.connect_safe(
				toggle_settings_action_prompt.pressed,
				_on_settings_prompt_pressed,
			)
		)

	_handle_first_focused_sound_event_mute.call_deferred()

	Signals.connect_safe(_options.pressed, _on_options_pressed)
	Signals.connect_safe(_play.pressed, _on_play_pressed)
	Signals.connect_safe(_quit.pressed, _on_quit_pressed)
	Signals.connect_safe(_saves.closed, _on_modal_closed)
	Signals.connect_safe(_saves.opened, _on_modal_opened)
	Signals.connect_safe(_settings.closed, _on_modal_closed)
	Signals.connect_safe(_settings.opened, _on_modal_opened)

	if music_sound_event:
		var audio := Systems.audio()
		_music_sound_instance = audio.play(music_sound_event, 2, Tween.TRANS_LINEAR)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _handle_first_focused_sound_event_mute() -> void:
	var input := Systems.input()
	if not input.is_cursor_visible():
		input.mute_next_focus_sound_event()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_modal_closed(_reason: Modal.CloseReason) -> void:
	var input := Systems.input()
	if not input.is_cursor_visible():
		input.mute_next_focus_sound_event()

	if music_filter_param:
		music_filter_param.enabled = false


func _on_modal_opened() -> void:
	var input := Systems.input()
	if not input.is_cursor_visible():
		input.mute_next_focus_sound_event()

	if music_filter_param:
		music_filter_param.enabled = true


func _on_options_pressed() -> void:
	_settings.visible = true


func _on_play_pressed() -> void:
	_saves.visible = true


func _on_settings_prompt_pressed() -> void:
	_settings.visible = true


func _on_quit_pressed() -> void:
	Lifecycle.shutdown()
