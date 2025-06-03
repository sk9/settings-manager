# core/StorageAdapter.gd
class_name StorageAdapter extends RefCounted

# Public Signals
#endregion

# Public Enum / Constants
#endregion

# Public Properties
#endregion

# Private Properties
#endregion

# Public API

## Returns a string identifying the adapter (e.g., "TresAdapter", "IniAdapter").
func get_adapter_name() -> String:
	return "BaseStorageAdapter"


## Loads all settings (values and metadata) from the storage.
## Returns them in a common dictionary format: {key: {"value": Variant, "meta": Dictionary}}
## Returns an empty dictionary if loading fails or no settings are found.
func load_all_settings() -> Dictionary:
	push_error("StorageAdapter: load_all_settings() must be implemented by a subclass.")
	return {}


## Saves the provided dictionary of settings to the storage.
## settings_data format: {key: {"value": Variant, "meta": Dictionary}}
## Returns true on success, false on failure.
func save_all_settings(settings_data: Dictionary) -> bool:
	push_error("StorageAdapter: save_all_settings() must be implemented by a subclass.")
	return false


## Optional: Loads default/environment settings from a specific path.
## This might be specialized by adapters if their default storage differs.
# func load_environment_defaults(env: String, path: String) -> Dictionary:
#   push_error("StorageAdapter: load_environment_defaults() must be implemented by a subclass if used.")
#   return {}

#endregion

# Private API
#endregion

# Private Live-Cyle API
#endregion
