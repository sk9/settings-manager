extends GutTest

const SettingsManagerInternal = preload("res://addons/settings_manager/core/settings_manager.gd")
const SettingsResource = preload("res://addons/settings_manager/core/settings_resource.gd")

var manager: SettingsManagerInternal


func before_each():
	manager = SettingsManagerInternal.new()
	manager._defaults_base_path = manager.DEFAULTS_PATH
	manager._resource = SettingsResource.new()


func test_load_test_defaults():
	manager.load_defaults_for_environment("test")
	assert_eq(manager.get_setting("env/name", ""), "test")
	assert_eq(manager.get_setting("audio/sound-volume", 0.0), 0.3)


func test_missing_environment_file_falls_back_gracefully():
	manager.load_defaults_for_environment("staging")
	assert_eq(manager.get_setting("env/name", "none"), "none")
