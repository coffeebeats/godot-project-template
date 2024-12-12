##
## platform/storefront/steam/steam.gd
##
## This node initializes the `Steam` storefront integration.
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Signals := preload("res://addons/std/event/signal.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

var _is_initialized: bool = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _enter_tree() -> void:
	# NOTE: Ensure this integration can always interact with the Steam SDK.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var response := Steam.steamInitEx(true)

	_is_initialized = response.status == OK
	if _is_initialized:
		print(
			"platform/storefront/steam/steam.gd[",
			get_instance_id(),
			"]: successfully initialized Steam",
		)

		return

	assert(false, "failed to initialize Steam")

	print(
		"platform/storefront/steam/steam.gd[",
		get_instance_id(),
		"]: failed to start Steam: %d: %s" % [response.status, response.verbal],
	)

	Lifecycle.shutdown(1)


func _exit_tree() -> void:
	if not _is_initialized:
		return

	Steam.steamShutdown()
