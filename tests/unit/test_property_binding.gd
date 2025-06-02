extends GutTest

const SettingsManagerInternal = preload("res://addons/settings_manager/core/settings_manager.gd")
const SettingsResource = preload("res://addons/settings_manager/core/settings_resource.gd")
const TestPersistentNode = preload("res://addons/settings_manager/tests/helpers/persistent_node.gd")  # Adjust path if needed
const TestRuntimeNode = preload("res://addons/settings_manager/tests/helpers/runtime_node.gd")  # Adjust path if needed

var manager: SettingsManagerInternal
var root_node_for_tests: Node


func before_each():
	manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()
	manager._defaults = {}
	manager._property_bindings = {}
	manager._runtime_bound_values = {}

	if not manager.setting_changed.is_connected(manager._on_internal_setting_changed_for_binding):
		manager.setting_changed.connect(manager._on_internal_setting_changed_for_binding)

	root_node_for_tests = Node.new()
	add_child_autofree(root_node_for_tests)


func _create_and_add_node(script_class, node_name: String) -> Node:
	var node = script_class.new()
	node.name = node_name
	root_node_for_tests.add_child(node)
	return node


func test_register_persistent_property_initial_values():
	var p_node: TestPersistentNode = _create_and_add_node(TestPersistentNode, "MyPersistentNode")
	manager.register_node_properties(p_node)
	var speed_key = "%s/speed" % p_node.get_path()

	assert_true(manager._resource.settings.has(speed_key))
	assert_true(manager._defaults.has(speed_key))
	assert_almost_eq(manager.get_setting(speed_key), p_node.speed, 0.001)
	assert_almost_eq(manager._defaults[speed_key].value, p_node.speed, 0.001)

	assert_true(manager._property_bindings.has(speed_key))
	var speed_bind_info = manager._property_bindings[speed_key]
	assert_eq(speed_bind_info.node_path, p_node.get_path())
	assert_eq(speed_bind_info.property, "speed")
	assert_eq(speed_bind_info.persistence, manager.PERSISTENCE_PERSISTENT)


func test_register_runtime_only_property_initial_values():
	var r_node: TestRuntimeNode = _create_and_add_node(TestRuntimeNode, "MyRuntimeNode")
	manager.register_node_properties(r_node)
	var mana_key = "%s/current_mana" % r_node.get_path()

	assert_true(manager._runtime_bound_values.has(mana_key))
	assert_almost_eq(manager._runtime_bound_values[mana_key], r_node.current_mana, 0.001)
	assert_true(manager._defaults.has(mana_key))
	assert_almost_eq(manager._defaults[mana_key].value, r_node.current_mana, 0.001)
	assert_false(
		manager._resource.settings.has(mana_key),
		"Runtime mana value should NOT be in _resource.settings."
	)

	assert_true(manager._property_bindings.has(mana_key))
	var mana_bind_info = manager._property_bindings[mana_key]
	assert_eq(mana_bind_info.node_path, r_node.get_path())
	assert_eq(mana_bind_info.property, "current_mana")
	assert_eq(mana_bind_info.persistence, manager.PERSISTENCE_RUNTIME_ONLY)


func test_initial_sync_from_resource_on_register():
	var p_node: TestPersistentNode = _create_and_add_node(TestPersistentNode, "PNodeSyncResource")
	var speed_key = "%s/speed" % p_node.get_path()
	var saved_speed = 25.5
	manager._resource.settings[speed_key] = {
		"value": saved_speed, "meta": {"persistence": manager.PERSISTENCE_PERSISTENT}
	}

	assert_ne(p_node.speed, saved_speed)  # Assuming script default is different
	manager.register_node_properties(p_node)
	assert_almost_eq(p_node.speed, saved_speed, 0.001)


func test_initial_sync_from_defaults_on_register():
	var p_node: TestPersistentNode = _create_and_add_node(TestPersistentNode, "PNodeSyncDefaults")
	var speed_key = "%s/speed" % p_node.get_path()
	var default_speed = 18.0
	manager._defaults[speed_key] = {
		"value": default_speed, "meta": {"persistence": manager.PERSISTENCE_PERSISTENT}
	}

	assert_ne(p_node.speed, default_speed)  # Assuming script default is different
	manager.register_node_properties(p_node)
	assert_almost_eq(p_node.speed, default_speed, 0.001)


var _node_prop_updated_info = null


func _on_node_property_updated_for_test(node: Node, property_name: StringName, new_value: Variant):
	_node_prop_updated_info = {"node": node, "property": property_name, "value": new_value}


func test_manager_set_setting_updates_bound_node_persistent():
	var p_node: TestPersistentNode = _create_and_add_node(TestPersistentNode, "PNodePropagate")
	manager.register_node_properties(p_node)
	var speed_key = "%s/speed" % p_node.get_path()
	var new_speed = 33.3

	_node_prop_updated_info = null
	manager.node_property_updated.connect(_on_node_property_updated_for_test)
	manager.set_setting(speed_key, new_speed)

	assert_almost_eq(p_node.speed, new_speed, 0.001)
	assert_not_null(_node_prop_updated_info)
	if _node_prop_updated_info:
		assert_eq(_node_prop_updated_info.node, p_node)
		assert_eq(_node_prop_updated_info.property, "speed")
		assert_almost_eq(_node_prop_updated_info.value, new_speed, 0.001)
	manager.node_property_updated.disconnect(_on_node_property_updated_for_test)


func test_manager_set_setting_updates_bound_node_runtime():
	var r_node: TestRuntimeNode = _create_and_add_node(TestRuntimeNode, "RNodePropagate")
	manager.register_node_properties(r_node)
	var mana_key = "%s/current_mana" % r_node.get_path()
	var new_mana = 75.2

	_node_prop_updated_info = null
	manager.node_property_updated.connect(_on_node_property_updated_for_test)
	manager.set_setting(mana_key, new_mana)

	assert_almost_eq(r_node.current_mana, new_mana, 0.001)
	assert_almost_eq(manager._runtime_bound_values[mana_key], new_mana, 0.001)
	assert_not_null(_node_prop_updated_info)
	if _node_prop_updated_info:
		assert_eq(_node_prop_updated_info.node, r_node)
		assert_eq(_node_prop_updated_info.property, "current_mana")
		assert_almost_eq(_node_prop_updated_info.value, new_mana, 0.001)
	manager.node_property_updated.disconnect(_on_node_property_updated_for_test)


func test_unregister_node_properties_removes_bindings():
	var p_node: TestPersistentNode = _create_and_add_node(TestPersistentNode, "PNodeUnregister")
	var r_node: TestRuntimeNode = _create_and_add_node(TestRuntimeNode, "RNodeUnregister")
	manager.register_node_properties(p_node)
	manager.register_node_properties(r_node)

	var p_speed_key = "%s/speed" % p_node.get_path()
	var r_mana_key = "%s/current_mana" % r_node.get_path()

	manager.unregister_node_properties(p_node)
	assert_false(manager._property_bindings.has(p_speed_key))
	assert_true(manager._property_bindings.has(r_mana_key))  # Should still be there

	manager.unregister_node_properties(r_node)
	assert_false(manager._property_bindings.has(r_mana_key))
	assert_false(manager._runtime_bound_values.has(r_mana_key))
	assert_true(manager._resource.settings.has(p_speed_key))  # Def should remain


func test_unregister_property_removes_specific_binding():
	var p_node: TestPersistentNode = _create_and_add_node(
		TestPersistentNode, "PNodeUnregisterSingle"
	)
	manager.register_node_properties(p_node)
	var speed_key = "%s/speed" % p_node.get_path()
	var name_key = "%s/player_name" % p_node.get_path()

	manager.unregister_property(speed_key)
	assert_false(manager._property_bindings.has(speed_key))
	assert_true(manager._property_bindings.has(name_key))


func test_set_setting_on_freed_node_cleans_binding():
	var p_node_instance: TestPersistentNode = TestPersistentNode.new()
	p_node_instance.name = "PNodeFreed"
	root_node_for_tests.add_child(p_node_instance)
	var speed_key = "%s/speed" % p_node_instance.get_path()
	manager.register_node_properties(p_node_instance)
	assert_true(manager._property_bindings.has(speed_key))

	p_node_instance.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(p_node_instance))

	manager.set_setting(speed_key, 99.0)
	assert_false(manager._property_bindings.has(speed_key))

	var r_node_instance: TestRuntimeNode = TestRuntimeNode.new()
	r_node_instance.name = "RNodeFreed"
	root_node_for_tests.add_child(r_node_instance)
	var mana_key = "%s/current_mana" % r_node_instance.get_path()
	manager.register_node_properties(r_node_instance)
	assert_true(manager._runtime_bound_values.has(mana_key))
	r_node_instance.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	manager.set_setting(mana_key, 11.0)
	assert_false(manager._runtime_bound_values.has(mana_key))
	assert_false(manager._property_bindings.has(mana_key))


func test_reset_setting_updates_bound_node_persistent():
	var p_node: TestPersistentNode = _create_and_add_node(TestPersistentNode, "PNodeReset")
	var speed_key = "%s/speed" % p_node.get_path()
	var default_speed = 5.0
	manager._defaults[speed_key] = {
		"value": default_speed, "meta": {"persistence": manager.PERSISTENCE_PERSISTENT}
	}
	manager.register_node_properties(p_node)  # Should sync to default_speed

	manager.set_setting(speed_key, 50.0)
	assert_almost_eq(p_node.speed, 50.0, 0.001)

	manager.reset_setting(speed_key)
	assert_almost_eq(p_node.speed, default_speed, 0.001)


func test_reset_settings_to_defaults_updates_bound_nodes():
	var p_node: TestPersistentNode = _create_and_add_node(TestPersistentNode, "PNodeResetAll")
	var r_node: TestRuntimeNode = _create_and_add_node(TestRuntimeNode, "RNodeResetAll")
	var p_speed_key = "%s/speed" % p_node.get_path()
	var r_mana_key = "%s/current_mana" % r_node.get_path()
	var p_default_speed = 2.0
	var r_default_mana = 22.0

	manager._defaults[p_speed_key] = {
		"value": p_default_speed, "meta": {"persistence": manager.PERSISTENCE_PERSISTENT}
	}
	manager._defaults[r_mana_key] = {
		"value": r_default_mana, "meta": {"persistence": manager.PERSISTENCE_RUNTIME_ONLY}
	}

	manager.register_node_properties(p_node)
	manager.register_node_properties(r_node)

	manager.set_setting(p_speed_key, 100.0)
	manager.set_setting(r_mana_key, 110.0)

	manager.reset_settings(true)

	assert_almost_eq(p_node.speed, p_default_speed, 0.001)
	assert_almost_eq(r_node.current_mana, r_default_mana, 0.001)
	assert_almost_eq(manager._runtime_bound_values.get(r_mana_key, -1.0), r_default_mana, 0.001)


func test_persistence_of_bound_persistent_properties():
	var node_name = "MyPersistentSaverNode"
	var original_speed = 10.0  # Script default for TestPersistentNode.speed
	var set_speed = 45.5

	var manager1 = SettingsManagerInternal.new()
	manager1._resource = SettingsResource.new()
	var p_node1: TestPersistentNode = TestPersistentNode.new()
	p_node1.name = node_name
	root_node_for_tests.add_child(p_node1)
	var speed_key = "%s/speed" % p_node1.get_path()

	manager1.register_node_properties(p_node1)  # speed becomes 10.0 (script default)
	assert_almost_eq(p_node1.speed, original_speed, 0.001)

	manager1.set_setting(speed_key, set_speed)  # speed becomes 45.5, node updates
	assert_almost_eq(p_node1.speed, set_speed, 0.001)

	var saved_resource_data = manager1._resource.settings.duplicate(true)
	# Detach p_node1 before freeing to avoid issues if root_node_for_tests is processed weirdly
	root_node_for_tests.remove_child(p_node1)
	p_node1.queue_free()  # Use queue_free for safety
	await get_tree().process_frame  # Ensure it's freed

	var manager2 = SettingsManagerInternal.new()
	manager2._resource = SettingsResource.new()
	manager2._resource.settings = saved_resource_data  # Simulate loading

	var p_node2: TestPersistentNode = TestPersistentNode.new()
	p_node2.name = node_name
	root_node_for_tests.add_child(p_node2)  # Add to tree *before* registration

	# At this point, p_node2.speed is its script default (10.0)
	assert_almost_eq(
		p_node2.speed, original_speed, 0.001, "New node instance starts with script default."
	)

	manager2.register_node_properties(p_node2)  # Should sync from "loaded" resource

	assert_almost_eq(
		p_node2.speed,
		set_speed,
		0.001,
		"Node property should be initialized to the saved/loaded value."
	)
