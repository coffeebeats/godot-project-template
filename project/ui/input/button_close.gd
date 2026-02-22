##
## project/ui/input/close_button.gd
##
## CloseButton is a `TextureButton` that triggers the "ui_cancel" action when pressed,
## allowing it to close any `StdScreen` that listens for that action (typically via a
## `StdScreenPusher` utility node).
##

extends TextureButton

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	pressed.connect(_on_pressed)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_pressed() -> void:
	StdInputEvent.trigger_action(&"ui_cancel")
