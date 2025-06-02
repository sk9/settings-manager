extends GutTest

const TEST_ACTION_NAME = "gut_test_settings_manager"
const USER_TEST_SETTING_RESSOURCE = "user://test_settings_save.tres"

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


func test_settings_saved_to_resource():
	var manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()
	manager.register_setting("audio/music_enabled", true)
	manager.set_setting("audio/music_enabled", false)

	var path := USER_TEST_SETTING_RESSOURCE
	ResourceSaver.save(manager._resource, path)

	var loaded = ResourceLoader.load(path) as SettingsResource
	assert_not_null(loaded)
	assert_eq(loaded.settings["audio/music_enabled"].value, false)


func after_each():
	var path = USER_TEST_SETTING_RESSOURCE
	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove("test_settings_save.tres")
