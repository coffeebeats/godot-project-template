##
## platform/profile/steam/profile.gd
##

extends Node

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Profile := preload("../profile.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## profile is the node path to the `Profile`-typed platform node.
@export var profile: NodePath = "../.."

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _profile: Profile = get_node(profile)

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #

func _ready() -> void:
	assert(_profile is Profile, "invalid state; missing profile")

	_profile.set_user_profile(_create_user_profile())

# -- PRIVATE METHODS ----------------------------------------------------------------- #

func _create_user_profile() -> UserProfile:
	var user_profile := UserProfile.new()
	user_profile.id = str(Steam.getSteamID())

	return user_profile
