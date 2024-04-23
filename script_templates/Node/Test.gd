# meta-name: Test
# meta-description: A unit test script using the 'Gut' addon.
# meta-space-indent: 4

##
## Insert test description here.
##

extends GutTest

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- INITIALIZATION ------------------------------------------------------------------ #

# -- TEST METHODS -------------------------------------------------------------------- #

#func test_something() -> void:
#	pass

# -- TEST HOOKS ---------------------------------------------------------------------- #


func before_all() -> void:
	# NOTE: Hide unactionable errors when using object doubles.
	ProjectSettings.set("debug/gdscript/warnings/native_method_override", false)

#func before_each() -> void:
#	pass

#func after_each() -> void:
#	pass

#func after_all() -> void:
#	pass

# -- PRIVATE METHODS ----------------------------------------------------------------- #
