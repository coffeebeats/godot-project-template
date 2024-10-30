##
## Version populates the title screen's version label based on the build version.
##

extends MarginContainer

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Version := preload("res://version.gd")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _ready():
	$Label.text = Version.get_semantic_version(false)
