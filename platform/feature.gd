##
## Feature
##
## A shared library for querying feature flags and platform metadata.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object
class_name Feature

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

## Storefront enumerates the set of storefronts on which this game might be published.
enum Storefront {
	UNKNOWN,
	GOG,
	STEAM,
}

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## get_storefront returns the 'Storefront' targeted by the current game build.
static func get_storefront() -> Storefront:
	if is_steam_storefront_enabled():
		assert(not is_gog_storefront_enabled(), "cannot enable multiple storefronts")
		return Storefront.STEAM
	if is_gog_storefront_enabled():
		assert(not is_steam_storefront_enabled(), "cannot enable multiple storefronts")
		return Storefront.GOG

	return Storefront.UNKNOWN


## is_steam_enabled returns whether the game build is targeting the Steam 'Storefront'.
static func is_steam_storefront_enabled() -> bool:
	return OS.has_feature("steam")


## is_gog_enabled returns whether the game build is targeting the GOG 'Storefront'.
static func is_gog_storefront_enabled() -> bool:
	return OS.has_feature("gog")


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(not OS.is_debug_build(), "Invalid config; this 'Object' should not be instantiated!")

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #
