##
## project/locale/locales.gd
##
## A shared library for working with translations.
##
## NOTE: This 'Object' should *not* be instanced and/or added to the 'SceneTree'. It is a
## "static" library that can be imported at compile-time using 'preload'.
##

extends Object

# -- DEFINITIONS --------------------------------------------------------------------- #

const MSGID_ACTION_PREFIX := &"actions_"
const MSGID_ACTION_SET_PREFIX := &"options_controls_"
const MSGID_LANGUAGE := &"locale_language"

# -- PUBLIC METHODS ------------------------------------------------------------------ #


## tr_action translates an input action. Provide `locale` to specify a locale other than
## the one currently loaded.
static func tr_action(
	action_set: StringName,
	action: StringName,
	locale: StringName = &"",
) -> String:
	var translated := _translate(action, MSGID_ACTION_PREFIX + action_set, locale)
	return translated if translated else str(action)


## tr_action_set translates an input action set. Provide `locale` to specify a locale
## other than the one currently loaded.
static func tr_action_set(action_set: StringName, locale: StringName = &"") -> String:
	var translated := _translate(MSGID_ACTION_SET_PREFIX + action_set, &"", locale)
	return translated if translated else str(action_set)


## tr_language translates the provided locale into the name of the language in the
## language itself.
##
## NOTE: This should be implemented within the engine; see
## https://github.com/godotengine/godot-proposals/issues/2378.
static func tr_language(locale: StringName) -> String:
	var translated := _translate(MSGID_LANGUAGE, &"", locale)
	match translated:
		MSGID_LANGUAGE:
			return "English"
		"":
			return str(locale)
		_:
			return translated


# -- PRIVATE METHODS ----------------------------------------------------------------- #


static func _translate(msg: StringName, ctx: StringName, locale: StringName) -> String:
	if locale == &"":
		locale = TranslationServer.get_locale()

	var translation := TranslationServer.get_translation_object(locale)
	if not translation:
		assert(false, "invalid argument; missing translation")
		return msg

	return translation.get_message(msg, ctx)


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _init():
	assert(
		not OS.is_debug_build(),
		"Invalid config; this 'Object' should not be instantiated!"
	)
