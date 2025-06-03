extends GutTest

const GenericSettingsPanel = preload("res://addons/settings_manager/ui/GenericSettingsPanel.gd")
const SettingsManagerInternal = preload("res://addons/settings_manager/core/settings_manager.gd") # To access SettingsManager
const IniStorageAdapter = preload("res://addons/settings_manager/core/ini_storage_adapter.gd")
const TresStorageAdapter = preload("res://addons/settings_manager/core/tres_storage_adapter.gd")

var settings_manager: SettingsManagerInternal
var panel: GenericSettingsPanel

# Test specific namespace
const TEST_NAMESPACE = "test_ui_panel"
const TEST_SETTINGS_INI = "user://test_panel_settings.ini"
const TEST_SETTINGS_TRES = "user://test_panel_settings.tres"


func before_all():
	# Ensure SettingsManager is set up for tests if it's not already by a test runner
	# This setup is crucial because GenericSettingsPanel relies on the SettingsManager singleton
	if not Engine.has_singleton("SettingsManager"):
		# This is a fallback, ideally SettingsManager Autoload should already exist.
		# If we create it here, it might not be the same instance the game uses or other tests expect.
		# Gut tests usually run within a game-like environment where autoloads are present.
		settings_manager = SettingsManagerInternal.new()
		# Forcibly making it a singleton here for test scope is tricky and not standard.
		# We'll rely on it being a proper autoload or use get_node("/root/SettingsManager")
		push_warning("TestGenericSettingsPanel: SettingsManager singleton was not found via Engine.has_singleton(). Attempting to use /root/SettingsManager. Ensure it's correctly set up as an Autoload.")

	var sm_node = Engine.get_singleton("SettingsManager") if Engine.has_singleton("SettingsManager") else get_node_or_null("/root/SettingsManager")

	if not is_instance_valid(sm_node):
		push_error("TestGenericSettingsPanel: SettingsManager singleton not found via Engine or /root. Cannot proceed with tests.")
		# This will likely cause tests to fail if Gut doesn't stop execution.
		return

	if not sm_node is SettingsManagerInternal:
		push_error("TestGenericSettingsPanel: SettingsManager is not the expected type! Found: %s" % str(sm_node))
		return 
	settings_manager = sm_node as SettingsManagerInternal

	# Ensure adapters are set for the global SettingsManager for these tests
	if not settings_manager.can_be_used():
		var ini_adapter_for_test = IniStorageAdapter.new(TEST_SETTINGS_INI)
		var tres_adapter_for_test = TresStorageAdapter.new(TEST_SETTINGS_TRES)
		settings_manager.set_adapters(ini_adapter_for_test, tres_adapter_for_test)
		# push_warning("TestGenericSettingsPanel: Global SettingsManager adapters were not set. Configured them for tests using test-specific paths.")
		# Ensure it loads after setting adapters, otherwise it might have errored in its _ready
		settings_manager.load_settings()


func before_each():
	if not is_instance_valid(settings_manager):
		# This check is crucial if before_all failed to get settings_manager
		push_error("TestGenericSettingsPanel: settings_manager instance is not valid in before_each. Skipping test setup.")
		return

	# Clear settings specifically for the test namespace if possible, or reset.
	# For now, we re-register per test, so clearing specific keys might be complex.
	# A full reset ensures a clean slate but is heavy.
	# Let's assume tests will register what they need.
	# We primarily need to ensure files are clean.
    
	if FileAccess.file_exists(TEST_SETTINGS_INI): DirAccess.remove_absolute(TEST_SETTINGS_INI)
	if FileAccess.file_exists(TEST_SETTINGS_TRES): DirAccess.remove_absolute(TEST_SETTINGS_TRES)
	
	# This ensures that if SM loaded these files, its state is cleared regarding them.
	# However, SM loads from its configured paths, which we set to TEST_SETTINGS_INI/TRES in before_all.
	settings_manager.load_settings() # Reload to clear any data from these test files.


	panel = GenericSettingsPanel.new()
	add_child(panel) 


func after_each():
	if is_instance_valid(panel):
		panel.queue_free() 

	if not is_instance_valid(settings_manager):
		return # Cannot do cleanup if SM is not valid

	# Minimal cleanup: remove test files. Avoid broad resets if other tests run in parallel or sequence.
	if FileAccess.file_exists(TEST_SETTINGS_INI): DirAccess.remove_absolute(TEST_SETTINGS_INI)
	if FileAccess.file_exists(TEST_SETTINGS_TRES): DirAccess.remove_absolute(TEST_SETTINGS_TRES)
	# And ensure SM reloads to clear any data from these files for the next test.
	settings_manager.load_settings()


func test_panel_shows_no_settings_label_when_namespace_empty():
	if not is_instance_valid(settings_manager) or not settings_manager.can_be_used():
		assert_true(false, "SettingsManager not ready for this test.") # Fail test explicitly
		return
	assert_true(is_instance_valid(panel), "Panel should be instanced.")
	
	panel.namespace = TEST_NAMESPACE # Trigger _populate_ui
	await get_tree().process_frame 
    
	var container = panel.get_node_or_null("SettingsDisplayContainer")
	assert_true(is_instance_valid(container), "SettingsDisplayContainer should exist.")
	assert_eq(container.get_child_count(), 1, "Should have one child (the 'no settings' label).")
	var label = container.get_child(0) as Label
	assert_true(is_instance_valid(label), "Child should be a Label.")
	assert_true(label.text.contains("No settings found"), "Label text should indicate no settings.")

func test_panel_generates_controls_for_settings():
	if not is_instance_valid(settings_manager) or not settings_manager.can_be_used():
		assert_true(false, "SettingsManager not ready for this test.")
		return

	settings_manager.register_setting(TEST_NAMESPACE + "/my_bool", true, {"ui_label": "My Boolean"})
	settings_manager.register_setting(TEST_NAMESPACE + "/my_slider", 0.5, {"ui_label": "My Slider", "ui_type": "slider", "ui_min": 0, "ui_max": 1})
    
	panel.namespace = TEST_NAMESPACE
	await get_tree().process_frame

	var container = panel.get_node_or_null("SettingsDisplayContainer")
	assert_true(is_instance_valid(container), "SettingsDisplayContainer should exist.")
	assert_eq(container.get_child_count(), 2, "Should generate two rows for two settings.")
    
	var row1 = container.get_child(0) as HBoxContainer
	var row2 = container.get_child(1) as HBoxContainer
	assert_true(is_instance_valid(row1) and is_instance_valid(row2), "Rows should be HBoxContainers.")

	var control_map_r1 = panel._ui_controls_map.get(TEST_NAMESPACE + "/my_bool")
	assert_true(is_instance_valid(control_map_r1) and control_map_r1 is CheckButton, "Row 1 control from map should be a CheckButton.")
    
	var control_map_r2 = panel._ui_controls_map.get(TEST_NAMESPACE + "/my_slider")
	assert_true(is_instance_valid(control_map_r2) and control_map_r2 is HSlider, "Row 2 control from map should be an HSlider.")


func test_panel_generates_group_headers():
	if not is_instance_valid(settings_manager) or not settings_manager.can_be_used():
		assert_true(false, "SettingsManager not ready for this test.")
		return

	settings_manager.register_setting(TEST_NAMESPACE + "/item_a1", true, {"ui_label": "Item A1", "ui_group": "Group A", "ui_order": 1})
	settings_manager.register_setting(TEST_NAMESPACE + "/item_b1", "text", {"ui_label": "Item B1", "ui_group": "Group B", "ui_order": 1})
	settings_manager.register_setting(TEST_NAMESPACE + "/item_a2", false, {"ui_label": "Item A2", "ui_group": "Group A", "ui_order": 2})

	panel.namespace = TEST_NAMESPACE
	await get_tree().process_frame
    
	var container = panel.get_node_or_null("SettingsDisplayContainer")
	assert_true(is_instance_valid(container), "SettingsDisplayContainer should exist.")
	# Expected: GroupA_Label, ItemA1_HBox, ItemA2_HBox, HSeparator, GroupB_Label, ItemB1_HBox
	assert_eq(container.get_child_count(), 6, "Should have 6 children (2 group labels, 1 separator, 3 setting rows).")

	assert_true(container.get_child(0) is Label, "Child 0 should be Group A Label.")
	assert_eq((container.get_child(0) as Label).text, "Group A", "Group A Label text.")
	assert_true(container.get_child(1) is HBoxContainer, "Child 1 should be Item A1 HBox.")
	assert_true(container.get_child(2) is HBoxContainer, "Child 2 should be Item A2 HBox.")
	assert_true(container.get_child(3) is HSeparator, "Child 3 should be HSeparator.")
	assert_true(container.get_child(4) is Label, "Child 4 should be Group B Label.")
	assert_eq((container.get_child(4) as Label).text, "Group B", "Group B Label text.")
	assert_true(container.get_child(5) is HBoxContainer, "Child 5 should be Item B1 HBox.")

func test_panel_readonly_setting_is_label():
	if not is_instance_valid(settings_manager) or not settings_manager.can_be_used():
		assert_true(false, "SettingsManager not ready for this test.")
		return
		
	settings_manager.register_setting(TEST_NAMESPACE + "/readonly_item", "FixedValue", {"ui_label": "Read Only", "ui_readonly": true})
    
	panel.namespace = TEST_NAMESPACE
	await get_tree().process_frame
    
	var container = panel.get_node_or_null("SettingsDisplayContainer")
	assert_true(is_instance_valid(container), "SettingsDisplayContainer should exist.")
	assert_eq(container.get_child_count(), 1, "Should have one row for the readonly setting.")
	
	var control_map_entry = panel._ui_controls_map.get(TEST_NAMESPACE + "/readonly_item")
	assert_true(is_instance_valid(control_map_entry) and control_map_entry is Label, "Control for readonly setting from map should be a Label.")
	assert_eq((control_map_entry as Label).text, "FixedValue", "Readonly label should display the value.")

# Add a test for ui_order and key fallback sorting
func test_panel_sorting_order_respected():
	if not is_instance_valid(settings_manager) or not settings_manager.can_be_used():
		assert_true(false, "SettingsManager not ready for this test.")
		return

	settings_manager.register_setting(TEST_NAMESPACE + "/zebra", true, {"ui_label": "Zebra", "ui_order": 30})
	settings_manager.register_setting(TEST_NAMESPACE + "/apple", true, {"ui_label": "Apple", "ui_order": 10})
	settings_manager.register_setting(TEST_NAMESPACE + "/banana", true, {"ui_label": "Banana", "ui_order": 20})
	# Add items with same order to test key fallback
	settings_manager.register_setting(TEST_NAMESPACE + "/grape", true, {"ui_label": "Grape", "ui_order": 15})
	settings_manager.register_setting(TEST_NAMESPACE + "/fig", true, {"ui_label": "Fig", "ui_order": 15})


	panel.namespace = TEST_NAMESPACE
	await get_tree().process_frame

	var container = panel.get_node_or_null("SettingsDisplayContainer")
	assert_true(is_instance_valid(container), "SettingsDisplayContainer should exist.")
	assert_eq(container.get_child_count(), 5, "Should have 5 setting rows.")

	var first_setting_label = (container.get_child(0) as HBoxContainer).get_child(0) as Label
	assert_eq(first_setting_label.text, "Apple", "First item should be Apple (order 10).")
	
	var second_setting_label = (container.get_child(1) as HBoxContainer).get_child(0) as Label
	assert_eq(second_setting_label.text, "Fig", "Second item should be Fig (order 15, alphabetical).")

	var third_setting_label = (container.get_child(2) as HBoxContainer).get_child(0) as Label
	assert_eq(third_setting_label.text, "Grape", "Third item should be Grape (order 15, alphabetical).")
	
	var fourth_setting_label = (container.get_child(3) as HBoxContainer).get_child(0) as Label
	assert_eq(fourth_setting_label.text, "Banana", "Fourth item should be Banana (order 20).")
	
	var fifth_setting_label = (container.get_child(4) as HBoxContainer).get_child(0) as Label
	assert_eq(fifth_setting_label.text, "Zebra", "Fifth item should be Zebra (order 30).")
