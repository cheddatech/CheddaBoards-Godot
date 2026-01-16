# Leaderboard.gd v1.5.0
# Leaderboard display with time periods, sorting options, and archive viewing
# Supports: All Time / Weekly switching + Current / Last Period archives
# v1.5.0: Added client-side sorting (fixes unsorted archive data)
# https://github.com/cheddatech/CheddaBoards-Godot
#
# ============================================================
# SETUP
# ============================================================
# Required Autoloads:
#   - CheddaBoards
#
# Required nodes in scene:
#   - MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
#   - MarginContainer/VBoxContainer/HeaderContainer/RefreshButton
#   - MarginContainer/VBoxContainer/HeaderContainer/TimeContainer/AllTimeButton
#   - MarginContainer/VBoxContainer/HeaderContainer/TimeContainer/WeeklyButton
#   - MarginContainer/VBoxContainer/HeaderContainer/PeriodContainer/CurrentButton
#   - MarginContainer/VBoxContainer/HeaderContainer/PeriodContainer/LastPeriodButton
#   - MarginContainer/VBoxContainer/HeaderContainer/SortContainer/SortByScoreButton
#   - MarginContainer/VBoxContainer/HeaderContainer/SortContainer/SortByStreakButton
#   - MarginContainer/VBoxContainer/LeaderboardScroll/LeaderboardList
#   - MarginContainer/VBoxContainer/YourRankPanel/MarginContainer/YourRankLabel
#   - MarginContainer/VBoxContainer/StatusLabel
#   - MarginContainer/VBoxContainer/ButtonsContainer/BackButton
#   - MarginContainer/VBoxContainer/ButtonsContainer/PlayAgainButton
#
# ============================================================

extends Control

# ============================================================
# CONFIGURATION
# ============================================================

## How many entries to load
const LEADERBOARD_LIMIT: int = 100

## How long to wait before timing out
const LOAD_TIMEOUT_SECONDS: float = 15.0

## Scene paths (adjust to match your project structure)
const SCENE_MAIN_MENU: String = "res://MainMenu.tscn"
const SCENE_GAME: String = "res://Game.tscn"

## Scoreboard IDs - must match your backend configuration
const SCOREBOARD_ALL_TIME: String = "all-time"  #
const SCOREBOARD_WEEKLY: String = "weekly"

## Which scoreboard to show by default (change to match your preference)
@export var scoreboard_id: String = "weekly"

# ============================================================
# NODE REFERENCES - HEADER
# ============================================================

@onready var title_label = $MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var refresh_button = $MarginContainer/VBoxContainer/HeaderContainer/RefreshButton

# ============================================================
# NODE REFERENCES - TIME PERIOD BUTTONS (All Time / Weekly)
# ============================================================

@onready var time_container = $MarginContainer/VBoxContainer/HeaderContainer/TimeContainer if has_node("MarginContainer/VBoxContainer/HeaderContainer/TimeContainer") else null
@onready var all_time_button = $MarginContainer/VBoxContainer/HeaderContainer/TimeContainer/AllTimeButton if time_container else null
@onready var weekly_button = $MarginContainer/VBoxContainer/HeaderContainer/TimeContainer/WeeklyButton if time_container else null

# ============================================================
# NODE REFERENCES - ARCHIVE BUTTONS (Current / Last Period)
# ============================================================

@onready var period_container = $MarginContainer/VBoxContainer/HeaderContainer/PeriodContainer if has_node("MarginContainer/VBoxContainer/HeaderContainer/PeriodContainer") else null
@onready var current_button = $MarginContainer/VBoxContainer/HeaderContainer/PeriodContainer/CurrentButton if period_container else null
@onready var last_period_button = $MarginContainer/VBoxContainer/HeaderContainer/PeriodContainer/LastPeriodButton if period_container else null

# ============================================================
# NODE REFERENCES - SORT BUTTONS
# ============================================================

@onready var sort_by_score_button = $MarginContainer/VBoxContainer/HeaderContainer/SortContainer/SortByScoreButton
@onready var sort_by_streak_button = $MarginContainer/VBoxContainer/HeaderContainer/SortContainer/SortByStreakButton

# ============================================================
# NODE REFERENCES - LEADERBOARD DISPLAY
# ============================================================

@onready var leaderboard_list = $MarginContainer/VBoxContainer/LeaderboardScroll/LeaderboardList
@onready var your_rank_label = $MarginContainer/VBoxContainer/YourRankPanel/MarginContainer/YourRankLabel
@onready var status_label = $MarginContainer/VBoxContainer/StatusLabel

# ============================================================
# NODE REFERENCES - NAVIGATION BUTTONS
# ============================================================

@onready var back_button = $MarginContainer/VBoxContainer/ButtonsContainer/BackButton
@onready var play_again_button = $MarginContainer/VBoxContainer/ButtonsContainer/PlayAgainButton

# ============================================================
# STATE
# ============================================================

## Current sort method: "score" or "streak"
var current_sort_by: String = "score"

## Whether we're currently loading data
var is_loading: bool = false

## Timer for load timeout
var load_timeout_timer: Timer = null

## Current player's nickname for highlighting their entry
var current_player_nickname: String = ""

## View mode: "current" for live scoreboard, "archive" for past period
var view_mode: String = "current"

## Cached archive configuration for display purposes
var current_archive_config: Dictionary = {}

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	"""Initialize the leaderboard scene"""
	# Wait for CheddaBoards to be ready
	if not CheddaBoards.is_ready():
		status_label.text = "Connecting..."
		await CheddaBoards.wait_until_ready()
	
	# Get current player's nickname for highlighting
	current_player_nickname = _get_player_nickname()
	
	# Connect header buttons
	refresh_button.pressed.connect(_on_refresh_pressed)
	
	# Connect time period buttons (All Time / Weekly)
	if all_time_button:
		all_time_button.pressed.connect(_on_all_time_pressed)
	if weekly_button:
		weekly_button.pressed.connect(_on_weekly_pressed)
	
	# Connect archive buttons (Current / Last Period)
	if current_button:
		current_button.pressed.connect(_on_current_pressed)
	if last_period_button:
		last_period_button.pressed.connect(_on_last_period_pressed)
	
	# Connect sort buttons
	sort_by_score_button.pressed.connect(_on_sort_by_score_pressed)
	sort_by_streak_button.pressed.connect(_on_sort_by_streak_pressed)
	
	# Connect navigation buttons
	back_button.pressed.connect(_on_back_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)
	
	# Connect CheddaBoards signals - Legacy
	CheddaBoards.leaderboard_loaded.connect(_on_leaderboard_loaded)
	CheddaBoards.player_rank_loaded.connect(_on_player_rank_loaded)
	CheddaBoards.rank_error.connect(_on_rank_error)
	
	# Connect CheddaBoards signals - Scoreboards
	CheddaBoards.scoreboard_loaded.connect(_on_scoreboard_loaded)
	CheddaBoards.scoreboard_rank_loaded.connect(_on_scoreboard_rank_loaded)
	CheddaBoards.scoreboard_error.connect(_on_scoreboard_error)
	
	# Connect CheddaBoards signals - Archives
	CheddaBoards.archived_scoreboard_loaded.connect(_on_archived_scoreboard_loaded)
	CheddaBoards.archive_error.connect(_on_archive_error)
	
	# Update all button states
	_update_all_buttons()
	
	# Initial load
	_load_leaderboard()
	
	print("[Leaderboard] v1.5.0 initialized")

# ============================================================
# LOADING FUNCTIONS
# ============================================================

func _load_leaderboard():
	"""Load leaderboard data - works with or without login"""
	if is_loading:
		print("[Leaderboard] Already loading, ignoring request")
		return
	
	is_loading = true
	_set_loading_ui(true)
	
	# Clear existing entries
	_clear_leaderboard()
	
	# Show loading state
	status_label.text = "Loading..."
	status_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Update button states
	_update_all_buttons()
	
	# Start timeout timer
	_start_load_timeout()
	
	if view_mode == "archive":
		# Load archived scoreboard (past period results)
		print("[Leaderboard] Requesting last archive for '%s'" % scoreboard_id)
		CheddaBoards.get_last_archived_scoreboard(scoreboard_id, LEADERBOARD_LIMIT)
		your_rank_label.text = "Viewing past results"
		your_rank_label.add_theme_color_override("font_color", Color.GRAY)
	else:
		# Load current scoreboard
		print("[Leaderboard] Requesting scoreboard '%s' (limit: %d)" % [scoreboard_id, LEADERBOARD_LIMIT])
		CheddaBoards.get_scoreboard(scoreboard_id, LEADERBOARD_LIMIT)
		
		# Only request player rank if user has a real account
		if CheddaBoards.has_account():
			your_rank_label.text = "Loading your rank..."
			CheddaBoards.get_scoreboard_rank(scoreboard_id)
		else:
			your_rank_label.text = "Login to see your rank"
			your_rank_label.add_theme_color_override("font_color", Color.GRAY)

func _set_loading_ui(loading: bool):
	"""Update UI elements based on loading state"""
	refresh_button.disabled = loading
	_update_all_buttons()

func _clear_leaderboard():
	"""Clear all leaderboard entries from the list"""
	for child in leaderboard_list.get_children():
		child.queue_free()

# ============================================================
# BUTTON STATE MANAGEMENT
# ============================================================

func _update_all_buttons():
	"""Update all button states based on current settings"""
	# Sort buttons
	sort_by_score_button.disabled = is_loading or current_sort_by == "score"
	sort_by_streak_button.disabled = is_loading or current_sort_by == "streak"
	
	# Time period buttons (All Time / Weekly)
	if all_time_button:
		all_time_button.disabled = is_loading or scoreboard_id == SCOREBOARD_ALL_TIME
	if weekly_button:
		weekly_button.disabled = is_loading or scoreboard_id == SCOREBOARD_WEEKLY
	
	# Hide archive buttons for all-time (no archives for all-time scoreboard)
	var show_archive_buttons = (scoreboard_id != SCOREBOARD_ALL_TIME)
	if period_container:
		period_container.visible = show_archive_buttons
	
	# Archive buttons (Current / Last Period)
	if current_button:
		current_button.disabled = is_loading or view_mode == "current"
	if last_period_button:
		last_period_button.disabled = is_loading or view_mode == "archive"
		_update_last_period_button_text()

func _update_last_period_button_text():
	"""Set the text for the 'last period' button based on scoreboard type"""
	if not last_period_button:
		return
	
	if scoreboard_id == SCOREBOARD_WEEKLY:
		last_period_button.text = "Last Week"
	elif scoreboard_id.contains("daily"):
		last_period_button.text = "Yesterday"
	elif scoreboard_id.contains("monthly"):
		last_period_button.text = "Last Month"
	else:
		last_period_button.text = "Previous"

# ============================================================
# PLAYER NICKNAME HELPER
# ============================================================

func _get_player_nickname() -> String:
	"""Get player nickname with proper fallbacks for anonymous players"""
	# First try CheddaBoards
	var nickname = CheddaBoards.get_nickname()
	
	# If it's "Player" or empty, check local save file (for anonymous players)
	if nickname == "Player" or nickname.is_empty():
		var save_path = "user://player_data.save"
		if FileAccess.file_exists(save_path):
			var file = FileAccess.open(save_path, FileAccess.READ)
			if file:
				var data = file.get_var()
				file.close()
				if data is Dictionary and data.has("nickname"):
					var saved_nickname = data.get("nickname", "")
					if not saved_nickname.is_empty():
						print("[Leaderboard] Using saved nickname: %s" % saved_nickname)
						return saved_nickname
	
	return nickname

# ============================================================
# TIMEOUT HANDLING
# ============================================================

func _start_load_timeout():
	"""Start timeout timer for loading"""
	_clear_load_timeout()
	
	load_timeout_timer = Timer.new()
	load_timeout_timer.wait_time = LOAD_TIMEOUT_SECONDS
	load_timeout_timer.one_shot = true
	load_timeout_timer.timeout.connect(_on_load_timeout)
	add_child(load_timeout_timer)
	load_timeout_timer.start()

func _clear_load_timeout():
	"""Clear timeout timer"""
	if load_timeout_timer:
		load_timeout_timer.stop()
		load_timeout_timer.queue_free()
		load_timeout_timer = null

func _on_load_timeout():
	"""Handle loading timeout"""
	if is_loading:
		print("[Leaderboard] Loading timed out")
		is_loading = false
		_set_loading_ui(false)
		status_label.text = "Loading timed out. Tap Refresh to try again."
		status_label.add_theme_color_override("font_color", Color.RED)

# ============================================================
# LEADERBOARD DISPLAY - SIGNAL HANDLERS
# ============================================================

func _on_leaderboard_loaded(entries: Array):
	"""Called when legacy leaderboard data is received"""
	_display_entries(entries)

func _on_scoreboard_loaded(sb_id: String, config: Dictionary, entries: Array):
	"""Called when scoreboard data is received"""
	if sb_id != scoreboard_id:
		return
	
	_update_title_from_config(config)
	_display_entries(entries)

func _on_archived_scoreboard_loaded(archive_id: String, config: Dictionary, entries: Array):
	"""Called when archived scoreboard data is received"""
	print("[Leaderboard] Archive loaded: %s with %d entries" % [archive_id, entries.size()])
	
	current_archive_config = config
	_update_title_for_archive(config)
	_display_entries(entries)

# ============================================================
# TITLE UPDATES
# ============================================================

func _update_title_from_config(config: Dictionary):
	"""Update title based on scoreboard config"""
	var name = config.get("name", _get_scoreboard_display_name())
	if current_sort_by == "streak":
		title_label.text = "%s - By Streak" % name
	else:
		title_label.text = "%s - By Score" % name

func _get_scoreboard_display_name() -> String:
	"""Get display name for current scoreboard"""
	if scoreboard_id == SCOREBOARD_ALL_TIME:
		return "All Time"
	elif scoreboard_id == SCOREBOARD_WEEKLY:
		return "Weekly"
	else:
		return scoreboard_id.capitalize()

func _update_title_for_archive(config: Dictionary):
	"""Update title for archived scoreboard with date range"""
	var name = config.get("name", _get_scoreboard_display_name())
	var period_start = config.get("periodStart", 0)
	var period_end = config.get("periodEnd", 0)
	
	# Convert nanoseconds to human-readable dates
	var start_date = _format_timestamp(period_start)
	var end_date = _format_timestamp(period_end)
	
	if start_date != "" and end_date != "":
		title_label.text = "%s: %s - %s" % [name, start_date, end_date]
	else:
		title_label.text = "%s (Previous Period)" % name

func _format_timestamp(timestamp_ns: int) -> String:
	"""Convert nanosecond timestamp to readable date"""
	if timestamp_ns == 0:
		return ""
	
	# Convert nanoseconds to seconds
	var timestamp_s = timestamp_ns / 1_000_000_000
	
	# Create dictionary from unix time
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp_s)
	
	return "%d/%d/%d" % [datetime.day, datetime.month, datetime.year]

# ============================================================
# LEADERBOARD DISPLAY - ENTRIES
# ============================================================

func _display_entries(entries: Array):
	"""Display leaderboard entries"""
	print("[Leaderboard] Displaying %d entries" % entries.size())
	
	_clear_load_timeout()
	is_loading = false
	_set_loading_ui(false)
	
	if entries.is_empty():
		if view_mode == "archive":
			status_label.text = "No archived data available yet"
		else:
			status_label.text = "No players yet. Be the first!"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
		return
	
	status_label.text = "%d players" % entries.size()
	status_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Clear existing entries
	_clear_leaderboard()
	
	# Sort entries client-side (archives may come unsorted from backend)
	var sorted_entries = _sort_entries(entries)
	
	# Add entries
	for i in range(sorted_entries.size()):
		var entry = sorted_entries[i]
		_add_leaderboard_entry(i + 1, entry)

func _sort_entries(entries: Array) -> Array:
	"""Sort entries by current sort method (score or streak), descending"""
	var sorted = entries.duplicate()
	
	sorted.sort_custom(func(a, b):
		var a_value = _get_sort_value(a)
		var b_value = _get_sort_value(b)
		return a_value > b_value  # Descending order (highest first)
	)
	
	return sorted

func _get_sort_value(entry) -> int:
	"""Extract the sort value from an entry based on current_sort_by"""
	if typeof(entry) == TYPE_ARRAY:
		# Array format: [nickname, score, streak]
		if current_sort_by == "streak":
			return entry[2] if entry.size() > 2 else 0
		else:
			return entry[1] if entry.size() > 1 else 0
	elif typeof(entry) == TYPE_DICTIONARY:
		# Dictionary format
		if current_sort_by == "streak":
			return entry.get("streak", entry.get("bestStreak", 0))
		else:
			return entry.get("score", entry.get("highScore", 0))
	return 0

func _add_leaderboard_entry(rank: int, entry) -> void:
	"""Add a single leaderboard entry (handles both array and dictionary formats)"""
	
	# Parse entry - handle both formats
	var nickname: String
	var score: int
	var streak: int
	
	if typeof(entry) == TYPE_ARRAY:
		# Array format: [nickname, score, streak] or [nickname, score]
		nickname = str(entry[0]) if entry.size() > 0 else "Unknown"
		score = entry[1] if entry.size() > 1 else 0
		streak = entry[2] if entry.size() > 2 else 0
	elif typeof(entry) == TYPE_DICTIONARY:
		# Dictionary format
		nickname = str(entry.get("nickname", entry.get("username", "Unknown")))
		score = entry.get("score", entry.get("highScore", 0))
		streak = entry.get("streak", entry.get("bestStreak", 0))
	else:
		push_warning("[Leaderboard] Unknown entry format: %s" % typeof(entry))
		return
	
	# Check if this is the current player (only highlight in current view)
	var is_current_player = (nickname == current_player_nickname) and current_player_nickname != "" and view_mode == "current"
	
	# Create entry container
	var entry_container = PanelContainer.new()
	entry_container.custom_minimum_size = Vector2(0, 50)
	
	# Highlight current player or archive winner
	if is_current_player:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color(0.2, 0.5, 0.2, 0.4)  # Green tint for current player
		stylebox.set_corner_radius_all(5)
		entry_container.add_theme_stylebox_override("panel", stylebox)
	elif view_mode == "archive" and rank == 1:
		# Highlight the winner in archive view with gold
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color(0.5, 0.4, 0.1, 0.4)  # Gold tint for winner
		stylebox.set_corner_radius_all(5)
		entry_container.add_theme_stylebox_override("panel", stylebox)
	
	# Add margin container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	entry_container.add_child(margin)
	
	# Create horizontal layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)
	
	# Rank label with medal colors for top 3
	var rank_label = Label.new()
	rank_label.custom_minimum_size = Vector2(60, 0)
	rank_label.add_theme_font_size_override("font_size", 26)
	
	match rank:
		1:
			rank_label.text = "#1"
			rank_label.add_theme_color_override("font_color", Color.GOLD)
		2:
			rank_label.text = "#2"
			rank_label.add_theme_color_override("font_color", Color.SILVER)
		3:
			rank_label.text = "#3"
			rank_label.add_theme_color_override("font_color", Color("#CD7F32"))  # Bronze
		_:
			rank_label.text = "#%d" % rank
	
	hbox.add_child(rank_label)
	
	# Nickname label (with crown emoji for archive winner)
	var nickname_label = Label.new()
	nickname_label.text = nickname
	nickname_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nickname_label.add_theme_font_size_override("font_size", 24)
	
	# Add crown emoji for archive winner
	if view_mode == "archive" and rank == 1:
		nickname_label.text = "👑 " + nickname
	
	hbox.add_child(nickname_label)
	
	# Score/Streak value label
	var value_label = Label.new()
	if current_sort_by == "score":
		value_label.text = "%d pts" % score
	else:
		value_label.text = "%d streak" % streak
	
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(120, 0)
	value_label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(value_label)
	
	# Add to list
	leaderboard_list.add_child(entry_container)

# ============================================================
# PLAYER RANK DISPLAY
# ============================================================

func _on_player_rank_loaded(rank: int, score: int, streak: int, total_players: int):
	"""Called when legacy player rank is received"""
	_display_player_rank(rank, score, streak, total_players)

func _on_scoreboard_rank_loaded(sb_id: String, rank: int, score: int, streak: int, total: int):
	"""Called when scoreboard player rank is received"""
	if sb_id != scoreboard_id:
		return
	_display_player_rank(rank, score, streak, total)

func _display_player_rank(rank: int, score: int, streak: int, total_players: int):
	"""Display player rank info"""
	print("[Leaderboard] Your rank: #%d / %d players" % [rank, total_players])
	
	if rank == 0:
		your_rank_label.text = "Not ranked yet - play a game to get on the leaderboard!"
	else:
		var rank_text = "Your Rank: #%d of %d" % [rank, total_players]
		
		if current_sort_by == "score":
			rank_text += "  |  Score: %d" % score
		else:
			rank_text += "  |  Streak: %d" % streak
		
		# Add encouraging message for top ranks
		if rank == 1:
			rank_text += "   You're #1!"
		elif rank <= 3:
			rank_text += "   Top 3!"
		elif rank <= 10:
			rank_text += "   Top 10!"
		
		your_rank_label.text = rank_text
		your_rank_label.add_theme_color_override("font_color", Color.WHITE)

# ============================================================
# ERROR HANDLERS
# ============================================================

func _on_rank_error(reason: String):
	"""Called when rank fetch fails"""
	print("[Leaderboard] Rank error: %s" % reason)
	your_rank_label.text = "Login to see your rank"
	your_rank_label.add_theme_color_override("font_color", Color.GRAY)

func _on_scoreboard_error(reason: String):
	"""Called when scoreboard fetch fails"""
	print("[Leaderboard] Scoreboard error: %s" % reason)
	_clear_load_timeout()
	is_loading = false
	_set_loading_ui(false)
	status_label.text = "Error loading leaderboard"
	status_label.add_theme_color_override("font_color", Color.RED)

func _on_archive_error(reason: String):
	"""Called when archive fetch fails"""
	print("[Leaderboard] Archive error: %s" % reason)
	_clear_load_timeout()
	is_loading = false
	_set_loading_ui(false)
	status_label.text = "No archived data available"
	status_label.add_theme_color_override("font_color", Color.YELLOW)

# ============================================================
# BUTTON HANDLERS - TIME PERIOD (All Time / Weekly)
# ============================================================

func _on_all_time_pressed():
	"""Switch to All Time scoreboard"""
	if scoreboard_id == SCOREBOARD_ALL_TIME:
		return
	
	print("[Leaderboard] Switching to All Time")
	scoreboard_id = SCOREBOARD_ALL_TIME
	view_mode = "current"  # All time has no archives
	_update_all_buttons()
	_load_leaderboard()

func _on_weekly_pressed():
	"""Switch to Weekly scoreboard"""
	if scoreboard_id == SCOREBOARD_WEEKLY:
		return
	
	print("[Leaderboard] Switching to Weekly")
	scoreboard_id = SCOREBOARD_WEEKLY
	view_mode = "current"
	_update_all_buttons()
	_load_leaderboard()

# ============================================================
# BUTTON HANDLERS - ARCHIVE (Current / Last Period)
# ============================================================

func _on_current_pressed():
	"""Switch to current period view"""
	if view_mode == "current":
		return
	
	print("[Leaderboard] Switching to current view")
	view_mode = "current"
	_update_all_buttons()
	_load_leaderboard()

func _on_last_period_pressed():
	"""Switch to last period (archive) view"""
	if view_mode == "archive":
		return
	
	print("[Leaderboard] Switching to archive view")
	view_mode = "archive"
	_update_all_buttons()
	_load_leaderboard()

# ============================================================
# BUTTON HANDLERS - SORT
# ============================================================

func _on_refresh_pressed():
	"""Reload leaderboard"""
	print("[Leaderboard] Refresh pressed")
	_load_leaderboard()

func _on_sort_by_score_pressed():
	"""Sort by score"""
	if current_sort_by == "score":
		return
	
	print("[Leaderboard] Sort by score")
	current_sort_by = "score"
	_update_all_buttons()
	_load_leaderboard()

func _on_sort_by_streak_pressed():
	"""Sort by streak"""
	if current_sort_by == "streak":
		return
	
	print("[Leaderboard] Sort by streak")
	current_sort_by = "streak"
	_update_all_buttons()
	_load_leaderboard()

# ============================================================
# BUTTON HANDLERS - NAVIGATION
# ============================================================

func _on_back_pressed():
	"""Return to main menu"""
	print("[Leaderboard] Back to menu")
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)

func _on_play_again_pressed():
	"""Start new game"""
	print("[Leaderboard] Play again")
	get_tree().change_scene_to_file(SCENE_GAME)

# ============================================================
# PUBLIC METHODS
# ============================================================

## Switch to a different scoreboard type
func set_scoreboard(new_scoreboard_id: String):
	"""Change the scoreboard being displayed"""
	scoreboard_id = new_scoreboard_id
	view_mode = "current"
	_update_all_buttons()
	_load_leaderboard()

## View current period
func show_current():
	"""Switch to viewing current period scores"""
	view_mode = "current"
	_update_all_buttons()
	_load_leaderboard()

## View last period (archive)
func show_last_period():
	"""Switch to viewing last period's archived scores"""
	view_mode = "archive"
	_update_all_buttons()
	_load_leaderboard()

# ============================================================
# CLEANUP
# ============================================================

func _exit_tree():
	"""Clean up on exit"""
	_clear_load_timeout()
