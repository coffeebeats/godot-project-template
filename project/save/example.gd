##
## project/save/example.gd
##
## ProjectExampleData is an example collection of properties which the demo scene uses.
##

class_name ProjectExampleData
extends StdConfigItem

# -- CONFIGURATION ------------------------------------------------------------------- #

## count is an example integer value.
@export var count: int = 0

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_category() -> StringName:
	return "example"
