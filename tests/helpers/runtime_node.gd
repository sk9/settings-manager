# test/helpers/runtime_node.gd
extends Node
class_name TestRuntimeNode

@export_custom(PropertyHint.PROPERTY_HINT_NONE, "[settings_bind:runtime_only]")
var current_mana: float = 50.0
@export_custom(PropertyHint.PROPERTY_HINT_NONE, "[settings_bind:persistent]")
var difficulty: String = "normal"  # Mixed example


func _ready():
	pass


func get_path_as_string() -> String:
	return get_path() as String
