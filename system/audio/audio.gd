##
## system/audio/audio.gd
##
## SystemAudio is a sound event player which manages pools of audio player nodes.
##

extends StdSoundEventPlayer

# -- DEFINITIONS --------------------------------------------------------------------- #

const GROUP_AUDIO_SHIM := &"system/audio:shim"

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _enter_tree() -> void:
	super._enter_tree()

	assert(StdGroup.is_empty(GROUP_AUDIO_SHIM), "invalid state; duplicate node found")
	StdGroup.with_id(GROUP_AUDIO_SHIM).add_member(self)


func _exit_tree() -> void:
	super._exit_tree()

	StdGroup.with_id(GROUP_AUDIO_SHIM).remove_member(self)
