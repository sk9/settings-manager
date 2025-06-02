extends GutTest

const SettingsManager = preload("res://addons/settings_manager/core/settings_manager.gd")
const SettingsResource = preload("res://addons/settings_manager/core/settings_resource.gd")

var manager: SettingsManagerInternal
var results := {}


func before_each():
	manager = SettingsManagerInternal.new()
	manager._resource = SettingsResource.new()


func test_performance_metrics_with_report():
	var now = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var filename = "res://perf_report_%s.txt" % now

	results["register"] = _measure_register_settings()
	results["update"] = _measure_update_settings()
	results["access"] = _measure_access_settings()

	var report = []
	report.append("Performance Report: %s" % now)
	for key in results:
		report.append("%s: %.2f ms" % [key.capitalize(), results[key]])
	report.append("")

	var file = FileAccess.open(filename, FileAccess.WRITE)
	for line in report:
		file.store_line(line)
	file.close()

	print("Report written to: ", filename)


func _measure_register_settings() -> float:
	var count = 1000
	var t0 = Time.get_ticks_usec()
	for i in count:
		manager.register_setting("perf/key_%d" % i, i)
	var t1 = Time.get_ticks_usec()
	return (t1 - t0) / 1000.0


func _measure_update_settings() -> float:
	var count = 1000
	for i in count:
		manager.register_setting("perf/key_%d" % i, 0)
	var t0 = Time.get_ticks_usec()
	for i in count:
		manager.set_setting("perf/key_%d" % i, i)
	var t1 = Time.get_ticks_usec()
	return (t1 - t0) / 1000.0


func _measure_access_settings() -> float:
	var count = 1000
	for i in count:
		manager.register_setting("perf/key_%d" % i, i)
	var t0 = Time.get_ticks_usec()
	for i in count:
		var tmp = manager.get_setting("perf/key_%d" % i)
	var t1 = Time.get_ticks_usec()
	return (t1 - t0) / 1000.0
