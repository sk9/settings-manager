extends GutTest


func test_set_meta_on_new_setting():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()
	var key = "graphics/resolution"
	var meta_data: Dictionary = {
		"description": "Screen resolution", "options": ["1920x1080", "1280x720"]
	}

	manager_internal.set_meta(key, meta_data)

	assert_true(
		manager_internal._resource.settings.has(key), "Setting key should exist after set_meta."
	)
	var setting_entry = manager_internal._resource.settings.get(key)
	assert_eq_deep(setting_entry.get("meta"), meta_data)
	assert_null(setting_entry.get("value"), "Value should be null when meta is set on a new key.")


func test_set_meta_on_existing_setting_preserves_value():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()  # Ensure _resource is initialized

	var key = "audio/volume"
	var initial_value = 0.75
	var initial_meta = {"min": 0.0, "max": 1.0}

	manager_internal.set_setting(key, initial_value)  # This creates {"value": 0.75, "meta": {}} in _resource.settings
	manager_internal.set_meta(key, initial_meta)  # _resource.settings[key].meta becomes initial_meta

	var new_meta_data = {"description": "Master volume", "step": 0.05}
	manager_internal.set_meta(key, new_meta_data)

	assert_true(manager_internal._resource.settings.has(key), "Setting key should still exist.")
	var setting_entry = manager_internal._resource.settings[key]

	var expected_meta = initial_meta.duplicate(true)
	expected_meta.merge(new_meta_data, true)

	assert_eq_deep(setting_entry.get("meta"), expected_meta)  # Check against the merged dictionary
	assert_eq(
		setting_entry.get("value"), initial_value, "Value should be preserved when meta is updated."
	)


func test_set_meta_on_existing_setting_without_value_in_resource():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()  # Ensure _resource is initialized

	var key = "ui/theme"
	var manually_set_initial_meta = {"old_info": "some_data"}
	manager_internal._resource.settings[key] = {"meta": manually_set_initial_meta.duplicate(true)}  # No "value" field

	var new_meta_data = {"description": "UI Theme selection"}
	manager_internal.set_meta(key, new_meta_data)

	assert_true(manager_internal._resource.settings.has(key), "Setting key should still exist.")
	var setting_entry = manager_internal._resource.settings[key]

	var expected_meta = manually_set_initial_meta.duplicate(true)
	expected_meta.merge(new_meta_data, true)

	assert_eq_deep(setting_entry.get("meta"), expected_meta)  # Check against merged
	assert_true(setting_entry.has("value"), "Entry should now have a 'value' field, even if null.")  # set_meta adds it
	assert_null(
		setting_entry.get("value"), "Value should remain null or be set to null if not retrievable."
	)


func test_set_meta_with_non_dictionary_input_preserves_state():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()
	var key = "controls/sensitivity"
	var initial_value = 0.5
	# First, set a valid setting with some meta
	manager_internal.set_setting(key, initial_value)
	var initial_meta_data = {"unit": "percent"}
	manager_internal.set_meta(key, initial_meta_data)

	# Capture the original state (value and meta)
	var original_setting_entry = manager_internal._resource.settings[key].duplicate(true)

	var invalid_meta = "not_a_dictionary"
	manager_internal.set_meta(key, invalid_meta)
	assert_eq_deep(manager_internal._resource.settings[key], original_setting_entry)
	assert_eq_deep(manager_internal.get_metadata(key), initial_meta_data)


func test_set_meta_with_empty_dictionary():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()
	var key = "experimental/feature_x"
	manager_internal.set_setting(key, true)  # Ensure key exists with a value

	var empty_meta = {}
	manager_internal.set_meta(key, empty_meta)

	assert_true(manager_internal._resource.settings.has(key), "Setting key should exist.")
	var setting_entry = manager_internal._resource.settings[key]
	assert_eq_deep(setting_entry.get("meta"), empty_meta)
	assert_true(setting_entry.get("value"), "Value should be preserved.")


func test_get_metadata_for_existing_setting_with_meta():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()
	var key = "player/name"
	var value = "Hero"
	var meta_data = {"maxLength": 12, "tooltip": "Enter your hero name"}

	manager_internal.set_setting(key, value)
	manager_internal.set_meta(key, meta_data)

	var retrieved_meta = manager_internal.get_metadata(key)
	assert_eq_deep(retrieved_meta, meta_data)


func test_get_metadata_for_existing_setting_without_meta_field():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()
	var key = "system/language"
	# Simulate a setting entry that only has a value
	manager_internal._resource.settings[key] = {"value": "en"}

	var retrieved_meta = manager_internal.get_metadata(key)
	assert_eq_deep(retrieved_meta, {})


func test_get_metadata_for_existing_setting_with_non_dictionary_meta_value_returns_empty():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()
	var key = "debug/level"
	# Simulate a setting entry where 'meta' is not a dictionary
	manager_internal._resource.settings[key] = {"value": 1, "meta": "this_is_not_a_dictionary"}

	var retrieved_meta = manager_internal.get_metadata(key)
	assert_eq_deep(retrieved_meta, {})


func test_get_metadata_for_non_existent_setting():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()
	var key = "non_existent_key"
	var retrieved_meta = manager_internal.get_metadata(key)
	assert_eq_deep(retrieved_meta, {})


func test_get_metadata_for_setting_with_value_null_and_meta():
	var manager_internal = SettingsManagerInternal.new()
	manager_internal._resource = SettingsResource.new()
	var key = "optional/feature"
	var meta_data = {"toggleable": true}
	# Setting meta on a new key results in value: null
	manager_internal.set_meta(key, meta_data)

	var retrieved_meta = manager_internal.get_metadata(key)
	assert_eq_deep(retrieved_meta, meta_data)

	var setting_entry = manager_internal._resource.settings[key]
	assert_null(setting_entry.get("value"), "Value in resource should be null.")
	assert_eq_deep(setting_entry.get("meta"), meta_data)
