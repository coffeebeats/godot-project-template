##
## platform/profile/user_profile.gd
##
## UserProfile contains information about the current/local user.
##

class_name UserProfile
extends Resource

# -- CONFIGURATION ------------------------------------------------------------------- #

## id is a `Storefront`-specific unique identifier for the user currently running the
## game application.
@export var id: String = ""
