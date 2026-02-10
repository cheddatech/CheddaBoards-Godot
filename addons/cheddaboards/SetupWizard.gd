@tool
extends EditorScript

# CheddaBoards Ultimate Setup Wizard v2.6
# Run via: File → Run (or Ctrl+Shift+X)
# Performs all checks, auto-fixes, AND interactive configuration!
#
# v2.6 Changes:
# - Updated file paths for v1.7.0 folder structure (scenes/, scripts/, autoloads/)
# - Added MobileUI autoload check
# - Achievements autoload now at res://autoloads/Achievements.gd
# - OAuth is now built-in (no developer setup required)
#
# v2.5 Changes:
# - API Key now syncs to BOTH CheddaBoards.gd AND template.html
#
# v2.4 Changes:
# - Added Google Client ID configuration
# - Added Apple Service ID and Redirect URI configuration
# - All OAuth credentials sync to template.html

const TEMPLATE_HTML_PATH = "res://template.html"
const PROJECT_GODOT_PATH = "res://project.godot"
const ADDON_PATH = "res://addons/cheddaboards/"
const CHEDDABOARDS_GD_PATH = "res://addons/cheddaboards/CheddaBoards.gd"
const AUTOLOADS_PATH = "res://autoloads/"

# Track issues for summary
var warnings: Array[String] = []
var errors: Array[String] = []
var fixes_applied: Array[String] = []

func _run():
	warnings.clear()
	errors.clear()
	fixes_applied.clear()
	
	_print_header()
	
	# Run all checks
	_check_godot_version()
	_check_autoloads()
	_check_required_files()
	_check_api_key()
	_check_game_id_sync()
	_check_oauth_config()
	_check_cheddaboards_config()
	_check_project_settings()
	_check_export_preset()
	_check_template_html()
	
	# Print summary
	_print_summary()
	
	# Interactive configuration (Game ID + API Key)
	_interactive_config()
	
	# Print next steps
	_print_next_steps()

# ============================================================
# HEADER & SUMMARY
# ============================================================

func _print_header():
	print("")
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║         🧀 CheddaBoards Ultimate Setup Wizard v2.6          ║")
	print("║                                                              ║")
	print("║  Automated checks • Auto-fixes • Configuration validation   ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	print("")

func _print_summary():
	print("")
	print("═══════════════════════════════════════════════════════════════")
	print("                        📊 SUMMARY")
	print("═══════════════════════════════════════════════════════════════")
	
	if fixes_applied.size() > 0:
		print("")
		print("🔧 Auto-Fixes Applied (%d):" % fixes_applied.size())
		for fix in fixes_applied:
			print("   • %s" % fix)
	
	if warnings.size() > 0:
		print("")
		print("⚠️  Warnings (%d):" % warnings.size())
		for warning in warnings:
			print("   • %s" % warning)
	
	if errors.size() > 0:
		print("")
		print("❌ Errors (%d):" % errors.size())
		for error in errors:
			print("   • %s" % error)
	
	print("")
	if errors.size() == 0 and warnings.size() == 0:
		print("✅ All checks passed! Your project is ready.")
	elif errors.size() == 0:
		print("✅ Setup complete with %d warning(s) - project should work!" % warnings.size())
	else:
		print("❌ Setup has %d error(s) that need attention." % errors.size())

func _print_next_steps():
	print("")
	print("═══════════════════════════════════════════════════════════════")
	print("                      📋 NEXT STEPS")
	print("═══════════════════════════════════════════════════════════════")
	print("")
	print("  1. Register at https://cheddaboards.com/dashboard")
	print("     • Sign in with Google, Apple, or Internet Identity")
	print("     • Create a game → Get your Game ID")
	print("     • Generate API Key → Get your API Key")
	print("")
	print("  2. Run this wizard again to enter your credentials")
	print("     • Game ID updates BOTH template.html and CheddaBoards.gd")
	print("     • API Key updates BOTH template.html and CheddaBoards.gd")
	print("")
	print("  3. Export & Test:")
	print("     • Web: Project → Export → Web → Export Project")
	print("       - Google/Apple Sign-In works out of the box")
	print("     • Native: Just export! API key handles auth")
	print("")
	print("  4. Test locally (web):")
	print("     • cd to export folder")
	print("     • python3 -m http.server 8000")
	print("     • Open http://localhost:8000")
	print("")
	print("")
	print("  🧀 Dashboard: https://cheddaboards.com/dashboard")
	print("")

# ============================================================
# CHECKS
# ============================================================

func _check_godot_version():
	_print_section("Godot Version")
	
	var version = Engine.get_version_info()
	var major = version.major
	var minor = version.minor
	var patch = version.patch
	
	if major >= 4:
		print("   ✅ Godot %d.%d.%d - Compatible" % [major, minor, patch])
	else:
		print("   ❌ Godot %d.%d.%d - Requires Godot 4+" % [major, minor, patch])
		errors.append("Godot version too old - requires 4.x")

func _check_autoloads():
	_print_section("Autoloads")
	
	var required_autoloads = {
		"CheddaBoards": ADDON_PATH + "CheddaBoards.gd",
		"Achievements": AUTOLOADS_PATH + "Achievements.gd",
		"MobileUI": AUTOLOADS_PATH + "MobileUI.gd",
	}
	
	for autoload_name in required_autoloads.keys():
		var expected_path = required_autoloads[autoload_name]
		
		if ProjectSettings.has_setting("autoload/" + autoload_name):
			var current_path = ProjectSettings.get_setting("autoload/" + autoload_name)
			if current_path.begins_with("*"):
				current_path = current_path.substr(1)
			
			if current_path == expected_path:
				print("   ✅ %s → %s" % [autoload_name, expected_path])
			else:
				print("   ⚠️  %s path mismatch (found: %s)" % [autoload_name, current_path])
				print("      → Expected: %s" % expected_path)
				warnings.append("%s autoload has unexpected path" % autoload_name)
		else:
			# Auto-fix: Add missing autoload
			if FileAccess.file_exists(expected_path):
				ProjectSettings.set_setting("autoload/" + autoload_name, "*" + expected_path)
				ProjectSettings.save()
				print("   🔧 %s → Added automatically" % autoload_name)
				fixes_applied.append("Added %s autoload" % autoload_name)
			else:
				print("   ❌ %s missing (file not found: %s)" % [autoload_name, expected_path])
				errors.append("%s autoload missing and file not found" % autoload_name)

func _check_required_files():
	_print_section("Required Files")
	
	var required_files = {
		ADDON_PATH + "CheddaBoards.gd": "Core SDK",
		AUTOLOADS_PATH + "Achievements.gd": "Achievements system",
		AUTOLOADS_PATH + "MobileUI.gd": "Mobile scaling",
		"res://scenes/MainMenu.tscn": "Main menu scene",
		"res://scripts/MainMenu.gd": "Main menu script",
		"res://scenes/Game.tscn": "Game wrapper scene",
		"res://scripts/Game.gd": "Game wrapper script",
		"res://scenes/Leaderboard.tscn": "Leaderboard scene",
		"res://scripts/Leaderboard.gd": "Leaderboard script",
		"res://scenes/AchievementsView.tscn": "Achievements view",
		"res://template.html": "Web export template",
	}
	
	var optional_files = {
		"res://scenes/AchievementNotification.tscn": "Achievement popups",
		"res://scripts/AchievementNotification.gd": "Achievement popup script",
		ADDON_PATH + "plugin.cfg": "Plugin configuration",
		ADDON_PATH + "icon.png": "Plugin icon",
	}
	
	for file_path in required_files.keys():
		var desc = required_files[file_path]
		if FileAccess.file_exists(file_path):
			print("   ✅ %s (%s)" % [file_path.get_file(), desc])
		else:
			print("   ❌ %s - MISSING (%s)" % [file_path, desc])
			errors.append("Missing required file: %s" % file_path)
	
	# Check optional files
	var has_optional = false
	for file_path in optional_files.keys():
		if FileAccess.file_exists(file_path):
			if not has_optional:
				print("   ── Optional ──")
				has_optional = true
			print("   ✅ %s" % file_path.get_file())

func _check_api_key():
	_print_section("API Key Sync Check")
	
	var gd_api_key = _get_current_api_key()
	var template_api_key = _get_template_api_key()
	
	print("   Native (CheddaBoards.gd): %s" % ("Not set" if gd_api_key.is_empty() else gd_api_key.substr(0, min(15, gd_api_key.length())) + "***"))
	print("   Web (template.html):      %s" % ("Not set" if template_api_key.is_empty() else template_api_key.substr(0, min(15, template_api_key.length())) + "***"))
	
	if gd_api_key.is_empty() and template_api_key.is_empty():
		print("   ⚠️  API Key not set in either file")
		print("      → Required for native builds and play sessions")
		print("      → Get one at cheddaboards.com/dashboard")
		warnings.append("API Key not set - required for native/anonymous play")
	elif gd_api_key != template_api_key:
		print("   ⚠️  API Key mismatch between files!")
		print("      → Run wizard to sync them")
		warnings.append("API Key mismatch: files have different keys")
	elif gd_api_key.begins_with("cb_"):
		print("   ✅ API Keys match and configured")
	else:
		print("   ⚠️  API Key format looks wrong (should start with cb_)")
		warnings.append("API Key format may be incorrect")

func _check_game_id_sync():
	_print_section("Game ID Sync Check")
	
	var web_game_id = _get_current_game_id()
	var native_game_id = _get_native_game_id()
	
	print("   Web (template.html):    '%s'" % web_game_id)
	print("   Native (CheddaBoards.gd): '%s'" % native_game_id)
	
	if web_game_id.is_empty() and native_game_id.is_empty():
		print("   ❌ No Game ID configured!")
		errors.append("Game ID not set in either file")
	elif web_game_id != native_game_id:
		print("   ❌ MISMATCH! Web and native using different games!")
		print("      → Run wizard to sync them")
		errors.append("Game ID mismatch: web='%s' vs native='%s'" % [web_game_id, native_game_id])
	elif web_game_id == "catch-the-cheese" or web_game_id == "test-game":
		print("   ⚠️  Using default/test Game ID")
		print("      → Create your own at cheddaboards.com/dashboard")
		warnings.append("Using default Game ID - create your own for production")
	else:
		print("   ✅ Game IDs match: '%s'" % web_game_id)

func _check_oauth_config():
	_print_section("OAuth Configuration")
	
	print("   ✅ Google & Apple Sign-In are built into CheddaBoards")
	print("      No developer OAuth setup required")
	print("      Works automatically on web exports")

func _check_cheddaboards_config():
	_print_section("CheddaBoards.gd Configuration")
	
	var cb_path = ADDON_PATH + "CheddaBoards.gd"
	if not FileAccess.file_exists(cb_path):
		print("   ❌ CheddaBoards.gd not found at %s" % cb_path)
		return
	
	var file = FileAccess.open(cb_path, FileAccess.READ)
	if not file:
		print("   ❌ Could not read CheddaBoards.gd")
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Check for key configurations
	var checks = {
		"sdk_ready": "SDK ready signal",
		"login_success": "Login success signal",
		"profile_loaded": "Profile loaded signal",
		"is_authenticated": "Auth check function",
		"get_cached_profile": "Profile cache function",
	}
	
	for check_str in checks.keys():
		if check_str in content:
			print("   ✅ %s found" % checks[check_str])
		else:
			print("   ⚠️  %s not found" % checks[check_str])
			warnings.append("CheddaBoards.gd may be missing: %s" % checks[check_str])

func _check_project_settings():
	_print_section("Project Settings")
	
	# Stretch mode
	var stretch_mode = ProjectSettings.get_setting("display/window/stretch/mode", "disabled")
	if stretch_mode in ["canvas_items", "viewport"]:
		print("   ✅ Stretch mode: %s" % stretch_mode)
	else:
		print("   ⚠️  Stretch mode: %s (recommend 'canvas_items')" % stretch_mode)
		warnings.append("Stretch mode '%s' may cause UI scaling issues" % stretch_mode)
	
	# Viewport size
	var width = ProjectSettings.get_setting("display/window/size/viewport_width", 1152)
	var height = ProjectSettings.get_setting("display/window/size/viewport_height", 648)
	print("   ℹ️  Viewport: %d × %d" % [width, height])
	
	# Check if main scene is set
	var main_scene = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene != "":
		print("   ✅ Main scene: %s" % main_scene.get_file())
	else:
		print("   ⚠️  No main scene set")
		warnings.append("No main scene configured")

func _check_export_preset():
	_print_section("Export Configuration")
	
	if FileAccess.file_exists("res://export_presets.cfg"):
		var file = FileAccess.open("res://export_presets.cfg", FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			
			if "Web" in content or "HTML5" in content:
				print("   ✅ Web export preset found")
				
				# Check for custom template
				if "custom_template" in content and "template.html" in content:
					print("   ✅ Custom template.html configured")
				else:
					print("   ⚠️  Custom template may not be configured")
					print("      → In Export settings, set Custom HTML Shell to template.html")
					warnings.append("Custom HTML template may not be set in export preset")
			else:
				print("   ⚠️  No Web export preset found")
				warnings.append("No Web export preset - add via Project → Export → Add → Web")
		else:
			print("   ⚠️  Could not read export_presets.cfg")
	else:
		print("   ⚠️  No export presets configured")
		print("      → Project → Export → Add → Web")
		warnings.append("No export presets - configure via Project → Export")

func _check_template_html():
	_print_section("Template.html (Web Game ID)")
	
	if not FileAccess.file_exists(TEMPLATE_HTML_PATH):
		print("   ❌ template.html not found")
		errors.append("template.html missing - required for web export")
		return
	
	var file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.READ)
	if not file:
		print("   ❌ Could not read template.html")
		errors.append("Could not read template.html")
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Extract Game ID
	var regex = RegEx.new()
	regex.compile("GAME_ID:\\s*['\"]([^'\"]+)['\"]")
	var result = regex.search(content)
	
	if result:
		var game_id = result.get_string(1)
		
		if game_id == "catch-the-cheese" or game_id == "test-game":
			print("   ⚠️  Using default Game ID: '%s'" % game_id)
			print("      → This works for testing!")
			print("      → For production, create your own at cheddaboards.com")
		elif game_id.is_empty():
			print("   ❌ Game ID is empty")
			errors.append("Game ID is empty in template.html")
		else:
			print("   ✅ Custom Game ID: '%s'" % game_id)
	else:
		print("   ❌ Could not find GAME_ID in template.html")
		errors.append("GAME_ID not found in template.html")
	
	# Check for SDK script inclusion
	if "cheddaboards" in content.to_lower():
		print("   ✅ CheddaBoards SDK script included")
	else:
		print("   ⚠️  SDK script tag may be missing")
		warnings.append("CheddaBoards SDK script may not be included in template.html")

# ============================================================
# HELPERS
# ============================================================

func _print_section(title: String):
	print("")
	print("┌─ %s" % title)
	print("│")

# ============================================================
# INTERACTIVE CONFIGURATION (Game ID + API Key)
# ============================================================

func _interactive_config():
	"""Interactive configuration via popup"""
	var web_game_id = _get_current_game_id()
	var native_game_id = _get_native_game_id()
	var gd_api_key = _get_current_api_key()
	var template_api_key = _get_template_api_key()
	
	# Use whichever game_id is set (prefer non-default)
	var current_game_id = web_game_id
	if web_game_id in ["catch-the-cheese", "test-game", ""] and native_game_id not in ["catch-the-cheese", "test-game", ""]:
		current_game_id = native_game_id
	elif native_game_id not in ["catch-the-cheese", "test-game", ""] and web_game_id != native_game_id:
		current_game_id = native_game_id
	
	# Use whichever API key is set (prefer non-empty)
	var current_api_key = gd_api_key if not gd_api_key.is_empty() else template_api_key
	
	# Show current config
	print("")
	print("═══════════════════════════════════════════════════════════════")
	print("                    🎮 CONFIGURATION")
	print("═══════════════════════════════════════════════════════════════")
	print("")
	print("   Game ID (syncs to BOTH files):")
	print("      Web (template.html):     '%s'" % web_game_id)
	print("      Native (CheddaBoards.gd): '%s'" % native_game_id)
	if web_game_id != native_game_id:
		print("      ⚠️  MISMATCH - will sync on save!")
	print("")
	print("   API Key (syncs to BOTH files):")
	print("      Native (CheddaBoards.gd): %s" % ("Not set" if gd_api_key.is_empty() else gd_api_key.substr(0, min(15, gd_api_key.length())) + "***"))
	print("      Web (template.html):      %s" % ("Not set" if template_api_key.is_empty() else template_api_key.substr(0, min(15, template_api_key.length())) + "***"))
	if gd_api_key != template_api_key:
		print("      ⚠️  MISMATCH - will sync on save!")
	print("")
	print("   OAuth: Built-in (Google & Apple work automatically on web)")
	print("")
	
	# Show popup to edit
	_show_config_dialog(current_game_id, current_api_key, web_game_id, native_game_id, gd_api_key, template_api_key)

func _show_config_dialog(current_game_id: String, current_api_key: String, web_game_id: String, native_game_id: String, gd_api_key: String, template_api_key: String):
	"""Show a dialog to edit Game ID and API Key"""
	var editor = get_editor_interface()
	var base_control = editor.get_base_control()
	
	# Create dialog
	var dialog = AcceptDialog.new()
	dialog.title = "🧀 CheddaBoards Configuration"
	dialog.dialog_hide_on_ok = false
	
	# Create scroll container
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	# Create content
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# === GAME ID SECTION ===
	var game_id_header = Label.new()
	game_id_header.text = "🎮 Game ID (syncs to BOTH web & native)"
	game_id_header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(game_id_header)
	
	var game_id_current = Label.new()
	if web_game_id == native_game_id:
		game_id_current.text = "Current: %s" % current_game_id
		if current_game_id in ["catch-the-cheese", "test-game"]:
			game_id_current.text += " (default)"
	else:
		game_id_current.text = "⚠️ MISMATCH! Web: '%s' / Native: '%s'" % [web_game_id, native_game_id]
		game_id_current.add_theme_color_override("font_color", Color.ORANGE)
	game_id_current.add_theme_font_size_override("font_size", 11)
	game_id_current.modulate = Color(0.7, 0.7, 0.7) if web_game_id == native_game_id else Color.WHITE
	vbox.add_child(game_id_current)
	
	var game_id_input = LineEdit.new()
	game_id_input.text = current_game_id
	game_id_input.placeholder_text = "my-game-id"
	vbox.add_child(game_id_input)
	
	# Spacer
	vbox.add_child(_create_spacer(15))
	
	# === API KEY SECTION ===
	var api_key_header = Label.new()
	api_key_header.text = "🔑 API Key (syncs to BOTH web & native)"
	api_key_header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(api_key_header)
	
	var api_key_current = Label.new()
	if gd_api_key == template_api_key:
		if current_api_key.is_empty():
			api_key_current.text = "Current: Not set"
		else:
			api_key_current.text = "Current: %s***" % current_api_key.substr(0, min(15, current_api_key.length()))
	else:
		api_key_current.text = "⚠️ MISMATCH! Will sync on save"
		api_key_current.add_theme_color_override("font_color", Color.ORANGE)
	api_key_current.add_theme_font_size_override("font_size", 11)
	api_key_current.modulate = Color(0.7, 0.7, 0.7) if gd_api_key == template_api_key else Color.WHITE
	vbox.add_child(api_key_current)
	
	var api_key_input = LineEdit.new()
	api_key_input.text = current_api_key
	api_key_input.placeholder_text = "cb_your-game_xxxxxxxxx"
	vbox.add_child(api_key_input)
	
	# Spacer
	vbox.add_child(_create_spacer(20))
	
	# === OAUTH INFO ===
	var oauth_info = Label.new()
	oauth_info.text = "✅ OAuth: Google & Apple Sign-In are built-in\n   No setup required — works automatically on web exports"
	oauth_info.add_theme_font_size_override("font_size", 11)
	oauth_info.modulate = Color(0.6, 0.8, 0.6)
	vbox.add_child(oauth_info)
	
	# Spacer
	vbox.add_child(_create_spacer(15))
	
	# Help text
	var help = Label.new()
	help.text = "💡 Get Game ID & API Key at cheddaboards.com/dashboard"
	help.add_theme_font_size_override("font_size", 11)
	help.modulate = Color(0.6, 0.8, 0.6)
	vbox.add_child(help)
	
	# Status label for errors
	var status = Label.new()
	status.text = ""
	status.add_theme_color_override("font_color", Color.RED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status)
	
	scroll.add_child(vbox)
	dialog.add_child(scroll)
	
	# Add cancel button
	dialog.add_cancel_button("Cancel")
	dialog.ok_button_text = "Save"
	
	# Handle OK pressed
	dialog.confirmed.connect(func():
		var new_game_id = game_id_input.text.strip_edges()
		var new_api_key = api_key_input.text.strip_edges()
		
		var had_error = false
		var changes_made = false
		
		# Validate Game ID
		if not new_game_id.is_empty():
			if " " in new_game_id:
				status.text = "❌ Game ID: No spaces allowed"
				had_error = true
			else:
				var valid_chars = RegEx.new()
				valid_chars.compile("^[a-zA-Z0-9_-]+$")
				if not valid_chars.search(new_game_id):
					status.text = "❌ Game ID: Only letters, numbers, - and _ allowed"
					had_error = true
		else:
			status.text = "❌ Game ID cannot be empty"
			had_error = true
		
		# Validate API Key format (if provided)
		if not had_error and not new_api_key.is_empty() and not new_api_key.begins_with("cb_"):
			status.text = "❌ API Key should start with 'cb_'"
			had_error = true
		
		# Save Game ID to BOTH files if valid and changed
		if not had_error:
			# Update template.html Game ID
			if new_game_id != web_game_id:
				if _set_game_id(new_game_id):
					changes_made = true
				else:
					status.text = "❌ Failed to save Game ID to template.html"
					had_error = true
			
			# Update CheddaBoards.gd Game ID
			if not had_error and new_game_id != native_game_id:
				if _set_native_game_id(new_game_id):
					changes_made = true
				else:
					status.text = "❌ Failed to save Game ID to CheddaBoards.gd"
					had_error = true
		
		# Save API Key to BOTH files
		if not had_error:
			# Update CheddaBoards.gd API Key
			if new_api_key != gd_api_key:
				if _set_api_key(new_api_key):
					changes_made = true
				else:
					status.text = "❌ Failed to save API Key to CheddaBoards.gd"
					had_error = true
			
			# Update template.html API Key
			if not had_error and new_api_key != template_api_key:
				if _set_template_api_key(new_api_key):
					changes_made = true
				else:
					status.text = "❌ Failed to save API Key to template.html"
					had_error = true
		
		if not had_error:
			dialog.hide()
			dialog.queue_free()
			if changes_made:
				print("   ✅ Configuration saved!")
				print("")
				print("   ⚠️  IMPORTANT: Restart Godot for changes to take effect!")
				print("")
			else:
				print("   ℹ️  No changes made")
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
		print("   ℹ️  Configuration unchanged")
	)
	
	base_control.add_child(dialog)
	dialog.popup_centered()
	game_id_input.grab_focus()

func _create_spacer(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

# ============================================================
# GAME ID FUNCTIONS - WEB (template.html)
# ============================================================

func _get_current_game_id() -> String:
	"""Extract current Game ID from template.html"""
	if not FileAccess.file_exists(TEMPLATE_HTML_PATH):
		return ""
	
	var file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.READ)
	if not file:
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile("GAME_ID:\\s*['\"]([^'\"]+)['\"]")
	var result = regex.search(content)
	
	return result.get_string(1) if result else ""

func _set_game_id(new_game_id: String) -> bool:
	"""Update Game ID in template.html"""
	new_game_id = new_game_id.strip_edges()
	
	if not FileAccess.file_exists(TEMPLATE_HTML_PATH):
		print("   ❌ template.html not found")
		return false
	
	var file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.READ)
	if not file:
		print("   ❌ Could not read template.html")
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile("GAME_ID:\\s*['\"]([^'\"]+)['\"]")
	var new_content = regex.sub(content, "GAME_ID: '%s'" % new_game_id)
	
	if new_content == content:
		print("   ⚠️  Could not find GAME_ID to replace in template.html")
		return false
	
	file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.WRITE)
	if not file:
		print("   ❌ Could not write to template.html")
		return false
	
	file.store_string(new_content)
	file.close()
	
	print("   ✅ Web Game ID updated: %s" % new_game_id)
	return true

# ============================================================
# GAME ID FUNCTIONS - NATIVE (CheddaBoards.gd)
# ============================================================

func _get_native_game_id() -> String:
	"""Extract current Game ID from CheddaBoards.gd (for native builds)"""
	if not FileAccess.file_exists(CHEDDABOARDS_GD_PATH):
		return ""
	
	var file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.READ)
	if not file:
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile('(?:var\\s+game_id|const\\s+GAME_ID)[^=]*=\\s*["\']([^"\']*)["\']')
	var result = regex.search(content)
	
	return result.get_string(1) if result else ""

func _set_native_game_id(new_game_id: String) -> bool:
	"""Update Game ID in CheddaBoards.gd (for native builds)"""
	new_game_id = new_game_id.strip_edges()
	
	if not FileAccess.file_exists(CHEDDABOARDS_GD_PATH):
		print("   ❌ CheddaBoards.gd not found")
		return false
	
	var file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.READ)
	if not file:
		print("   ❌ Could not read CheddaBoards.gd")
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile('(var\\s+game_id[^=]*=\\s*)["\'][^"\']*["\']')
	var new_content = regex.sub(content, '$1"%s"' % new_game_id)
	
	if new_content == content:
		regex.compile('(const\\s+GAME_ID[^=]*=\\s*)["\'][^"\']*["\']')
		new_content = regex.sub(content, '$1"%s"' % new_game_id)
	
	if new_content == content:
		print("   ⚠️  Could not find game_id to replace in CheddaBoards.gd")
		return false
	
	file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.WRITE)
	if not file:
		print("   ❌ Could not write to CheddaBoards.gd")
		return false
	
	file.store_string(new_content)
	file.close()
	
	print("   ✅ Native Game ID updated: %s" % new_game_id)
	return true

# ============================================================
# API KEY FUNCTIONS - NATIVE (CheddaBoards.gd)
# ============================================================

func _get_current_api_key() -> String:
	"""Extract current API Key from CheddaBoards.gd"""
	if not FileAccess.file_exists(CHEDDABOARDS_GD_PATH):
		return ""
	
	var file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.READ)
	if not file:
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile('var\\s+api_key[^=]*=\\s*["\']([^"\']*)["\']')
	var result = regex.search(content)
	
	return result.get_string(1) if result else ""

func _set_api_key(new_api_key: String) -> bool:
	"""Update API Key in CheddaBoards.gd"""
	new_api_key = new_api_key.strip_edges()
	
	if not FileAccess.file_exists(CHEDDABOARDS_GD_PATH):
		print("   ❌ CheddaBoards.gd not found")
		return false
	
	var file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.READ)
	if not file:
		print("   ❌ Could not read CheddaBoards.gd")
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile('(var\\s+api_key[^=]*=\\s*)["\'][^"\']*["\']')
	var new_content = regex.sub(content, '$1"%s"' % new_api_key)
	
	if new_content == content:
		print("   ⚠️  Could not find api_key to replace in CheddaBoards.gd")
		return false
	
	file = FileAccess.open(CHEDDABOARDS_GD_PATH, FileAccess.WRITE)
	if not file:
		print("   ❌ Could not write to CheddaBoards.gd")
		return false
	
	file.store_string(new_content)
	file.close()
	
	if new_api_key.is_empty():
		print("   ✅ Native API Key cleared")
	else:
		print("   ✅ Native API Key updated: %s***" % new_api_key.substr(0, min(15, new_api_key.length())))
	return true

# ============================================================
# API KEY FUNCTIONS - WEB (template.html)
# ============================================================

func _get_template_api_key() -> String:
	"""Extract API Key from template.html"""
	if not FileAccess.file_exists(TEMPLATE_HTML_PATH):
		return ""
	
	var file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.READ)
	if not file:
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile("API_KEY:\\s*['\"]([^'\"]*)['\"]")
	var result = regex.search(content)
	
	return result.get_string(1) if result else ""

func _set_template_api_key(new_api_key: String) -> bool:
	"""Update API Key in template.html"""
	new_api_key = new_api_key.strip_edges()
	
	if not FileAccess.file_exists(TEMPLATE_HTML_PATH):
		print("   ❌ template.html not found")
		return false
	
	var file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.READ)
	if not file:
		print("   ❌ Could not read template.html")
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile("API_KEY:\\s*['\"][^'\"]*['\"]")
	var new_content = regex.sub(content, "API_KEY: '%s'" % new_api_key)
	
	if new_content == content:
		print("   ⚠️  Could not find API_KEY to replace in template.html")
		return false
	
	file = FileAccess.open(TEMPLATE_HTML_PATH, FileAccess.WRITE)
	if not file:
		print("   ❌ Could not write to template.html")
		return false
	
	file.store_string(new_content)
	file.close()
	
	if new_api_key.is_empty():
		print("   ✅ Web API Key cleared")
	else:
		print("   ✅ Web API Key updated: %s***" % new_api_key.substr(0, min(15, new_api_key.length())))
	return true

# ============================================================
# UTILITY FUNCTIONS (Can be called from other scripts)
# ============================================================

func fix_autoloads() -> Array[String]:
	"""Fix missing autoloads - returns list of fixed items"""
	var fixed: Array[String] = []
	
	var autoloads = {
		"CheddaBoards": ADDON_PATH + "CheddaBoards.gd",
		"Achievements": AUTOLOADS_PATH + "Achievements.gd",
		"MobileUI": AUTOLOADS_PATH + "MobileUI.gd",
	}
	
	for autoload_name in autoloads.keys():
		var path = autoloads[autoload_name]
		if not ProjectSettings.has_setting("autoload/" + autoload_name):
			if FileAccess.file_exists(path):
				ProjectSettings.set_setting("autoload/" + autoload_name, "*" + path)
				fixed.append(autoload_name)
	
	if fixed.size() > 0:
		ProjectSettings.save()
	
	return fixed

func get_project_status() -> Dictionary:
	"""Get quick status of project setup"""
	var web_game_id = _get_current_game_id()
	var native_game_id = _get_native_game_id()
	var gd_api_key = _get_current_api_key()
	var template_api_key = _get_template_api_key()
	
	return {
		"has_cheddaboards_autoload": ProjectSettings.has_setting("autoload/CheddaBoards"),
		"has_achievements_autoload": ProjectSettings.has_setting("autoload/Achievements"),
		"has_mobileui_autoload": ProjectSettings.has_setting("autoload/MobileUI"),
		"has_template_html": FileAccess.file_exists(TEMPLATE_HTML_PATH),
		"has_cheddaboards_gd": FileAccess.file_exists(ADDON_PATH + "CheddaBoards.gd"),
		"has_export_preset": FileAccess.file_exists("res://export_presets.cfg"),
		"web_game_id": web_game_id,
		"native_game_id": native_game_id,
		"game_ids_match": web_game_id == native_game_id,
		"gd_api_key": gd_api_key,
		"template_api_key": template_api_key,
		"api_keys_match": gd_api_key == template_api_key,
		"using_default_game_id": web_game_id in ["catch-the-cheese", "test-game"],
		"has_api_key": not gd_api_key.is_empty() or not template_api_key.is_empty(),
	}

func is_ready_to_export() -> bool:
	"""Check if project is ready for web export"""
	var status = get_project_status()
	return (
		status.has_cheddaboards_autoload and
		status.has_achievements_autoload and
		status.has_mobileui_autoload and
		status.has_template_html and
		status.has_cheddaboards_gd and
		status.has_export_preset and
		not status.web_game_id.is_empty() and
		status.game_ids_match and
		status.api_keys_match
	)

func is_ready_for_native() -> bool:
	"""Check if project is ready for native export"""
	var status = get_project_status()
	return (
		status.has_cheddaboards_autoload and
		status.has_cheddaboards_gd and
		status.has_api_key and
		not status.native_game_id.is_empty()
	)
