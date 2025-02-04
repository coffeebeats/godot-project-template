extends Control

@onready var _button: Button = %Button
@onready var _label: Label = %Sample
@onready var _fps: Label = %FPS


func _process(delta):
	_fps.text = str(Engine.get_frames_per_second())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_tab_next"):
		_button.grab_focus()
	if event.is_action_pressed("ui_tab_prev"):
		_button.release_focus()

	if event.is_action_pressed("ui_cancel"):
		_label.visible = not _label.visible

	if event.is_action_pressed("ui_accept"):
		_label.size *= Vector2(1.1, 1.1)
		($Body as Control).update_minimum_size()

	if event.is_action_pressed("ui_left"):
		_label.position -= Vector2(10, 0)
	if event.is_action_pressed("ui_right"):
		_label.position += Vector2(10, 0)
	if event.is_action_pressed("ui_up"):
		_label.position -= Vector2(0, 10)
	if event.is_action_pressed("ui_down"):
		_label.position += Vector2(0, 10)
