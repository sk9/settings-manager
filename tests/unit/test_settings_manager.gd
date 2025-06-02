extends GutTest

const TEST_ACTION_NAME = "gut_test_settings_manager"
const USER_TEST_SETTING_RESSOURCE = "user://test_settings_save.tres"
const USER_TEST_SETTING_INI = "user://test_settings_save.ini"

const SettingsManagerInternal = preload("res://addons/settings_manager/core/settings_manager.gd")
const SettingsResource = preload("res://addons/settings_manager/core/settings_resource.gd")

var settings: SettingsManagerInternal
var changed = false


func before_each():
	settings = SettingsManagerInternal.new()
	settings._resource = SettingsResource.new()


func _on_setting_changed(key, value):
	if key == "debug/enabled" and value == true:
		changed = true


func test_register_sets_default():
	settings.register_setting("volume", 0.5)
	assert_eq(settings.get_setting("volume"), 0.5)


func test_get_returns_default_if_not_set():
	var value = settings.get_setting("non_existent", 123)
	assert_eq(value, 123)


func test_set_overrides_existing():
	settings.register_setting("quality", "medium")
	settings.set_setting("quality", "high")
	assert_eq(settings.get_setting("quality"), "high")


func test_reset_clears_all():
	settings.register_setting("sound", true)
	settings.set_setting("sound", false)
	settings.reset_settings()
	assert_eq(settings.get_setting("sound"), true)


func test_reset_no_defaults_clears_all():
	settings.set_setting("temp_key", "temp_value")
	settings.reset_settings(false)
	var result = settings.get_setting("temp_key", null)
	assert_eq(result, null)


func test_multiple_types():
	settings.register_setting("number", 42)
	settings.register_setting("bool", true)
	settings.register_setting("text", "hello")
	settings.register_setting("vector", Vector2(5, 5))

	assert_eq(settings.get_setting("number"), 42)
	assert_eq(settings.get_setting("bool"), true)
	assert_eq(settings.get_setting("text"), "hello")


func test_register_setting_with_metadata():
	var manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()

	var meta = {
		"label": "settings.audio.volume",
		"min": 0.0,
		"max": 1.0,
		"tooltip": "settings.audio.volume.tooltip"
	}

	manager.register_setting("audio/volume", 0.7, meta)

	assert_eq(manager.get_setting("audio/volume"), 0.7)
	var loaded_meta = manager.get_metadata("audio/volume")
	assert_eq(loaded_meta.label, "settings.audio.volume")
	assert_eq(loaded_meta.min, 0.0)
	assert_eq(loaded_meta.max, 1.0)
	assert_eq(loaded_meta.tooltip, "settings.audio.volume.tooltip")


func test_setting_changed_signal():
	var manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()

	changed = false
	manager.connect("setting_changed", Callable(self, "_on_setting_changed"))
	manager.set_setting("debug/enabled", true)

	# Yield one frame to ensure signal is processed (just in case)
	await get_tree().process_frame
	assert_true(changed)


func test_reset_entire_settings_to_defaults():
	var manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()

	manager.register_setting("audio/volume", 0.5, {}, 0.8)
	manager.register_setting("graphics/quality", "low", {}, "high")
	manager.register_setting("graphics/vsync", false, {}, true)

	manager.reset_settings()
	assert_eq(manager.get_setting("audio/volume"), 0.8)
	assert_eq(manager.get_setting("graphics/quality"), "high")
	assert_eq(manager.get_setting("graphics/vsync"), true)


func test_reset_specific_setting_to_default():
	var manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()
	manager.register_setting("graphics/quality", "low", {}, "high")

	manager.set_setting("graphics/quality", "medium")
	manager.reset_setting("graphics/quality")
	assert_eq(manager.get_setting("graphics/quality"), "high")


func test_get_settings_in_namespace():
	var manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()
	manager.register_setting("graphics/quality", "low", {}, "high")
	manager.register_setting("graphics/vsync", false, {}, true)
	manager.register_setting("audio/volume", 0.5, {}, 0.8)

	var graphics = manager.get_settings_in_namespace("graphics")
	assert_true(graphics.has("graphics/quality"))
	assert_true(graphics.has("graphics/vsync"))
	assert_false(graphics.has("audio/volume"))


func test_get_metadata_returns_empty_when_missing():
	var manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()
	var meta = manager.get_metadata("nonexistent")
	assert_eq(meta, {})


func test_settings_saved_to_default_format(): # Renamed for clarity
	# settings manager will try to load ini, then tres, then default to ini for saving
	# Ensure no old files exist from other tests that might make it choose tres
	if FileAccess.file_exists(USER_TEST_SETTING_RESSOURCE):
		DirAccess.remove_absolute(USER_TEST_SETTING_RESSOURCE)
	if FileAccess.file_exists(USER_TEST_SETTING_INI):
		DirAccess.remove_absolute(USER_TEST_SETTING_INI)
		
	# Re-initialize settings to ensure it picks up the default adapter logic correctly
	# after file cleanup
	# Note: `settings` is already created in before_each, but we need to ensure its internal
	# adapter paths point to the generic user paths, not specific test paths yet.
	# The before_each creates a new SettingsManagerInternal, which is good.
	# We also need to ensure its internal _ini_adapter and _tres_adapter point to the actual
	# default user paths initially so its load logic works as expected before we might
	# override paths for specific save/load tests.
	# For this specific test, we want it to save to its default user path (which is INI_USER_PATH)
	# The `settings` instance from `before_each` should be fine IF its internal adapters
	# are using their default paths (e.g. "user://settings.ini")
	
	# Reset/Reinitialize settings from before_each to ensure clean state for default paths
	settings = SettingsManagerInternal.new() 
	settings._resource = SettingsResource.new() # Critical for manager's internal state

	settings.register_setting("audio/music_enabled", true)
	settings.set_setting("audio/music_enabled", false)
	settings.set_meta("audio/music_enabled", {"category": "sound"})

	settings.save_settings() # This should now save to INI by default (user://settings.ini)

	# The SettingsManager saves to its configured INI_USER_PATH by default.
	# We should check that file, not USER_TEST_SETTING_INI unless we reconfigure the adapter.
	var default_ini_path = settings.INI_USER_PATH # This is "user://settings.ini"
	
	assert_true(FileAccess.file_exists(default_ini_path), "INI file should be created at default path.")
	# Ensure the generic TRES path wasn't used
	assert_false(FileAccess.file_exists(settings.TRES_USER_PATH), "TRES file should NOT be created by default at its default path.")

	# Verify INI content
	var config_file := ConfigFile.new()
	var err := config_file.load(default_ini_path)
	assert_eq(err, OK, "Should be able to load the saved INI file from default path.")
	
	assert_true(config_file.has_section_key("audio", "music_enabled"), "INI should have audio/music_enabled.")
	assert_eq(config_file.get_value("audio", "music_enabled"), false, "Value in INI should be false.")
	
	assert_true(config_file.has_section_key("audio.music_enabled.meta", "category"), "INI should have meta category.")
	assert_eq(config_file.get_value("audio.music_enabled.meta", "category"), "sound", "Meta category in INI should be 'sound'.")
	
	# Cleanup the default file created by this test
	if FileAccess.file_exists(default_ini_path):
		DirAccess.remove_absolute(default_ini_path)


func test_settings_loads_tres_and_saves_tres_if_ini_absent():
	# Ensure INI does not exist, TRES does
	if FileAccess.file_exists(USER_TEST_SETTING_INI):
		DirAccess.remove_absolute(USER_TEST_SETTING_INI)
	# Ensure default user INI also doesn't exist to not interfere with load choice
	if is_instance_valid(settings) and FileAccess.file_exists(settings.INI_USER_PATH):
		DirAccess.remove_absolute(settings.INI_USER_PATH)

	# Create a dummy TRES file for the manager to load using the specific test path
	var dummy_tres_content := {
		"video/resolution": {"value": "1920x1080", "meta": {"source": "tres_test"}}
	}
	# Use TresStorageAdapter directly for setup, pointing to USER_TEST_SETTING_RESSOURCE
	var tres_adapter_for_setup = preload("res://addons/settings_manager/core/tres_storage_adapter.gd").new(USER_TEST_SETTING_RESSOURCE)
	var setup_save_ok = tres_adapter_for_setup.save_all_settings(dummy_tres_content)
	assert_true(setup_save_ok, "Setup: Saving dummy TRES file should succeed.")
	assert_true(FileAccess.file_exists(USER_TEST_SETTING_RESSOURCE), "Setup: Dummy TRES file should exist at test path.")

	# Initialize SettingsManagerInternal - it should load from USER_TEST_SETTING_RESSOURCE
	# We need to configure the settings instance from before_each to use our test paths
	settings._tres_adapter.user_settings_path = USER_TEST_SETTING_RESSOURCE
	settings._ini_adapter.user_settings_path = USER_TEST_SETTING_INI # Ensure it looks for INI at our test path (which shouldn't exist)
	
	settings.load_settings() # This should load the TRES file from USER_TEST_SETTING_RESSOURCE

	assert_eq(settings._active_user_settings_format, "tres", "Manager should have detected TRES format.")
	assert_eq(settings.get_setting("video/resolution"), "1920x1080", "Should get value from TRES.")
	var meta = settings.get_metadata("video/resolution")
	assert_true(meta.has("source"), "Meta should have 'source' key.")
	assert_eq(meta.source, "tres_test", "Should get meta 'source' from TRES.")

	# Modify a setting and save. It should save back to TRES at USER_TEST_SETTING_RESSOURCE.
	settings.set_setting("video/vsync", true)
	settings.save_settings()

	assert_true(FileAccess.file_exists(USER_TEST_SETTING_RESSOURCE), "TRES file should still exist at test path after save.")
	assert_false(FileAccess.file_exists(USER_TEST_SETTING_INI), "INI file should NOT be created at test path if TRES was active.")

	# Verify TRES content
	var loaded_tres_data = tres_adapter_for_setup.load_all_settings() # Reads from USER_TEST_SETTING_RESSOURCE
	assert_true(loaded_tres_data.has("video/resolution"), "Saved TRES should retain old key.")
	assert_true(loaded_tres_data.has("video/vsync"), "Saved TRES should have new key 'video/vsync'.")
	assert_eq(loaded_tres_data["video/vsync"].value, true, "VSync value in TRES should be true.")


func after_each():
	if FileAccess.file_exists(USER_TEST_SETTING_RESSOURCE):
		DirAccess.remove_absolute(USER_TEST_SETTING_RESSOURCE)
	if FileAccess.file_exists(USER_TEST_SETTING_INI):
		DirAccess.remove_absolute(USER_TEST_SETTING_INI)
	
	# Cleanup default files that might have been created by tests if not handled locally by the test
	if is_instance_valid(settings): # settings might be nullified if a test suite fails badly
		if FileAccess.file_exists(settings.INI_USER_PATH):
			DirAccess.remove_absolute(settings.INI_USER_PATH)
		if FileAccess.file_exists(settings.TRES_USER_PATH):
			DirAccess.remove_absolute(settings.TRES_USER_PATH)

	# Make sure to clear any adapter path overrides if set during a test
	if is_instance_valid(settings) and is_instance_valid(settings._ini_adapter):
		settings._ini_adapter.user_settings_path = settings.INI_USER_PATH # Reset to default
	if is_instance_valid(settings) and is_instance_valid(settings._tres_adapter):
		settings._tres_adapter.user_settings_path = settings.TRES_USER_PATH # Reset to default
