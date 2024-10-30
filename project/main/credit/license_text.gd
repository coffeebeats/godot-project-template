##
## LicenseText is a node for displaying license text for a component in the game UI.
##

extends VBoxContainer

# -- SIGNALS ------------------------------------------------------------------------- #

# -- DEPENDENCIES -------------------------------------------------------------------- #

# -- DEFINITIONS --------------------------------------------------------------------- #

# -- CONFIGURATION ------------------------------------------------------------------- #

## title is the name of the component to which the license text applies.
@export var title: String

## content is the license text to display for the component.
@export var content: String

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _ready():
	$Title.text = title
	$Content.text = content
