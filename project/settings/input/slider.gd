##
## project/settings/input/slider.gd
##
## Slider is an `HSlider` node, along with a label.
##

@tool
extends HBoxContainer

# -- INITIALIZATION ------------------------------------------------------------------ #

@onready var _label: Label = $Label
@onready var _slider: HSlider = $HSlider

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready():
	var err := _slider.value_changed.connect(_on_HSlider_value_changed)
	assert(err == OK, "failed to connect to signal")

	_set_label_text(_slider.value)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


func _set_label_text(value: float) -> void:
	_label.text = "%d" % round(value)


# -- SIGNAL HANDLERS ----------------------------------------------------------------- #


func _on_HSlider_value_changed(value: float) -> void:
	_set_label_text(value)
