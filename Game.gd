# Game.gd v1.2.0
# Main game scene with CheddaBoards integration
# https://github.com/cheddatech/CheddaBoards-SDK
#
# ============================================================
# SETUP
# ============================================================
# Required nodes in scene:
#   - GameOverPanel (Control)
#   - TestButton (Button)
#   - ScoreDisplay (Label)
#   - CountdownDisplay (Label)
#   - AchievementNotification (custom node)
#
# Required Autoloads:
#   - CheddaBoards
#   - Achievements
#
# ============================================================

extends Control

# ============================================================
# GAME STATE
# ============================================================

var current_score: int = 0
var current_streak: int = 0
var is_game_over: bool = false
var score_submitted: bool = false
var countdown_time: float = 15.0
var game_started: bool = false

# ============================================================
# NODE REFERENCES - GAME OVER
# ============================================================

@onready var game_over_panel = $GameOverPanel
@onready var title_label = $GameOverPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var score_label = $GameOverPanel/MarginContainer/VBoxContainer/ScoreLabel
@onready var streak_label = $GameOverPanel/MarginContainer/VBoxContainer/StreakLabel
@onready var status_label = $GameOverPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var play_again_button = $GameOverPanel/MarginContainer/VBoxContainer/ButtonsContainer/PlayAgainButton
@onready var main_menu_button = $GameOverPanel/MarginContainer/VBoxContainer/ButtonsContainer/MainMenuButton
@onready var leaderboard_button = $GameOverPanel/MarginContainer/VBoxContainer/LeaderboardButton

# ============================================================
# NODE REFERENCES - GAME UI
# ============================================================

@onready var test_button = $TestButton
@onready var score_display = $ScoreDisplay
@onready var countdown_display = $CountdownDisplay
@onready var achievement_notification = $AchievementNotification

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# Hide game over panel initially
	game_over_panel.visible = false
	
	# Wait for CheddaBoards to be ready
	if not CheddaBoards.is_ready():
		await CheddaBoards.wait_until_ready()
	
	# Connect game over buttons
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	
	# Connect test button
	test_button.pressed.connect(_on_test_pressed)
	
	# Connect CheddaBoards signals
	CheddaBoards.score_submitted.connect(_on_score_submitted)
	CheddaBoards.score_error.connect(_on_score_error)
	
	# Connect achievement signals
	Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
	
	# Validate required nodes
	if not achievement_notification:
		push_warning("[Game] AchievementNotification node missing - notifications disabled")
	
	print("[Game] Starting new game (games played: %d)" % Achievements.get_games_played())
	print("[Game] Debug shortcuts: Ctrl+Shift+C (clear cache), Ctrl+Shift+D (debug)")
	
	_start_game()

func _input(event):
	"""Handle keyboard input for testing shortcuts"""
	if event is InputEventKey and event.pressed:
		# Ctrl+Shift+C to clear achievements cache
		if event.keycode == KEY_C and event.ctrl_pressed and event.shift_pressed:
			_clear_achievements_cache()
			get_viewport().set_input_as_handled()
		
		# Ctrl+Shift+D for debug info
		if event.keycode == KEY_D and event.ctrl_pressed and event.shift_pressed:
			_debug_status()
			get_viewport().set_input_as_handled()

# ============================================================
# GAME LOGIC
# ============================================================

func _start_game():
	"""Initialize new game"""
	current_score = 0
	current_streak = 0
	is_game_over = false
	score_submitted = false
	countdown_time = 15.0
	game_started = true
	game_over_panel.visible = false
	test_button.visible = true
	
	_update_score_display()
	_update_countdown_display()

func _process(delta):
	"""Update countdown timer"""
	if game_started and not is_game_over:
		countdown_time -= delta
		_update_countdown_display()
		
		# Check if time is up
		if countdown_time <= 0:
			countdown_time = 0
			_update_countdown_display()
			game_over()

func _update_countdown_display():
	"""Update the countdown display label"""
	if not countdown_display:
		return
	
	var seconds = int(ceil(countdown_time))
	countdown_display.text = "Time: %d" % seconds
	
	# Change color based on time remaining
	if countdown_time <= 5:
		countdown_display.add_theme_color_override("font_color", Color.RED)
	elif countdown_time <= 10:
		countdown_display.add_theme_color_override("font_color", Color.YELLOW)
	else:
		countdown_display.add_theme_color_override("font_color", Color.WHITE)

func _update_score_display():
	"""Update the score display label"""
	if score_display:
		score_display.text = "Score: %d | Streak: %d" % [current_score, current_streak]

# ============================================================
# SCORE & STREAK
# ============================================================

func add_score(points: int):
	"""Add points to score"""
	if is_game_over:
		return
	
	current_score += points
	_update_score_display()
	
	# Check score achievements in real-time
	Achievements.check_score(current_score)

func add_streak():
	"""Increment streak"""
	if is_game_over:
		return
	
	current_streak += 1
	_update_score_display()

func reset_streak():
	"""Reset streak to 0"""
	current_streak = 0
	_update_score_display()

# ============================================================
# GAME OVER
# ============================================================

func game_over():
	"""End the game and process achievements"""
	if is_game_over:
		return
	
	is_game_over = true
	game_started = false
	test_button.visible = false
	
	print("[Game] ════════════════════════════════════")
	print("[Game] GAME OVER")
	print("[Game] Score: %d | Streak: %d | Time Left: %.1fs" % [
		current_score, current_streak, countdown_time
	])
	print("[Game] ════════════════════════════════════")
	
	# Increment games played counter
	Achievements.increment_games_played()
	
	# Check score and clutch achievements at game over
	# Pass time remaining for clutch achievement checks
	Achievements.check_game_over(current_score, countdown_time)
	
	# Show the game over screen
	_show_game_over_screen()

func _show_game_over_screen():
	"""Display game over panel and submit score with achievements"""
	game_over_panel.visible = true
	
	# Update labels
	title_label.text = "Game Over!"
	score_label.text = "Score: %d" % current_score
	streak_label.text = "Streak: %d" % current_streak
	
	# Check if authenticated
	if CheddaBoards.is_authenticated():
		status_label.text = "Saving score..."
		status_label.add_theme_color_override("font_color", Color.WHITE)
		
		# Disable buttons while submitting
		_set_buttons_disabled(true)
		
		# Submit score WITH any pending achievements
		Achievements.submit_with_score(current_score, current_streak)
		print("[Game] Submitting score + achievements to CheddaBoards...")
	else:
		status_label.text = "Not logged in - Score not saved"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
		_set_buttons_disabled(false)

func _set_buttons_disabled(disabled: bool):
	"""Enable/disable game over buttons"""
	play_again_button.disabled = disabled
	main_menu_button.disabled = disabled
	leaderboard_button.disabled = disabled

# ============================================================
# CHEDDABOARDS CALLBACKS
# ============================================================

func _on_score_submitted(score: int, streak: int):
	"""Called when score is successfully submitted"""
	print("[Game] ✅ Score submitted: %d points, %d streak" % [score, streak])
	score_submitted = true
	
	# Profile now exists - safe to sync achievements to backend
	Achievements.sync_pending_to_backend()
	
	# Check for new high score
	var profile = CheddaBoards.get_cached_profile()
	var previous_high = profile.get("score", 0) if not profile.is_empty() else 0
	
	if score > previous_high and previous_high > 0:
		title_label.text = "🏆 NEW HIGH SCORE!"
		status_label.text = "New record: %d!" % score
		status_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		status_label.text = "Score saved!"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	
	_set_buttons_disabled(false)

func _on_score_error(reason: String):
	"""Called when score submission fails"""
	print("[Game] ❌ Score submission failed: %s" % reason)
	
	status_label.text = "Save failed: %s" % reason
	status_label.add_theme_color_override("font_color", Color.RED)
	
	_set_buttons_disabled(false)

# ============================================================
# ACHIEVEMENT NOTIFICATIONS
# ============================================================

func _on_achievement_unlocked(_achievement_id: String, _achievement_name: String):
	"""Called when an achievement is unlocked"""
	# Show notifications from queue (handles multiple unlocks)
	_show_next_achievement_notification()

func _show_next_achievement_notification():
	"""Show achievement notifications one at a time"""
	if not achievement_notification:
		return
	
	if not Achievements.has_pending_notifications():
		return
	
	var notif = Achievements.get_next_notification()
	print("[Game] 🏆 Showing achievement: %s" % notif.name)
	
	achievement_notification.show_achievement(
		notif.name,
		notif.get("icon", ""),
		notif.get("description", "")
	)
	
	# If your notification has a "finished" signal, connect it to show the next one:
	# achievement_notification.finished.connect(_show_next_achievement_notification, CONNECT_ONE_SHOT)

# ============================================================
# BUTTON HANDLERS
# ============================================================

func _on_test_pressed():
	"""Called when test button is clicked"""
	add_score(100)
	add_streak()
	
	# Auto game-over after reaching 10000 points (for testing)
	if current_score >= 10000:
		print("[Game] Reached 10000 points - triggering game over")
		game_over()

func _on_play_again_pressed():
	"""Restart the game"""
	print("[Game] Play again")
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	"""Return to main menu"""
	print("[Game] Main menu")
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_leaderboard_pressed():
	"""View leaderboard"""
	print("[Game] Leaderboard")
	get_tree().change_scene_to_file("res://Leaderboard.tscn")

# ============================================================
# DEBUG & TESTING
# ============================================================

func _clear_achievements_cache():
	"""Clear all cached achievements for testing (Ctrl+Shift+C)"""
	print("")
	print("[Game] ⚠️  CLEARING ACHIEVEMENTS CACHE")
	Achievements.clear_local_cache()
	print("[Game] ✓ Cache cleared - all achievements reset locally")
	print("[Game] Note: Backend achievements remain intact")
	print("")
	
	# Visual feedback
	if achievement_notification:
		achievement_notification.show_achievement("Cache Cleared", "", "Local achievements reset")

func _debug_status():
	"""Print debug status (Ctrl+Shift+D)"""
	print("")
	print("╔══════════════════════════════════════════════╗")
	print("║            Game Debug Status                 ║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Game State                                   ║")
	print("║  - Score:            %s" % str(current_score).rpad(24) + "║")
	print("║  - Streak:           %s" % str(current_streak).rpad(24) + "║")
	print("║  - Time Left:        %s" % ("%.1fs" % countdown_time).rpad(24) + "║")
	print("║  - Game Over:        %s" % str(is_game_over).rpad(24) + "║")
	print("║  - Games Played:     %s" % str(Achievements.get_games_played()).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ CheddaBoards                                 ║")
	print("║  - Ready:            %s" % str(CheddaBoards.is_ready()).rpad(24) + "║")
	print("║  - Authenticated:    %s" % str(CheddaBoards.is_authenticated()).rpad(24) + "║")
	print("║  - Nickname:         %s" % CheddaBoards.get_nickname().rpad(24) + "║")
	print("╚══════════════════════════════════════════════╝")
	print("")
	
	# Also print achievement status
	Achievements.debug_status()
