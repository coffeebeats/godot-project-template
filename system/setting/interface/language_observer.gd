##
## system/setting/language_observer.gd
##
## LanguageObserver is a `StdSettingsObserver` that handles updating the display
## language.
##

extends StdSettingsObserver

# -- DEPENDENCIES -------------------------------------------------------------------- #

const LanguageOptionsProperty := preload("language_options_property.gd")
const LanguageProperty := preload("language_property.gd")

# -- CONFIGURATION ------------------------------------------------------------------- #

## language_property is a `StdSettingsPropertyString` defining the target locale code.
@export var language_property: StdSettingsPropertyString = null

## language_options_property is a `StdSettingsPropertyStringList` defining the list of
## supported locale codes.
@export var language_options_property: StdSettingsPropertyStringList = null

# -- INITIALIZATION ------------------------------------------------------------------ #

var _logger := StdLogger.create(&"system/setting/language")

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready() -> void:
	assert(language_property is LanguageProperty, "invalid config: missing property")
	assert(
		language_options_property is LanguageOptionsProperty,
		"invalid config: missing property",
	)

	language_property.initialize()

	super._ready()


# NOTE: Some operating systems may produce 'NOTIFICATION_APPLICATION_FOCUS_OUT'
# multiple times on the same focus loss event. As a result, the handler must be
# idempotent.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_OUT:
			pass


# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _get_settings_properties() -> Array[StdSettingsProperty]:
	return [language_property, language_options_property]


func _handle_value_change(property: StdSettingsProperty, value: Variant) -> void:
	if property == language_property:
		_update_display_language(value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _update_display_language(locale: String) -> void:
	assert(locale != "", "invalid argument; missing locale")

	_logger.debug("Updating display language.", {&"locale": locale})

	TranslationServer.set_locale(locale)
