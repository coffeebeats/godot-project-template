##
## platform/profile/sync_target.gd
##
## StdSettingsSyncTargetFile specifies that the configuration should be synced to a
## binary file at the specified relative path within the current/local user-specific
## game data directory.
##

class_name StdSettingsSyncTargetProfileFile
extends StdSettingsSyncTarget

# -- CONFIGURATION ------------------------------------------------------------------- #

## path is a *relative* path to a file, under the `UserProfile`'s directory, in which
## the 'StdSettingsScope' contents will be synced to.
@export var path: String = ""

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## make_path_relative_to_profile returns an absolute path to provided profile-relative
## path.
static func make_path_relative_to_profile(path_rel: String) -> String:
	path_rel = path_rel.trim_prefix("profile://")

	if path_rel.is_absolute_path():
		assert(false, "invalid config; expected relative path")
		return ""

	var profile := Platform.get_user_profile()
	if not profile:
		return ""

	return ("user://profiles/%s" % profile.id).path_join(path_rel)


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _create_sync_target_node() -> StdConfigWriter:
	var writer := StdConfigWriterBinary.new()
	writer.path = make_path_relative_to_profile(path)

	return writer
