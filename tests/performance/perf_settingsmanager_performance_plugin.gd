extends GutTest

const SettingsManager = preload("res://addons/settings_manager/core/settings_manager.gd")
const SettingsResource = preload("res://addons/settings_manager/core/settings_resource.gd")

var manager: SettingsManagerInternal


func before_each():
	manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()


func test_register_large_amount_of_settings():
	var count = 1000
	var t0 = Time.get_ticks_usec()
	for i in count:
		manager.register_setting("perf/key_%d" % i, i, {"meta": {"label": "Label %d" % i}})
	var t1 = Time.get_ticks_usec()
	var duration = (t1 - t0) / 1000.0
	print("Registered %d settings in %.2f ms" % [count, duration])
	assert_true(duration < 100.0, "Registration took too long: %.2f ms" % duration)


func test_bulk_setting_update():
	var count = 1000
	for i in count:
		manager.register_setting("perf/key_%d" % i, 0)
	var t0 = Time.get_ticks_usec()
	for i in count:
		manager.set_setting("perf/key_%d" % i, i)
	var t1 = Time.get_ticks_usec()
	var duration = (t1 - t0) / 1000.0
	print("Updated %d settings in %.2f ms" % [count, duration])
	assert_true(duration < 100.0, "Bulk update took too long: %.2f ms" % duration)


func test_get_setting_performance():
	var count = 1000
	for i in count:
		manager.register_setting("perf/key_%d" % i, i)
	var t0 = Time.get_ticks_usec()
	for i in count:
		var tmp = manager.get_setting("perf/key_%d" % i)
	var t1 = Time.get_ticks_usec()
	var duration = (t1 - t0) / 1000.0
	print("Accessed %d settings in %.2f ms" % [count, duration])
	assert_true(duration < 100.0, "Accessing settings took too long: %.2f ms" % duration)
