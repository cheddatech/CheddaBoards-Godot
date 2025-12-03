# MainMenu.gd v1.1.0
# Main menu with authentication flow and profile display
# https://github.com/cheddatech/CheddaBoards-Godot
#
# ============================================================
# SETUP
# ============================================================
# Required Autoloads:
#   - CheddaBoards
#   - Achievements
#
# Required nodes: See NODE REFERENCES sections below
#
# ============================================================

extends Control

# ============================================================
# CONFIGURATION
# ============================================================

const SCENE_GAME: String = "res://Game.tscn"
const SCENE_LEADERBOARD: String = "res://Leaderboard.tscn"
const SCENE_ACHIEVEMENTS: String = "res://AchievementsView.tscn"

const UI_TIMEOUT_DURATION: float = 40.0
const PROFILE_TIMEOUT_DURATION: float = 10.0
const POLL_INTERVAL: float = 0.5
const MAX_PROFILE_LOAD_ATTEMPTS: int = 3
const MAX_POLL_ATTEMPTS: int = 15  # 15 * 0.5s = 7.5 seconds

# ============================================================
# NODE REFERENCES - LOGIN PANEL
# ============================================================

@onready var login_panel = $LoginPanel
@onready var google_button = $LoginPanel/MarginContainer/VBoxContainer/GoogleButton
@onready var apple_button = $LoginPanel/MarginContainer/VBoxContainer/AppleButton
@onready var chedda_button = $LoginPanel/MarginContainer/VBoxContainer/CheddaButton
@onready var status_label = $LoginPanel/MarginContainer/VBoxContainer/StatusLabel

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
@onready var logout_button = $MainPanel/MarginContainer/VBoxContainer/LogoutButton

# ============================================================
# STATE
# ============================================================

var is_logging_in: bool = false
var waiting_for_profile: bool = false
var profile_load_attempts: int = 0
var profile_poll_attempts: int = 0

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
	
	# Connect CheddaBoards signals
	CheddaBoards.sdk_ready.connect(_on_sdk_ready)
	CheddaBoards.login_success.connect(_on_login_success)
	CheddaBoards.login_failed.connect(_on_login_failed)
	CheddaBoards.login_timeout.connect(_on_login_timeout)
	CheddaBoards.profile_loaded.connect(_on_profile_loaded)
	CheddaBoards.no_profile.connect(_on_no_profile)
	CheddaBoards.logout_success.connect(_on_logout_success)
	CheddaBoards.nickname_changed.connect(_on_nickname_changed)
	
	# Connect button signals
	google_button.pressed.connect(_on_google_button_pressed)
	apple_button.pressed.connect(_on_apple_button_pressed)
	chedda_button.pressed.connect(_on_chedda_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	change_nickname_button.pressed.connect(_on_change_nickname_button_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_button_pressed)
	achievement_button.pressed.connect(_on_achievements_button_pressed)
	logout_button.pressed.connect(_on_logout_button_pressed)
	
	# Initial state - show login panel while loading
	_show_login_panel()
	status_label.text = "Connecting..."
	_enable_login_buttons(false)
	
	_log("MainMenu initialized")
	_log("Debug: F8 = force refresh, F9 = dump debug")
	
	# Wait for SDK to be ready
	if CheddaBoards.is_ready():
		_on_sdk_ready()
	# else: wait for sdk_ready signal

func _on_sdk_ready():
	"""Called when CheddaBoards SDK is ready"""
	_log("SDK ready")
	status_label.text = ""
	_enable_login_buttons(true)
	_check_existing_auth()

func _input(event):
	"""Debug keyboard shortcuts"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F8:
				_log("🔄 Force profile refresh (F8)")
				CheddaBoards.refresh_profile()
				_start_profile_polling()
				get_viewport().set_input_as_handled()
			KEY_F9:
				_dump_debug()
				get_viewport().set_input_as_handled()

# ============================================================
# AUTHENTICATION CHECK
# ============================================================

func _check_existing_auth():
	"""Check if user is already authenticated"""
	_log("Checking existing auth...")
	
	if CheddaBoards.is_authenticated():
		_log("User authenticated - loading profile")
		_load_authenticated_profile()
	else:
		_log("User not authenticated")
		_show_login_panel()

func _load_authenticated_profile():
	"""Load profile for already authenticated user"""
	# Always refresh profile from backend when returning to main menu
	# This ensures we have the latest score/streak after playing
	_log("Refreshing profile from backend...")
	waiting_for_profile = true
	profile_load_attempts = 0
	
	# Show current cached data immediately (if available) while refreshing
	var profile = CheddaBoards.get_cached_profile()
	if not profile.is_empty():
		_log("Showing cached profile while refreshing")
		_show_main_panel(profile)
	else:
		_show_main_panel_loading()
	
	# Request fresh profile from backend
	_request_profile_with_timeout()

func _request_profile_with_timeout():
	"""Request profile with timeout handling"""
	CheddaBoards.refresh_profile()
	_start_profile_polling()
	_start_profile_timeout()

# ============================================================
# PROFILE POLLING (BACKUP MECHANISM)
# ============================================================

func _start_profile_polling():
	"""Start polling for profile as backup"""
	_stop_profile_polling()
	
	profile_poll_timer = Timer.new()
	profile_poll_timer.wait_time = POLL_INTERVAL
	profile_poll_timer.timeout.connect(_check_profile_poll)
	add_child(profile_poll_timer)
	profile_poll_timer.start()
	profile_poll_attempts = 0
	_log("Started profile polling")

func _check_profile_poll():
	"""Check if profile has loaded via polling"""
	profile_poll_attempts += 1
	
	var profile = CheddaBoards.get_cached_profile()
	
	if not profile.is_empty() and waiting_for_profile:
		_log("✓ Profile found via polling (attempt %d)" % profile_poll_attempts)
		_stop_all_timers()
		waiting_for_profile = false
		_show_main_panel(profile)
		return
	
	if profile_poll_attempts >= MAX_POLL_ATTEMPTS:
		_log("Polling limit reached (%d attempts)" % MAX_POLL_ATTEMPTS)
		_stop_profile_polling()

func _stop_profile_polling():
	"""Stop polling timer"""
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
	"""Clear profile timeout timer"""
	if profile_timeout_timer:
		profile_timeout_timer.stop()
		profile_timeout_timer.queue_free()
		profile_timeout_timer = null

func _on_profile_timeout():
	"""Handle profile load timeout"""
	if not waiting_for_profile:
		return
	
	profile_load_attempts += 1
	_log("Profile timeout (attempt %d/%d)" % [profile_load_attempts, MAX_PROFILE_LOAD_ATTEMPTS])
	
	if profile_load_attempts < MAX_PROFILE_LOAD_ATTEMPTS:
		_log("Retrying profile fetch...")
		_request_profile_with_timeout()
	else:
		_log("Max attempts reached - using defaults")
		_stop_all_timers()
		waiting_for_profile = false
		
		# Show main panel with default values since user IS authenticated
		_show_main_panel({
			"nickname": CheddaBoards.get_nickname(),
			"score": 0,
			"streak": 0,
			"playCount": 0,
			"achievements": []
		})

# ============================================================
# UI TIMEOUT (FOR LOGIN)
# ============================================================

func _start_ui_timeout():
	"""Start timeout for login UI"""
	_clear_ui_timeout()
	
	ui_timeout_timer = Timer.new()
	ui_timeout_timer.wait_time = UI_TIMEOUT_DURATION
	ui_timeout_timer.one_shot = true
	ui_timeout_timer.timeout.connect(_on_ui_timeout)
	add_child(ui_timeout_timer)
	ui_timeout_timer.start()

func _clear_ui_timeout():
	"""Clear UI timeout timer"""
	if ui_timeout_timer:
		ui_timeout_timer.stop()
		ui_timeout_timer.queue_free()
		ui_timeout_timer = null

func _on_ui_timeout():
	"""Handle UI timeout"""
	_log("UI timeout")
	_set_status("Login timeout. Please try again.", true)
	_enable_login_buttons(true)
	_stop_all_timers()
	waiting_for_profile = false
	is_logging_in = false

# ============================================================
# STOP ALL TIMERS
# ============================================================

func _stop_all_timers():
	"""Stop all active timers"""
	_clear_ui_timeout()
	_clear_profile_timeout()
	_stop_profile_polling()

# ============================================================
# UI STATE MANAGEMENT
# ============================================================

func _show_login_panel():
	"""Show login panel"""
	login_panel.visible = true
	main_panel.visible = false
	status_label.text = ""
	
	waiting_for_profile = false
	is_logging_in = false
	
	_stop_all_timers()
	_enable_login_buttons(true)

func _show_main_panel_loading():
	"""Show main panel in loading state"""
	login_panel.visible = false
	main_panel.visible = true
	
	welcome_label.text = "Loading..."
	score_label.text = "High Score: --"
	streak_label.text = "Best Streak: --"
	
	# Handle optional plays_label
	if plays_label:
		plays_label.text = "Games Played: --"
	
	_set_main_buttons_disabled(true)

func _show_main_panel(profile: Dictionary):
	"""Show main panel with profile data"""
	_log("Showing main panel")
	
	waiting_for_profile = false
	_stop_all_timers()
	
	login_panel.visible = false
	main_panel.visible = true
	
	# Extract profile data
	var nickname = str(profile.get("nickname", profile.get("username", "Player")))
	var score = int(profile.get("score", profile.get("highScore", 0)))
	var streak = int(profile.get("streak", profile.get("bestStreak", 0)))
	var play_count = int(profile.get("playCount", profile.get("plays", 0)))
	
	# Update labels
	welcome_label.text = "Welcome, %s!" % nickname
	score_label.text = "High Score: %d" % score
	streak_label.text = "Best Streak: %d" % streak
	
	# Handle optional plays_label
	if plays_label:
		plays_label.text = "Games Played: %d" % play_count
	
	# Update achievement button with progress
	_update_achievement_button()
	
	# Enable buttons
	_set_main_buttons_disabled(false)
	
	_log("Profile displayed - Score: %d, Streak: %d, Plays: %d" % [score, streak, play_count])

func _update_achievement_button():
	"""Update achievement button text with progress"""
	if achievement_button and Achievements.is_ready:
		var unlocked = Achievements.get_unlocked_count()
		var total = Achievements.get_total_count()
		achievement_button.text = "Achievements (%d/%d)" % [unlocked, total]

func _enable_login_buttons(enabled: bool):
	"""Enable/disable login buttons"""
	google_button.disabled = not enabled
	apple_button.disabled = not enabled
	chedda_button.disabled = not enabled

func _set_main_buttons_disabled(disabled: bool):
	"""Enable/disable main panel buttons"""
	play_button.disabled = disabled
	change_nickname_button.disabled = disabled
	achievement_button.disabled = disabled
	leaderboard_button.disabled = disabled
	# Logout always enabled
	logout_button.disabled = false

func _set_status(message: String, is_error: bool = false):
	"""Set status label text and color"""
	status_label.text = message
	if is_error:
		status_label.add_theme_color_override("font_color", Color.RED)
	else:
		status_label.remove_theme_color_override("font_color")

# ============================================================
# LOGIN BUTTON HANDLERS
# ============================================================

func _on_google_button_pressed():
	_log("Google login pressed")
	_set_status("Opening Google login...")
	_enable_login_buttons(false)
	_start_ui_timeout()
	is_logging_in = true
	CheddaBoards.login_google()

func _on_apple_button_pressed():
	_log("Apple login pressed")
	_set_status("Opening Apple login...")
	_enable_login_buttons(false)
	_start_ui_timeout()
	is_logging_in = true
	CheddaBoards.login_apple()

func _on_chedda_button_pressed():
	_log("Internet Identity login pressed")
	_set_status("Opening Internet Identity...")
	_enable_login_buttons(false)
	_start_ui_timeout()
	is_logging_in = true
	CheddaBoards.login_internet_identity()

# ============================================================
# CHEDDABOARDS SIGNAL HANDLERS
# ============================================================

func _on_login_success(nickname: String):
	_log("✅ Login success: %s" % nickname)
	_clear_ui_timeout()
	is_logging_in = false
	
	# Show loading state and request profile
	_show_main_panel_loading()
	waiting_for_profile = true
	profile_load_attempts = 0
	_request_profile_with_timeout()

func _on_login_failed(reason: String):
	_log("❌ Login failed: %s" % reason)
	_clear_ui_timeout()
	_set_status("Login failed: %s" % reason, true)
	_enable_login_buttons(true)
	_stop_all_timers()
	waiting_for_profile = false
	is_logging_in = false

func _on_login_timeout():
	_log("⏰ Login timeout signal")
	_clear_ui_timeout()
	_set_status("Login took too long. Please try again.", true)
	_enable_login_buttons(true)
	_stop_all_timers()
	waiting_for_profile = false
	is_logging_in = false

func _on_profile_loaded(nickname: String, score: int, streak: int, achievements: Array):
	_log("📊 Profile loaded: %s (score: %d, streak: %d)" % [nickname, score, streak])
	
	var profile = CheddaBoards.get_cached_profile()
	if profile.is_empty():
		_log("Warning: profile_loaded signal but cache is empty")
		return
	
	# Always update UI when profile loads
	if main_panel.visible:
		_log("Updating main panel with fresh profile")
		_update_main_panel_stats(profile)
	
	# Clear waiting state
	if waiting_for_profile:
		waiting_for_profile = false
		_stop_all_timers()
		if not main_panel.visible:
			_show_main_panel(profile)

func _update_main_panel_stats(profile: Dictionary):
	"""Update just the stats on main panel (not full refresh)"""
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

func _on_no_profile():
	_log("📭 No profile signal (logging_in: %s, auth: %s)" % [is_logging_in, CheddaBoards.is_authenticated()])
	
	# Only show login if NOT authenticated and NOT in login flow
	if not CheddaBoards.is_authenticated() and not is_logging_in:
		_log("Not authenticated - showing login")
		_stop_all_timers()
		waiting_for_profile = false
		_show_login_panel()
	elif is_logging_in:
		_log("Still logging in - ignoring no_profile")
	else:
		_log("Authenticated but no profile - using defaults")
		# User is authenticated, show main panel with defaults
		_stop_all_timers()
		waiting_for_profile = false
		_show_main_panel({
			"nickname": CheddaBoards.get_nickname(),
			"score": 0,
			"streak": 0,
			"playCount": 0,
			"achievements": []
		})

func _on_logout_success():
	_log("👋 Logout success")
	is_logging_in = false
	_show_login_panel()

func _on_nickname_changed(new_nickname: String):
	_log("✏️ Nickname changed: %s" % new_nickname)
	if main_panel.visible:
		welcome_label.text = "Welcome, %s!" % new_nickname

# ============================================================
# MAIN PANEL BUTTON HANDLERS
# ============================================================

func _on_play_button_pressed():
	_log("▶️ Play pressed")
	get_tree().change_scene_to_file(SCENE_GAME)

func _on_change_nickname_button_pressed():
	_log("✏️ Change nickname pressed")
	CheddaBoards.change_nickname()

func _on_leaderboard_button_pressed():
	_log("📊 Leaderboard pressed")
	get_tree().change_scene_to_file(SCENE_LEADERBOARD)

func _on_achievements_button_pressed():
	_log("🏆 Achievements pressed")
	get_tree().change_scene_to_file(SCENE_ACHIEVEMENTS)

func _on_logout_button_pressed():
	_log("🚪 Logout pressed")
	CheddaBoards.logout()

# ============================================================
# LOGGING & DEBUG
# ============================================================

func _log(message: String):
	"""Log message with timestamp"""
	if not debug_logging:
		return
	
	var timestamp = Time.get_ticks_msec()
	var entry = "[%d] %s" % [timestamp, message]
	state_history.append(entry)
	print("[MainMenu] %s" % message)

func _dump_debug():
	"""Dump all debug info (F9)"""
	print("")
	print("╔══════════════════════════════════════════════╗")
	print("║           MainMenu Debug v1.1.0              ║")
	print("╠══════════════════════════════════════════════╣")
	print("║ State                                        ║")
	print("║  - Is Logging In:    %s" % str(is_logging_in).rpad(24) + "║")
	print("║  - Waiting Profile:  %s" % str(waiting_for_profile).rpad(24) + "║")
	print("║  - Profile Attempts: %s" % str(profile_load_attempts).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Timers                                       ║")
	print("║  - UI Timeout:       %s" % str(ui_timeout_timer != null).rpad(24) + "║")
	print("║  - Profile Timeout:  %s" % str(profile_timeout_timer != null).rpad(24) + "║")
	print("║  - Polling:          %s" % str(profile_poll_timer != null).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ CheddaBoards                                 ║")
	print("║  - SDK Ready:        %s" % str(CheddaBoards.is_ready()).rpad(24) + "║")
	print("║  - Authenticated:    %s" % str(CheddaBoards.is_authenticated()).rpad(24) + "║")
	print("║  - Nickname:         %s" % CheddaBoards.get_nickname().rpad(24) + "║")
	print("║  - High Score:       %s" % str(CheddaBoards.get_high_score()).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Cached Profile                               ║")
	var profile = CheddaBoards.get_cached_profile()
	if profile.is_empty():
		print("║  (empty)                                     ║")
	else:
		print("║  - score:            %s" % str(profile.get("score", 0)).rpad(24) + "║")
		print("║  - streak:           %s" % str(profile.get("streak", 0)).rpad(24) + "║")
		print("║  - playCount:        %s" % str(profile.get("playCount", 0)).rpad(24) + "║")
	print("╚══════════════════════════════════════════════╝")
	print("")
	print("State History (last 10):")
	var start_idx = max(0, state_history.size() - 10)
	for i in range(start_idx, state_history.size()):
		print("  %s" % state_history[i])
	print("")

# ============================================================
# CLEANUP
# ============================================================

func _exit_tree():
	"""Clean up on exit"""
	_stop_all_timers()
