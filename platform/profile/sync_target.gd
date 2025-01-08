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

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _create_sync_target_node() -> StdConfigWriter:
	path = path.trim_prefix("profile://")

	if path.is_absolute_path():
		assert(false, "invalid config; expected relative path")
		return null

	var profile := Platform.get_user_profile()
	if not profile:
		return

	var writer := StdBinaryConfigWriter.new()
	writer.path = ("user://%s" % profile.id).path_join(path)

	return writer
