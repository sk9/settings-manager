# core/IniStorageAdapter.gd
extends StorageAdapter
class_name IniStorageAdapter

const DEFAULT_USER_SETTINGS_PATH: StringName = "user://settings.ini"

var user_settings_path: StringName = DEFAULT_USER_SETTINGS_PATH

func _init(path: StringName = DEFAULT_USER_SETTINGS_PATH):
	user_settings_path = path

## Returns a string identifying the adapter.
func get_adapter_name() -> String:
	return "IniStorageAdapter"

## Loads all settings (values and metadata) from the INI file.
## Returns them in a common dictionary format: {key: {"value": Variant, "meta": Dictionary}}
func load_all_settings() -> Dictionary:
	var config_file := ConfigFile.new()
	var err := config_file.load(user_settings_path)
	if err != OK and err != ERR_FILE_NOT_FOUND: # Allow file not found, means no settings yet
		push_error("IniStorageAdapter: Failed to load INI file '%s'. Error code: %s" % [user_settings_path, err])
		return {}
	if err == ERR_FILE_NOT_FOUND:
		return {} # No file, so no settings

	var loaded_settings := {}
	var sections := config_file.get_sections()

	for section_name in sections:
		if section_name.ends_with(".meta"):
			continue # Meta sections are handled separately

		var keys_in_section := config_file.get_section_keys(section_name)
		for key_name in keys_in_section:
			var setting_key_path := "%s/%s" % [section_name, key_name]
			var value = config_file.get_value(section_name, key_name)
			
			var meta_section_name = "%s.%s.meta" % [section_name, key_name]
			var meta_dict := {}
			if sections.has(meta_section_name):
				var meta_keys := config_file.get_section_keys(meta_section_name)
				for meta_key_name in meta_keys:
					meta_dict[meta_key_name] = config_file.get_value(meta_section_name, meta_key_name)
			
			loaded_settings[setting_key_path] = {"value": value, "meta": meta_dict}
			
	return loaded_settings

## Saves the provided dictionary of settings to the INI file.
## settings_data format: {key: {"value": Variant, "meta": Dictionary}}
## Returns true on success, false on failure.
func save_all_settings(settings_data: Dictionary) -> bool:
	var config_file := ConfigFile.new()

	for full_key in settings_data:
		var key_parts = full_key.split("/", true, 1)
		if key_parts.size() != 2:
			push_warning("IniStorageAdapter: Invalid setting key format '%s'. Skipping." % full_key)
			continue

		var section_name: String = key_parts[0]
		var key_name: String = key_parts[1]
		
		var entry: Dictionary = settings_data[full_key]
		var value = entry.get("value")
		var meta: Dictionary = entry.get("meta", {})

		config_file.set_value(section_name, key_name, value)
		
		if not meta.is_empty():
			var meta_section_name = "%s.%s.meta" % [section_name, key_name]
			# Clear existing meta keys for this section first if any (not strictly necessary with ConfigFile but good practice)
			# config_file.erase_section(meta_section_name) # ConfigFile handles overwrites fine
			for meta_key in meta:
				config_file.set_value(meta_section_name, meta_key, meta[meta_key])

	var err := config_file.save(user_settings_path)
	if err != OK:
		push_error("IniStorageAdapter: Failed to save INI file to '%s'. Error code: %s" % [user_settings_path, err])
		return false
		
	return true
