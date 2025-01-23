##
## system/system.gd
##
## System is an autoloaded singleton `Node` which serves as the root for all system-
## related functionality (i.e. not game-specific).
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const SystemInput := preload("input/input.gd")
const SystemSaves := preload("save/saves.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## input is the input system component.
@export var input: SystemInput = null

## saves is the save system component.
@export var saves: SystemSaves = null

## setting is the settings system component.
@export var setting: Node = null
