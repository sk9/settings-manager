# core/TresStorageAdapter.gd
extends StorageAdapter
class_name TresStorageAdapter

const SettingsResource = preload("res://addons/settings_manager/core/settings_resource.gd")
const DEFAULT_USER_SETTINGS_PATH: StringName = "user://settings.tres"

var user_settings_path: StringName = DEFAULT_USER_SETTINGS_PATH

func _init(path: StringName = DEFAULT_USER_SETTINGS_PATH):
	user_settings_path = path

## Returns a string identifying the adapter.
func get_adapter_name() -> String:
	return "TresStorageAdapter"

## Loads all settings (values and metadata) from the TRES file.
## Returns them in a common dictionary format: {key: {"value": Variant, "meta": Dictionary}}
func load_all_settings() -> Dictionary:
	if not ResourceLoader.exists(user_settings_path, "SettingsResource"):
		# Return empty if the file doesn't exist, SettingsManager can decide to create a new one.
		return {}

	var resource: SettingsResource = ResourceLoader.load(user_settings_path, "SettingsResource")
	if not resource:
		push_error(
			(
				"TresStorageAdapter: Failed to load settings resource from %s."
				% user_settings_path
			)
		)
		return {}

	# The resource.settings dictionary is already in the desired format.
	# However, it's good practice to ensure it's a deep copy if it's going to be modified elsewhere,
	# or if the resource itself might be shared or cached by Godot in unexpected ways.
	# For now, let's assume SettingsManagerInternal will handle copying if needed.
	return resource.settings.duplicate(true) # Return a deep copy


## Saves the provided dictionary of settings to the TRES file.
## settings_data format: {key: {"value": Variant, "meta": Dictionary}}
## Returns true on success, false on failure.
func save_all_settings(settings_data: Dictionary) -> bool:
	var resource: SettingsResource = SettingsResource.new()
	resource.settings = settings_data.duplicate(true) # Save a deep copy

	var result = ResourceSaver.save(resource, user_settings_path)
	if result != OK:
		push_error(
			(
				"TresStorageAdapter: Failed to save settings to '%s'. Error code: %s"
				% [user_settings_path, result]
			)
		)
		return false
	return true
