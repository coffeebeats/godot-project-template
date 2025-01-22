##
## system/system.gd
##
## System is an autoloaded singleton `Node` which serves as the root for all system-
## related functionality (i.e. not game-specific).
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Saves := preload("save/saves.gd")

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var saves: Saves = get_node("Saves")
