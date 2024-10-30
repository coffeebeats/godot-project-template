##
## Lifecycle
##
## A shared library for coordinating lifecycle events, like application shutdown.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- INITIALIZATION ------------------------------------------------------------------ #

## _is_shutdown_requested tracks whether a shutdown request has been issued. This helps
## prevent recursively invoking shutdown handlers.
static var _is_shutdown_requested: bool = false

## _lifecycle_mu is a 'Mutex' guarding lifecycle state. This enables multiple threads to
## safely use the methods here.
static var _lifecycle_mu: Mutex = Mutex.new()

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## shutdown gracefully shuts down the application, allowing all nodes in the scene the
## chance to respond to the shutdown notification.
static func shutdown(node: Node, exit_code: int = 0) -> void:
	assert(node is Node, "invalid argument: node")
	assert(exit_code >= 0, "invalid argument: must be >= 0")

	_lifecycle_mu.lock()

	var should_exit: bool = true
	if not _is_shutdown_requested:
		_is_shutdown_requested = true
		should_exit = false

	_lifecycle_mu.unlock()

	if should_exit:
		return

	# Propagate the quit request to all nodes in the scene, then exit. See
	# https://docs.godotengine.org/en/stable/tutorials/inputs/handling_quit_requests.html#sending-your-own-quit-notification.
	node.get_tree().root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	node.get_tree().quit(exit_code)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init():
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
