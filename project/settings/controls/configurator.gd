##
## project/settings/controls/steam_configurator.gd
##
## SteamConfigurator is a node which will open the Steam Configurator (i.e. bindings
## panel) whenever the configure `Button` node is pressed.
##

extends Node

# -- CONFIGURATION ------------------------------------------------------------------- #

## button is a `Button` node which, when pressed, will trigger the Steam bindings panel
## to be shown.
@export var button: Button = null

## player_id is a player identifier which will be used to look up the action's input
## origin bindings. Specifically, this is used to find the corresponding `StdInputSlot`
## node, which must be present in the scene tree.
@export var player_id: int = 1

## configurator is a scene with a `StdInputSteamConfigurator` root node.
@export var configurator: PackedScene = null

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(button is Button, "invalid config; missing button node")
	assert(configurator is PackedScene, "invalid state; missing scene")

	var node := configurator.instantiate()
	if not node:
		assert(false, "failed to load configurator resource")
		return

	node.button = button
	node.player_id = player_id

	add_child(node)
