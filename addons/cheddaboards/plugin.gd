@tool
extends EditorPlugin

# CheddaBoards editor plugin.
# Enabling the plugin (Project Settings -> Plugins) registers the
# CheddaBoards SDK autoload so you can immediately call:
#
#     CheddaBoards.submit_score(score, streak)
#
# Disabling the plugin removes the autoload again, but only if this
# plugin was the one that added it - a pre-existing autoload (for
# example one set up by the full CheddaBoards template, or added
# manually per the drop-in quickstart) is left untouched.

const AUTOLOAD_NAME := "CheddaBoards"
const AUTOLOAD_PATH := "res://addons/cheddaboards/CheddaBoards.gd"

var _added_autoload := false


func _enter_tree() -> void:
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		# Already registered (template project or manual drop-in setup).
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	_added_autoload = true


func _exit_tree() -> void:
	if _added_autoload and ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
		_added_autoload = false
