# SettingsManagerInternal.gd

extends Node
class_name SettingsManagerInternal

#region Public Signals

## Emitted when any setting's value (persistent or runtime_only) changes.
signal setting_changed(key: String, value: Variant)
## Emitted when a bound node's property is updated by the SettingsManager.
signal node_property_updated(node: Node, property_name: StringName, new_value: Variant)
#endregion

#region Public Enum / Constants
const SettingsResource = preload("res://addons/settings_manager/core/settings_resource.gd")
const SETTINGS_PATH: StringName = "user://settings.tres"
const DEFAULTS_PATH: StringName = "res://addons/settings_manager/defaults/"
const DEFAULTS_PATH_SETTING: StringName = "settings_manager/defaults_path"
const BIND_PREFIX = "[settings_bind"

const PERSISTENCE_PERSISTENT = "persistent"
const PERSISTENCE_RUNTIME_ONLY = "runtime_only"
#endregion

#region Private Properties
var _env: StringName = ProjectSettings.get_setting("application/config/environment", "dev")
var _defaults_base_path = ProjectSettings.get_setting(DEFAULTS_PATH_SETTING, DEFAULTS_PATH)
var _resource: SettingsResource
var _defaults := {}  # Stores default values and their meta. Structure: {key: {"value": Variant, "meta": Dictionary}}

var _property_bindings: Dictionary = {}
# Key: setting_key (String, e.g., "/root/Player/speed")
# Value: Dictionary {
#   node_weak_ref: WeakRef,
#   node_path: NodePath,
#   property: StringName,
#   persistence: String, (PERSISTENCE_PERSISTENT or PERSISTENCE_RUNTIME_ONLY)
#   effective_meta: Dictionary (Consolidated meta, especially for runtime_only)
# }

var _runtime_bound_values: Dictionary = {}  # Key: setting_key -> Value: Variant (for runtime_only properties)
#endregion


#region Public API
## Loads default settings for the specified environment from a .tres file.
func load_defaults_for_environment(env: StringName) -> void:
	var path := "%sdefault_%s.tres" % [_defaults_base_path, env]
	if ResourceLoader.exists(path, "SettingsResource"):
		var defaults_res: SettingsResource = ResourceLoader.load(path, "SettingsResource")
		if defaults_res:
			for key in defaults_res.settings:
				var setting_entry: Dictionary = defaults_res.settings[key]
				var value = setting_entry.get("value")
				var meta = setting_entry.get("meta", {})
				register_setting(key, value, meta.duplicate(true))  # Meta is duplicated for safety
		else:
			push_warning(
				(
					"SettingsManager: Failed to load defaults resource at '%s', though file exists."
					% path
				)
			)
	else:
		push_warning(
			(
				"SettingsManager: Default settings file not found for environment '%s' at '%s'"
				% [env, path]
			)
		)


## Loads settings from the user-specific settings file (SETTINGS_PATH).
func load_settings() -> void:
	if ResourceLoader.exists(SETTINGS_PATH):
		_resource = ResourceLoader.load(SETTINGS_PATH, "SettingsResource")
		if not _resource:
			push_error(
				(
					"SettingsManager: Failed to load settings resource from %s. Creating new."
					% SETTINGS_PATH
				)
			)
			_resource = SettingsResource.new()
	else:
		_resource = SettingsResource.new()


## Registers a setting with a default value and meta.
## This primarily populates the internal `_defaults` dictionary.
## If the setting is persistent and not already in the live settings, it might be added there.
func register_setting(
	key: StringName, value: Variant, meta: Dictionary = {}, default_value: Variant = null
) -> void:
	var actual_default_value = value if default_value == null else default_value
	var current_meta = meta.duplicate(true)  # Work with a copy

	if not _defaults.has(key):
		_defaults[key] = {"value": actual_default_value, "meta": current_meta}
	else:  # Default already exists, merge meta. Value is not typically overridden here.
		if (
			_defaults[key].has("meta")
			and _defaults[key].meta is Dictionary
			and current_meta is Dictionary
		):
			_defaults[key].meta.merge(current_meta, true)
		elif current_meta is Dictionary:  # If old meta wasn't a dict or didn't exist
			_defaults[key].meta = current_meta

	# If this is a new persistent setting, prime it in _resource.settings with its default value.
	# Bound properties will manage their _resource entries more actively during their registration.
	if _resource and not _resource.settings.has(key):  # Check if _resource is valid
		var persistence_type = current_meta.get("persistence", PERSISTENCE_PERSISTENT)
		if persistence_type == PERSISTENCE_PERSISTENT:
			_resource.settings[key] = {
				"value": actual_default_value, "meta": current_meta.duplicate(true)
			}


## Sets the value for a given setting key.
## Handles persistent and runtime_only bound properties accordingly.
## Emits `setting_changed` if the value effectively changes.
func set_setting(key: StringName, value: Variant) -> void:
	var bind_info = _property_bindings.get(key)
	# Determine persistence type: from binding if available, else from general metadata, default to persistent
	var persistence_type = PERSISTENCE_PERSISTENT
	if bind_info:
		persistence_type = bind_info.persistence
	else:
		var meta_lookup = get_metadata(key)  # Uses the more robust get_metadata
		persistence_type = meta_lookup.get("persistence", PERSISTENCE_PERSISTENT)

	if persistence_type == PERSISTENCE_RUNTIME_ONLY:
		var old_runtime_value = _runtime_bound_values.get(key)
		if not _runtime_bound_values.has(key) or not are_variants_equal(old_runtime_value, value):
			_runtime_bound_values[key] = value
			setting_changed.emit(key, value)
	elif _resource:
		var old_value = null
		var current_meta = _resource.settings.get(key, {}).get("meta", {}).duplicate(true)

		# If key is new to _resource.settings, try to base its meta on _defaults
		if not _resource.settings.has(key) and _defaults.has(key):
			current_meta = _defaults[key].get("meta", {}).duplicate(true)

		if _resource.settings.has(key):  # Get old_value only if key actually exists
			old_value = _resource.settings[key].value

		if not _resource.settings.has(key) or not are_variants_equal(old_value, value):
			# If it's a bound persistent property, ensure its specific binding meta is present
			if bind_info and bind_info.persistence == PERSISTENCE_PERSISTENT:
				current_meta.bound_to_node = str(bind_info.node_path)
				current_meta.bound_property = bind_info.property
				current_meta.persistence = PERSISTENCE_PERSISTENT  # Ensure this is correctly set

			_resource.settings[key] = {"value": value, "meta": current_meta}
			setting_changed.emit(key, value)
	else:
		push_error("SettingsManager: Settings resource not loaded. Cannot set setting '%s'." % key)


## Gets the value of a setting.
## Checks runtime_only cache, then live resource, then defaults.
func get_setting(key: StringName, default_value: Variant = null) -> Variant:
	var bind_info = _property_bindings.get(key)
	if bind_info and bind_info.persistence == PERSISTENCE_RUNTIME_ONLY:
		return _runtime_bound_values.get(key, default_value)

	if _resource and _resource.settings.has(key):
		return _resource.settings[key].value

	if _defaults.has(key):
		return _defaults[key].value

	return default_value


## Retrieves all settings (value and meta) within a given namespace prefix.
func get_settings_in_namespace(namespace_prefix: StringName) -> Dictionary:
	var result := {}
	var prefix_str := namespace_prefix + "/"

	# Order: Defaults first, then resource, then runtime
	for key in _defaults:
		self._add_or_merge_setting_to_dict(
			result, prefix_str, key, _defaults[key].value, _defaults[key].get("meta", {})
		)

	if _resource:
		for key in _resource.settings:
			self._add_or_merge_setting_to_dict(
				result,
				prefix_str,
				key,
				_resource.settings[key].value,
				_resource.settings[key].get("meta", {})
			)

	for key in _runtime_bound_values:
		# For runtime, its meta should have been established by _defaults or (less likely) _resource by this point.
		var meta_for_runtime = result.get(key, {}).get("meta", get_metadata(key))  # get_metadata is fallback
		self._add_or_merge_setting_to_dict(
			result, prefix_str, key, _runtime_bound_values[key], meta_for_runtime
		)

	return result


## Resets a single setting to its default value.
## For runtime_only, it attempts to reset to its registered default.
## For persistent, it resets the value in the live settings resource.
func reset_setting(key: StringName) -> void:
	var bind_info = _property_bindings.get(key)
	var persistence_type = PERSISTENCE_PERSISTENT  # Default assumption
	if bind_info:
		persistence_type = bind_info.persistence
	else:
		var meta = get_metadata(key)  # Check stored meta if not actively bound
		persistence_type = meta.get("persistence", PERSISTENCE_PERSISTENT)

	if persistence_type == PERSISTENCE_RUNTIME_ONLY:
		_reset_runtime_only_setting(key, bind_info)  # bind_info might be null if not currently bound
	elif persistence_type == PERSISTENCE_PERSISTENT:
		_reset_persistent_setting(key)
	elif _resource and _resource.settings.has(key):  # Not bound, no clear persistence, but exists in resource
		_resource.settings.erase(key)
		setting_changed.emit(key, null)
	else:
		push_warning(
			"SettingsManager: Setting '%s' not found or cannot determine reset behavior." % key
		)


## Saves all persistent settings to the user-specific settings file.
func save_settings() -> void:
	if not _resource:
		_resource = SettingsResource.new()
		push_warning(
			"SettingsManager: Settings resource was not initialized before save. Creating new."
		)

	var result = ResourceSaver.save(_resource, SETTINGS_PATH)
	if result != OK:
		push_error(
			(
				"SettingsManager: Failed to save settings to '%s'. Error code: %s"
				% [SETTINGS_PATH, result]
			)
		)


## Sets or updates metadata for a given setting key.
## For runtime_only bound properties, updates `effective_meta` in `_property_bindings`.
## For persistent properties, updates meta in `_resource.settings` and `_defaults`.
func set_meta(key: StringName, meta_to_set: Variant) -> void:
	if not meta_to_set is Dictionary:
		push_error(
			(
				"SettingsManager: Invalid type for meta_to_set. Expected Dictionary, got %s"
				% typeof(meta_to_set)
			)
		)
		return

	var new_meta_dict: Dictionary = meta_to_set  # Already a dictionary

	var bind_info = _property_bindings.get(key)
	if bind_info and bind_info.persistence == PERSISTENCE_RUNTIME_ONLY:
		var existing_effective_meta = bind_info.get("effective_meta", {}).duplicate(true)
		existing_effective_meta.merge(new_meta_dict, true)
		_property_bindings[key].effective_meta = existing_effective_meta
		# Consider if a meta_changed signal is needed for runtime settings
		return

	# For persistent settings (or settings not yet bound but could become persistent)
	# Update _resource.settings
	if _resource:
		var current_value: Variant = null
		var existing_meta_in_resource: Dictionary = {}
		if _resource.settings.has(key) and _resource.settings[key] is Dictionary:
			current_value = _resource.settings[key].get("value")
			existing_meta_in_resource = _resource.settings[key].get("meta", {}).duplicate(true)
		elif _defaults.has(key) and _defaults[key] is Dictionary:  # Base new resource entry on default
			current_value = _defaults[key].get("value")
			existing_meta_in_resource = _defaults[key].get("meta", {}).duplicate(true)

		existing_meta_in_resource.merge(new_meta_dict, true)
		_resource.settings[key] = {"value": current_value, "meta": existing_meta_in_resource}
	else:
		push_error(
			"SettingsManager: Settings resource not loaded. Cannot set meta for key '%s'." % key
		)

	# Also update meta in _defaults to keep them aligned
	if (
		_defaults.has(key)
		and _defaults[key] is Dictionary
		and _defaults[key].has("meta")
		and _defaults[key].meta is Dictionary
	):
		_defaults[key].meta.merge(new_meta_dict, true)  # Merge, new values overwrite
	elif _defaults.has(key) and _defaults[key] is Dictionary:  # Default exists but no meta key or meta is not dict
		_defaults[key].meta = new_meta_dict.duplicate(true)


## Retrieves the metadata for a given setting key.
## Prioritizes runtime_only binding meta, then live resource meta, then defaults meta.
func get_metadata(key: StringName) -> Dictionary:
	var bind_info = _property_bindings.get(key)
	if bind_info and bind_info.persistence == PERSISTENCE_RUNTIME_ONLY:
		return bind_info.get("effective_meta", {}).duplicate(true)

	if _resource and _resource.settings.has(key):
		var setting_entry = _resource.settings.get(key, {})  # Default to empty dict if key somehow invalid
		var meta_data = setting_entry.get("meta")
		if meta_data is Dictionary:
			return meta_data.duplicate(true)

	if _defaults.has(key):
		var default_entry = _defaults.get(key, {})  # Default to empty dict
		var meta_data = default_entry.get("meta")
		if meta_data is Dictionary:
			return meta_data.duplicate(true)

	return {}


## Resets all settings.
## If `to_defaults` is true, persistent settings are reverted to their default values,
## and bound properties (persistent and runtime_only) are updated to their defaults.
## If `to_defaults` is false, user-saved values and runtime caches are cleared.
func reset_settings(to_defaults := true) -> void:
	var affected_keys_map: Dictionary = {}  # Use a Dictionary to easily store unique keys

	# Collect keys from _resource.settings before clearing
	if _resource:
		for key in _resource.settings:
			affected_keys_map[key] = true  # Value doesn't matter, just existence of key
		_resource.settings.clear()

	# Collect keys from _runtime_bound_values before clearing
	for key in _runtime_bound_values:
		affected_keys_map[key] = true
	_runtime_bound_values.clear()

	if to_defaults:
		for key_str_name in _defaults:  # Iterate StringName keys from _defaults
			var key: StringName = key_str_name  # Ensure it's treated as StringName
			var default_entry = _defaults[key]
			var default_value = default_entry.value
			var default_meta = default_entry.get("meta", {})
			var persistence_type = default_meta.get("persistence", PERSISTENCE_PERSISTENT)

			if persistence_type == PERSISTENCE_PERSISTENT:
				if _resource:  # Should always be true after _init
					_resource.settings[key] = default_entry.duplicate(true)

			var bind_info = _property_bindings.get(key)
			if bind_info:
				var node_instance = _get_valid_node_from_binding(bind_info)
				if node_instance:
					if bind_info.persistence == PERSISTENCE_RUNTIME_ONLY:
						_runtime_bound_values[key] = default_value

					if not are_variants_equal(node_instance.get(bind_info.property), default_value):
						node_instance.set(bind_info.property, default_value)
						node_property_updated.emit(node_instance, bind_info.property, default_value)

			setting_changed.emit(key, default_value)
			affected_keys_map.erase(key)  # Remove from map as it has been handled by default emit

	# For any remaining keys in affected_keys_map (cleared but not reset to a default)
	# This typically applies when to_defaults is false, or if a setting was cleared
	# that didn't have a corresponding entry in _defaults.
	for key_str_name in affected_keys_map:
		var key: StringName = key_str_name
		# If to_defaults was true, this loop should ideally be empty if all cleared keys had defaults.
		# If to_defaults was false, we emit null (or a more defined "cleared" state if desired).
		var value_after_clear = null
		if to_defaults and _defaults.has(key):  # Should not happen if logic above is correct
			push_warning(
				(
					"SettingsManager: Key %s was in affected_keys_map but also had a default during reset_settings(true)."
					% key
				)
			)
			value_after_clear = _defaults[key].value  # Fallback to default if it was supposed to be set

		setting_changed.emit(key, value_after_clear)

	if not to_defaults:
		push_warning(
			"SettingsManager: reset_settings(false) called. User settings cleared. Bound nodes retain current values unless re-registered or their default is re-applied."
		)


## Returns a dictionary of all known settings (defaults, overridden by resource, then by runtime).
func get_all_settings() -> Dictionary:
	var all_settings_view := {}
	var prefix_str_unused = ""  # Not filtering by prefix here

	for key in _defaults:
		self._add_or_merge_setting_to_dict(
			all_settings_view,
			prefix_str_unused,
			key,
			_defaults[key].value,
			_defaults[key].get("meta", {}),
			false
		)

	if _resource:
		for key in _resource.settings:
			self._add_or_merge_setting_to_dict(
				all_settings_view,
				prefix_str_unused,
				key,
				_resource.settings[key].value,
				_resource.settings[key].get("meta", {}),
				false
			)

	for key in _runtime_bound_values:
		var meta_for_runtime = all_settings_view.get(key, {}).get("meta", get_metadata(key))
		self._add_or_merge_setting_to_dict(
			all_settings_view,
			prefix_str_unused,
			key,
			_runtime_bound_values[key],
			meta_for_runtime,
			false
		)

	return all_settings_view


## Validates the settings manager configuration, like paths and default files.
func validate_configuration() -> void:
	var defaults_path_value: String = ProjectSettings.get_setting(
		DEFAULTS_PATH_SETTING, DEFAULTS_PATH
	)

	if not ProjectSettings.has_setting(DEFAULTS_PATH_SETTING):
		push_warning(
			(
				"SettingsManager: ⚠ Project setting '%s' is not configured. Using default: '%s'"
				% [DEFAULTS_PATH_SETTING, DEFAULTS_PATH]
			)
		)

	if defaults_path_value == DEFAULTS_PATH:
		push_warning(
			(
				"SettingsManager: ⚠ Using default settings path ('%s'). Consider customizing '%s'."
				% [DEFAULTS_PATH, DEFAULTS_PATH_SETTING]
			)
		)

	if not DirAccess.dir_exists_absolute(defaults_path_value):
		push_warning(
			"SettingsManager: ⚠ Configured defaults path does not exist: '%s'" % defaults_path_value
		)

	if _defaults.is_empty():
		var env_defaults_file_path = "%sdefault_%s.tres" % [_defaults_base_path, _env]
		push_warning(
			(
				"SettingsManager: ⚠ No default settings registered. Check file '%s' or environment ('%s')."
				% [env_defaults_file_path, _env]
			)
		)


#endregion

#region Property Binding API


## Registers properties of a node that are marked with "@export_custom([settings_bind:...])".
func register_node_properties(node: Node) -> void:
	if not is_instance_valid(node):
		push_error("SettingsManager: Cannot register properties for an invalid node.")
		return

	var node_path_obj: NodePath = node.get_path()
	var property_list = node.get_property_list()

	for prop_info in property_list:
		var property_name: StringName = prop_info.name
		var hint_string: String = prop_info.hint_string

		if not hint_string.begins_with(BIND_PREFIX):
			continue

		var content = hint_string.trim_prefix("[").trim_suffix("]")
		var parts = content.split(":", false, 1)

		if not (parts.size() == 2 and parts[0] == "settings_bind"):
			push_warning(
				(
					"SettingsManager: Node '%s' property '%s': Malformed settings_bind directive '%s'"
					% [node_path_obj, property_name, hint_string]
				)
			)
			continue

		var persistence_type: String = parts[1]
		if not (
			persistence_type == PERSISTENCE_PERSISTENT
			or persistence_type == PERSISTENCE_RUNTIME_ONLY
		):
			push_warning(
				(
					"SettingsManager: Node '%s' property '%s': Unknown persistence type '%s'"
					% [node_path_obj, property_name, persistence_type]
				)
			)
			continue

		var setting_key := "%s/%s" % [str(node_path_obj), property_name]
		_register_single_bound_property(
			node, node_path_obj, property_name, persistence_type, setting_key
		)

	# Connect signal handler if not already connected
	if not setting_changed.is_connected(_on_internal_setting_changed_for_binding):
		setting_changed.connect(_on_internal_setting_changed_for_binding)


## Unregisters all bound properties for a given node.
func unregister_node_properties(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var node_path_to_match: NodePath = node.get_path()
	var keys_to_remove: Array[StringName] = []

	for key in _property_bindings:
		var bind_info = _property_bindings[key]
		var node_instance_from_ref = (
			bind_info.node_weak_ref.get_ref() if bind_info.node_weak_ref else null
		)
		if (
			bind_info.node_path == node_path_to_match
			or (is_instance_valid(node_instance_from_ref) and node_instance_from_ref == node)
		):
			keys_to_remove.append(key)

	for key_to_remove in keys_to_remove:
		_unregister_single_property_binding(key_to_remove, node_path_to_match)


## Unregisters a single property binding by its setting key.
func unregister_property(setting_key: StringName) -> void:
	if _property_bindings.has(setting_key):
		var node_path_for_log = _property_bindings[setting_key].node_path
		_unregister_single_property_binding(setting_key, node_path_for_log)
	else:
		push_warning(
			"SettingsManager: No property binding found for key '%s' to unregister." % setting_key
		)


#endregion

#region Private API / Signal Handlers


## Helper method to add or merge a setting into a target dictionary, typically for get_all_settings or get_settings_in_namespace.
func _add_or_merge_setting_to_dict(
	target_dict: Dictionary,
	prefix_filter: String,
	key: StringName,
	entry_value: Variant,
	entry_meta: Dictionary,
	use_prefix_filter := true
) -> void:
	if use_prefix_filter and not key.begins_with(prefix_filter):
		return

	var meta_to_use = entry_meta.duplicate(true) if entry_meta is Dictionary else {}

	if not target_dict.has(key):
		target_dict[key] = {"value": entry_value, "meta": meta_to_use}
	else:
		target_dict[key].value = entry_value  # Value from current source overrides
		if (
			target_dict[key].has("meta")
			and target_dict[key].meta is Dictionary
			and meta_to_use is Dictionary
		):
			target_dict[key].meta.merge(meta_to_use, true)  # Current source meta merges/overrides
		elif meta_to_use is Dictionary:
			target_dict[key].meta = meta_to_use


func _register_single_bound_property(
	node: Node,
	node_path_obj: NodePath,
	property_name: StringName,
	persistence_type: String,
	setting_key: StringName
) -> void:
	var current_node_value: Variant = node.get(property_name)
	var initial_value_to_use: Variant = current_node_value

	var binding_specific_meta := {
		"bound_to_node": str(node_path_obj),
		"bound_property": property_name,
		"persistence": persistence_type
	}
	var effective_meta = get_metadata(setting_key).duplicate(true)
	effective_meta.merge(binding_specific_meta, true)

	if persistence_type == PERSISTENCE_PERSISTENT:
		var loaded_value_exists = false
		if _resource and _resource.settings.has(setting_key):
			initial_value_to_use = _resource.settings[setting_key].value
			loaded_value_exists = true
		elif (
			_defaults.has(setting_key)
			and (
				_defaults[setting_key].get("meta", {}).get("persistence", PERSISTENCE_PERSISTENT)
				== PERSISTENCE_PERSISTENT
			)
		):
			initial_value_to_use = _defaults[setting_key].value
			loaded_value_exists = true

		if (
			loaded_value_exists
			and not are_variants_equal(node.get(property_name), initial_value_to_use)
		):
			node.set(property_name, initial_value_to_use)
			node_property_updated.emit(node, property_name, initial_value_to_use)

		self.set_setting(setting_key, initial_value_to_use)
		self.set_meta(setting_key, effective_meta)

		if not _defaults.has(setting_key):
			_defaults[setting_key] = {
				"value": initial_value_to_use, "meta": effective_meta.duplicate(true)
			}
		else:
			if _defaults[setting_key].has("meta") and _defaults[setting_key].meta is Dictionary:
				_defaults[setting_key].meta.merge(effective_meta, true)
			else:
				_defaults[setting_key].meta = effective_meta.duplicate(true)

	elif persistence_type == PERSISTENCE_RUNTIME_ONLY:
		_runtime_bound_values[setting_key] = current_node_value
		if not _defaults.has(setting_key):
			_defaults[setting_key] = {
				"value": current_node_value, "meta": effective_meta.duplicate(true)
			}
		else:
			if _defaults[setting_key].has("meta") and _defaults[setting_key].meta is Dictionary:
				_defaults[setting_key].meta.merge(effective_meta, true)
			else:
				_defaults[setting_key].meta = effective_meta.duplicate(true)

	_property_bindings[setting_key] = {
		"node_weak_ref": weakref(node),
		"node_path": node_path_obj,
		"property": property_name,
		"persistence": persistence_type,
		"effective_meta": effective_meta.duplicate(true)
	}
	# print("SettingsManager: Registered property '%s' of node '%s' (key: '%s'). Persistence: %s." % [property_name, node_path_obj, setting_key, persistence_type])


func _unregister_single_property_binding(
	setting_key: StringName, node_path_for_log: NodePath
) -> void:
	if not _property_bindings.has(setting_key):
		return

	var bind_info = _property_bindings[setting_key]
	# print("SettingsManager: Unregistering property bound to key '%s' for node '%s'" % [setting_key, node_path_for_log])

	if bind_info.persistence == PERSISTENCE_RUNTIME_ONLY:
		_runtime_bound_values.erase(setting_key)

	_property_bindings.erase(setting_key)


func _get_valid_node_from_binding(bind_info: Dictionary) -> Node:
	if not bind_info:
		return null
	var node_ref = bind_info.get("node_weak_ref")  # Use .get() for safety
	var node_instance: Node = null
	if node_ref is WeakRef and node_ref.get_ref():  # Check type before calling get_ref()
		node_instance = node_ref.get_ref()
	if not is_instance_valid(node_instance):
		var node_path = bind_info.get("node_path")
		if node_path is NodePath:  # Check type
			node_instance = get_node_or_null(node_path)
	return node_instance


func _on_internal_setting_changed_for_binding(changed_key: StringName, new_value: Variant):
	var bind_info = _property_bindings.get(changed_key)
	if not bind_info:
		return

	var node_instance = _get_valid_node_from_binding(bind_info)

	if is_instance_valid(node_instance):
		var property_name: StringName = bind_info.property
		if not are_variants_equal(node_instance.get(property_name), new_value):
			node_instance.set(property_name, new_value)
			node_property_updated.emit(node_instance, property_name, new_value)
	else:
		_unregister_single_property_binding(
			changed_key, bind_info.get("node_path", NodePath("unknown_path"))
		)  # Pass a default NodePath if missing


func are_variants_equal(v1: Variant, v2: Variant) -> bool:
	if typeof(v1) == TYPE_FLOAT and typeof(v2) == TYPE_FLOAT:
		return is_equal_approx(float(v1), float(v2))
	return v1 == v2


# Helper for reset_settings to avoid code duplication with Array.has for StringName
# This would ideally be a static utility or a custom Array extension if used widely.
# For now, keeping it simple or assuming a simple loop if ArrayUtil not available.
# For reset_settings, a simple Array.has() check is fine for StringName.
# class ArrayUtil:
#   static func unique_string_names(arr: Array) -> Array:
#       var unique_arr := []
#       for item in arr:
#           if not unique_arr.has(item):
#               unique_arr.append(item)
#       return unique_arr


func _reset_runtime_only_setting(key: StringName, bind_info_nullable: Dictionary) -> void:  # bind_info can be null
	if not _defaults.has(key):
		push_warning(
			(
				"SettingsManager: Cannot reset runtime_only setting '%s' as no default is registered."
				% key
			)
		)
		return

	var default_entry = _defaults[key]
	var default_val = default_entry.value

	var value_changed = false
	if (
		not _runtime_bound_values.has(key)
		or not are_variants_equal(_runtime_bound_values.get(key), default_val)
	):
		_runtime_bound_values[key] = default_val
		value_changed = true

	# Update node even if cached value was already default, in case node was out of sync
	var node_instance = _get_valid_node_from_binding(bind_info_nullable)
	if node_instance:
		var property_name = bind_info_nullable.property  # Assumes bind_info is not null if node_instance is valid from it
		if not are_variants_equal(node_instance.get(property_name), default_val):
			node_instance.set(property_name, default_val)
			node_property_updated.emit(node_instance, property_name, default_val)
			value_changed = true  # Ensure signal if node value changed

	if value_changed:
		setting_changed.emit(key, default_val)


func _reset_persistent_setting(key: StringName) -> void:
	if not _defaults.has(key):
		push_warning(
			(
				"SettingsManager: Cannot reset persistent setting '%s' as no default is registered."
				% key
			)
		)
		if _resource and _resource.settings.has(key):
			_resource.settings.erase(key)
			setting_changed.emit(key, null)
		return

	if not _resource:
		push_error(
			(
				"SettingsManager: Settings resource not loaded, cannot reset persistent setting '%s'."
				% key
			)
		)
		return

	var default_entry = _defaults[key]
	# Check if current value in resource is already the default
	var current_resource_value = _resource.settings.get(key, {}).get("value")  # Default to avoid error if key just got erased
	if (
		not _resource.settings.has(key)
		or not are_variants_equal(current_resource_value, default_entry.value)
	):
		_resource.settings[key] = default_entry.duplicate(true)
		setting_changed.emit(key, default_entry.value)
	# If value was already default, no change, no signal for value. Meta is part of default_entry.


#endregion


#region Private Live-Cyle API
func _init():
	if not _resource:
		_resource = SettingsResource.new()
	if not ProjectSettings.has_setting(DEFAULTS_PATH_SETTING):
		ProjectSettings.set_setting(DEFAULTS_PATH_SETTING, DEFAULTS_PATH)
		ProjectSettings.set_initial_value(DEFAULTS_PATH_SETTING, DEFAULTS_PATH)
		ProjectSettings.set_as_basic(DEFAULTS_PATH_SETTING, true)


func _ready():
	load_settings()
	load_defaults_for_environment(_env)
	validate_configuration()
	if not setting_changed.is_connected(_on_internal_setting_changed_for_binding):
		setting_changed.connect(_on_internal_setting_changed_for_binding)
#endregion
