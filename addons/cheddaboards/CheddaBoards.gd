# MainMenu.gd v1.7.0
# Main menu with authentication flow, profile display, roguelike progression, and upgrade shop
# - Login panel: PLAY NOW (with name entry), Shop, Leaderboard, and login buttons
# - Name entry panel: For anonymous players to set their display name
# - Main panel: Profile stats when logged in (Google/Apple/Chedda)
# - Fixed: Landscape scrolling support for mobile
# https://github.com/cheddatech/CheddaBoards-Godot
#
# ============================================================
# SETUP
# ============================================================
# Required Autoloads (in order):
#   - CheddaBoards
#   - RunManager
#   - UpgradeManager
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
const SCENE_SETTINGS: String = "res://Settings.tscn"
const SCENE_SHOP: String = "res://UpgradeShop.tscn"
const DEVICE_ID_FILE: String = "user://device_id.txt"

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
@onready var login_shop_button = $LoginPanel/MarginContainer/VBoxContainer/ShopButton
@onready var login_leaderboard_button = $LoginPanel/MarginContainer/VBoxContainer/LeaderboardButton
@onready var google_button = $LoginPanel/MarginContainer/VBoxContainer/GoogleButton
@onready var apple_button = $LoginPanel/MarginContainer/VBoxContainer/AppleButton
@onready var chedda_button = $LoginPanel/MarginContainer/VBoxContainer/CheddaButton
@onready var exit_button = $LoginPanel/MarginContainer/VBoxContainer/ExitButton
@onready var status_label = $LoginPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var login_cheese_bank_label = $LoginPanel/CheeseBankLabel
@onready var login_best_progress_label = $LoginPanel/BestProgressLabel

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
@onready var main_shop_button = $MainPanel/MarginContainer/VBoxContainer/ShopButton
@onready var change_nickname_button = $MainPanel/MarginContainer/VBoxContainer/ChangeNicknameButton
@onready var achievement_button = $MainPanel/MarginContainer/VBoxContainer/AchievementsButton
@onready var leaderboard_button = $MainPanel/MarginContainer/VBoxContainer/LeaderboardButton
@onready var settings_button = $MainPanel/MarginContainer/VBoxContainer/SettingsButton
@onready var logout_button = $MainPanel/MarginContainer/VBoxContainer/LogoutButton
@onready var main_cheese_bank_label = $MainPanel/CheeseBankLabel
@onready var main_best_progress_label = $MainPanel/BestProgressLabel

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

# Test mode flag
var _is_test_submission: bool = false

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
	if login_shop_button:
		login_shop_button.pressed.connect(_on_shop_pressed)
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
	if main_shop_button:
		main_shop_button.pressed.connect(_on_shop_pressed)
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
	
	# Apply mobile-responsive UI scaling
	_adapt_for_mobile()
	
	# Add scroll support for landscape mode
	_add_scroll_support()
	
	_log("MainMenu v1.7.0 initialized")
	
	# Check if SDK already ready
	if CheddaBoards.is_ready():
		_on_sdk_ready()

func _add_scroll_support():
	"""Wrap panel contents in ScrollContainers for landscape mobile support"""
	_wrap_panel_in_scroll(login_panel)
	_wrap_panel_in_scroll(main_panel)
	if name_entry_panel:
		_wrap_panel_in_scroll(name_entry_panel)
	print("[MainMenu] Scroll support added for landscape mode")

func _wrap_panel_in_scroll(panel: Control):
	"""Wrap a panel's MarginContainer content in a ScrollContainer"""
	if not panel:
		return
	
	var margin_container = panel.get_node_or_null("MarginContainer")
	if not margin_container:
		return
	
	var vbox = margin_container.get_node_or_null("VBoxContainer")
	if not vbox:
		return
	
	# Remove VBox from MarginContainer
	margin_container.remove_child(vbox)
	
	# Create ScrollContainer that fills the space
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	# Create a wrapper VBox that expands to fill scroll viewport
	# This ensures content is centered when smaller than viewport
	var wrapper = VBoxContainer.new()
	wrapper.name = "ScrollWrapper"
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# The wrapper needs to be at least as tall as the scroll viewport
	# We achieve this by connecting to the scroll's resized signal
	scroll.resized.connect(func(): 
		wrapper.custom_minimum_size.y = scroll.size.y
	)
	
	# Add original VBox to wrapper (centered)
	wrapper.add_child(vbox)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Add wrapper to scroll
	scroll.add_child(wrapper)
	
	# Add scroll to MarginContainer
	margin_container.add_child(scroll)
	
	# Trigger initial size
	await panel.get_tree().process_frame
	if scroll.size.y > 0:
		wrapper.custom_minimum_size.y = scroll.size.y

func _adapt_for_mobile() -> void:
	"""Apply mobile-responsive UI scaling using MobileUI autoload"""
	var is_mobile = MobileUI.is_mobile
	
	# === LOGIN PANEL ===
	if direct_play_button:
		MobileUI.scale_button(direct_play_button, 22 if is_mobile else 18, 60 if is_mobile else 44)
	if login_shop_button:
		MobileUI.scale_button(login_shop_button, 20 if is_mobile else 16, 50 if is_mobile else 40)
	if login_leaderboard_button:
		MobileUI.scale_button(login_leaderboard_button, 20 if is_mobile else 16, 50 if is_mobile else 40)
	if google_button:
		MobileUI.scale_button(google_button, 18 if is_mobile else 14, 50 if is_mobile else 40)
	if apple_button:
		MobileUI.scale_button(apple_button, 18 if is_mobile else 14, 50 if is_mobile else 40)
	if chedda_button:
		MobileUI.scale_button(chedda_button, 18 if is_mobile else 14, 50 if is_mobile else 40)
	if exit_button:
		MobileUI.scale_button(exit_button, 16 if is_mobile else 14, 44 if is_mobile else 36)
	if status_label:
		status_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(16))
	if login_cheese_bank_label:
		login_cheese_bank_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(20))
	if login_best_progress_label:
		login_best_progress_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(14))
	
	# === NAME ENTRY PANEL ===
	if name_line_edit:
		name_line_edit.add_theme_font_size_override("font_size", MobileUI.get_font_size(20))
		name_line_edit.custom_minimum_size.y = MobileUI.get_touch_size(50)
	if confirm_name_button:
		MobileUI.scale_button(confirm_name_button, 20, 50)
	if cancel_name_button:
		MobileUI.scale_button(cancel_name_button, 18, 44)
	if name_status_label:
		name_status_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(14))
	
	# === MAIN PANEL ===
	if welcome_label:
		welcome_label.add_theme_font_size_override("font_size", MobileUI.get_title_font_size())
	if score_label:
		score_label.add_theme_font_size_override("font_size", MobileUI.get_hud_font_size())
	if streak_label:
		streak_label.add_theme_font_size_override("font_size", MobileUI.get_hud_font_size())
	if plays_label:
		plays_label.add_theme_font_size_override("font_size", MobileUI.get_hud_font_size())
	if play_button:
		MobileUI.scale_button(play_button, 24 if is_mobile else 20, 60 if is_mobile else 50)
	if main_shop_button:
		MobileUI.scale_button(main_shop_button, 20 if is_mobile else 16, 50 if is_mobile else 40)
	if change_nickname_button:
		MobileUI.scale_button(change_nickname_button, 18 if is_mobile else 14, 44 if is_mobile else 36)
	if achievement_button:
		MobileUI.scale_button(achievement_button, 18 if is_mobile else 14, 44 if is_mobile else 36)
	if leaderboard_button:
		MobileUI.scale_button(leaderboard_button, 18 if is_mobile else 14, 44 if is_mobile else 36)
	if settings_button:
		MobileUI.scale_button(settings_button, 18 if is_mobile else 14, 44 if is_mobile else 36)
	if logout_button:
		MobileUI.scale_button(logout_button, 16 if is_mobile else 14, 40 if is_mobile else 36)
	if main_cheese_bank_label:
		main_cheese_bank_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(20))
	if main_best_progress_label:
		main_best_progress_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(14))
	
	# Apply safe area margins on mobile
	if is_mobile:
		if login_panel:
			var margin = login_panel.get_node_or_null("MarginContainer")
			if margin:
				MobileUI.scale_container_margins(margin, 30)
		if main_panel:
			var margin = main_panel.get_node_or_null("MarginContainer")
			if margin:
				MobileUI.scale_container_margins(margin, 30)
	
	print("[MainMenu] Mobile UI adapted - Scale: %.2f" % MobileUI.ui_scale)

func _on_sdk_ready():
	"""Called when CheddaBoards SDK is ready"""
	_log("SDK ready")
	status_label.text = ""
	_enable_login_buttons(true)
	
	# Update roguelike progress display
	_update_roguelike_display()
	
	# Check for existing REAL auth (not anonymous)
	_check_existing_auth()

func _input(event):
	"""Debug keyboard shortcuts"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:
				UpgradeManager.debug_add_cheese(500)
				_update_roguelike_display()
				get_viewport().set_input_as_handled()
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
# ROGUELIKE PROGRESSION DISPLAY
# ============================================================

func _update_roguelike_display():
	"""Update cheese bank and best progress labels"""
	var cheese = RunManager.cheese_bank
	var best_cycle = RunManager.highest_cycle
	var best_level = RunManager.highest_level
	
	# Update login panel labels
	if login_cheese_bank_label:
		login_cheese_bank_label.text = "🧀 %d" % cheese
	
	if login_best_progress_label:
		if best_cycle > 1 or best_level > 1:
			var level_name = _get_level_name(best_level)
			if best_cycle > 1:
				login_best_progress_label.text = "Best: %s (Cycle %d)" % [level_name, best_cycle]
			else:
				login_best_progress_label.text = "Best: %s" % level_name
			login_best_progress_label.visible = true
		else:
			login_best_progress_label.visible = false
	
	# Update main panel labels
	if main_cheese_bank_label:
		main_cheese_bank_label.text = "🧀 %d" % cheese
	
	if main_best_progress_label:
		if best_cycle > 1 or best_level > 1:
			var level_name = _get_level_name(best_level)
			if best_cycle > 1:
				main_best_progress_label.text = "Best: %s (Cycle %d)" % [level_name, best_cycle]
			else:
				main_best_progress_label.text = "Best: %s" % level_name
			main_best_progress_label.visible = true
		else:
			main_best_progress_label.visible = false
	
	# Update shop button to show upgrade count
	var purchased_count = UpgradeManager.purchased.size()
	var total_upgrades = UpgradeManager.upgrades.size()
	
	if login_shop_button:
		if purchased_count > 0:
			login_shop_button.text = "🛒 Upgrades (%d/%d)" % [purchased_count, total_upgrades]
		else:
			login_shop_button.text = "🛒 Upgrade Shop"
	
	if main_shop_button:
		if purchased_count > 0:
			main_shop_button.text = "🛒 Upgrades (%d/%d)" % [purchased_count, total_upgrades]
		else:
			main_shop_button.text = "🛒 Upgrade Shop"

func _get_level_name(level: int) -> String:
	"""Get level name from RunManager"""
	if level < 1 or level > RunManager.level_configs.size():
		return "Level %d" % level
	return RunManager.level_configs[level - 1].name

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
	
	# Update roguelike display
	_update_roguelike_display()

func _show_name_entry_panel():
	login_panel.visible = false
	main_panel.visible = false
	name_entry_panel.visible = true
	
	if not anonymous_nickname.is_empty():
		name_line_edit.text = anonymous_nickname
	else:
		name_line_edit.text = _generate_default_name()
	
	name_line_edit.placeholder_text = "Enter your name..."
	name_status_label.text = ""
	
	name_line_edit.grab_focus()
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
	_update_roguelike_display()

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
	_update_roguelike_display()

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
	_update_roguelike_display()

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
	if login_shop_button:
		login_shop_button.disabled = not enabled
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
	if main_shop_button:
		main_shop_button.disabled = disabled
	if change_nickname_button:
		change_nickname_button.disabled = disabled
	if achievement_button:
		achievement_button.disabled = disabled
	if leaderboard_button:
		leaderboard_button.disabled = disabled
	if settings_button:
		settings_button.disabled = disabled
	if logout_button:
		logout_button.disabled = false

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

func _on_shop_pressed():
	"""Open upgrade shop"""
	_log("Shop pressed")
	get_tree().change_scene_to_file(SCENE_SHOP)

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
	_save_player_data()
	
	CheddaBoards.set_player_id(anonymous_player_id)
	
	_log(">>> Calling change_nickname('%s')" % name_text)
	CheddaBoards.change_nickname(name_text)
	
	CheddaBoards.login_anonymous(name_text)
	_log("Starting game as: %s (ID: %s)" % [anonymous_nickname, anonymous_player_id])
	
	# Start new roguelike run
	RunManager.start_new_run()
	get_tree().change_scene_to_file(SCENE_GAME)

func _on_name_text_changed(_new_text: String):
	"""Handle name text changes"""
	_update_confirm_button_state()
	name_status_label.text = ""

func _on_name_submitted(name_text: String):
	"""Handle Enter key in name field"""
	if not confirm_name_button.disabled:
		_on_confirm_name_pressed()

func _on_confirm_name_pressed():
	"""Confirm name and start game"""
	var name_text = name_line_edit.text.strip_edges()
	
	_log("=== NAME CONFIRMATION ===")
	_log("Entered name: '%s'" % name_text)
	_log("Old nickname: '%s'" % anonymous_nickname)
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
	_save_player_data()
	
	CheddaBoards.set_player_id(anonymous_player_id)
	_log("Set player ID to: %s" % anonymous_player_id)
	
	_log(">>> Calling change_nickname('%s')" % name_text)
	CheddaBoards.change_nickname(name_text)
	
	_log(">>> Calling login_anonymous('%s')" % name_text)
	CheddaBoards.login_anonymous(name_text)
	
	_log("Starting game as: %s (ID: %s)" % [anonymous_nickname, anonymous_player_id])
	
	# Start new roguelike run
	RunManager.start_new_run()
	get_tree().change_scene_to_file(SCENE_GAME)

func _on_cancel_name_pressed():
	"""Cancel name entry, go back to login panel"""
	_log("Name entry cancelled")
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

func _on_profile_loaded(nickname: String, score: int, streak: int, achievements: Array):
	"""Profile loaded from backend"""
	_log("Profile loaded: %s (score: %d)" % [nickname, score])
	
	var profile = CheddaBoards.get_cached_profile()
	if profile.is_empty():
		return
	
	if main_panel.visible:
		_update_main_panel_stats(profile)
	
	if waiting_for_profile:
		waiting_for_profile = false
		_stop_all_timers()
		if not main_panel.visible:
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

# ============================================================
# MAIN PANEL BUTTON HANDLERS
# ============================================================

func _on_play_button_pressed():
	"""Start game (logged in)"""
	_log("Play pressed")
	# Start new roguelike run
	RunManager.start_new_run()
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

func _on_settings_pressed():
	"""Open settings"""
	_log("Settings pressed")
	if FileAccess.file_exists(SCENE_SETTINGS):
		get_tree().change_scene_to_file(SCENE_SETTINGS)

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
	print("       MainMenu Debug v1.7.0           ")
	print("========================================")
	print(" State")
	print("  - Is Logging In:   %s" % str(is_logging_in))
	print("  - Waiting Profile: %s" % str(waiting_for_profile))
	print("----------------------------------------")
	print(" Anonymous Player")
	print("  - Nickname:        %s" % anonymous_nickname)
	print("  - Player ID:       %s" % anonymous_player_id)
	print("----------------------------------------")
	print(" Roguelike Progress")
	print("  - Cheese Bank:     %d" % RunManager.cheese_bank)
	print("  - Best Cycle:      %d" % RunManager.highest_cycle)
	print("  - Best Level:      %d" % RunManager.highest_level)
	print("  - Total Runs:      %d" % RunManager.total_runs)
	print("  - Upgrades:        %d" % UpgradeManager.purchased.size())
	print("----------------------------------------")
	print(" CheddaBoards")
	print("  - SDK Ready:       %s" % str(CheddaBoards.is_ready()))
	print("  - Has Account:     %s" % str(CheddaBoards.has_account()))
	print("  - Is Authenticated:%s" % str(CheddaBoards.is_authenticated()))
	print("  - Is Anonymous:    %s" % str(CheddaBoards.is_anonymous()))
	print("  - Nickname:        %s" % CheddaBoards.get_nickname())
	print("----------------------------------------")
	print(" Debug Shortcuts")
	print("  - F5: Add 500 cheese")
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
