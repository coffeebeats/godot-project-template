##
## Version
##
## A shared library containing the project's version. See https://semver.org/
## for a detailed explanation of the versioning scheme.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- PUBLIC METHODS ------------------------------------------------------------------ #


# get_build_metadata returns the build metadata, if present.
func get_build_metadata() -> String:
	var version := get_semantic_version()
	if "-" not in version:
		return ""

	var label := version.split("-", true, 1)[1]
	return label.split("+")[0]


# get_label returns the pre-release label for the semantic version, if present.
func get_label() -> String:
	var version := get_semantic_version()
	if "+" not in version:
		return ""

	return version.split("+", true, 1)[1]


# get_major_version returns the major version component.
func get_major_version() -> String:
	return "0"  # x-release-please-major


# get_minor_version returns the minor version component.
func get_minor_version() -> String:
	return "1"  # x-release-please-minor


# get_patch_version returns the patch version component.
func get_patch_version() -> String:
	return "3"  # x-release-please-patch


# get_semantic_version returns the full semantic version.
func get_semantic_version(strip_v_prefix: bool = true) -> String:
	var version := "v0.1.0"  # x-release-please-version
	if strip_v_prefix:
		return version.trim_prefix("v")

	return version


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init() -> void:
	assert(not OS.is_debug_build(), "Invalid config; this 'Object' should not be instantiated!")

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #

# -- PRIVATE METHODS ----------------------------------------------------------------- #
