##
## project/menu/settings/interface/language_option_formatter.gd
##
## LanguageOptionFormatter is a type which describes how to format a locale code into a
## list of language names, translated into the respective language.
##

extends StdSettingsControllerOptionButtonFormatter

# -- DEPENDENCIES -------------------------------------------------------------------- #

const Locales := preload("res://project/locale/locales.gd")

# -- PRIVATE METHODS (OVERRIDES) ----------------------------------------------------- #


func _format_option(locale: Variant) -> String:
	return Locales.tr_language(locale)
