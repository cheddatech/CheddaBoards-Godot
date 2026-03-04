@tool
extends EditorScript

# CheddaBoards Setup Wizard v2.0
# Run via: File → Run (or Ctrl+Shift+X)
#
# What it does:
#   1. Checks & auto-fixes autoloads (CheddaBoards, Achievements, MobileUI)
#   2. Prompts for API Key (cb_gamename_xxxxx format)
#   3. Auto-extracts Game ID from the API Key
#   4. Syncs API Key + Game ID to BOTH CheddaBoards.gd AND template.html

const TEMPLATE_HTML_PATH = "res://template.html"
const ADDON_PATH = "res://addons/cheddaboards/"
const CHEDDABOARDS_GD_PATH = "res://addons/cheddaboards/CheddaBoards.gd"
const AUTOLOADS_PATH = "res://autoloads/"

var fixes_applied: Array[String] = []
var errors: Array[String] = []

func _run():
	fixes_applied.clear()
	errors.clear()
	
	print("")
	print("╔════════════════════════════════════════════════╗")
	print("║       🧀 CheddaBoards Setup Wizard v2.0       ║")
	print("╚════════════════════════════════════════════════╝")
	print("")
	
	_fix_autoloads()
	_print_status()
	_show_api_key_dialog()


# ============================================================
# AUTOLOADS
# ============================================================

func _fix_autoloads():
	print("┌─ Autoloads")
	print("│")
	
	var required = {
		"CheddaBoards": ADDON_PATH + "CheddaBoards.gd",
		"Achievements": AUTOLOADS_PATH + "Achievements.gd",
		"MobileUI": AUTOLOADS_PATH + "MobileUI.gd",
	}
	
	var needs_save = false
	
	for autoload_name in required.keys():
		var expected_path = required[autoload_name]
		
		if ProjectSettings.has_setting("autoload/" + autoload_name):
			var current_path = ProjectSettings.get_setting("autoload/" + autoload_name)
			if current_path.begins_with("*"):
				current_path = current_path.substr(1)
			
			if current_path == expected_path:
				print("   ✅ %s" % autoload_name)
			else:
				print("   ⚠️  %s → wrong path (%s), fixing..." % [autoload_name, current_path])
				if FileAccess.file_exists(expected_path):
					ProjectSettings.set_setting("autoload/" + autoload_name, "*" + expected_path)
					needs_save = true
					fixes_applied.append("Fixed %s path" % autoload_name)
					print("   🔧 %s → fixed" % autoload_name)
				else:
					errors.append("%s file not found at %s" % [autoload_name, expected_path])
					print("   ❌ %s file missing: %s" % [autoload_name, expected_path])
		else:
			if FileAccess.file_exists(expected_path):
				ProjectSettings.set_setting("autoload/" + autoload_name, "*" + expected_path)
				needs_save = true
				fixes_applied.append("Added %s autoload" % autoload_name)
				print("   🔧 %s → added" % autoload_name)
			else:
				errors.append("%s missing (file not found)" % autoload_name)
				print("   ❌ %s → file not found: %s" % [autoload_name, expected_path])
	
	if needs_save:
		ProjectSettings.save()
	
	print("")


# ============================================================
# STATUS
# ============================================================

func _print_status():
	var gd_api_key = _get_gd_value("api_key")
	var gd_game_id = _get_gd_value("game_id", "GAME_ID")
	var template_api_key = _get_template_value("API_KEY")
	var template_game_id = _get_template_value("GAME_ID")
	
	print("┌─ Current Configuration")
	print("│")
	print("   CheddaBoards.gd:")
	print("      API Key:  %s" % _mask(gd_api_key))
	print("      Game ID:  %s" % ("Not set" if gd_game_id.is_empty() else "'%s'" % gd_game_id))
	print("   template.html:")
	print("      API Key:  %s" % _mask(template_api_key))
	print("      Game ID:  %s" % ("Not set" if template_game_id.is_empty() else "'%s'" % template_game_id))
	
	if not gd_api_key.is_empty() and gd_api_key == template_api_key and gd_game_id == template_game_id:
		print("   ✅ Files in sync")
	elif gd_api_key != template_api_key or gd_game_id != template_game_id:
		print("   ⚠️  Files out of sync — enter API Key to fix")
	
	print("")


# ============================================================
# API KEY DIALOG
# ============================================================

func _show_api_key_dialog():
	var editor = get_editor_interface()
	var base_control = editor.get_base_control()
	
	var current_key = _get_gd_value("api_key")
	if current_key.is_empty():
		current_key = _get_template_value("API_KEY")
	
	# Dialog
	var dialog = AcceptDialog.new()
	dialog.title = "🧀 CheddaBoards Setup"
	dialog.dialog_hide_on_ok = false
	dialog.ok_button_text = "Save"
	dialog.add_cancel_button("Cancel")
	
	# Layout
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(480, 0)
	
	# Header
	var header = Label.new()
	header.text = "Enter your API Key from cheddaboards.com/dashboard"
	header.add_theme_font_size_override("font_size", 13)
	vbox.add_child(header)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer1)
	
	# API Key input
	var key_label = Label.new()
	key_label.text = "🔑 API Key"
	key_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(key_label)
	
	var key_input = LineEdit.new()
	key_input.text = current_key
	key_input.placeholder_text = "cb_my-game-name_xxxxxxxxxx"
	vbox.add_child(key_input)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)
	
	# Game ID preview (auto-derived)
	var game_id_label = Label.new()
	game_id_label.text = "🎮 Game ID (auto-detected from API Key)"
	game_id_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(game_id_label)
	
	var game_id_preview = Label.new()
	game_id_preview.add_theme_font_size_override("font_size", 14)
	game_id_preview.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	vbox.add_child(game_id_preview)
	
	# Update preview as user types
	var _update_preview = func():
		var extracted = _extract_game_id(key_input.text.strip_edges())
		if extracted.is_empty():
			game_id_preview.text = "—"
			game_id_preview.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		else:
			game_id_preview.text = extracted
			game_id_preview.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	
	key_input.text_changed.connect(func(_new_text): _update_preview.call())
	_update_preview.call()
	
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer3)
	
	# Status / error label
	var status = Label.new()
	status.text = ""
	status.add_theme_color_override("font_color", Color.RED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status)
	
	dialog.add_child(vbox)
	
	# Save handler
	dialog.confirmed.connect(func():
		var api_key = key_input.text.strip_edges()
		
		# Validate
		if api_key.is_empty():
			status.text = "❌ API Key cannot be empty"
			return
		
		if not api_key.begins_with("cb_"):
			status.text = "❌ API Key must start with 'cb_'"
			return
		
		var game_id = _extract_game_id(api_key)
		if game_id.is_empty():
			status.text = "❌ Could not extract Game ID — expected format: cb_gamename_xxxxx"
			return
		
		# Write to both files
		var ok = true
		
		if not _set_gd_value("api_key", api_key):
			status.text = "❌ Failed to update API Key in CheddaBoards.gd"
			ok = false
		
		if ok and not _set_gd_value("game_id", api_key, game_id):
			# Try const GAME_ID too
			if not _set_gd_const("GAME_ID", game_id):
				status.text = "❌ Failed to update Game ID in CheddaBoards.gd"
				ok = false
		
		if ok and not _set_template_value("API_KEY", api_key):
			status.text = "❌ Failed to update API Key in template.html"
			ok = false
		
		if ok and not _set_template_value("GAME_ID", game_id):
			status.text = "❌ Failed to update Game ID in template.html"
			ok = false
		
		if ok:
			dialog.hide()
			dialog.queue_free()
			print("┌─ Configuration Saved")
			print("│")
			print("   ✅ API Key:  %s" % _mask(api_key))
			print("   ✅ Game ID:  %s" % game_id)
			print("   ✅ Synced to CheddaBoards.gd + template.html")
			print("")
			print("   ⚠️  Restart Godot for changes to take effect!")
			print("")
			
			if fixes_applied.size() > 0:
				print("   🔧 Auto-fixes applied: %s" % ", ".join(fixes_applied))
				print("")
			
			if errors.size() > 0:
				print("   ❌ Issues: %s" % ", ".join(errors))
				print("")
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
		print("   ℹ️  Setup cancelled — no changes made")
		print("")
	)
	
	base_control.add_child(dialog)
	dialog.popup_centered()
	key_input.grab_focus()


# ============================================================
# GAME ID EXTRACTION
# ============================================================

func _extract_game_id(api_key: String) -> String:
	"""Extract game name from cb_gamename_randomchars format"""
	if not api_key.begins_with("cb_"):
		return ""
	
	var without_prefix = api_key.substr(3)  # Remove "cb_"
	var last_underscore = without_prefix.rfind("_")
	
	if last_underscore <= 0:
		return ""
	
	return without_prefix.substr(0, last_underscore)


# ============================================================
# FILE READ/WRITE HELPERS
# ============================================================

func _get_gd_value(var_name: String, const_name: String = "") -> String:
	"""Read a var or const value from CheddaBoards.gd"""
	if not FileAccess.file_exists(CHEDDABOARDS_GD_PATH):
		return ""
	
	var file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.READ)
	if not file:
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile('var\\s+%s[^=]*=\\s*["\']([^"\']*)["\']' % var_name)
	var result = regex.search(content)
	
	if result:
		return result.get_string(1)
	
	# Try const version
	if not const_name.is_empty():
		regex.compile('const\\s+%s[^=]*=\\s*["\']([^"\']*)["\']' % const_name)
		result = regex.search(content)
		if result:
			return result.get_string(1)
	
	return ""


func _set_gd_value(var_name: String, _api_key: String, value: String = "") -> bool:
	"""Write a var value in CheddaBoards.gd"""
	if value.is_empty():
		value = _api_key
	
	if not FileAccess.file_exists(CHEDDABOARDS_GD_PATH):
		return false
	
	var file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile('(var\\s+%s[^=]*=\\s*)["\'][^"\']*["\']' % var_name)
	var new_content = regex.sub(content, '$1"%s"' % value)
	
	if new_content == content:
		return false
	
	file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_string(new_content)
	file.close()
	return true


func _set_gd_const(const_name: String, value: String) -> bool:
	"""Write a const value in CheddaBoards.gd"""
	if not FileAccess.file_exists(CHEDDABOARDS_GD_PATH):
		return false
	
	var file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile('(const\\s+%s[^=]*=\\s*)["\'][^"\']*["\']' % const_name)
	var new_content = regex.sub(content, '$1"%s"' % value)
	
	if new_content == content:
		return false
	
	file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_string(new_content)
	file.close()
	return true


func _get_template_value(key: String) -> String:
	"""Read a config value from template.html (KEY: 'value' format)"""
	if not FileAccess.file_exists(TEMPLATE_HTML_PATH):
		return ""
	
	var file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.READ)
	if not file:
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile("%s:\\s*['\"]([^'\"]*)['\"]" % key)
	var result = regex.search(content)
	
	return result.get_string(1) if result else ""


func _set_template_value(key: String, value: String) -> bool:
	"""Write a config value in template.html (KEY: 'value' format)"""
	if not FileAccess.file_exists(TEMPLATE_HTML_PATH):
		return false
	
	var file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.READ)
	if not file:
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile("%s:\\s*['\"][^'\"]*['\"]" % key)
	var new_content = regex.sub(content, "%s: '%s'" % [key, value])
	
	if new_content == content:
		return false
	
	file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.WRITE)
	if not file:
		return false
	
	file.store_string(new_content)
	file.close()
	return true


func _mask(value: String) -> String:
	"""Mask a value for display"""
	if value.is_empty():
		return "Not set"
	if value.length() <= 15:
		return value.substr(0, 5) + "***"
	return value.substr(0, 15) + "***"
