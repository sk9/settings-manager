# GenericSettingsPanel.gd
extends Control
class_name GenericSettingsPanel

## The namespace of settings to display and manage.
@export var namespace: StringName = "ui":
	set(value):
		namespace = value
		if is_inside_tree() and _settings_manager_ready:
			_populate_ui()

@onready var _settings_container: VBoxContainer = %SettingsDisplayContainer

var _settings_manager_ready := false
var _settings_manager # Will hold the SettingsManager singleton instance
var _ui_controls_map: Dictionary = {} # To map setting keys to their UI controls

func _ready():
	if Engine.has_singleton("SettingsManager"):
		_settings_manager = Engine.get_singleton("SettingsManager")
		if _settings_manager.can_be_used():
			_settings_manager_ready = true
			if not _settings_manager.setting_changed.is_connected(_on_external_setting_changed):
				_settings_manager.setting_changed.connect(_on_external_setting_changed)
			_populate_ui()
		else:
			push_warning("GenericSettingsPanel: SettingsManager found, but it's not ready (adapters might not be set). UI will not be populated.")
	else:
		push_error("GenericSettingsPanel: SettingsManager singleton not found. UI cannot be populated.")

func _exit_tree():
	if is_instance_valid(_settings_manager) and _settings_manager.setting_changed.is_connected(_on_external_setting_changed):
		_settings_manager.setting_changed.disconnect(_on_external_setting_changed)

# Helper function to sort settings
func _sort_settings_data(settings_dict: Dictionary) -> Array:
	var sorted_array: Array = []
	for key in settings_dict:
		var data = settings_dict[key].duplicate(true) # Work with a copy
		data["_key_"] = key # Inject key for easy access
		sorted_array.append(data)

	sorted_array.sort_custom(func(a, b):
		var group_a = str(a.meta.get("ui_group", "")).to_lower()
		var group_b = str(b.meta.get("ui_group", "")).to_lower()
		if group_a != group_b:
			return group_a < group_b
		
		var order_a = a.meta.get("ui_order", INF)
		var order_b = b.meta.get("ui_order", INF)
		if order_a == order_b:
			return str(a._key_).naturalnocasecmp_to(str(b._key_)) < 0
		return order_a < order_b
	)
	return sorted_array

func _populate_ui() -> void:
	_ui_controls_map.clear() # Clear map before repopulating

	if not _settings_manager_ready:
		push_warning("GenericSettingsPanel: Cannot populate UI, SettingsManager not ready.")
		return
	if namespace == &"":
		push_warning("GenericSettingsPanel: Namespace not set. Cannot populate UI.")
		return
	if not is_instance_valid(_settings_container):
		push_error("GenericSettingsPanel: SettingsDisplayContainer (VBoxContainer) not found. Scene setup error.")
		return

	for c in _settings_container.get_children():
		c.queue_free()

	if not _settings_manager:
		push_error("GenericSettingsPanel: SettingsManager instance is null in _populate_ui.")
		return
		
	var settings_dict = _settings_manager.get_settings_in_namespace(namespace)

	if settings_dict.is_empty():
		var no_settings_label = Label.new()
		no_settings_label.text = "No settings found for namespace '%s'." % namespace
		_settings_container.add_child(no_settings_label)
		return

	var sorted_settings_array = _sort_settings_data(settings_dict)
	var current_group = "_NO_GROUP_"

	for setting_data in sorted_settings_array:
		var key: StringName = setting_data._key_
		var value = setting_data.value
		var meta: Dictionary = setting_data.meta

		var group_name = meta.get("ui_group", "")
		if group_name != current_group:
			current_group = group_name
			if _settings_container.get_child_count() > 0 and group_name != "":
				_settings_container.add_child(HSeparator.new())
			if group_name != "":
				var group_label = Label.new()
				group_label.text = group_name
				var default_font_size = get_theme_font_size("font_size", "Label")
				if default_font_size > 0:
					group_label.add_theme_font_size_override("font_size", int(default_font_size * 1.2))
				group_label.add_theme_constant_override("margin_top", 10)
				group_label.add_theme_constant_override("margin_bottom", 5)
				_settings_container.add_child(group_label)

		var row_hbox = HBoxContainer.new()
		row_hbox.custom_minimum_size.y = 30
		_settings_container.add_child(row_hbox)

		var label_node = Label.new()
		label_node.text = meta.get("ui_label", str(key).capitalize())
		label_node.custom_minimum_size.x = 250
		label_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label_node.clip_text = true
		label_node.tooltip_text = meta.get("ui_tooltip", "")
		row_hbox.add_child(label_node)

		var control_node: Control = null # This will be the main interactive element
		var actual_input_control: Control = null # The specific node that holds the value and signals

		var ui_type_hint = meta.get("ui_type", "")

		if meta.get("ui_readonly", false) == true:
			actual_input_control = Label.new() # Treat as the input control for map
			actual_input_control.name = "ReadOnlyValue"
			actual_input_control.text = str(value)
			actual_input_control.clip_text = true
			control_node = actual_input_control # It's the same in this case
		else:
			if ui_type_hint == "checkbox" or (ui_type_hint == "" and typeof(value) == TYPE_BOOL):
				actual_input_control = CheckButton.new()
				actual_input_control.button_pressed = bool(value)
				actual_input_control.toggled.connect(_on_setting_control_value_changed.bind(key, actual_input_control))
				control_node = actual_input_control
			elif ui_type_hint == "slider" or (ui_type_hint == "" and (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and meta.has("ui_min") and meta.has("ui_max")):
				var slider_hbox = HBoxContainer.new() # This is the overall control_node for layout
				actual_input_control = HSlider.new() # This is the actual input control
				actual_input_control.min_value = float(meta.ui_min)
				actual_input_control.max_value = float(meta.ui_max)
				actual_input_control.step = float(meta.get("ui_step", 0.001 if typeof(value) == TYPE_FLOAT else 1.0))
				actual_input_control.value = float(value)
				actual_input_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slider_hbox.add_child(actual_input_control)
				
				var value_label = Label.new()
				value_label.name = "ValueLabel"
				value_label.text = _format_slider_label_text(float(value), float(actual_input_control.step))
				value_label.custom_minimum_size.x = 70
				value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				slider_hbox.add_child(value_label)
				
				actual_input_control.value_changed.connect(func(new_slider_val): value_label.text = _format_slider_label_text(new_slider_val, actual_input_control.step))
				actual_input_control.value_changed.connect(_on_setting_control_value_changed.bind(key, actual_input_control))
				control_node = slider_hbox
			elif ui_type_hint == "spinbox" or (ui_type_hint == "" and (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT)):
				actual_input_control = SpinBox.new()
				actual_input_control.min_value = float(meta.get("ui_min", -INF))
				actual_input_control.max_value = float(meta.get("ui_max", INF))
				actual_input_control.step = float(meta.get("ui_step", 0.01 if typeof(value) == TYPE_FLOAT else 1.0))
				actual_input_control.value = float(value)
				actual_input_control.editable = true
				if typeof(value) == TYPE_INT and actual_input_control.step >= 1.0:
					actual_input_control.rounded = true
				actual_input_control.value_changed.connect(_on_setting_control_value_changed.bind(key, actual_input_control))
				control_node = actual_input_control
			elif ui_type_hint == "line_edit" or (ui_type_hint == "" and typeof(value) == TYPE_STRING):
				actual_input_control = LineEdit.new()
				actual_input_control.text = str(value)
				actual_input_control.text_submitted.connect(_on_setting_control_value_changed.bind(key, actual_input_control))
				control_node = actual_input_control
			elif ui_type_hint == "option_button" and meta.has("ui_options"):
				actual_input_control = OptionButton.new()
				var ob = actual_input_control as OptionButton
				var options_arr = meta.ui_options
				var value_to_select = value
				var selected_id = -1
				if options_arr is Array:
					for i in range(options_arr.size()):
						var item_label = ""
						var item_value = null
						if options_arr[i] is String:
							item_label = options_arr[i]; item_value = options_arr[i]
						elif options_arr[i] is Dictionary:
							item_label = str(options_arr[i].get("label", str(options_arr[i].get("value", "ERR_LABEL"))))
							item_value = options_arr[i].get("value")
						else:
							push_warning("GenericSettingsPanel: Invalid option item format for key %s. Item: %s" % [key, str(options_arr[i])])
							continue
						ob.add_item(item_label, i)
						ob.set_item_metadata(i, item_value)
						if item_value == value_to_select: selected_id = i
				else:
					push_warning("GenericSettingsPanel: ui_options for key %s is not an Array." % key)

				if selected_id != -1: ob.select(selected_id)
				elif ob.get_item_count() > 0: ob.select(0)
				
				ob.item_selected.connect(_on_setting_control_value_changed.bind(key, ob))
				control_node = ob
			elif ui_type_hint == "color_picker" or (ui_type_hint == "" and typeof(value) == TYPE_COLOR):
				actual_input_control = ColorPickerButton.new()
				actual_input_control.color = value if typeof(value) == TYPE_COLOR else Color.WHITE
				actual_input_control.color_changed.connect(_on_setting_control_value_changed.bind(key, actual_input_control))
				control_node = actual_input_control
			elif ui_type_hint == "text_edit":
				actual_input_control = TextEdit.new()
				actual_input_control.text = str(value)
				actual_input_control.custom_minimum_size.y = 75
				actual_input_control.focus_exited.connect(_on_setting_control_value_changed.bind(key, actual_input_control))
				control_node = actual_input_control
			else:
				actual_input_control = Label.new() # Fallback input control
				actual_input_control.text = "Unsupported UI for type: %s, key: %s" % [typeof(value), key]
				control_node = actual_input_control
		
		if is_instance_valid(control_node):
			# Store the actual_input_control (which holds the value) in the map
			if is_instance_valid(actual_input_control):
				_ui_controls_map[key] = actual_input_control
				actual_input_control.name = "InputControl_" + str(key).replace("/", "_") # Unique name for easier debugging
				if not (actual_input_control is Label and actual_input_control.name == "ReadOnlyValue"):
					actual_input_control.tooltip_text = meta.get("ui_tooltip", "")
			
			control_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_hbox.add_child(control_node)
		else:
			push_error("GenericSettingsPanel: Failed to create control for key %s" % key)


func _format_slider_label_text(value: float, step: float) -> String:
	if step == 0: 
		return "%.2f" % value
	if fmod(step, 1.0) < 0.00001: 
		return str(int(round(value)))
	else: 
		var s_step = str(step)
		if "." in s_step:
			var dp = s_step.split(".")[1].length()
			return "%.*f" % [dp, value]
		return "%.2f" % value

func _on_setting_control_value_changed(new_val_or_idx_or_text, setting_key: StringName, control: Control):
	var final_value = new_val_or_idx_or_text 

	if control is CheckButton: final_value = control.button_pressed
	elif control is HSlider: final_value = control.value
	elif control is SpinBox: final_value = control.value
	elif control is LineEdit: final_value = control.text # text_submitted passes text
	elif control is OptionButton: final_value = control.get_item_metadata(control.selected if control.selected >=0 else 0) # item_selected passes index
	elif control is ColorPickerButton: final_value = control.color # color_changed passes color
	elif control is TextEdit: final_value = control.text # focus_exited, so get current text
	
	if _settings_manager and _settings_manager_ready:
		_settings_manager.set_setting(setting_key, final_value)
	else:
		push_error("GenericSettingsPanel: SettingsManager not available to save setting '%s'." % setting_key)

func _on_external_setting_changed(changed_key: StringName, new_value: Variant) -> void:
	if not is_inside_tree() or not is_instance_valid(_settings_container):
		return

	if not _ui_controls_map.has(changed_key):
		# This can happen if the setting is not in the current panel's namespace,
		# or if the panel hasn't been populated for that specific key yet.
		# Or if the key belongs to a different panel instance.
		return

	var control_to_update = _ui_controls_map[changed_key] as Control
	if not is_instance_valid(control_to_update):
		push_error("GenericSettingsPanel: Control for key '%s' is no longer valid." % changed_key)
		_ui_controls_map.erase(changed_key) # Clean up invalid entry
		return

	# Block signals from the control we are about to update, to prevent feedback loop
	# For some controls, checking value before setting is enough. For others, explicit block might be safer.
	# However, Godot's built-in controls often don't emit signal if value set programmatically is same as current.
	
	var current_ui_value

	if control_to_update is CheckButton:
		current_ui_value = (control_to_update as CheckButton).button_pressed
		if current_ui_value != bool(new_value):
			(control_to_update as CheckButton).button_pressed = bool(new_value)
	elif control_to_update is HSlider:
		current_ui_value = (control_to_update as HSlider).value
		# Use a small tolerance for float comparison
		if abs(current_ui_value - float(new_value)) > (control_to_update as HSlider).step * 0.1 and abs(current_ui_value - float(new_value)) > 0.00001 : # Check against step and epsilon
			(control_to_update as HSlider).value = float(new_value)
		# Update sibling ValueLabel if HSlider is part of the standard slider_hbox structure
		var slider_hbox = control_to_update.get_parent()
		if slider_hbox is HBoxContainer and slider_hbox.get_child_count() > 1 and slider_hbox.get_child(1) is Label:
			var value_label = slider_hbox.get_child(1) as Label
			value_label.text = _format_slider_label_text(float(new_value), float((control_to_update as HSlider).step))
	elif control_to_update is SpinBox:
		current_ui_value = (control_to_update as SpinBox).value
		if abs(current_ui_value - float(new_value)) > (control_to_update as SpinBox).step * 0.1 and abs(current_ui_value - float(new_value)) > 0.00001:
			(control_to_update as SpinBox).value = float(new_value)
	elif control_to_update is LineEdit:
		current_ui_value = (control_to_update as LineEdit).text
		if current_ui_value != str(new_value):
			(control_to_update as LineEdit).text = str(new_value)
	elif control_to_update is OptionButton:
		var ob = control_to_update as OptionButton
		var target_item_id = -1
		for i in range(ob.item_count):
			if ob.get_item_metadata(i) == new_value:
				target_item_id = i
				break
		current_ui_value = ob.get_item_metadata(ob.selected) if ob.selected >=0 else null
		if current_ui_value != new_value and target_item_id != -1 and ob.selected != target_item_id:
			 ob.select(target_item_id)
	elif control_to_update is ColorPickerButton:
		current_ui_value = (control_to_update as ColorPickerButton).color
		if current_ui_value != new_value: # Color comparison works directly
			(control_to_update as ColorPickerButton).color = new_value if typeof(new_value) == TYPE_COLOR else Color.BLACK
	elif control_to_update is TextEdit:
		current_ui_value = (control_to_update as TextEdit).text
		if current_ui_value != str(new_value):
			(control_to_update as TextEdit).text = str(new_value)
	elif control_to_update is Label and control_to_update.name == "ReadOnlyValue": # Read-only label
		current_ui_value = (control_to_update as Label).text
		if current_ui_value != str(new_value):
			(control_to_update as Label).text = str(new_value)


## Call this method if you need to manually refresh the UI, e.g., after changing the namespace programmatically.
func refresh_ui() -> void:
	if is_inside_tree() and _settings_manager_ready:
		_populate_ui()
	elif not _settings_manager_ready:
		push_warning("GenericSettingsPanel: Cannot refresh UI, SettingsManager not ready.")
