##
## project/main/menu/main_menu.gd
##
## MainMenu implements a main menu for the game.
##

extends Control

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _ready() -> void:
    var err: int = %Quit.pressed.connect(_on_Quit_pressed)
    assert(err == OK, "failed to connect to signal")

    %Play.grab_focus()


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_Quit_pressed():
    # Propagate the quit request to all nodes in the scene, then exit. See
    # https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html#sending-your-own-quit-notification.
    get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
    get_tree().quit()