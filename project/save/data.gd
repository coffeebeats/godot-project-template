##
## project/save/data.gd
##
## ProjectSave is the schema for the game's save data (for a single save slot).
##

class_name ProjectSaveData
extends StdSaveData

# -- CONFIGURATION ------------------------------------------------------------------- #

# TODO: Populate with relevant information.

## example is a sample `StdConfigItem` used by the demo scene.
@export var example := ProjectExampleData.new()
