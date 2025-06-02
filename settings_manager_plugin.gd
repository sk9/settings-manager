@tool
extends EditorPlugin

#region Public Signals
#endregion

#region Public Enum / Constants
const SETTINGS_MANAGER_SINGLETON_NAME = "SettingsManager"
const SETTINGS_MANAGER_SCRIPT_PATH = "res://addons/settings_manager/core/settings_manager.gd"

const IniStorageAdapter = preload("res://addons/settings_manager/core/ini_storage_adapter.gd")
const TresStorageAdapter = preload("res://addons/settings_manager/core/tres_storage_adapter.gd")
const SettingsManagerInternal = preload("res://addons/settings_manager/core/settings_manager.gd")

#endregion

#region Public Properties
#endregion

#region Private Properties
#endregion

#region Public API
#endregion

#region Private API
#endregion


#region Private Live-Cyle API
func _enter_tree():
	add_autoload_singleton(SETTINGS_MANAGER_SINGLETON_NAME, SETTINGS_MANAGER_SCRIPT_PATH)
	
	if Engine.is_editor_hint(): # Only run this setup logic in the editor tool context initially
		var settings_manager_node = get_editor_interface().get_singleton(SETTINGS_MANAGER_SINGLETON_NAME)
		if settings_manager_node is SettingsManagerInternal: # Type check
			var settings_manager = settings_manager_node as SettingsManagerInternal
			
			# Instantiate adapters
			# Adapters use their own internal default paths if none are provided to .new()
			var ini_adapter = IniStorageAdapter.new() 
			var tres_adapter = TresStorageAdapter.new() 
			
			settings_manager.set_adapters(ini_adapter, tres_adapter)
			# print("SettingsManagerPlugin: Injected adapters into SettingsManager singleton.")
			
			# SettingsManagerInternal._ready() will call load_settings(). 
			# This injection in _enter_tree() of the plugin should occur 
			# before the singleton's _ready() is called for the first time.
		else:
			push_error("SettingsManagerPlugin: Could not retrieve SettingsManager singleton or it's not the correct type.")


func _exit_tree():
	remove_autoload_singleton(SETTINGS_MANAGER_SINGLETON_NAME)
#endregion
