extends Control

@export var runner: NodePath

@onready var _runner: Node = get_node_or_null(runner)

func _ready():
	assert(_runner != null)

func _process(_delta):
	if _runner.state != null:
		$Runner.text = _runner.state.name
