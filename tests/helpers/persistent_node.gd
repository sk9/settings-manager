extends Node
class_name TestPersistentNode

@export_custom(PropertyHint.PROPERTY_HINT_NONE, "[settings_bind:persistent]") var speed: float = 10.0
@export_custom(PropertyHint.PROPERTY_HINT_NONE, "[settings_bind:persistent]")
var player_name: String = "Hero"
# A property not bound to settings
@export var local_health: int = 100


func _ready():
	# In a real scenario, this would be SettingsManager.register_node_properties(self)
	# For tests, we'll call it manually on the manager instance.
	pass


func get_path_as_string() -> String:
	return get_path() as String
