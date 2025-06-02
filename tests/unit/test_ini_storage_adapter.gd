extends GutTest

const IniStorageAdapter = preload("res://addons/settings_manager/core/ini_storage_adapter.gd")
const TEST_INI_PATH = "user://test_settings_adapter.ini"

var adapter: IniStorageAdapter

func before_each():
	adapter = IniStorageAdapter.new(TEST_INI_PATH)
	# Ensure no previous test file contaminates the results
	if FileAccess.file_exists(TEST_INI_PATH):
		DirAccess.remove_absolute(TEST_INI_PATH)

func after_each():
	if FileAccess.file_exists(TEST_INI_PATH):
		DirAccess.remove_absolute(TEST_INI_PATH)

func test_get_adapter_name():
	assert_eq(adapter.get_adapter_name(), "IniStorageAdapter", "Adapter name should be correct.")

func test_save_and_load_empty_settings():
	var settings_data := {}
	var save_success = adapter.save_all_settings(settings_data)
	assert_true(save_success, "Saving empty settings should succeed.")
	
	var loaded_settings = adapter.load_all_settings()
	assert_true(loaded_settings.is_empty(), "Loading from an empty save should result in empty settings.")

func test_save_and_load_simple_settings():
	var settings_data := {
		"graphics/fullscreen": {"value": true, "meta": {}},
		"audio/volume": {"value": 0.75, "meta": {}}
	}
	var save_success = adapter.save_all_settings(settings_data)
	assert_true(save_success, "Saving simple settings should succeed.")
	
	var loaded_settings = adapter.load_all_settings()
	assert_eq(loaded_settings.size(), 2, "Should load the correct number of settings.")
	assert_true(loaded_settings.has("graphics/fullscreen"), "Loaded settings should have graphics/fullscreen.")
	assert_eq(loaded_settings["graphics/fullscreen"].value, true, "Fullscreen value should match.")
	assert_true(loaded_settings["graphics/fullscreen"].meta.is_empty(), "Fullscreen meta should be empty.")
	
	assert_true(loaded_settings.has("audio/volume"), "Loaded settings should have audio/volume.")
	assert_almost_eq(loaded_settings["audio/volume"].value, 0.75, 0.001, "Volume value should match.")
	assert_true(loaded_settings["audio/volume"].meta.is_empty(), "Volume meta should be empty.")

func test_save_and_load_settings_with_metadata():
	var settings_data := {
		"player/name": {
			"value": "GodotUser", 
			"meta": {"label_key": "ui.player.name", "max_length": 20}
		},
		"controls/sensitivity": {
			"value": 0.5, 
			"meta": {"min": 0.1, "max": 1.0, "step": 0.05}
		}
	}
	var save_success = adapter.save_all_settings(settings_data)
	assert_true(save_success, "Saving settings with metadata should succeed.")
	
	var loaded_settings = adapter.load_all_settings()
	assert_eq(loaded_settings.size(), 2, "Should load the correct number of settings with metadata.")

	assert_true(loaded_settings.has("player/name"), "Loaded settings should have player/name.")
	assert_eq(loaded_settings["player/name"].value, "GodotUser", "Player name value should match.")
	assert_eq(loaded_settings["player/name"].meta.size(), 2, "Player name should have 2 meta entries.")
	assert_eq(loaded_settings["player/name"].meta.label_key, "ui.player.name", "Player name label_key should match.")
	assert_eq(loaded_settings["player/name"].meta.max_length, 20, "Player name max_length should match.")

	assert_true(loaded_settings.has("controls/sensitivity"), "Loaded settings should have controls/sensitivity.")
	assert_almost_eq(loaded_settings["controls/sensitivity"].value, 0.5, 0.001, "Sensitivity value should match.")
	assert_eq(loaded_settings["controls/sensitivity"].meta.size(), 3, "Sensitivity should have 3 meta entries.")
	assert_almost_eq(loaded_settings["controls/sensitivity"].meta.min, 0.1, 0.001, "Sensitivity min should match.")
	assert_almost_eq(loaded_settings["controls/sensitivity"].meta.max, 1.0, 0.001, "Sensitivity max should match.")
	assert_almost_eq(loaded_settings["controls/sensitivity"].meta.step, 0.05, 0.001, "Sensitivity step should match.")

func test_load_non_existent_file():
	# Ensure file does not exist (done in before_each, but double check)
	if FileAccess.file_exists(TEST_INI_PATH):
		DirAccess.remove_absolute(TEST_INI_PATH)
	var loaded_settings = adapter.load_all_settings()
	assert_true(loaded_settings.is_empty(), "Loading a non-existent file should result in empty settings.")

func test_save_overwrites_existing_file():
	var initial_settings := {
		"ui/language": {"value": "en", "meta": {}}
	}
	var save_success1 = adapter.save_all_settings(initial_settings)
	assert_true(save_success1, "Initial save should succeed.")

	var new_settings := {
		"ui/theme": {"value": "dark", "meta": {"contrast": 1.2}}
	}
	var save_success2 = adapter.save_all_settings(new_settings)
	assert_true(save_success2, "Second save (overwrite) should succeed.")

	var loaded_settings = adapter.load_all_settings()
	assert_eq(loaded_settings.size(), 1, "Should load one setting after overwrite.")
	assert_true(loaded_settings.has("ui/theme"), "Loaded settings should have the new ui/theme key.")
	assert_false(loaded_settings.has("ui/language"), "Loaded settings should not have the old ui/language key.")
	assert_eq(loaded_settings["ui/theme"].value, "dark", "Theme value should be 'dark'.")
	assert_eq(loaded_settings["ui/theme"].meta.contrast, 1.2, "Theme contrast meta should match.")

func test_data_types_persistence():
	var settings_data := {
		"types/my_string": {"value": "hello world", "meta": {}},
		"types/my_int": {"value": 12345, "meta": {}},
		"types/my_float": {"value": 123.456, "meta": {}},
		"types/my_bool_true": {"value": true, "meta": {}},
		"types/my_bool_false": {"value": false, "meta": {}},
		# Arrays and Dictionaries might be stringified by ConfigFile, needs careful checking
		# For now, focus on basic types that ConfigFile handles natively.
	}
	var save_success = adapter.save_all_settings(settings_data)
	assert_true(save_success, "Saving various data types should succeed.")

	var loaded_settings = adapter.load_all_settings()
	assert_eq(loaded_settings["types/my_string"].value, "hello world")
	assert_eq(loaded_settings["types/my_int"].value, 12345)
	assert_almost_eq(loaded_settings["types/my_float"].value, 123.456, 0.0001)
	assert_eq(loaded_settings["types/my_bool_true"].value, true)
	assert_eq(loaded_settings["types/my_bool_false"].value, false)
