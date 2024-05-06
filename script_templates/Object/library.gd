# meta-name: Library
# meta-description: A non-instantiable shared library.
# meta-space-indent: 4

##
## LIBRARY
##
## A shared library for ...
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- PUBLIC METHODS ------------------------------------------------------------------ #

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #
