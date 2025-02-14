##
## Class 'Main' is the top-level 'Node', responsible for orchestrating all
## systems and scenes.
##

@tool
extends ColorRect

# -- DEFINITIONS --------------------------------------------------------------------- #

## PROJECT_SETTING_BG_COLOR is the project setting name for the game's background color.
const PROJECT_SETTING_BG_COLOR := &"application/boot_splash/bg_color"

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		var err := ProjectSettings.settings_changed.connect(_update_color)
		assert(err == OK, "failed to connect to signal")

	_update_color()


func _exit_tree() -> void:
	if ProjectSettings.settings_changed.is_connected(_update_color):
		ProjectSettings.settings_changed.disconnect(_update_color)


func _ready() -> void:
	# Move to front of parent's children so system components see events first.
	get_viewport().move_child.call_deferred(self, 0)

# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_color() -> void:
	color = ProjectSettings.get_setting_with_override(PROJECT_SETTING_BG_COLOR)
