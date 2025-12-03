# Leaderboard.gd v1.1.0
# Leaderboard display with sorting options
# https://github.com/cheddatech/CheddaBoards-SDK
#
# ============================================================
# SETUP
# ============================================================
# Required nodes in scene:
#   - MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
#   - MarginContainer/VBoxContainer/HeaderContainer/RefreshButton
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

# ============================================================
# NODE REFERENCES
# ============================================================

@onready var title_label = $MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var refresh_button = $MarginContainer/VBoxContainer/HeaderContainer/RefreshButton
@onready var sort_by_score_button = $MarginContainer/VBoxContainer/HeaderContainer/SortContainer/SortByScoreButton
@onready var sort_by_streak_button = $MarginContainer/VBoxContainer/HeaderContainer/SortContainer/SortByStreakButton
@onready var leaderboard_list = $MarginContainer/VBoxContainer/LeaderboardScroll/LeaderboardList
@onready var your_rank_label = $MarginContainer/VBoxContainer/YourRankPanel/MarginContainer/YourRankLabel
@onready var status_label = $MarginContainer/VBoxContainer/StatusLabel
@onready var back_button = $MarginContainer/VBoxContainer/ButtonsContainer/BackButton
@onready var play_again_button = $MarginContainer/VBoxContainer/ButtonsContainer/PlayAgainButton

# ============================================================
# STATE
# ============================================================

var current_sort_by: String = "score"  # "score" or "streak"
var is_loading: bool = false
var load_timeout_timer: Timer = null
var current_player_nickname: String = ""

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# Wait for CheddaBoards to be ready
	if not CheddaBoards.is_ready():
		status_label.text = "Connecting..."
		await CheddaBoards.wait_until_ready()
	
	# Get current player's nickname for highlighting
	current_player_nickname = CheddaBoards.get_nickname()
	
	# Connect buttons
	refresh_button.pressed.connect(_on_refresh_pressed)
	sort_by_score_button.pressed.connect(_on_sort_by_score_pressed)
	sort_by_streak_button.pressed.connect(_on_sort_by_streak_pressed)
	back_button.pressed.connect(_on_back_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)
	
	# Connect CheddaBoards signals
	CheddaBoards.leaderboard_loaded.connect(_on_leaderboard_loaded)
	CheddaBoards.player_rank_loaded.connect(_on_player_rank_loaded)
	CheddaBoards.rank_error.connect(_on_rank_error)
	
	# Initial load
	_load_leaderboard()

# ============================================================
# LOADING FUNCTIONS
# ============================================================

func _load_leaderboard():
	"""Load leaderboard data"""
	if is_loading:
		print("[Leaderboard] Already loading, ignoring request")
		return
	
	# Check authentication
	if not CheddaBoards.is_authenticated():
		status_label.text = "Login to view leaderboard"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
		your_rank_label.text = "Login to see your rank"
		_set_loading_ui(false)
		return
	
	is_loading = true
	_set_loading_ui(true)
	
	# Clear existing entries
	_clear_leaderboard()
	
	# Show loading state
	status_label.text = "Loading..."
	status_label.add_theme_color_override("font_color", Color.WHITE)
	your_rank_label.text = "Loading your rank..."
	
	# Update button states
	_update_sort_buttons()
	
	print("[Leaderboard] Requesting leaderboard (sort: %s, limit: %d)" % [current_sort_by, LEADERBOARD_LIMIT])
	
	# Start timeout timer
	_start_load_timeout()
	
	# Request leaderboard and player rank
	CheddaBoards.get_leaderboard(current_sort_by, LEADERBOARD_LIMIT)
	CheddaBoards.get_player_rank(current_sort_by)

func _set_loading_ui(loading: bool):
	"""Update UI elements based on loading state"""
	refresh_button.disabled = loading
	sort_by_score_button.disabled = loading or current_sort_by == "score"
	sort_by_streak_button.disabled = loading or current_sort_by == "streak"

func _clear_leaderboard():
	"""Clear all leaderboard entries"""
	for child in leaderboard_list.get_children():
		child.queue_free()

func _update_sort_buttons():
	"""Update visual state of sort buttons"""
	sort_by_score_button.disabled = is_loading or current_sort_by == "score"
	sort_by_streak_button.disabled = is_loading or current_sort_by == "streak"

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
# LEADERBOARD DISPLAY
# ============================================================

func _on_leaderboard_loaded(entries: Array):
	"""Called when leaderboard data is received"""
	print("[Leaderboard] Loaded %d entries" % entries.size())
	
	_clear_load_timeout()
	is_loading = false
	_set_loading_ui(false)
	
	if entries.is_empty():
		status_label.text = "No players yet. Be the first!"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
		return
	
	status_label.text = "%d players" % entries.size()
	status_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Clear existing entries
	_clear_leaderboard()
	
	# Add entries
	for i in range(entries.size()):
		var entry = entries[i]
		_add_leaderboard_entry(i + 1, entry)

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
	
	# Check if this is the current player
	var is_current_player = (nickname == current_player_nickname)
	
	# Create entry container
	var entry_container = PanelContainer.new()
	entry_container.custom_minimum_size = Vector2(0, 50)
	
	# Highlight current player
	if is_current_player:
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color(0.2, 0.5, 0.2, 0.4)  # Green tint
		stylebox.set_corner_radius_all(5)
		entry_container.add_theme_stylebox_override("panel", stylebox)
	
	# Add margin
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
	
	# Nickname label
	var nickname_label = Label.new()
	nickname_label.text = nickname
	if is_current_player:
		nickname_label.text += ""
	nickname_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nickname_label.add_theme_font_size_override("font_size", 24)
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
	"""Called when player rank is received"""
	print("[Leaderboard] Your rank: #%d / %d players" % [rank, total_players])
	
	if rank == 0:
		your_rank_label.text = "Not ranked yet — play a game to get on the leaderboard!"
	else:
		var rank_text = "Your Rank: #%d of %d" % [rank, total_players]
		
		if current_sort_by == "score":
			rank_text += "  •  Score: %d" % score
		else:
			rank_text += "  •  Streak: %d" % streak
		
		# Add encouraging message for top ranks
		if rank == 1:
			rank_text += "   You're #1!"
		elif rank <= 3:
			rank_text += "   Top 3!"
		elif rank <= 10:
			rank_text += "   Top 10!"
		
		your_rank_label.text = rank_text

func _on_rank_error(reason: String):
	"""Called when rank fetch fails"""
	print("[Leaderboard] Rank error: %s" % reason)
	your_rank_label.text = "Could not load your rank"

# ============================================================
# BUTTON HANDLERS
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
	title_label.text = "Leaderboard — By Score"
	_load_leaderboard()

func _on_sort_by_streak_pressed():
	"""Sort by streak"""
	if current_sort_by == "streak":
		return
	
	print("[Leaderboard] Sort by streak")
	current_sort_by = "streak"
	title_label.text = "Leaderboard — By Streak"
	_load_leaderboard()

func _on_back_pressed():
	"""Return to main menu"""
	print("[Leaderboard] Back to menu")
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)

func _on_play_again_pressed():
	"""Start new game"""
	print("[Leaderboard] Play again")
	get_tree().change_scene_to_file(SCENE_GAME)

# ============================================================
# CLEANUP
# ============================================================

func _exit_tree():
	"""Clean up on exit"""
	_clear_load_timeout()
