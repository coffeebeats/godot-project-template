##
## system/input/steam/observer.gd
##
## SteamInputObserver is a `StdSettingsObserver` which handles swapping out input device
## components based on changes to Steam Input.
##

extends StdSettingsObserver

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

# TODO: Add property for whether Steam Input is enabled.

# -- INITIALIZATION ------------------------------------------------------------------ #

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	assert(false, "unimplemented")
	return []


func _handle_value_change(_property: StdSettingsProperty, _value) -> void:
	assert(false, "unimplemented")

# -- PRIVATE METHODS ----------------------------------------------------------------- #

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

# -- SETTERS/GETTERS ----------------------------------------------------------------- #
