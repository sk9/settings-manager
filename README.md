
# SettingsManager (Godot Plugin)

A robust, extensible plugin for managing user, environment-specific, and automatically bound node property settings in Godot 4. It uses `.tres` resource files for persistence and offers a flexible API.

## 🚀 Core Features

*   **Type-Safe Settings:** Stored in a custom `SettingsResource` (for TRES) or managed by `ConfigFile` (for INI).
*   **Flexible User Persistence:** User settings are loaded from `user://settings.ini` (preferred) or `user://settings.tres` (fallback for existing users). New settings are saved to `user://settings.ini`.
*   **Environment Defaults:** Load default values from environment-specific `.tres` files (e.g., `default_dev.tres`, `default_prod.tres`). These always use the TRES format.
*   **Extensible Storage:** Includes a storage adapter system, initially supporting INI and TRES file formats, allowing for future expansion (e.g., JSON, SQLite).
*   **Automatic Property Binding:** Nodes can easily bind their properties to the SettingsManager for automatic loading, saving, and synchronization.
*   **Persistent & Runtime-Only Bindings:** Supports properties that should be saved and those that are only for the current session.
*   **Metadata Support:** Store rich metadata (labels, tooltips, ranges) alongside settings to drive UIs or for i18n.
*   **Signal-Driven:** Emits signals on setting changes and when bound node properties are updated.
*   **Autoload-Friendly Design:** Intended to be used as an Autoload singleton (e.g., named `SettingsManager`).

## 🧠 Behavior & Load Order

1.  **User Settings (INI or TRES):** Loaded first. The system checks for `user://settings.ini`. If found, it's used. Otherwise, it checks for `user://settings.tres` for backward compatibility. If neither is found, settings start fresh. New settings are saved to `user://settings.ini` unless loaded from an existing `.tres` file (in which case changes are saved back to `.tres`).
2.  **Environment Defaults (`res://addons/settings_manager/defaults/default_<env>.tres`):** Loaded next. These provide baseline values for the current environment (always in TRES format). They only apply if a setting isn't already present from user settings.
3.  **Programmatic Defaults (`SettingsManager.register_setting()`):** Can be used to define fallback defaults if a setting is not found in user settings or environment defaults.
4.  **Node Property Binding (`SettingsManager.register_node_properties(node)`):**
	*   When a node registers its properties, the manager checks for existing saved or default values for those settings.
	*   **If a stored value exists:** The node's property is updated to this value.
	*   **If no stored value exists:** The node's current property value is used as the initial value and registered with the manager (and becomes the default if no other default was defined).

This order ensures user preferences are always prioritized.

## ⚙️ Setting Resolution Order (When calling `get_setting(key, fallback_value)`)

1.  ✅ **Runtime-Only Bound Value:** If the key is for a `runtime_only` bound property, its current live (cached) value is returned.
2.  ✅ **User-Set Value:** If a user has a saved value for a persistent setting (from the active `user://settings.ini` or `user://settings.tres` file), that is returned.
3.  ✅ **Environment Default / Registered Default:** If no user value, the value from `_defaults` (populated by environment files or `register_setting()`) is returned.
4.  ✅ **Fallback Value:** If none of the above, the `fallback_value` passed to `get_setting()` is returned.

## 🛠️ Basic Usage (Manual API)

```gdscript
# Assumes SettingsManager is an Autoload singleton

func _ready():
	# Register with a default and metadata (optional)
	SettingsManager.register_setting("audio/master_volume", 0.8, {
		"label_key": "ui.settings.volume.master", # For i18n
		"min": 0.0,
		"max": 1.0,
		"step": 0.05
	})

	# Set a value (overrides default or saved user value)
	SettingsManager.set_setting("audio/master_volume", 0.5)

	# Read the setting
	var volume = SettingsManager.get_setting("audio/master_volume", 1.0) # 0.5
	var volume_meta = SettingsManager.get_metadata("audio/master_volume")
	# if volume_meta.has("label_key"):
	#     print(TranslationServer.translate(volume_meta.label_key))

	# Save current persistent settings to disk
	SettingsManager.save_settings()

	# Reset a specific setting to its default
	SettingsManager.reset_setting("audio/master_volume") # volume is now 0.8

	# Reset all settings to their defaults
	SettingsManager.reset_settings()
```

## 🔗 Automatic Property Binding

Nodes can have their properties automatically managed by the SettingsManager.

### 1. Mark Properties in Your Node Script

Use the `@export_custom` annotation with a special hint string:

*   `[settings_bind:persistent]`: The property's value will be loaded from and saved to the user's chosen settings file (`user://settings.ini` by default for new configurations, or `user://settings.tres` if that's what was loaded). It will also respect environment defaults.
*   `[settings_bind:runtime_only]`: The property's value is managed for the current session only. It's initialized from the script's value (or a registered default for its key) and synchronized if changed via the manager, but not saved.

```gdscript
# player.gd
extends CharacterBody2D
class_name Player

@export_custom(PropertyHint.NONE, "[settings_bind:persistent]") var speed: float = 150.0
@export_custom(PropertyHint.NONE, "[settings_bind:persistent]") var player_name: String = "Adventurer"
@export_custom(PropertyHint.NONE, "[settings_bind:runtime_only]") var current_stamina: float = 100.0

# This property is not bound
@export var health: int = 10
```

### 2. Register Node in `_ready()`

In the `_ready()` function of your node, tell the `SettingsManager` to scan and register its bound properties:

```gdscript
# player.gd
# ... (exports from above) ...

func _ready():
	SettingsManager.register_node_properties(self)
	# Now, self.speed, self.player_name, and self.current_stamina are managed.
```

### How Property Binding Works:

*   **Registration:** `SettingsManager.register_node_properties(self)` scans the node for properties marked with `[settings_bind:...]`.
*   **Key Generation:** A unique setting key is generated (e.g., `"/root/Game/Player/speed"`).
*   **Initial Value:**
	*   If a saved value or default exists for this key, the node's property is updated to that value.
	*   Otherwise, the node's current property value is registered as the initial/default value.
*   **Synchronization:**
	*   If `SettingsManager.set_setting("node/path/property", new_value)` is called, the corresponding node's property will be automatically updated.
	*   The `SettingsManager.node_property_updated(node, property_name, new_value)` signal is emitted.
*   **Persistence:**
	*   Properties marked `persistent` are saved when `SettingsManager.save_settings()` is called.
	*   `runtime_only` properties are not saved.
*   **Unregistration:**
	*   `SettingsManager.unregister_node_properties(node)`: Removes all bindings for a specific node.
	*   `SettingsManager.unregister_property(setting_key)`: Removes a specific property binding.

## 💾 Storage Formats & Behavior

The SettingsManager aims for flexibility in how user settings are stored.

### Supported Formats

*   **INI Files (`.ini`):** The preferred format for new user configurations. Uses Godot's `ConfigFile` system. Offers human-readable text-based storage.
*   **Resource Files (`.tres`):** Used for backward compatibility if an existing `user://settings.tres` is found and no `user://settings.ini` exists. Also used for environment default files.

### Loading Logic

When the SettingsManager initializes or `load_settings()` is called:
1.  It checks for `user://settings.ini`. If found, it's loaded using the INI adapter.
2.  If `user://settings.ini` is not found, it then checks for `user://settings.tres`. If found, it's loaded using the TRES adapter. This ensures backward compatibility for users who previously had settings saved in the `.tres` format.
3.  If neither file is found, the system starts with no user-saved settings, and any new settings will be saved to `user://settings.ini`.

### Saving Logic

When `save_settings()` is called:
*   If settings were initially loaded from `user://settings.ini`, or if no settings file existed at startup (causing it to default to INI), then all current settings are saved to `user://settings.ini`.
*   If settings were loaded from `user://settings.tres` (because no `.ini` file was present at startup), any changes will be saved back to the original `user://settings.tres` file. This maintains consistency for existing users.

### INI File Structure

Settings are mapped to INI sections and keys. A setting key in the format `section_name/key_name` is stored as:

```ini
[section_name]
key_name = value
```

Metadata associated with a setting is stored in a separate section named `section_name.key_name.meta`.

**Example:**

A setting registered with key `audio/master_volume`, value `0.5`, and metadata `{"label_key": "ui.volume", "max": 1.0}` would be stored in `user://settings.ini` as:

```ini
[audio]
master_volume = 0.5

[audio.master_volume.meta]
label_key = "ui.volume"
max = 1.0
```

Arrays and complex dictionary values stored in INI files might be stringified or handled according to `ConfigFile`'s capabilities. For complex data structures, TRES files (used for defaults) handle them more natively.

## 🌍 Environment Support

Environment defaults provide baseline settings for different deployment environments (development, QA, release, etc.).

1.  **Default Files Location:**
	*   Default path: `res://addons/settings_manager/defaults/default_<env>.tres`
	*   Example: `res://addons/settings_manager/defaults/default_dev.tres`
2.  **Customize Defaults Path (Optional):**
	*   Create a Project Setting:
		*   **Key:** `settings_manager/defaults_path`
		*   **Value (Example):** `res://my_game_data/settings_defaults/` (Note the trailing slash)
3.  **Set Current Environment:**
	*   Create a Project Setting:
		*   **Key:** `application/config/environment`
		*   **Value (Example):** `dev` (or `qa`, `release`, `prod`, etc.)
	*   The SettingsManager reads this value to determine which `default_<env>.tres` file to load.

### Creating a Default Settings File (`.tres`)

1.  In the Godot Editor's FileSystem dock:
	*   Right-click in the desired defaults folder.
	*   Select "New Resource..."
	*   Search for and choose `SettingsResource`.
	*   Name the file (e.g., `default_dev.tres`).
2.  Open the newly created `.tres` file in the Inspector.
3.  You'll see a `settings` property (Dictionary). Click it, add elements:
	*   **Key:** The setting key (e.g., `audio/sfx_volume`, `graphics/fullscreen`).
	*   **Value:** A Dictionary with two sub-keys:
		*   `value`: The actual default value for the setting (e.g., `0.75`, `true`).
		*   `meta`: Another Dictionary for any metadata (e.g., `{"label_key": "ui.sfx_volume"}`).
	*   Example structure within the `settings` Dictionary of the `.tres` file:
		```
		"audio/sfx_volume": {
			"value": 0.75,
			"meta": {"label_key": "ui.sfx_volume", "max": 1.0}
		},
		"graphics/fullscreen": {
			"value": false,
			"meta": {}
		}
		```
4.  Save the `.tres` file.

## 🧩 Metadata for Settings

You can associate arbitrary metadata with any setting. This is useful for driving UIs, providing internationalization keys, validation rules, etc.

### Registering/Setting Meta:

```gdscript
# When registering a new setting (manual API)
SettingsManager.register_setting("player/jump_force", 10.0, {
	"label_key": "settings.player.jump",
	"unit": "pixels/sec^2",
	"min": 5.0,
	"max": 20.0
})

# Or update meta for an existing setting
SettingsManager.set_meta("player/jump_force", {"tooltip_key": "settings.player.jump.tooltip"})
```

### Accessing Meta:

```gdscript
var jump_meta = SettingsManager.get_metadata("player/jump_force")
if jump_meta.has("label_key"):
	var ui_label = TranslationServer.translate(jump_meta.label_key)
	# Use ui_label in your settings screen
```

For **bound properties**, metadata like `bound_to_node`, `bound_property`, and `persistence` is automatically added by the manager. You can add your custom metadata on top of this.

## ✅ Best Practices

*   **Autoload:** Set up `SettingsManager` (or your wrapper around `SettingsManagerInternal`) as an Autoload singleton for easy global access.
*   **Initialize in `_ready()`:** Call `SettingsManager.register_node_properties(self)` in the `_ready()` function of nodes that need their properties bound.
*   **Clear Naming:** Use clear and consistent keys for your settings (e.g., `category/setting_name`).
*   **Default Values:** Provide sensible default values via `register_setting()` or environment default files.
*   **Save Appropriately:** Call `SettingsManager.save_settings()` at appropriate times (e.g., when exiting a settings menu, on game quit).
*   **Backup User Files:** During development or for users, be aware of `user://settings.ini` (the new default) and potentially `user://settings.tres` (for older setups).

## 🔌 Extending Storage (For Developers)

The SettingsManager now uses a storage adapter pattern to handle persistence. The base class is `StorageAdapter.gd` (`res://addons/settings_manager/core/storage_adapter.gd`).

To add support for a new storage format (e.g., JSON, XML, SQLite), you would create a new script that extends `StorageAdapter` and implements the following core methods:

*   `get_adapter_name() -> String`: Return a unique name for your adapter.
*   `load_all_settings() -> Dictionary`: Load all settings from your custom source and return them as a Dictionary in the standard format: `{ "setting_key": {"value": ..., "meta": {...}}, ... }`.
*   `save_all_settings(settings_data: Dictionary) -> bool`: Take a Dictionary in the standard format and save it to your custom source. Return `true` on success, `false` on failure.

Once your adapter is created, you would modify `SettingsManagerInternal.gd` to instantiate and use your adapter, potentially adding logic to select it based on file extensions or project settings.
