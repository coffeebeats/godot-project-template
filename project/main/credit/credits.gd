##
## Insert class description here.
##

extends Control

# -- DEPENDENCIES -------------------------------------------------------------------- #

const License := preload("license.gd")
const LicenseText := preload("license_text.gd")
const LicenseTextScene := preload("license_text.tscn")

# -- CONFIGURATION ------------------------------------------------------------------- #

@export var licenses: Array[License] = []

## include_godot_license configures whether the engine license is displayed.
@export var include_godot_license: bool = true

## include_godot_third_party_licenses configures whether the engine's third party
## component licenses are included.
@export var include_godot_third_party_licenses: bool = true

# -- PUBLIC METHODS ------------------------------------------------------------------ #

func open() -> void:
	visible = true
	$AcceptDialog.visible = true
	%Contents.get_children()[-1].get_node("Content").grab_focus()

func close() -> void:
	visible = false
	$AcceptDialog.visible = false

# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _ready():
	var err: int = $AcceptDialog.confirmed.connect(_on_AcceptDialog_closed)
	assert(err == OK, "failed to connect to signal")

	err = $AcceptDialog.canceled.connect(_on_AcceptDialog_closed)
	assert(err == OK, "failed to connect to signal")

	var children: Array[LicenseText] = []

	for license in licenses:
		var license_text := LicenseTextScene.instantiate()
		license_text.title = license.title
		license_text.content = license.content
		children.append(license_text)

	if include_godot_license:
		var license_text := LicenseTextScene.instantiate()
		license_text.title = "%s (%s)" % ["Godot Engine", Engine.get_version_info().string]
		license_text.content = Engine.get_license_text()
		children.append(license_text)

	if include_godot_third_party_licenses:
		var info: Dictionary = Engine.get_license_info()
		for component in info:
			var license_text := LicenseTextScene.instantiate()

			license_text.title = component
			license_text.content = info[component]

			children.append(license_text)

	for license_text in children:
		license_text.name = license_text.title.c_escape()
		%Contents.add_child(license_text, true)

	for index in len(children):
		if index > 0:
			var child: Control = children[index]
			child.focus_previous = child.get_path_to(children[index - 1])

	for index in len(children):
		if index < len(children) - 1:
			var child: Control = children[index]
			child.focus_next = child.get_path_to(children[index + 1])

# -- SIGNAL HANDLERS ----------------------------------------------------------------- #

func _on_AcceptDialog_closed() -> void:
	close()
