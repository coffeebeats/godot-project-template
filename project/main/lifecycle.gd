##
## Lifecycle
##
## An autoloaded node for coordinating lifecycle events, like application shutdown.
##

extends Node

# -- SIGNALS ------------------------------------------------------------------------- #

## shutdown_requested is emitted when the application was requested to be shut down,
## either by the game itself or the window manager. Listeners can use this signal to
## perform shot, *synchronous* clean up actions.
signal shutdown_requested(exit_code: int)

# -- INITIALIZATION ------------------------------------------------------------------ #

## _is_shutdown_requested tracks whether a shutdown request has been issued. This helps
## prevent recursively invoking shutdown handlers.
var _is_shutdown_requested: bool = false

## _lifecycle_mu is a 'Mutex' guarding lifecycle state. This enables multiple threads to
## safely use the methods here.
var _lifecycle_mu: Mutex = Mutex.new()

var _logger := StdLogger.create(&"project/main/lifecycle")

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## shutdown gracefully shuts down the application, allowing all nodes in the scene the
## chance to respond to the shutdown notification.
func shutdown(exit_code: int = 0) -> void:
	assert(exit_code >= 0, "invalid argument: must be >= 0")

	var logger := _logger.with({&"exit_code": exit_code})
	logger.info("Shutdown requested.")

	if not _lifecycle_mu.try_lock():
		logger.warn("Shutdown already in progress; exiting without changes.")
		return

	var should_exit: bool = true
	if not _is_shutdown_requested:
		_is_shutdown_requested = true
		should_exit = false

	_lifecycle_mu.unlock()

	if should_exit:
		logger.warn("Shutdown already in progress; exiting without changes.")
		return

	logger.info("Shutdown started.")

	# First, emit the shutdown signal so any listeners can gracefully handle it.
	shutdown_requested.emit(exit_code)

	# Next, propagate the quit request to all nodes in the scene. See
	# https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html#sending-your-own-quit-notification. # gdlint:ignore=max-line-length
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

	# Just prior to exit, record orphaned nodes.
	print_orphan_nodes()

	get_tree().quit(exit_code)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	# Prevent the game from automatically exiting when requested by the OS. Instead,
	# first propagate a quit signal to all nodes, allowing for a graceful shutdown. For
	# reference, see https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html#handling-the-notification. # gdlint:ignore=max-line-length
	get_tree().set_auto_accept_quit(false)


func _notification(what):
	# Prior to quitting, propagate the quit request to all nodes in the scene tree. This
	# allows for graceful shutdown. See
	#   https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html#handling-the-notification. # gdlint:ignore=max-line-length
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			shutdown()
