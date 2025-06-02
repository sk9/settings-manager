@tool
extends EditorPlugin

#region Public Signals
#endregion

#region Public Enum / Constants
const SETTINGS_MANAGER_SINGLETON_NAME = "SettingsManager"
const SETTINGS_MANAGER_SCRIPT_PATH = "res://addons/settings_manager/core/settings_manager.gd"

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


func _exit_tree():
	remove_autoload_singleton(SETTINGS_MANAGER_SINGLETON_NAME)
#endregion
