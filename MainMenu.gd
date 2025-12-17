# MainMenu.gd v1.3.0
# Main menu with authentication flow, profile display, and anonymous name entry
# - Login panel: PLAY NOW (with name entry), Leaderboard, and login buttons
# - Name entry panel: For anonymous players to set their display name
# - Main panel: Profile stats when logged in (Google/Apple/Chedda)
# https://github.com/cheddatech/CheddaBoards-Godot
#
# ============================================================
# SETUP
# ============================================================
# Required Autoloads:
#   - CheddaBoards
#   - Achievements (optional)
#
# Login Panel nodes needed:
#   - DirectPlayButton (play without login)
#   - LeaderboardButton (view leaderboard without login)
#   - GoogleButton, AppleButton, CheddaButton
#   - StatusLabel
#
# Name Entry Panel nodes needed:
#   - NameLineEdit, ConfirmNameButton, CancelNameButton
#   - NameStatusLabel
#
# Main Panel nodes needed:
#   - WelcomeLabel, ScoreLabel, StreakLabel, PlaysLabel
#   - PlayButton, LeaderboardButton, AchievementsButton
#   - ChangeNicknameButton, LogoutButton
#
# ============================================================

extends Control

# ============================================================
# CONFIGURATION
# ============================================================

const SCENE_GAME: String = "res://Game.tscn"
const SCENE_LEADERBOARD: String = "res://Leaderboard.tscn"
const SCENE_ACHIEVEMENTS: String = "res://AchievementsView.tscn"
const SCENE_SETTINGS: String = "res://Settings.tscn"

const UI_TIMEOUT_DURATION: float = 40.0
const PROFILE_TIMEOUT_DURATION: float = 10.0
const POLL_INTERVAL: float = 0.5
const MAX_PROFILE_LOAD_ATTEMPTS: int = 3
const MAX_POLL_ATTEMPTS: int = 15

const SAVE_FILE_PATH: String = "user://player_data.save"
const MIN_NAME_LENGTH: int = 2
const MAX_NAME_LENGTH: int = 16

# ============================================================
# NODE REFERENCES - LOGIN PANEL
# ============================================================

@onready var login_panel = $LoginPanel
@onready var direct_play_button = $LoginPanel/MarginContainer/VBoxContainer/DirectPlayButton
@onready var login_leaderboard_button = $LoginPanel/MarginContainer/VBoxContainer/LeaderboardButton
@onready var google_button = $LoginPanel/MarginContainer/VBoxContainer/GoogleButton
@onready var apple_button = $LoginPanel/MarginContainer/VBoxContainer/AppleButton
@onready var chedda_button = $LoginPanel/MarginContainer/VBoxContainer/CheddaButton
@onready var exit_button = $LoginPanel/MarginContainer/VBoxContainer/ExitButton
@onready var status_label = $LoginPanel/MarginContainer/VBoxContainer/StatusLabel

# ============================================================
# NODE REFERENCES - NAME ENTRY PANEL
# ============================================================

@onready var name_entry_panel = $NameEntryPanel
@onready var name_line_edit = $NameEntryPanel/MarginContainer/VBoxContainer/NameLineEdit
@onready var confirm_name_button = $NameEntryPanel/MarginContainer/VBoxContainer/ConfirmNameButton
@onready var cancel_name_button = $NameEntryPanel/MarginContainer/VBoxContainer/CancelNameButton
@onready var name_status_label = $NameEntryPanel/MarginContainer/VBoxContainer/NameStatusLabel

# ============================================================
# NODE REFERENCES - MAIN PANEL
# ============================================================

@onready var main_panel = $MainPanel
@onready var welcome_label = $MainPanel/MarginContainer/VBoxContainer/WelcomeLabel
@onready var score_label = $MainPanel/MarginContainer/VBoxContainer/StatsPanel/VBoxContainer/ScoreLabel
@onready var streak_label = $MainPanel/MarginContainer/VBoxContainer/StatsPanel/VBoxContainer/StreakLabel
@onready var plays_label = $MainPanel/MarginContainer/VBoxContainer/StatsPanel/VBoxContainer/PlaysLabel
@onready var play_button = $MainPanel/MarginContainer/VBoxContainer/PlayButton
@onready var change_nickname_button = $MainPanel/MarginContainer/VBoxContainer/ChangeNicknameButton
@onready var achievement_button = $MainPanel/MarginContainer/VBoxContainer/AchievementsButton
@onready var leaderboard_button = $MainPanel/MarginContainer/VBoxContainer/LeaderboardButton
@onready var settings_button = $MainPanel/MarginContainer/VBoxContainer/SettingsButton
@onready var logout_button = $MainPanel/MarginContainer/VBoxContainer/LogoutButton

# ============================================================
# STATE
# ============================================================

var is_logging_in: bool = false
var waiting_for_profile: bool = false
var profile_load_attempts: int = 0
var profile_poll_attempts: int = 0

# Anonymous player data
var anonymous_nickname: String = ""
var anonymous_player_id: String = ""

# ============================================================
# TIMERS
# ============================================================

var ui_timeout_timer: Timer = null
var profile_poll_timer: Timer = null
var profile_timeout_timer: Timer = null

# ============================================================
# DEBUG
# ============================================================

var debug_logging: bool = true
var state_history: Array = []

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# Generate anonymous player ID
	_setup_anonymous_player()
	
	# Load saved anonymous nickname
	_load_player_data()
	
	# Connect CheddaBoards signals
	CheddaBoards.sdk_ready.connect(_on_sdk_ready)
	CheddaBoards.login_success.connect(_on_login_success)
	CheddaBoards.login_failed.connect(_on_login_failed)
	CheddaBoards.login_timeout.connect(_on_login_timeout)
	CheddaBoards.profile_loaded.connect(_on_profile_loaded)
	CheddaBoards.no_profile.connect(_on_no_profile)
	CheddaBoards.logout_success.connect(_on_logout_success)
	CheddaBoards.nickname_changed.connect(_on_nickname_changed)
	
	# Connect LOGIN PANEL buttons
	if direct_play_button:
		direct_play_button.pressed.connect(_on_direct_play_pressed)
	if login_leaderboard_button:
		login_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	if google_button:
		google_button.pressed.connect(_on_google_button_pressed)
	if apple_button:
		apple_button.pressed.connect(_on_apple_button_pressed)
	if chedda_button:
		chedda_button.pressed.connect(_on_chedda_button_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)
	
	# Connect NAME ENTRY PANEL buttons
	if confirm_name_button:
		confirm_name_button.pressed.connect(_on_confirm_name_pressed)
	if cancel_name_button:
		cancel_name_button.pressed.connect(_on_cancel_name_pressed)
	if name_line_edit:
		name_line_edit.text_submitted.connect(_on_name_submitted)
		name_line_edit.text_changed.connect(_on_name_text_changed)
	
	# Connect MAIN PANEL buttons
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
	if change_nickname_button:
		change_nickname_button.pressed.connect(_on_change_nickname_pressed)
	if leaderboard_button:
		leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	if achievement_button:
		achievement_button.pressed.connect(_on_achievements_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if logout_button:
		logout_button.pressed.connect(_on_logout_pressed)
	
	# Initial state - show login panel
	_show_login_panel()
	status_label.text = "Connecting..."
	_enable_login_buttons(false)
	
	_log("MainMenu v1.3.0 initialized")
	
	# Check if SDK already ready
	if CheddaBoards.is_ready():
		_on_sdk_ready()

func _on_sdk_ready():
	"""Called when CheddaBoards SDK is ready"""
	_log("SDK ready")
	status_label.text = ""
	_enable_login_buttons(true)
	
	# Check for existing REAL auth (not anonymous)
	_check_existing_auth()

func _input(event):
	"""Debug keyboard shortcuts"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F8:
				_log("Force profile refresh (F8)")
				CheddaBoards.refresh_profile()
				get_viewport().set_input_as_handled()
			KEY_F9:
				_dump_debug()
				get_viewport().set_input_as_handled()

# ============================================================
# ANONYMOUS PLAYER SETUP
# ============================================================

func _setup_anonymous_player():
	"""Setup anonymous player ID"""
	if OS.get_name() == "Web":
		# Web: Try to get device ID from JS, fallback to random
		var js_device_id = JavaScriptBridge.eval("window.deviceId || ''", true)
		if js_device_id and str(js_device_id) != "":
			anonymous_player_id = str(js_device_id)
		else:
			anonymous_player_id = "player_" + str(randi())
	else:
		# Native: Use device unique ID
		anonymous_player_id = OS.get_unique_id()
		if anonymous_player_id.is_empty():
			anonymous_player_id = "player_" + str(randi())
	_log("Anonymous player ID: %s" % anonymous_player_id)

func _load_player_data():
	"""Load saved player data (anonymous nickname)"""
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		_log("No save file found")
		return
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		
		if data is Dictionary:
			anonymous_nickname = data.get("nickname", "")
			_log("Loaded anonymous nickname: %s" % anonymous_nickname)

func _save_player_data():
	"""Save player data (anonymous nickname)"""
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"nickname": anonymous_nickname,
			"player_id": anonymous_player_id
		}
		file.store_var(data)
		file.close()
		_log("Saved player data")

# ============================================================
# AUTHENTICATION CHECK
# ============================================================

func _check_existing_auth():
	"""Check if user has REAL authentication (not anonymous)"""
	_log("Checking existing auth...")
	_log("  has_account: %s" % CheddaBoards.has_account())
	_log("  is_authenticated: %s" % CheddaBoards.is_authenticated())
	_log("  is_anonymous: %s" % CheddaBoards.is_anonymous())
	
	# Must have REAL account AND be currently authenticated
	# Anonymous/device users stay on login panel
	if CheddaBoards.has_account() and CheddaBoards.is_authenticated() and not CheddaBoards.is_anonymous():
		_log("User has real account and is authenticated - loading profile")
		_load_authenticated_profile()
	else:
		_log("No real auth - showing login panel")
		_show_login_panel()

func _load_authenticated_profile():
	"""Load profile for authenticated user"""
	_log("Loading profile...")
	waiting_for_profile = true
	profile_load_attempts = 0
	
	# Show cached data immediately while refreshing
	var profile = CheddaBoards.get_cached_profile()
	if not profile.is_empty():
		_log("Showing cached profile")
		_show_main_panel(profile)
	else:
		_show_main_panel_loading()
	
	_request_profile_with_timeout()

func _request_profile_with_timeout():
	"""Request profile with timeout"""
	CheddaBoards.refresh_profile()
	_start_profile_polling()
	_start_profile_timeout()

# ============================================================
# PROFILE POLLING
# ============================================================

func _start_profile_polling():
	"""Start polling for profile"""
	_stop_profile_polling()
	
	profile_poll_timer = Timer.new()
	profile_poll_timer.wait_time = POLL_INTERVAL
	profile_poll_timer.timeout.connect(_check_profile_poll)
	add_child(profile_poll_timer)
	profile_poll_timer.start()
	profile_poll_attempts = 0

func _check_profile_poll():
	"""Check if profile has loaded"""
	profile_poll_attempts += 1
	
	var profile = CheddaBoards.get_cached_profile()
	
	if not profile.is_empty() and waiting_for_profile:
		_log("Profile found via polling")
		_stop_all_timers()
		waiting_for_profile = false
		_show_main_panel(profile)
		return
	
	if profile_poll_attempts >= MAX_POLL_ATTEMPTS:
		_stop_profile_polling()

func _stop_profile_polling():
	"""Stop polling"""
	if profile_poll_timer:
		profile_poll_timer.stop()
		profile_poll_timer.queue_free()
		profile_poll_timer = null

# ============================================================
# PROFILE TIMEOUT
# ============================================================

func _start_profile_timeout():
	"""Start timeout for profile loading"""
	_clear_profile_timeout()
	
	profile_timeout_timer = Timer.new()
	profile_timeout_timer.wait_time = PROFILE_TIMEOUT_DURATION
	profile_timeout_timer.one_shot = true
	profile_timeout_timer.timeout.connect(_on_profile_timeout)
	add_child(profile_timeout_timer)
	profile_timeout_timer.start()

func _clear_profile_timeout():
	"""Clear profile timeout"""
	if profile_timeout_timer:
		profile_timeout_timer.stop()
		profile_timeout_timer.queue_free()
		profile_timeout_timer = null

func _on_profile_timeout():
	"""Handle profile timeout"""
	if not waiting_for_profile:
		return
	
	profile_load_attempts += 1
	_log("Profile timeout (attempt %d/%d)" % [profile_load_attempts, MAX_PROFILE_LOAD_ATTEMPTS])
	
	if profile_load_attempts < MAX_PROFILE_LOAD_ATTEMPTS:
		_request_profile_with_timeout()
	else:
		_log("Max attempts - using defaults")
		_stop_all_timers()
		waiting_for_profile = false
		_show_main_panel({
			"nickname": CheddaBoards.get_nickname(),
			"score": 0,
			"streak": 0,
			"playCount": 0
		})

# ============================================================
# UI TIMEOUT (LOGIN)
# ============================================================

func _start_ui_timeout():
	"""Start login timeout"""
	_clear_ui_timeout()
	
	ui_timeout_timer = Timer.new()
	ui_timeout_timer.wait_time = UI_TIMEOUT_DURATION
	ui_timeout_timer.one_shot = true
	ui_timeout_timer.timeout.connect(_on_ui_timeout)
	add_child(ui_timeout_timer)
	ui_timeout_timer.start()

func _clear_ui_timeout():
	"""Clear login timeout"""
	if ui_timeout_timer:
		ui_timeout_timer.stop()
		ui_timeout_timer.queue_free()
		ui_timeout_timer = null

func _on_ui_timeout():
	"""Handle login timeout"""
	_log("Login timeout")
	_set_status("Login timeout. Please try again.", true)
	_enable_login_buttons(true)
	_stop_all_timers()
	is_logging_in = false

func _stop_all_timers():
	"""Stop all timers"""
	_clear_ui_timeout()
	_clear_profile_timeout()
	_stop_profile_polling()

# ============================================================
# UI STATE
# ============================================================

func _show_login_panel():
	"""Show login panel (anonymous/not logged in)"""
	login_panel.visible = true
	main_panel.visible = false
	if name_entry_panel:
		name_entry_panel.visible = false
	status_label.text = ""
	
	waiting_for_profile = false
	is_logging_in = false
	
	_stop_all_timers()
	_enable_login_buttons(true)
	
	# Update PLAY NOW button to show returning player
	if direct_play_button and not anonymous_nickname.is_empty():
		direct_play_button.text = "PLAY AS %s" % anonymous_nickname.to_upper()
	elif direct_play_button:
		direct_play_button.text = "PLAY NOW"

func _show_name_entry_panel():
	"""Show name entry panel for anonymous play"""
	login_panel.visible = false
	main_panel.visible = false
	name_entry_panel.visible = true
	
	# Pre-fill with saved nickname if exists
	if not anonymous_nickname.is_empty():
		name_line_edit.text = anonymous_nickname
	else:
		name_line_edit.text = ""
	
	name_line_edit.placeholder_text = "Enter your name..."
	name_status_label.text = ""
	
	# Focus the input field
	name_line_edit.grab_focus()
	
	# Update button state
	_update_confirm_button_state()

func _update_confirm_button_state():
	"""Enable/disable confirm button based on name validity"""
	var name_text = name_line_edit.text.strip_edges()
	var is_valid = name_text.length() >= MIN_NAME_LENGTH and name_text.length() <= MAX_NAME_LENGTH
	confirm_name_button.disabled = not is_valid

func _show_main_panel_loading():
	"""Show main panel in loading state"""
	login_panel.visible = false
	main_panel.visible = true
	if name_entry_panel:
		name_entry_panel.visible = false
	
	welcome_label.text = "Loading..."
	score_label.text = "High Score: --"
	streak_label.text = "Best Streak: --"
	if plays_label:
		plays_label.text = "Games Played: --"
	
	_set_main_buttons_disabled(true)

func _show_main_panel(profile: Dictionary):
	"""Show main panel with profile (logged in)"""
	_log("Showing main panel")
	
	waiting_for_profile = false
	_stop_all_timers()
	
	login_panel.visible = false
	main_panel.visible = true
	if name_entry_panel:
		name_entry_panel.visible = false
	
	var nickname = str(profile.get("nickname", profile.get("username", "Player")))
	var score = int(profile.get("score", profile.get("highScore", 0)))
	var streak = int(profile.get("streak", profile.get("bestStreak", 0)))
	var play_count = int(profile.get("playCount", profile.get("plays", 0)))
	
	welcome_label.text = "Welcome, %s!" % nickname
	score_label.text = "High Score: %d" % score
	streak_label.text = "Best Streak: %d" % streak
	if plays_label:
		plays_label.text = "Games Played: %d" % play_count
	
	_update_achievement_button()
	_set_main_buttons_disabled(false)

func _update_main_panel_stats(profile: Dictionary):
	"""Update stats on main panel"""
	var nickname = str(profile.get("nickname", "Player"))
	var score = int(profile.get("score", 0))
	var streak = int(profile.get("streak", 0))
	var play_count = int(profile.get("playCount", 0))
	
	welcome_label.text = "Welcome, %s!" % nickname
	score_label.text = "High Score: %d" % score
	streak_label.text = "Best Streak: %d" % streak
	if plays_label:
		plays_label.text = "Games Played: %d" % play_count
	
	_update_achievement_button()

func _update_achievement_button():
	"""Update achievement button text"""
	if not achievement_button:
		return
	var achievements = get_node_or_null("/root/Achievements")
	if achievements and achievements.has_method("get_unlocked_count"):
		var unlocked = achievements.get_unlocked_count()
		var total = achievements.get_total_count()
		achievement_button.text = "Achievements (%d/%d)" % [unlocked, total]

func _enable_login_buttons(enabled: bool):
	"""Enable/disable login panel buttons"""
	if direct_play_button:
		direct_play_button.disabled = not enabled
	if login_leaderboard_button:
		login_leaderboard_button.disabled = not enabled
	if google_button:
		google_button.disabled = not enabled
	if apple_button:
		apple_button.disabled = not enabled
	if chedda_button:
		chedda_button.disabled = not enabled
	if exit_button:
		exit_button.disabled = not enabled

func _set_main_buttons_disabled(disabled: bool):
	"""Enable/disable main panel buttons"""
	if play_button:
		play_button.disabled = disabled
	if change_nickname_button:
		change_nickname_button.disabled = disabled
	if achievement_button:
		achievement_button.disabled = disabled
	if leaderboard_button:
		leaderboard_button.disabled = disabled
	if settings_button:
		settings_button.disabled = disabled
	if logout_button:
		logout_button.disabled = false  # Always enabled

func _set_status(message: String, is_error: bool = false):
	"""Set status label"""
	status_label.text = message
	if is_error:
		status_label.add_theme_color_override("font_color", Color.RED)
	else:
		status_label.remove_theme_color_override("font_color")

# ============================================================
# LOGIN PANEL BUTTON HANDLERS
# ============================================================

func _on_direct_play_pressed():
	"""Handle PLAY NOW button - show name entry or use mobile prompt"""
	_log("PLAY NOW pressed")
	
	# Check if mobile web - use native prompt for better keyboard experience
	if OS.get_name() == "Web" and _is_mobile_web():
		_show_mobile_name_prompt()
		return
	
	# Desktop/native: show name entry panel as normal
	_log("Showing name entry panel")
	_show_name_entry_panel()

func _on_google_button_pressed():
	"""Login with Google"""
	_log("Google login pressed")
	_set_status("Opening Google login...")
	_enable_login_buttons(false)
	_start_ui_timeout()
	is_logging_in = true
	CheddaBoards.login_google()

func _on_apple_button_pressed():
	"""Login with Apple"""
	_log("Apple login pressed")
	_set_status("Opening Apple login...")
	_enable_login_buttons(false)
	_start_ui_timeout()
	is_logging_in = true
	CheddaBoards.login_apple()

func _on_chedda_button_pressed():
	"""Login with Internet Identity"""
	_log("Chedda/II login pressed")
	_set_status("Opening Internet Identity...")
	_enable_login_buttons(false)
	_start_ui_timeout()
	is_logging_in = true
	CheddaBoards.login_internet_identity()

func _on_exit_button_pressed():
	"""Exit game - redirect to website on web, quit on native"""
	_log("Exit pressed")
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href = 'https://cheddagames.com'")
	else:
		get_tree().quit()

# ============================================================
# NAME ENTRY PANEL HANDLERS
# ============================================================
func _is_mobile_web() -> bool:
	"""Check if running on mobile web browser"""
	if OS.get_name() != "Web":
		return false
	var is_mobile = JavaScriptBridge.eval("""
		/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
	""", true)
	return bool(is_mobile)

func _show_mobile_n
