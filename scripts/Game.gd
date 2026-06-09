
# GameWrapper.gd v1.1.0
# Modular wrapper for CheddaBoards integration
# Drop ANY game scene as a child - just emit the right signals!
# https://github.com/cheddatech/CheddaBoards-Godot
#
# ============================================================
# HOW TO USE
# ============================================================
# 1. Create your game as a separate scene (e.g. MyGame.tscn)
# 2. Your game script must emit:
#    - game_over(final_score: int, stats: Dictionary) - when game ends
#      All stats keys are OPTIONAL. Each one you include shows on the game-over
#      screen; omit it and that field is hidden (no bogus "Accuracy: 0%").
#      Recognised keys:
#        "hits": int        - used for achievement checks
#        "misses": int      - used by the HUD stats panel
#        "level": int       - shows "Level: N" on game over
#        "accuracy": int    - shows "Accuracy: N%" on game over
#        "max_combo": int   - shows "Max Combo: xN" on game over
#
#    Optional (only needed if you want the built-in HUD):
#    - score_changed(score: int, combo: int) - live score/combo display + mid-game achievement pops
#    - stats_changed(hits: int, misses: int, level: int) - level/misses display
#    - time_changed(time_remaining: float, max_time: float) - timer display
#
#    The HUD is OPT-IN per panel: each panel (score/combo, timer, stats) stays
#    hidden unless your game declares the matching signal above. A game that
#    emits none of them shows a clean, empty HUD bar - no leftover placeholders.
#
#    Without score_changed, score/combo achievements are checked at game-over
#    only (via check_game_over in the game_over handler), not live during play.
# 3. Set game_scene_path to your game scene
# 4. Set main_menu_scene / leaderboard_scene to match YOUR project layout
#    (defaults assume res://scenes/). The "Main Menu" / "Leaderboard" buttons
#    route to these.
# 5. Optionally implement these methods in your game:
#    - restart() - called when Play Again is pressed
#    - pause() / unpause() - if you need pause support
#
# NOTE: the wrapper scene includes a dark "Background" ColorRect behind the
# game. If your game draws its own background, you can delete that node.
# ============================================================

extends Control

# ============================================================
# CONFIGURATION - CHANGE THIS TO YOUR GAME!
# ============================================================

## Path to your game scene - this gets instantiated as a child
@export var game_scene_path: String = "res://example_game/CheddaClickGame.tscn"

## Scenes the game-over buttons route to. Change these to match YOUR project.
@export var main_menu_scene: String = "res://scenes/MainMenu.tscn"
@export var leaderboard_scene: String = "res://scenes/Leaderboard.tscn"

## Title shown on game over screen when reaching different "levels" or scores
@export var game_over_titles: Dictionary = {
	"amazing": "AMAZING!",
	"excellent": "Excellent!",
	"great": "Great Game!",
	"good": "Good Effort!",
	"default": "Game Over"
}

## Score thresholds for game over titles (highest first)
@export var title_thresholds: Array[int] = [10000, 5000, 2500, 1000]

# ============================================================
# NODE REFERENCES - HUD
# ============================================================

@onready var game_container = $GameContainer
@onready var score_panel = $HUD/TopBar/ScorePanel
@onready var time_panel = $HUD/TopBar/TimePanel
@onready var stats_panel = $HUD/TopBar/StatsPanel
@onready var score_label = $HUD/TopBar/ScorePanel/VBox/ScoreLabel
@onready var combo_label = $HUD/TopBar/ScorePanel/VBox/ComboLabel
@onready var time_label = $HUD/TopBar/TimePanel/TimeLabel
@onready var stat1_label = $HUD/TopBar/StatsPanel/VBox/Stat1Label
@onready var stat2_label = $HUD/TopBar/StatsPanel/VBox/Stat2Label

# ============================================================
# NODE REFERENCES - GAME OVER
# ============================================================

@onready var game_over_panel = $GameOverPanel
@onready var title_label = $GameOverPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var final_score_label = $GameOverPanel/MarginContainer/VBoxContainer/FinalScoreLabel
@onready var stats_container = $GameOverPanel/MarginContainer/VBoxContainer/StatsContainer
@onready var stat1_result = $GameOverPanel/MarginContainer/VBoxContainer/StatsContainer/Stat1Result
@onready var stats_spacer = $GameOverPanel/MarginContainer/VBoxContainer/StatsContainer/Spacer
@onready var stat2_result = $GameOverPanel/MarginContainer/VBoxContainer/StatsContainer/Stat2Result
@onready var extra_stat_label = $GameOverPanel/MarginContainer/VBoxContainer/ExtraStatLabel
@onready var status_label = $GameOverPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var play_again_button = $GameOverPanel/MarginContainer/VBoxContainer/ButtonsContainer/PlayAgainButton
@onready var main_menu_button = $GameOverPanel/MarginContainer/VBoxContainer/ButtonsContainer/MainMenuButton
@onready var leaderboard_button = $GameOverPanel/MarginContainer/VBoxContainer/LeaderboardButton

# ============================================================
# STATE
# ============================================================

var game_instance: Node = null
var current_score: int = 0
var current_combo: int = 1
var max_combo: int = 1
var is_game_over: bool = false
var score_submitted: bool = false

# Achievements (check if available)
var has_achievements: bool = false

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# Hide game over panel
	game_over_panel.visible = false
	
	# HUD panels are opt-in: stay hidden until the game declares the
	# matching signal (see _connect_game_signals). Prevents leftover
	# placeholder text showing for games that don't use the built-in HUD.
	score_panel.visible = false
	time_panel.visible = false
	stats_panel.visible = false
	
	# Connect game over buttons
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	
	# Connect CheddaBoards signals
	CheddaBoards.score_submitted.connect(_on_score_submitted)
	CheddaBoards.score_error.connect(_on_score_error)
	CheddaBoards.play_session_started.connect(_on_play_session_started)
	CheddaBoards.play_session_error.connect(_on_play_session_error)
	
	# Check if Achievements autoload exists
	has_achievements = get_node_or_null("/root/Achievements") != null
	
	print("[GameWrapper] Initializing v1.1.0")
	print("[GameWrapper] Platform: %s" % ("Web" if OS.get_name() == "Web" else "Native"))
	print("[GameWrapper] Achievements: %s" % ("enabled" if has_achievements else "disabled"))
	
	# Load and instantiate the game scene
	_load_game()

func _load_game():
	"""Load and instantiate the game scene"""
	if game_scene_path.is_empty():
		push_error("[GameWrapper] No game_scene_path set!")
		return
	
	var game_scene = load(game_scene_path)
	if not game_scene:
		push_error("[GameWrapper] Failed to load game scene: %s" % game_scene_path)
		return
	
	game_instance = game_scene.instantiate()
	game_container.add_child(game_instance)
	
	# Connect to game signals
	_connect_game_signals()
	
	# Start play session for anti-cheat
	if CheddaBoards.is_ready():
		CheddaBoards.start_play_session()
	
	print("[GameWrapper] Game loaded: %s" % game_scene_path)

func _connect_game_signals():
	"""Connect to the game's signals"""
	if not game_instance:
		return
	
	# Required signal — the submit + game-over flow needs this
	if game_instance.has_signal("game_over"):
		game_instance.game_over.connect(_on_game_over)
	else:
		push_warning("[GameWrapper] Game missing 'game_over' signal")
	
	# Optional signals — only needed if you want the built-in HUD.
	# Each panel is revealed only if the game declares its signal, so a
	# game that uses none of these shows an empty HUD bar (no placeholders).
	if game_instance.has_signal("score_changed"):
		game_instance.score_changed.connect(_on_game_score_changed)
		score_panel.visible = true
	
	if game_instance.has_signal("stats_changed"):
		game_instance.stats_changed.connect(_on_game_stats_changed)
		stats_panel.visible = true
	
	if game_instance.has_signal("time_changed"):
		game_instance.time_changed.connect(_on_game_time_changed)
		time_panel.visible = true

# ============================================================
# GAME SIGNAL HANDLERS
# ============================================================

func _on_game_score_changed(score: int, combo: int):
	"""Called when game score changes"""
	current_score = score
	current_combo = combo
	if combo > max_combo:
		max_combo = combo
		# Check combo achievements
		if has_achievements:
			Achievements.check_combo(max_combo)
	
	_update_score_display()
	
	# Check score achievements
	if has_achievements:
		Achievements.check_score(current_score)

func _on_game_stats_changed(hits: int, misses: int, level: int):
	"""Called when game stats change"""
	stat1_label.text = "Level: %d" % level
	stat2_label.text = "Misses: %d" % misses

func _on_game_time_changed(time_remaining: float, max_time: float):
	"""Called when game time changes"""
	var seconds = int(ceil(time_remaining))
	time_label.text = "%d" % seconds
	
	# Color code time
	if time_remaining <= 10:
		time_label.add_theme_color_override("font_color", Color.RED)
	elif time_remaining <= 30:
		time_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		time_label.add_theme_color_override("font_color", Color.WHITE)

func _on_game_over(final_score: int, stats: Dictionary):
	"""Called when game ends"""
	if is_game_over:
		return
	
	is_game_over = true
	current_score = final_score
	
	# Extract stats with defaults
	var hits = stats.get("hits", 0)
	var misses = stats.get("misses", 0)
	var game_max_combo = stats.get("max_combo", max_combo)
	var level = stats.get("level", 1)
	var accuracy = stats.get("accuracy", 0)
	
	# Use the higher of tracked or reported max_combo
	max_combo = max(max_combo, game_max_combo)
	
	print("[GameWrapper] ========================================")
	print("[GameWrapper] GAME OVER")
	print("[GameWrapper] Score: %d | Level: %d | Hits: %d" % [final_score, level, hits])
	print("[GameWrapper] Accuracy: %d%% | Max Combo: x%d" % [accuracy, max_combo])
	print("[GameWrapper] ========================================")
	
	# Check achievements at game over
	if has_achievements:
		Achievements.increment_games_played()
		Achievements.check_game_over(final_score, hits, max_combo)
		print("[GameWrapper] Achievements checked - games played: %d" % Achievements.get_games_played())
	
	_show_game_over_screen(stats)

# ============================================================
# HUD UPDATES
# ============================================================

func _update_score_display():
	"""Update score and combo display"""
	score_label.text = "Score: %d" % current_score
	combo_label.text = "Combo: x%d" % current_combo
	
	# Color combo based on multiplier
	if current_combo >= 8:
		combo_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	elif current_combo >= 5:
		combo_label.add_theme_color_override("font_color", Color(1, 0.5, 0.1))
	elif current_combo >= 3:
		combo_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	else:
		combo_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

# ============================================================
# GAME OVER
# ============================================================

func _show_game_over_screen(stats: Dictionary):
	"""Display game over panel and submit score"""
	game_over_panel.visible = true
	
	# Set title based on score thresholds
	var title_key = "default"
	var title_colors = {
		"amazing": Color.GOLD,
		"excellent": Color(1.0, 0.8, 0.2),
		"great": Color(0.2, 1.0, 0.4),
		"good": Color(0.2, 0.8, 1.0),
		"default": Color.WHITE
	}
	
	if current_score >= title_thresholds[0]:
		title_key = "amazing"
	elif current_score >= title_thresholds[1]:
		title_key = "excellent"
	elif current_score >= title_thresholds[2]:
		title_key = "great"
	elif current_score >= title_thresholds[3]:
		title_key = "good"
	
	title_label.text = game_over_titles.get(title_key, "Game Over")
	title_label.add_theme_color_override("font_color", title_colors.get(title_key, Color.WHITE))
	
	# Final score is universal — every game has one
	final_score_label.text = "Final Score: %d" % current_score
	
	# Stat fields are opt-in: a field shows only if the game reported it in
	# `stats`, so non-arcade games don't get bogus "Accuracy: 0% / Level: 1".
	#   stats["level"]     -> Level
	#   stats["accuracy"]  -> Accuracy
	#   stats["max_combo"] (or any combo seen during play) -> Max Combo
	var show_level = stats.has("level")
	var show_accuracy = stats.has("accuracy")
	var show_combo = stats.has("max_combo") or max_combo > 1
	
	if show_level:
		stat1_result.text = "Level: %d" % int(stats.get("level", 1))
	if show_accuracy:
		stat2_result.text = "Accuracy: %d%%" % int(stats.get("accuracy", 0))
	if show_combo:
		extra_stat_label.text = "Max Combo: x%d" % max_combo
	
	stat1_result.visible = show_level
	stat2_result.visible = show_accuracy
	# Gap between the two stats only matters when both are present
	stats_spacer.visible = show_level and show_accuracy
	# Hide the whole row if neither stat applies
	stats_container.visible = show_level or show_accuracy
	extra_stat_label.visible = show_combo
	
	# Submit score
	if CheddaBoards.is_ready():
		if CheddaBoards.is_authenticated():
			var auth_type = "anonymous" if CheddaBoards.is_anonymous() else "account"
			status_label.text = "Saving score..."
			status_label.add_theme_color_override("font_color", Color.WHITE)
			_set_buttons_disabled(true)
			_submit_score()
			print("[GameWrapper] Submitting score (auth: %s)" % auth_type)
		else:
			status_label.text = "Saving score..."
			status_label.add_theme_color_override("font_color", Color.WHITE)
			_set_buttons_disabled(true)
			_submit_score()
	else:
		status_label.text = "Offline - Score not saved"
		status_label.add_theme_color_override("font_color", Color.GRAY)
		_set_buttons_disabled(false)

func _submit_score():
	"""Submit score to CheddaBoards with achievements"""
	if has_achievements:
		Achievements.submit_with_score(current_score, max_combo)
		print("[GameWrapper] Submitting score with achievements: %d (combo: %d)" % [current_score, max_combo])
	else:
		CheddaBoards.submit_score(current_score, max_combo)
		print("[GameWrapper] Submitting score: %d (combo: %d)" % [current_score, max_combo])

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
	print("[GameWrapper] ✓ Score submitted: %d points" % score)
	score_submitted = true
	CheddaBoards.clear_play_session()
	
	var profile = CheddaBoards.get_cached_profile()
	var previous_high = 0
	if not profile.is_empty():
		previous_high = int(profile.get("score", 0))
	
	if score > previous_high and previous_high > 0:
		title_label.text = "NEW HIGH SCORE!"
		status_label.text = "New record: %d!" % score
		status_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		status_label.text = "Score saved!"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	
	_set_buttons_disabled(false)

func _on_score_error(reason: String):
	"""Called when score submission fails"""
	print("[GameWrapper] ✗ Score submission failed: %s" % reason)
	CheddaBoards.clear_play_session()
	
	status_label.text = "Save failed: %s" % reason
	status_label.add_theme_color_override("font_color", Color.RED)
	
	_set_buttons_disabled(false)

func _on_play_session_started(token: String):
	"""Called when play session is started for time validation"""
	print("[GameWrapper] ✓ Play session started: %s" % token.left(30))

func _on_play_session_error(reason: String):
	"""Called when play session fails to start"""
	print("[GameWrapper] ⚠ Play session error: %s (scores may be rejected)" % reason)

# ============================================================
# BUTTON HANDLERS
# ============================================================

func _on_play_again_pressed():
	"""Restart the game"""
	print("[GameWrapper] Play again")
	
	# Option 1: If game has a restart method, use it
	if game_instance and game_instance.has_method("restart"):
		is_game_over = false
		current_score = 0
		current_combo = 1
		max_combo = 1
		score_submitted = false
		game_over_panel.visible = false
		_update_score_display()
		
		# Start new play session
		if CheddaBoards.is_ready():
			CheddaBoards.start_play_session()
		
		game_instance.restart()
	else:
		# Option 2: Reload entire scene
		get_tree().reload_current_scene()

func _on_main_menu_pressed():
	print("[GameWrapper] Main menu")
	get_tree().change_scene_to_file(main_menu_scene)

func _on_leaderboard_pressed():
	print("[GameWrapper] Leaderboard")
	get_tree().change_scene_to_file(leaderboard_scene)

# ============================================================
# DEBUG
# ============================================================

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F9:
			_debug_status()
			get_viewport().set_input_as_handled()
		if event.keycode == KEY_F10 and has_achievements:
			Achievements.debug_status()
			get_viewport().set_input_as_handled()

func _debug_status():
	"""Print debug status"""
	print("")
	print("========================================")
	print("       GameWrapper Debug Status        ")
	print("========================================")
	print(" Score:        %d" % current_score)
	print(" Combo:        x%d" % current_combo)
	print(" Max Combo:    x%d" % max_combo)
	print(" Game Over:    %s" % str(is_game_over))
	print("----------------------------------------")
	print(" Game Scene:   %s" % game_scene_path)
	print(" Game Loaded:  %s" % str(game_instance != null))
	print("----------------------------------------")
	print(" Platform:     %s" % OS.get_name())
	print(" SDK Ready:    %s" % CheddaBoards.is_ready())
	print(" Authenticated: %s" % CheddaBoards.is_authenticated())
	print(" Play Session: %s" % ("active" if CheddaBoards.has_play_session() else "none"))
	print(" Achievements: %s" % ("enabled" if has_achievements else "disabled"))
	if has_achievements:
		print(" Games Played: %d" % Achievements.get_games_played())
		print(" Unlocked:     %d / %d" % [Achievements.get_unlocked_count(), Achievements.get_total_count()])
	print("========================================")
	print("")
