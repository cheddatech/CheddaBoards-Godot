# MainMenu.gd v1.5.0
# Main menu with authentication flow and profile display
# - Login panel: PLAY NOW (with name entry), Leaderboard, and login buttons
# - Name entry panel: For new anonymous players to set their display name
# - Anonymous panel: Dashboard for returning anonymous players (after first game)
# - Main panel: Profile stats when logged in (Google/Apple/Chedda)
# - Shows weekly score and games played
# https://github.com/cheddatech/CheddaBoards-Godot
#
# ============================================================
# SETUP
# ============================================================
# Required Autoloads (in order):
#   - CheddaBoards
#   - Achievements (optional)
#
# ============================================================

extends Control

# ============================================================
# CONFIGURATION
# ============================================================

const SCENE_GAME: String = "res://Game.tscn"
const SCENE_LEADERBOARD: String = "res://Leaderboard.tscn"
const SCENE_ACHIEVEMENTS: String = "res://AchievementsView.tscn"
const DEVICE_ID_FILE: String = "user://device_id.txt"

# CheddaBoards configuration for rank fetching
const GAME_ID: String = "your-game-id"  # Your game ID on CheddaBoards
const SCOREBOARD_ID: String = "weekly"  # Scoreboard to fetch rank from

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
# NODE REFERENCES - ANONYMOUS PANEL (Dashboard for returning anon players)
# ============================================================

@onready var anonymous_panel = $AnonymousPanel
@onready var anon_welcome_label = $AnonymousPanel/MarginContainer/VBoxContainer/WelcomeLabel
@onready var anon_weekly_score_label = $AnonymousPanel/MarginContainer/VBoxContainer/StatsPanel/VBoxContainer/WeeklyScoreLabel
@onready var anon_rank_label = $AnonymousPanel/MarginContainer/VBoxContainer/StatsPanel/VBoxContainer/RankLabel
@onready var anon_plays_label = $AnonymousPanel/MarginContainer/VBoxContainer/StatsPanel/VBoxContainer/PlaysLabel
@onready var anon_play_button = $AnonymousPanel/MarginContainer/VBoxContainer/PlayButton
@onready var anon_change_name_button = $AnonymousPanel/MarginContainer/VBoxContainer/ChangeNameButton
@onready var anon_achievement_button = $AnonymousPanel/MarginContainer/VBoxContainer/AchievementsButton
@onready var anon_leaderboard_button = $AnonymousPanel/MarginContainer/VBoxContainer/LeaderboardButton
@onready var anon_exit_button = $AnonymousPanel/MarginContainer/VBoxContainer/ExitButton

# ============================================================
# NODE REFERENCES - MAIN PANEL (Logged in users)
# ============================================================

@onready var main_panel = $MainPanel
@onready var welcome_label = $MainPanel/MarginContainer/VBoxContainer/WelcomeLabel
@onready var weekly_score_label = $MainPanel/MarginContainer/VBoxContainer/StatsPanel/VBoxContainer/WeeklyScoreLabel
@onready var rank_label = $MainPanel/MarginContainer/VBoxContainer/StatsPanel/VBoxContainer/RankLabel
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

# Anonymous player data
var anonymous_nickname: String = ""
var anonymous_player_id: String = ""
var anonymous_has_played: bool = false  # Track if anon player has played at least once

# Test mode flag
var _is_test_submission: bool = false

# Silent login flag (for anonymous dashboard - don't trigger full login flow)
var _is_silent_login: bool = false

# Prevent duplicate SDK ready handling
var _sdk_ready_handled: bool = false

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
	
	# Load saved anonymous player data (nickname + has_played status)
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
	
	# Connect ANONYMOUS PANEL buttons
	if anon_play_button:
		anon_play_button.pressed.connect(_on_anon_play_pressed)
	if anon_change_name_button:
		anon_change_name_button.pressed.connect(_on_anon_change_name_pressed)
	if anon_achievement_button:
		anon_achievement_button.pressed.connect(_on_achievements_pressed)
	if anon_leaderboard_button:
		anon_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	if anon_exit_button:
		anon_exit_button.pressed.connect(_on_exit_button_pressed)
	
	# Connect MAIN PANEL buttons
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
	if change_nickname_button:
		change_nickname_button.pressed.connect(_on_change_nickname_pressed)
	if leaderboard_button:
		leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	if achievement_button:
		achievement_button.pressed.connect(_on_achievements_pressed)
	if logout_button:
		logout_button.pressed.connect(_on_logout_pressed)
	
	# Initial state - show login panel
	_show_login_panel()
	status_label.text = "Connecting..."
	_enable_login_buttons(false)
	
	_log("MainMenu v1.5.0 initialized")
	
	# Check if SDK already ready
	if CheddaBoards.is_ready():
		_on_sdk_ready()

func _on_sdk_ready():
	"""Called when CheddaBoards SDK is ready"""
	# Prevent duplicate handling
	if _sdk_ready_handled:
		_log("SDK ready (duplicate, ignoring)")
		return
	_sdk_ready_handled = true
	
	_log("SDK ready")
	status_label.text = ""
	_enable_login_buttons(true)
	
	# Check for existing auth or returning anonymous player
	_check_existing_auth()

func _input(event):
	"""Debug keyboard shortcuts"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F6:
				_test_submit_bulk_scores(5)
				get_viewport().set_input_as_handled()
			KEY_F7:
				_test_submit_random_score()
				get_viewport().set_input_as_handled()
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
	"""Setup anonymous player ID - persistent across sessions"""
	if OS.get_name() == "Web":
		var js_device_id = JavaScriptBridge.eval("chedda_get_device_id()", true)
		if js_device_id and str(js_device_id) != "" and str(js_device_id) != "null":
			anonymous_player_id = str(js_device_id)
		else:
			anonymous_player_id = _get_or_create_native_device_id()
	else:
		anonymous_player_id = _get_or_create_native_device_id()
	
	_log("Anonymous player ID: %s" % anonymous_player_id)

func _get_or_create_native_device_id() -> String:
	"""Get existing device ID or create new one (persisted to file)"""
	if FileAccess.file_exists(DEVICE_ID_FILE):
		var file = FileAccess.open(DEVICE_ID_FILE, FileAccess.READ)
		if file:
			var stored_id = file.get_line().strip_edges()
			file.close()
			if stored_id != "":
				return stored_id
	
	randomize()
	var new_id = "dev_%d_%08x" % [Time.get_unix_time_from_system(), randi()]
	
	var file = FileAccess.open(DEVICE_ID_FILE, FileAccess.WRITE)
	if file:
		file.store_line(new_id)
		file.close()
	
	return new_id

func _load_player_data():
	"""Load saved player data (anonymous nickname + has_played status)"""
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		_log("No save file found")
		return
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		
		if data is Dictionary:
			anonymous_nickname = data.get("nickname", "")
			anonymous_has_played = data.get("has_played", false)
			_log("Loaded anonymous data: nickname='%s', has_played=%s" % [anonymous_nickname, anonymous_has_played])

func _save_player_data():
	"""Save player data (anonymous nickname + has_played status)"""
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"nickname": anonymous_nickname,
			"player_id": anonymous_player_id,
			"has_played": anonymous_has_played
		}
		file.store_var(data)
		file.close()
		_log("Saved player data")

func _mark_anonymous_has_played():
	"""Mark that the anonymous player has completed at least one game and save data"""
	anonymous_has_played = true
	_save_player_data()
	_log("Saved anonymous player data")

# ============================================================
# AUTHENTICATION CHECK
# ============================================================

func _check_existing_auth():
	"""Check if user has REAL authentication OR is a returning anonymous player"""
	_log("Checking existing auth...")
	_log("  has_account: %s" % CheddaBoards.has_account())
	_log("  is_authenticated: %s" % CheddaBoards.is_authenticated())
	_log("  is_anonymous: %s" % CheddaBoards.is_anonymous())
	_log("  anonymous_has_played: %s" % anonymous_has_played)
	_log("  anonymous_nickname: '%s'" % anonymous_nickname)
	
	# Check for real (non-anonymous) authenticated user
	if CheddaBoards.has_account() and CheddaBoards.is_authenticated() and not CheddaBoards.is_anonymous():
		_log("User has real account and is authenticated - loading profile")
		_load_authenticated_profile()
	# Check for returning anonymous player (has played before)
	elif _is_returning_anonymous_player():
		_log("Returning anonymous player - showing anonymous dashboard")
		_show_anonymous_panel()
	else:
		_log("New player - showing login panel")
		_show_login_panel()

func _is_returning_anonymous_player() -> bool:
	"""Check if this is a returning anonymous player who has played at least once"""
	# Must have a nickname saved AND have played before
	return not anonymous_nickname.is_empty() and anonymous_has_played

func _load_authenticated_profile():
	"""Load profile for authenticated user"""
	_log("Loading profile...")
	waiting_for_profile = true
	profile_load_attempts = 0
	
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
# UI STATE - PANEL SWITCHING
# ============================================================

func _show_login_panel():
	"""Show login panel (first time / new anonymous player)"""
	login_panel.visible = true
	main_panel.visible = false
	if name_entry_panel:
		name_entry_panel.visible = false
	if anonymous_panel:
		anonymous_panel.visible = false
	status_label.text = ""
	
	waiting_for_profile = false
	is_logging_in = false
	
	_stop_all_timers()
	_enable_login_buttons(true)

func _show_name_entry_panel():
	"""Show name entry panel for new anonymous players"""
	login_panel.visible = false
	main_panel.visible = false
	name_entry_panel.visible = true
	if anonymous_panel:
		anonymous_panel.visible = false
	
	if not anonymous_nickname.is_empty():
		name_line_edit.text = anonymous_nickname
	else:
		name_line_edit.text = _generate_default_name()
	
	name_line_edit.placeholder_text = "Enter your name..."
	name_status_label.text = ""
	
	name_line_edit.grab_focus()
	_update_confirm_button_state()

func _show_anonymous_panel():
	"""Show anonymous player dashboard (returning anonymous player)"""
	login_panel.visible = false
	main_panel.visible = false
	if name_entry_panel:
		name_entry_panel.visible = false
	anonymous_panel.visible = true
	
	# Clear any profile loading state
	waiting_for_profile = false
	_stop_all_timers()
	
	# Update welcome message
	if anon_welcome_label:
		anon_welcome_label.text = "Welcome back, %s!" % anonymous_nickname
	
	# Show loading state while we fetch stats
	if anon_weekly_score_label:
		anon_weekly_score_label.text = "This Week: --"
	if anon_rank_label:
		anon_rank_label.text = "Rank: --"
	if anon_plays_label:
		anon_plays_label.text = "Games Played: --"
	
	# Update achievement button
	_update_anon_achievement_button()
	
	# Auto-login anonymously and fetch stats
	_silent_anonymous_login()
	
	# Fallback: fetch stats after delay in case login_success doesn't fire
	_fetch_stats_after_delay()

func _silent_anonymous_login():
	"""Silently log in as anonymous to fetch profile data (don't trigger full login flow)"""
	_is_silent_login = true
	_log("Starting silent anonymous login as: %s (ID: %s)" % [anonymous_nickname, anonymous_player_id])
	CheddaBoards.set_player_id(anonymous_player_id)
	CheddaBoards.login_anonymous(anonymous_nickname)

func _fetch_stats_after_delay():
	"""Fallback to fetch stats with polling until we get data"""
	var attempts = 0
	var max_attempts = 10
	
	while attempts < max_attempts:
		await get_tree().create_timer(0.5).timeout
		attempts += 1
		
		# Only proceed if still on anonymous panel
		if not anonymous_panel or not anonymous_panel.visible:
			_log("Stats polling stopped - panel no longer visible")
			return
		
		# Check if we have cached profile now
		var profile = CheddaBoards.get_cached_profile()
		if not profile.is_empty():
			_log("Stats polling: found cached profile on attempt %d" % attempts)
			_update_anonymous_panel_stats(profile)
			return
		
		# Try refreshing profile again
		_log("Stats polling attempt %d/%d - requesting refresh" % [attempts, max_attempts])
		CheddaBoards.refresh_profile()
	
	_log("Stats polling: gave up after %d attempts" % max_attempts)

func _fetch_player_rank():
	"""Fetch player's rank from the leaderboard API"""
	_log("Fetching player rank...")
	
	# Get session token from CheddaBoards
	var session_token = ""
	if CheddaBoards.has_method("get_session_token"):
		session_token = CheddaBoards.get_session_token()
	elif CheddaBoards.has_method("get_session"):
		session_token = CheddaBoards.get_session()
	
	if session_token.is_empty():
		_log("No session token for rank fetch - trying alternative method")
		if CheddaBoards.get("_session_token"):
			session_token = CheddaBoards._session_token
	
	if session_token.is_empty():
		_log("No session token available for rank fetch")
		return
	
	# Make HTTP request to rank endpoint
	var url = "https://api.cheddaboards.com/games/%s/scoreboards/%s/rank" % [GAME_ID, SCOREBOARD_ID]
	_log("Rank request URL: %s" % url)
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_rank_request_completed.bind(http))
	
	var headers = [
		"Content-Type: application/json",
		"X-Session-Token: %s" % session_token
	]
	
	var err = http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_log("Rank request failed to start: %d" % err)
		http.queue_free()

func _on_rank_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	"""Handle rank API response"""
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		_log("Rank request failed: result=%d" % result)
		return
	
	var body_str = body.get_string_from_utf8()
	_log("Rank response (code %d): %s" % [response_code, body_str.left(200)])
	
	if response_code != 200:
		_log("Rank request returned non-200: %d" % response_code)
		return
	
	var json = JSON.parse_string(body_str)
	if json == null or not json.get("ok", false):
		_log("Rank response invalid or error")
		return
	
	var data = json.get("data", {})
	if data.get("found", false):
		var rank = int(data.get("rank", 0))
		var total = int(data.get("totalPlayers", 0))
		_log("Player rank fetched: #%d of %d" % [rank, total])
		
		# Update the rank label
		if anonymous_panel and anonymous_panel.visible and anon_rank_label:
			anon_rank_label.text = "Rank: #%d" % rank
		elif main_panel and main_panel.visible and rank_label:
			rank_label.text = "Rank: #%d" % rank
	else:
		_log("Player not ranked yet: %s" % data.get("message", "unknown"))

func _load_anonymous_stats():
	"""Load and display stats for anonymous player from CheddaBoards API"""
	_log("Loading anonymous stats...")
	
	var profile = CheddaBoards.get_cached_profile()
	
	if not profile.is_empty():
		_log("Found cached profile, updating stats")
		_update_anonymous_panel_stats(profile)
	else:
		_log("No cached profile, showing placeholders")
		if anon_weekly_score_label:
			anon_weekly_score_label.text = "This Week: --"
		if anon_rank_label:
			anon_rank_label.text = "Rank: --"
		if anon_plays_label:
			anon_plays_label.text = "Games Played: --"
	
	_log("Requesting profile refresh...")
	CheddaBoards.refresh_profile()

func _update_anonymous_panel_stats(profile: Dictionary):
	"""Update the anonymous panel with profile stats from dictionary"""
	_log("Updating from profile: %s" % str(profile))
	
	var weekly_score = int(profile.get("score", 0))
	var play_count = int(profile.get("playCount", profile.get("plays", 0)))
	var rank = int(profile.get("rank", profile.get("position", 0)))
	
	# SDK helper method fallbacks
	if weekly_score == 0:
		weekly_score = CheddaBoards.get_high_score()
	if play_count == 0:
		play_count = CheddaBoards.get_play_count()
	if rank == 0 and CheddaBoards.has_method("get_rank"):
		rank = CheddaBoards.get_rank()
	
	_update_anonymous_panel_stats_direct(weekly_score, play_count, rank)
	
	if rank == 0:
		_fetch_player_rank()

func _update_anonymous_panel_stats_direct(weekly_score: int, play_count: int, rank: int = 0):
	"""Update the anonymous panel with stats values directly"""
	_log("Updating anon panel stats: weekly=%d, rank=%d, plays=%d" % [weekly_score, rank, play_count])
	
	if anon_weekly_score_label:
		anon_weekly_score_label.text = "This Week: %d" % weekly_score
	if anon_rank_label:
		if rank > 0:
			anon_rank_label.text = "Rank: #%d" % rank
		else:
			anon_rank_label.text = "Rank: --"
	if anon_plays_label:
		anon_plays_label.text = "Games Played: %d" % play_count

func _update_anon_achievement_button():
	"""Update achievement button text on anonymous panel"""
	if not anon_achievement_button:
		return
	var achievements = get_node_or_null("/root/Achievements")
	if achievements and achievements.has_method("get_unlocked_count"):
		var unlocked = achievements.get_unlocked_count()
		var total = achievements.get_total_count()
		anon_achievement_button.text = "Achievements (%d/%d)" % [unlocked, total]

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
	if anonymous_panel:
		anonymous_panel.visible = false
	
	welcome_label.text = "Loading..."
	if weekly_score_label:
		weekly_score_label.text = "This Week: --"
	if rank_label:
		rank_label.text = "Rank: --"
	if plays_label:
		plays_label.text = "Games Played: --"
	
	_set_main_buttons_disabled(true)

func _show_main_panel(profile: Dictionary):
	"""Show main panel with profile (logged in with real account)"""
	_log("Showing main panel with profile: %s" % str(profile))
	
	waiting_for_profile = false
	_stop_all_timers()
	
	login_panel.visible = false
	main_panel.visible = true
	if name_entry_panel:
		name_entry_panel.visible = false
	if anonymous_panel:
		anonymous_panel.visible = false
	
	var nickname = str(profile.get("nickname", profile.get("username", "Player")))
	var weekly = int(profile.get("score", 0))
	var play_count = int(profile.get("playCount", profile.get("plays", 0)))
	var rank = int(profile.get("rank", 0))
	
	welcome_label.text = "Welcome, %s!" % nickname
	if weekly_score_label:
		weekly_score_label.text = "This Week: %d" % weekly
	if rank_label:
		if rank > 0:
			rank_label.text = "Rank: #%d" % rank
		else:
			rank_label.text = "Rank: --"
	if plays_label:
		plays_label.text = "Games Played: %d" % play_count
	
	_update_achievement_button()
	_set_main_buttons_disabled(false)
	
	if rank == 0:
		_fetch_player_rank()

func _update_main_panel_stats(profile: Dictionary):
	"""Update stats on main panel"""
	var nickname = str(profile.get("nickname", "Player"))
	var weekly = int(profile.get("score", 0))
	var play_count = int(profile.get("playCount", profile.get("plays", 0)))
	var rank = int(profile.get("rank", 0))
	
	welcome_label.text = "Welcome, %s!" % nickname
	if weekly_score_label:
		weekly_score_label.text = "This Week: %d" % weekly
	if rank_label:
		if rank > 0:
			rank_label.text = "Rank: #%d" % rank
		else:
			rank_label.text = "Rank: --"
	if plays_label:
		plays_label.text = "Games Played: %d" % play_count
	
	_update_achievement_button()
	
	if rank == 0:
		_fetch_player_rank()

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
	if logout_button:
		logout_button.disabled = false  # Always allow logout

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
	
	if OS.get_name() == "Web" and _is_mobile_web():
		_show_mobile_name_prompt()
		return
	
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
	"""Exit game"""
	_log("Exit pressed")
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.location.href = 'https://cheddagames.com'")
	else:
		get_tree().quit()

# ============================================================
# ANONYMOUS PANEL BUTTON HANDLERS
# ============================================================

func _on_anon_play_pressed():
	"""Start game from anonymous dashboard"""
	_log("Anonymous play pressed")
	
	# Ensure we're logged in anonymously
	CheddaBoards.set_player_id(anonymous_player_id)
	CheddaBoards.login_anonymous(anonymous_nickname)
	
	get_tree().change_scene_to_file(SCENE_GAME)

func _on_anon_change_name_pressed():
	"""Change name from anonymous dashboard"""
	_log("Anonymous change name pressed")
	_show_name_entry_panel()

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

func _generate_default_name() -> String:
	"""Generate a unique default name like 'Player_4829'"""
	randomize()
	var suffix = str(randi() % 10000).pad_zeros(4)
	return "Player_%s" % suffix

func _show_mobile_name_prompt():
	"""Show native prompt for mobile web users"""
	var default_name = anonymous_nickname if anonymous_nickname != "" else _generate_default_name()
	var js_code = "prompt('Enter your name:', '%s')" % default_name.replace("'", "\\'")
	var result = JavaScriptBridge.eval(js_code, true)
	
	if result == null or str(result) == "null" or str(result).strip_edges() == "":
		_log("Mobile prompt cancelled")
		return
	
	var name_text = str(result).strip_edges()
	
	if name_text.length() < MIN_NAME_LENGTH or name_text.length() > MAX_NAME_LENGTH:
		JavaScriptBridge.eval("alert('Name must be %d-%d characters')" % [MIN_NAME_LENGTH, MAX_NAME_LENGTH], true)
		return
	
	anonymous_nickname = name_text
	_mark_anonymous_has_played()
	
	CheddaBoards.set_player_id(anonymous_player_id)
	CheddaBoards.change_nickname(name_text)
	CheddaBoards.login_anonymous(name_text)
	
	_log("Starting game as: %s (ID: %s)" % [anonymous_nickname, anonymous_player_id])
	get_tree().change_scene_to_file(SCENE_GAME)

func _on_name_text_changed(_new_text: String):
	"""Handle name text changes"""
	_update_confirm_button_state()
	name_status_label.text = ""

func _on_name_submitted(_name_text: String):
	"""Handle Enter key in name field"""
	if not confirm_name_button.disabled:
		_on_confirm_name_pressed()

func _on_confirm_name_pressed():
	"""Confirm name and start game"""
	var name_text = name_line_edit.text.strip_edges()
	
	_log("=== NAME CONFIRMATION ===")
	_log("Entered name: '%s'" % name_text)
	_log("Player ID: '%s'" % anonymous_player_id)
	
	if name_text.length() < MIN_NAME_LENGTH:
		name_status_label.text = "Name too short (min %d characters)" % MIN_NAME_LENGTH
		name_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	if name_text.length() > MAX_NAME_LENGTH:
		name_status_label.text = "Name too long (max %d characters)" % MAX_NAME_LENGTH
		name_status_label.add_theme_color_override("font_color", Color.RED)
		return
	
	anonymous_nickname = name_text
	_mark_anonymous_has_played()
	
	CheddaBoards.set_player_id(anonymous_player_id)
	CheddaBoards.change_nickname(name_text)
	CheddaBoards.login_anonymous(name_text)
	
	_log("Starting game as: %s (ID: %s)" % [anonymous_nickname, anonymous_player_id])
	get_tree().change_scene_to_file(SCENE_GAME)

func _on_cancel_name_pressed():
	"""Cancel name entry, go back to previous panel"""
	_log("Name entry cancelled")
	if anonymous_has_played:
		_show_anonymous_panel()
	else:
		_show_login_panel()

# ============================================================
# CHEDDABOARDS SIGNAL HANDLERS
# ============================================================

func _on_login_success(nickname: String):
	"""Login succeeded"""
	_log("Login success: %s" % nickname)
	_clear_ui_timeout()
	is_logging_in = false
	
	if _is_test_submission:
		_is_test_submission = false
		return
	
	# Silent login is just for anonymous dashboard
	if _is_silent_login:
		_is_silent_login = false
		_log("Silent login complete - loading anonymous stats")
		await get_tree().create_timer(0.3).timeout
		_load_anonymous_stats()
		return
	
	_show_main_panel_loading()
	waiting_for_profile = true
	profile_load_attempts = 0
	_request_profile_with_timeout()

func _on_login_failed(reason: String):
	"""Login failed"""
	_log("Login failed: %s" % reason)
	_clear_ui_timeout()
	_set_status("Login failed: %s" % reason, true)
	_enable_login_buttons(true)
	_stop_all_timers()
	is_logging_in = false

func _on_login_timeout():
	"""Login timeout from SDK"""
	_log("Login timeout signal")
	_clear_ui_timeout()
	_set_status("Login took too long. Please try again.", true)
	_enable_login_buttons(true)
	_stop_all_timers()
	is_logging_in = false

func _on_profile_loaded(nickname: String, score: int, _streak: int, achievements: Array):
	"""Profile loaded from backend"""
	_log("Profile loaded: %s (weekly score: %d)" % [nickname, score])
	
	var cached = CheddaBoards.get_cached_profile()
	var play_count = 0
	
	if not cached.is_empty():
		play_count = int(cached.get("playCount", cached.get("plays", 0)))
	
	var profile = {
		"nickname": nickname,
		"score": score,
		"playCount": play_count,
		"achievements": achievements
	}
	
	if main_panel.visible:
		_update_main_panel_stats(profile)
	elif anonymous_panel and anonymous_panel.visible:
		_update_anonymous_panel_stats_direct(score, play_count)
	
	if waiting_for_profile:
		waiting_for_profile = false
		_stop_all_timers()
		if not main_panel.visible and not anonymous_panel.visible:
			_show_main_panel(profile)

func _on_no_profile():
	"""No profile found"""
	_log("No profile signal")
	
	if not CheddaBoards.has_account() and not is_logging_in:
		_stop_all_timers()
		waiting_for_profile = false
		_show_login_panel()
	elif is_logging_in:
		pass
	else:
		_stop_all_timers()
		waiting_for_profile = false
		_show_main_panel({
			"nickname": CheddaBoards.get_nickname(),
			"score": 0,
			"streak": 0,
			"playCount": 0
		})

func _on_logout_success():
	"""Logout completed"""
	_log("Logout success")
	is_logging_in = false
	_show_login_panel()

func _on_nickname_changed(new_nickname: String):
	"""Nickname changed"""
	_log("Nickname changed: %s" % new_nickname)
	if main_panel.visible:
		welcome_label.text = "Welcome, %s!" % new_nickname
	elif anonymous_panel and anonymous_panel.visible:
		anon_welcome_label.text = "Welcome back, %s!" % new_nickname

# ============================================================
# MAIN PANEL BUTTON HANDLERS
# ============================================================

func _on_play_button_pressed():
	"""Start game (logged in)"""
	_log("Play pressed")
	get_tree().change_scene_to_file(SCENE_GAME)

func _on_change_nickname_pressed():
	"""Change nickname"""
	_log("Change nickname pressed")
	CheddaBoards.change_nickname()

func _on_leaderboard_pressed():
	"""View leaderboard"""
	_log("Leaderboard pressed")
	get_tree().change_scene_to_file(SCENE_LEADERBOARD)

func _on_achievements_pressed():
	"""View achievements"""
	_log("Achievements pressed")
	get_tree().change_scene_to_file(SCENE_ACHIEVEMENTS)

func _on_logout_pressed():
	"""Logout"""
	_log("Logout pressed")
	CheddaBoards.logout()

# ============================================================
# PUBLIC GETTERS
# ============================================================

func get_anonymous_nickname() -> String:
	"""Get the saved anonymous nickname"""
	return anonymous_nickname

func get_anonymous_player_id() -> String:
	"""Get the anonymous player ID"""
	return anonymous_player_id

func has_anonymous_played() -> bool:
	"""Check if anonymous player has played at least once"""
	return anonymous_has_played

# ============================================================
# DEBUG / TESTING
# ============================================================

func _test_submit_random_score():
	"""F7 - Submit single random score for testing leaderboard"""
	randomize()
	var test_name = "Test_%04d" % (randi() % 10000)
	var test_score = randi_range(500, 7000)
	var test_streak = randi_range(1, 10)
	var test_id = "test_%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000]
	
	_is_test_submission = true
	CheddaBoards.set_player_id(test_id)
	CheddaBoards.login_anonymous(test_name)
	CheddaBoards.submit_score(test_score, test_streak)
	
	_log("TEST: %s submitted %d pts (streak: %d)" % [test_name, test_score, test_streak])
	_set_status("Test: %s - %d pts" % [test_name, test_score], false)

func _test_submit_bulk_scores(count: int = 5):
	"""F6 - Submit multiple random scores for testing"""
	_log("TEST: Submitting %d random scores..." % count)
	_set_status("Submitting %d test scores..." % count, false)
	
	for i in count:
		await get_tree().create_timer(2.0).timeout
		_test_submit_random_score()
	
	_log("TEST: Bulk submission complete")

# ============================================================
# LOGGING
# ============================================================

func _log(message: String):
	"""Log with timestamp"""
	if not debug_logging:
		return
	var entry = "[%d] %s" % [Time.get_ticks_msec(), message]
	state_history.append(entry)
	print("[MainMenu] %s" % message)

func _dump_debug():
	"""Dump debug info (F9)"""
	print("")
	print("========================================")
	print("       MainMenu Debug v1.5.0           ")
	print("========================================")
	print(" State")
	print("  - Is Logging In:   %s" % str(is_logging_in))
	print("  - Waiting Profile: %s" % str(waiting_for_profile))
	print("----------------------------------------")
	print(" Anonymous Player")
	print("  - Nickname:        %s" % anonymous_nickname)
	print("  - Player ID:       %s" % anonymous_player_id)
	print("  - Has Played:      %s" % str(anonymous_has_played))
	print("----------------------------------------")
	print(" CheddaBoards")
	print("  - SDK Ready:       %s" % str(CheddaBoards.is_ready()))
	print("  - Has Account:     %s" % str(CheddaBoards.has_account()))
	print("  - Is Authenticated:%s" % str(CheddaBoards.is_authenticated()))
	print("  - Is Anonymous:    %s" % str(CheddaBoards.is_anonymous()))
	print("  - Nickname:        %s" % CheddaBoards.get_nickname())
	print("----------------------------------------")
	print(" Debug Shortcuts")
	print("  - F6: Submit 5 random test scores")
	print("  - F7: Submit 1 random test score")
	print("  - F8: Force profile refresh")
	print("  - F9: This debug dump")
	print("========================================")
	print("")

# ============================================================
# CLEANUP
# ============================================================

func _exit_tree():
	"""Cleanup"""
	_stop_all_timers()
