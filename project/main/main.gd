##
## Class 'Main' is the top-level 'Node', responsible for orchestrating all
## systems and scenes.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Lifecycle := preload("res://project/main/lifecycle.gd")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _notification(what):
	# Prior to quitting, propagate the quit request to all nodes in the scene tree. This
	# allows for graceful shutdown. See
	#   https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html#handling-the-notification.
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			Lifecycle.shutdown(self)


func _enter_tree() -> void:
	# Prevent the game from automatically exiting when requested by the OS. Instead,
	# first propagate a quit signal to all nodes, allowing for a graceful shutdown. For
	# reference, see https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html#handling-the-notification.
	get_tree().set_auto_accept_quit(false)
