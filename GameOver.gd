# GameOver.gd v1.1.0
# Game over screen with score submission and achievements
# https://github.com/cheddatech/CheddaBoards-Godot
#
# ============================================================
# USAGE
# ============================================================
# Option A: As a separate scene
#   get_tree().change_scene_to_file("res://scenes/game_over.tscn")
#   # Then call show_game_over() from the new scene's _ready()
#
# Option B: As an overlay in your game scene
#   $GameOverPanel.show_game_over(score, streak, is_first_game)
#
# ============================================================

extends Control

# ============================================================
# NODE REFERENCES
# ============================================================

@onready var title_label = $TitleLabel
@onready var score_label = $ScoreLabel
@onready var status_label = $StatusLabel
@onready var submit_button = $SubmitButton
@onready var play_again_button = $PlayAgainButton
@onready var main_menu_button = $MainMenuButton

# ============================================================
# STATE
# ============================================================

var final_score: int = 0
var final_streak: int = 0
var is_submitting: bool = false
var score_submitted: bool = false

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# Connect CheddaBoards signals
	CheddaBoards.score_submitted.connect(_on_score_submitted)
	CheddaBoards.score_error.connect(_on_score_error)
	
	# Connect buttons
	submit_button.pressed.connect(_on_submit_pressed)
	
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_pressed)
	
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Hide by default if used as overlay
	visible = false

# ============================================================
# SHOW GAME OVER
# ============================================================

func show_game_over(score: int, streak: int, is_first_game: bool = false):
	"""Display game over screen and optionally auto-submit score"""
	final_score = score
	final_streak = streak
	is_submitting = false
	score_submitted = false
	
	# Update display
	if title_label:
		title_label.text = "Game Over!"
	
	score_label.text = "Score: %d\nStreak: %d" % [score, streak]
	status_label.text = ""
	
	# Reset button state
	submit_button.disabled = false
	submit_button.text = "Submit Score"
	
	# Show the panel
	visible = true
	
	# Check achievements before submitting
	Achievements.check_game_over(score, streak)
	
	# Auto-submit if authenticated
	if CheddaBoards.is_authenticated():
		_submit_score()
	else:
		status_label.text = "Login to save your score"
		submit_button.text = "Login to Submit"

# ============================================================
# SCORE SUBMISSION
# ============================================================

func _submit_score():
	"""Submit score with achievements to CheddaBoards"""
	if is_submitting:
		print("[GameOver] Already submitting, ignoring")
		return
	
	if score_submitted:
		print("[GameOver] Already submitted, ignoring")
		return
	
	is_submitting = true
	submit_button.disabled = true
	status_label.text = "Submitting..."
	status_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Submit score WITH any pending achievements
	Achievements.submit_with_score(final_score, final_streak)
	print("[GameOver] Submitting score: %d, streak: %d" % [final_score, final_streak])

# ============================================================
# BUTTON HANDLERS
# ============================================================

func _on_submit_pressed():
	"""Handle submit button press - context-aware"""
	if score_submitted:
		# Already submitted - go to leaderboard
		_go_to_leaderboard()
	elif CheddaBoards.is_authenticated():
		# Authenticated - submit score
		_submit_score()
	else:
		# Not authenticated - go to login
		_go_to_login()

func _on_play_again_pressed():
	"""Restart the game"""
	print("[GameOver] Play again")
	# Option A: Reload current scene (if game is same scene)
	# get_tree().reload_current_scene()
	
	# Option B: Go to game scene
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_main_menu_pressed():
	"""Return to main menu"""
	print("[GameOver] Main menu")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _go_to_leaderboard():
	"""Navigate to leaderboard scene"""
	print("[GameOver] View leaderboard")
	get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")

func _go_to_login():
	"""Navigate to login scene"""
	print("[GameOver] Go to login")
	get_tree().change_scene_to_file("res://scenes/login.tscn")

# ============================================================
# CHEDDABOARDS CALLBACKS
# ============================================================

func _on_score_submitted(score: int, streak: int):
	"""Called when score is successfully submitted"""
	print("[GameOver] ✅ Score submitted: %d" % score)
	
	is_submitting = false
	score_submitted = true
	submit_button.disabled = false
	
	# Check for new high score
	var profile = CheddaBoards.get_cached_profile()
	var previous_high = profile.get("score", 0) if not profile.is_empty() else 0
	
	if score > previous_high and previous_high > 0:
		# New high score!
		if title_label:
			title_label.text = "🏆 NEW HIGH SCORE!"
		status_label.text = "New record: %d!" % score
		status_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		status_label.text = "Score saved!"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	
	# Change button to view leaderboard
	submit_button.text = "View Leaderboard"

func _on_score_error(reason: String):
	"""Called when score submission fails"""
	print("[GameOver] ❌ Score error: %s" % reason)
	
	is_submitting = false
	submit_button.disabled = false
	
	status_label.text = "Error: %s" % reason
	status_label.add_theme_color_override("font_color", Color.RED)
	
	# Allow retry
	submit_button.text = "Retry Submit"

# ============================================================
# UTILITY
# ============================================================

func hide_game_over():
	"""Hide the game over screen"""
	visible = false

func get_final_score() -> int:
	"""Get the final score"""
	return final_score

func get_final_streak() -> int:
	"""Get the final streak"""
	return final_streak

func was_score_submitted() -> bool:
	"""Check if score was successfully submitted"""
	return score_submitted
