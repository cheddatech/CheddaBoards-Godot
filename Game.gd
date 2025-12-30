# Game.gd v1.5.0
# Dynamic clicker game with moving targets, combo system, and LEVELS
# Compatible with CheddaBoards SDK (Web + Native API)
# https://github.com/cheddatech/CheddaBoards-SDK
#
# ============================================================
# FEATURES
# ============================================================
# - Moving targets that spawn around the screen
# - Combo system with multipliers (max x10)
# - LEVEL SYSTEM - score thresholds unlock harder levels
# - TIME EXTENSION - earn extra time from hits and level ups
# - Time bonuses for quick consecutive clicks
# - Difficulty scales with level (speed, spawns, size)
# - Achievement system integration
# - Works with both Web (JS bridge) and Native (HTTP API)
#
# ============================================================

extends Control

# ============================================================
# CONFIGURATION
# ============================================================

const GAME_DURATION: float = 30.0
const BASE_POINTS: int = 100
const COMBO_DECAY_TIME: float = 2.0
const MAX_COMBO_MULTIPLIER: int = 10
const QUICK_CLICK_BONUS: float = 0.5  # seconds for time bonus

# Target settings
const TARGET_MIN_SIZE: float = 80.0
const TARGET_MAX_SIZE: float = 150.0
const TARGET_MIN_SPEED: float = 50.0
const TARGET_MAX_SPEED: float = 200.0
const TARGET_MIN_LIFETIME: float = 3.0
const TARGET_MAX_LIFETIME: float = 8.0
const MAX_TARGETS_ON_SCREEN: int = 5

# Spawn timing
const SPAWN_TIME_MIN: float = 0.5
const SPAWN_TIME_MAX: float = 2.0

# Time extension
const TIME_BONUS_PER_HIT: float = 0.15
const TIME_BONUS_PER_LEVEL: float = 3.0
const MAX_TIME: float = 45.0

# ============================================================
# LEVEL SYSTEM
# ============================================================

# Score thresholds for each level (index = level - 1)
const LEVEL_THRESHOLDS: Array[int] = [0, 1000, 2500, 5000, 8000]

# Speed multiplier per level
const LEVEL_SPEED_MULT: Array[float] = [1.0, 1.1, 1.2, 1.35, 1.5]

# Spawn rate multiplier per level (lower = faster spawns)
const LEVEL_SPAWN_MULT: Array[float] = [1.0, 0.85, 0.7, 0.55, 0.4]

# Size reduction per level (smaller targets at higher levels)
const LEVEL_SIZE_MULT: Array[float] = [1.0, 0.95, 0.9, 0.85, 0.8]

# Max targets on screen per level
const LEVEL_MAX_TARGETS: Array[int] = [5, 6, 7, 8, 10]

const MAX_LEVEL: int = 5

# ============================================================
# GAME STATE
# ============================================================

var current_score: int = 0
var combo_count: int = 0
var combo_multiplier: int = 1
var max_combo: int = 1
var total_hits: int = 0
var total_misses: int = 0
var time_remaining: float = GAME_DURATION
var last_hit_time: float = 0.0
var combo_timer: float = 0.0
var is_game_over: bool = false
var game_started: bool = false
var score_submitted: bool = false

# Level tracking
var current_level: int = 1
var max_level_reached: int = 1

# Target tracking
var active_targets: Array = []
var target_texture: Texture2D = null

# Achievements (check if available)
var has_achievements: bool = false

# ============================================================
# NODE REFERENCES - HUD
# ============================================================

@onready var game_area = $GameArea
@onready var score_label = $HUD/TopBar/ScorePanel/VBox/ScoreLabel
@onready var combo_label = $HUD/TopBar/ScorePanel/VBox/ComboLabel
@onready var time_label = $HUD/TopBar/TimePanel/TimeLabel
@onready var hits_label = $HUD/TopBar/StatsPanel/VBox/HitsLabel
@onready var misses_label = $HUD/TopBar/StatsPanel/VBox/MissesLabel
@onready var multiplier_label = $MultiplierLabel

# ============================================================
# NODE REFERENCES - GAME OVER
# ============================================================

@onready var game_over_panel = $GameOverPanel
@onready var title_label = $GameOverPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var final_score_label = $GameOverPanel/MarginContainer/VBoxContainer/FinalScoreLabel
@onready var hits_result = $GameOverPanel/MarginContainer/VBoxContainer/StatsContainer/HitsResult
@onready var accuracy_result = $GameOverPanel/MarginContainer/VBoxContainer/StatsContainer/AccuracyResult
@onready var max_combo_label = $GameOverPanel/MarginContainer/VBoxContainer/MaxComboLabel
@onready var status_label = $GameOverPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var play_again_button = $GameOverPanel/MarginContainer/VBoxContainer/ButtonsContainer/PlayAgainButton
@onready var main_menu_button = $GameOverPanel/MarginContainer/VBoxContainer/ButtonsContainer/MainMenuButton
@onready var leaderboard_button = $GameOverPanel/MarginContainer/VBoxContainer/LeaderboardButton

# ============================================================
# NODE REFERENCES - TIMERS
# ============================================================

@onready var spawn_timer = $SpawnTimer

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# Load target texture (cheese icon)
	target_texture = load("res://addons/cheddaboards/cheese.png")
	if not target_texture:
		push_warning("[Game] Target texture not found - using placeholder")
	
	# Hide game over panel
	game_over_panel.visible = false
	multiplier_label.visible = false
	
	# Connect timers
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Connect game over buttons
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	
	# Connect CheddaBoards signals
	CheddaBoards.score_submitted.connect(_on_score_submitted)
	CheddaBoards.score_error.connect(_on_score_error)

	# Connect game area click for misses
	game_area.gui_input.connect(_on_game_area_input)
	
	# Check if Achievements autoload exists
	has_achievements = get_node_or_null("/root/Achievements") != null
	
	print("[Game] Starting dynamic game v1.5.0 (with levels + time extension!)")
	print("[Game] Platform: %s" % ("Web" if OS.get_name() == "Web" else "Native"))
	print("[Game] Achievements: %s" % ("enabled" if has_achievements else "disabled"))
	
	_start_game()

# ============================================================
# GAME LOOP
# ============================================================

func _start_game():
	"""Initialize new game"""
	current_score = 0
	combo_count = 0
	combo_multiplier = 1
	max_combo = 1
	total_hits = 0
	total_misses = 0
	time_remaining = GAME_DURATION
	current_level = 1
	max_level_reached = 1
	is_game_over = false
	game_started = true
	score_submitted = false
	last_hit_time = 0.0
	combo_timer = 0.0
	
	# Clear any existing targets
	_clear_all_targets()
	
	# Set initial spawn rate for level 1
	spawn_timer.wait_time = SPAWN_TIME_MAX
	spawn_timer.start()
	
	# Update UI
	_update_hud()
	game_over_panel.visible = false
	
	print("[Game] Level 1 - GO!")

func _process(delta):
	if not game_started or is_game_over:
		return
	
	# Update time
	time_remaining -= delta
	_update_time_display()
	
	# Update combo decay
	if combo_count > 0:
		combo_timer += delta
		if combo_timer >= COMBO_DECAY_TIME:
			_reset_combo()
	
	# Check game over
	if time_remaining <= 0:
		time_remaining = 0
		_game_over()

func _update_time_display():
	"""Update the time display with color coding"""
	var seconds = int(ceil(time_remaining))
	time_label.text = "%d" % seconds
	
	if time_remaining <= 10:
		time_label.add_theme_color_override("font_color", Color.RED)
	elif time_remaining <= 30:
		time_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		time_label.add_theme_color_override("font_color", Color.WHITE)

func _update_hud():
	"""Update all HUD elements"""
	score_label.text = "Score: %d" % current_score
	combo_label.text = "Combo: x%d" % combo_multiplier
	hits_label.text = "Level: %d" % current_level  # Changed from Hits
	misses_label.text = "Misses: %d" % total_misses
	
	# Color combo based on multiplier
	if combo_multiplier >= 8:
		combo_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))  # Red
	elif combo_multiplier >= 5:
		combo_label.add_theme_color_override("font_color", Color(1, 0.5, 0.1))  # Orange
	elif combo_multiplier >= 3:
		combo_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))  # Yellow
	else:
		combo_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))  # Gray

# ============================================================
# LEVEL SYSTEM
# ============================================================

func _check_level_up():
	"""Check if player has reached a new level"""
	if current_level >= MAX_LEVEL:
		return
	
	var next_level = current_level + 1
	var threshold = LEVEL_THRESHOLDS[next_level - 1]
	
	if current_score >= threshold:
		_level_up(next_level)

func _level_up(new_level: int):
	"""Handle level up event"""
	current_level = new_level
	if current_level > max_level_reached:
		max_level_reached = current_level
	
	print("[Game] ★★★ LEVEL %d ★★★" % current_level)
	
	# Add time bonus for leveling up
	var time_added = _add_time(TIME_BONUS_PER_LEVEL)
	print("[Game] +%.1fs time bonus! (now %.1fs)" % [time_added, time_remaining])
	
	# Update spawn rate for new level
	var spawn_mult = LEVEL_SPAWN_MULT[current_level - 1]
	spawn_timer.wait_time = SPAWN_TIME_MAX * spawn_mult
	
	# Show level up popup (includes time bonus)
	_show_level_up_popup(time_added)
	
	# Update HUD
	_update_hud()
	
	# Check level achievements (pass time for speed achievements)
	if has_achievements:
		Achievements.check_level(current_level, time_remaining)

func _show_level_up_popup(time_added: float = 0.0):
	"""Display big level up notification with time bonus"""
	var popup = Label.new()
	if time_added > 0:
		popup.text = "LEVEL %d!\n+%.1fs" % [current_level, time_added]
	else:
		popup.text = "LEVEL %d!" % current_level
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Big bold styling
	popup.add_theme_font_size_override("font_size", 64)
	
	# Color based on level
	match current_level:
		2:
			popup.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))  # Cyan
		3:
			popup.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))  # Green
		4:
			popup.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Gold
		5:
			popup.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red
		_:
			popup.add_theme_color_override("font_color", Color.WHITE)
	
	# Center on screen
	var viewport_size = get_viewport().get_visible_rect().size
	popup.position = Vector2(viewport_size.x / 2 - 150, viewport_size.y / 2 - 60)
	popup.custom_minimum_size = Vector2(300, 120)
	
	add_child(popup)
	
	# Animate: scale up, hold, fade out
	popup.scale = Vector2(0.5, 0.5)
	popup.pivot_offset = Vector2(150, 60)
	
	var tween = create_tween()
	tween.tween_property(popup, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(0.5)
	tween.tween_property(popup, "modulate:a", 0, 0.4)
	tween.tween_callback(popup.queue_free)

func _get_level_speed_mult() -> float:
	"""Get current level's speed multiplier"""
	return LEVEL_SPEED_MULT[current_level - 1]

func _get_level_size_mult() -> float:
	"""Get current level's size multiplier"""
	return LEVEL_SIZE_MULT[current_level - 1]

func _get_level_max_targets() -> int:
	"""Get current level's max targets"""
	return LEVEL_MAX_TARGETS[current_level - 1]

func _add_time(amount: float) -> float:
	"""Add time to the clock (capped at MAX_TIME). Returns actual amount added."""
	var old_time = time_remaining
	time_remaining = min(time_remaining + amount, MAX_TIME)
	return time_remaining - old_time

# ============================================================
# TARGET SPAWNING
# ============================================================

func _on_spawn_timer_timeout():
	if is_game_over or active_targets.size() >= _get_level_max_targets():
		return
	
	_spawn_target()

func _spawn_target():
	"""Spawn a new clickable target"""
	var target = _create_target()
	game_area.add_child(target)
	active_targets.append(target)

func _create_target() -> Control:
	"""Create a target node with random properties"""
	var target = TextureRect.new()
	
	# Set texture
	if target_texture:
		target.texture = target_texture
	
	# Random size based on level (smaller at higher levels)
	var size_mult = _get_level_size_mult()
	var size_range = (TARGET_MAX_SIZE - TARGET_MIN_SIZE) * size_mult
	var target_size = TARGET_MIN_SIZE + (size_range * randf())
	target.custom_minimum_size = Vector2(target_size, target_size)
	target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Random position within game area
	var game_rect = game_area.get_rect()
	var margin = target_size / 2
	var pos_x = randf_range(margin, game_rect.size.x - target_size - margin)
	var pos_y = randf_range(margin, game_rect.size.y - target_size - margin)
	target.position = Vector2(pos_x, pos_y)
	
	# Speed scales with level
	var speed_mult = _get_level_speed_mult()
	var speed = randf_range(TARGET_MIN_SPEED, TARGET_MAX_SPEED) * speed_mult
	var direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var lifetime = randf_range(TARGET_MIN_LIFETIME, TARGET_MAX_LIFETIME)
	
	target.set_meta("speed", speed)
	target.set_meta("direction", direction)
	target.set_meta("lifetime", lifetime)
	target.set_meta("age", 0.0)
	target.set_meta("points", _calculate_target_points(target_size))
	
	# Make clickable
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	target.gui_input.connect(_on_target_input.bind(target))
	
	# Start movement
	target.set_process(true)
	
	return target

func _calculate_target_points(size: float) -> int:
	"""Smaller targets = more points, higher levels = more points"""
	var size_factor = 1.0 - ((size - TARGET_MIN_SIZE) / (TARGET_MAX_SIZE - TARGET_MIN_SIZE))
	var level_bonus = 1.0 + (current_level - 1) * 0.1  # 10% bonus per level
	return int(BASE_POINTS * (1 + size_factor) * level_bonus)

func _physics_process(delta):
	"""Update target positions"""
	if is_game_over:
		return
	
	var game_rect = game_area.get_rect()
	var targets_to_remove = []
	
	for target in active_targets:
		if not is_instance_valid(target):
			targets_to_remove.append(target)
			continue
		
		# Update age
		var age = target.get_meta("age") + delta
		target.set_meta("age", age)
		
		# Check lifetime
		var lifetime = target.get_meta("lifetime")
		if age >= lifetime:
			targets_to_remove.append(target)
			_on_target_missed(target)
			continue
		
		# Move target
		var speed = target.get_meta("speed")
		var direction = target.get_meta("direction")
		target.position += direction * speed * delta
		
		# Bounce off walls
		var target_size = target.custom_minimum_size
		if target.position.x <= 0 or target.position.x + target_size.x >= game_rect.size.x:
			direction.x *= -1
			target.set_meta("direction", direction)
			target.position.x = clamp(target.position.x, 0, game_rect.size.x - target_size.x)
		
		if target.position.y <= 0 or target.position.y + target_size.y >= game_rect.size.y:
			direction.y *= -1
			target.set_meta("direction", direction)
			target.position.y = clamp(target.position.y, 0, game_rect.size.y - target_size.y)
		
		# Fade out near end of lifetime
		var fade_start = lifetime * 0.7
		if age > fade_start:
			var fade_progress = (age - fade_start) / (lifetime - fade_start)
			target.modulate.a = 1.0 - fade_progress
	
	# Remove expired targets
	for target in targets_to_remove:
		_remove_target(target)

func _remove_target(target: Control):
	"""Remove a target from the game"""
	if target in active_targets:
		active_targets.erase(target)
	if is_instance_valid(target):
		target.queue_free()

func _clear_all_targets():
	"""Remove all active targets"""
	for target in active_targets:
		if is_instance_valid(target):
			target.queue_free()
	active_targets.clear()

# ============================================================
# INPUT HANDLING
# ============================================================

func _on_target_input(event: InputEvent, target: Control):
	"""Handle click on target"""
	if is_game_over:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hit_target(target)
		get_viewport().set_input_as_handled()

func _on_game_area_input(event: InputEvent):
	"""Handle click on empty area (miss)"""
	if is_game_over:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_register_miss()

func _hit_target(target: Control):
	"""Process a successful hit"""
	if not is_instance_valid(target):
		return
	
	var base_points = target.get_meta("points")
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check for quick click bonus
	var time_bonus = 1.0
	if last_hit_time > 0 and (current_time - last_hit_time) < QUICK_CLICK_BONUS:
		time_bonus = 1.5
	
	# Update combo
	combo_count += 1
	combo_timer = 0.0
	combo_multiplier = min(1 + (combo_count / 3), MAX_COMBO_MULTIPLIER)
	
	# Track max combo and check achievements
	if combo_multiplier > max_combo:
		max_combo = combo_multiplier
		if has_achievements:
			Achievements.check_combo(max_combo)
	
	# Calculate final points
	var points = int(base_points * combo_multiplier * time_bonus)
	current_score += points
	total_hits += 1
	last_hit_time = current_time
	
	# Add time bonus for hit
	var time_added = _add_time(TIME_BONUS_PER_HIT)
	
	# Check for level up!
	_check_level_up()
	
	# Check score achievements
	if has_achievements:
		Achievements.check_score(current_score)
	
	# Show floating score
	_show_score_popup(target.position + target.custom_minimum_size / 2, points, time_bonus > 1.0)
	
	# Remove target
	_remove_target(target)
	
	# Update HUD
	_update_hud()
	
	print("[Game] HIT! +%d (combo x%d, level %d)" % [points, combo_multiplier, current_level])

func _on_target_missed(target: Control):
	"""Target expired without being clicked"""
	total_misses += 1
	_reset_combo()
	_update_hud()

func _register_miss():
	"""Clicked on empty space"""
	total_misses += 1
	_reset_combo()
	_update_hud()

func _reset_combo():
	"""Reset combo counter"""
	combo_count = 0
	combo_multiplier = 1
	combo_timer = 0.0
	_update_hud()

# ============================================================
# VISUAL FEEDBACK
# ============================================================

func _show_score_popup(pos: Vector2, points: int, is_bonus: bool):
	"""Show floating score text"""
	var popup = Label.new()
	popup.text = "+%d" % points
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.position = pos - Vector2(50, 25)
	
	# Style based on points
	if is_bonus:
		popup.add_theme_color_override("font_color", Color(0.2, 1, 0.4))
		popup.add_theme_font_size_override("font_size", 32)
	elif combo_multiplier >= 5:
		popup.add_theme_color_override("font_color", Color(1, 0.5, 0.1))
		popup.add_theme_font_size_override("font_size", 28)
	else:
		popup.add_theme_color_override("font_color", Color(1, 1, 1))
		popup.add_theme_font_size_override("font_size", 24)
	
	game_area.add_child(popup)
	
	# Animate and remove
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", pos.y - 80, 0.8)
	tween.tween_property(popup, "modulate:a", 0, 0.8)
	tween.chain().tween_callback(popup.queue_free)

# ============================================================
# GAME OVER
# ============================================================

func _game_over():
	"""End the game"""
	if is_game_over:
		return
	
	is_game_over = true
	game_started = false
	spawn_timer.stop()
	
	_clear_all_targets()
	
	# Calculate stats
	var total_clicks = total_hits + total_misses
	var accuracy = 0
	if total_clicks > 0:
		accuracy = int((float(total_hits) / total_clicks) * 100)
	
	print("[Game] ========================================")
	print("[Game] GAME OVER")
	print("[Game] Score: %d | Level: %d | Hits: %d" % [current_score, max_level_reached, total_hits])
	print("[Game] Accuracy: %d%% | Max Combo: x%d" % [accuracy, max_combo])
	print("[Game] ========================================")
	
	# ========================================
	# ACHIEVEMENTS - Check at game over
	# ========================================
	if has_achievements:
		Achievements.increment_games_played()
		Achievements.check_game_over(current_score, total_hits, max_combo)
		print("[Game] Achievements checked - games played: %d" % Achievements.get_games_played())
	
	_show_game_over_screen(accuracy)

func _show_game_over_screen(accuracy: int):
	"""Display game over panel and submit score"""
	game_over_panel.visible = true
	
	# Title based on level reached
	match max_level_reached:
		5:
			title_label.text = "CHEESE MASTER!"
			title_label.add_theme_color_override("font_color", Color.GOLD)
		4:
			title_label.text = "Excellent Run!"
			title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		3:
			title_label.text = "Great Game!"
			title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		2:
			title_label.text = "Good Effort!"
			title_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		_:
			title_label.text = "Game Over"
			title_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Update labels
	final_score_label.text = "Final Score: %d" % current_score
	hits_result.text = "Level: %d" % max_level_reached
	accuracy_result.text = "Accuracy: %d%%" % accuracy
	max_combo_label.text = "Max Combo: x%d" % max_combo
	
	# Submit score
	if CheddaBoards.is_ready():
		if CheddaBoards.is_authenticated():
			var auth_type = "anonymous" if CheddaBoards.is_anonymous() else "account"
			status_label.text = "Saving score..."
			status_label.add_theme_color_override("font_color", Color.WHITE)
			_set_buttons_disabled(true)
			_submit_score()
			print("[Game] Submitting score (auth: %s)" % auth_type)
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
	# Use max_combo as the streak value for this game
	if has_achievements:
		Achievements.submit_with_score(current_score, max_combo)
		print("[Game] Submitting score with achievements: %d (combo: %d, level: %d)" % [current_score, max_combo, max_level_reached])
	else:
		CheddaBoards.submit_score(current_score, max_combo)
		print("[Game] Submitting score: %d (combo: %d)" % [current_score, max_combo])

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
	print("[Game] Score submitted: %d points" % score)
	score_submitted = true
	
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
	print("[Game] Score submission failed: %s" % reason)
	
	status_label.text = "Save failed: %s" % reason
	status_label.add_theme_color_override("font_color", Color.RED)
	
	_set_buttons_disabled(false)

# ============================================================
# BUTTON HANDLERS
# ============================================================

func _on_play_again_pressed():
	print("[Game] Play again")
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	print("[Game] Main menu")
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_leaderboard_pressed():
	print("[Game] Leaderboard")
	get_tree().change_scene_to_file("res://Leaderboard.tscn")

# ============================================================
# DEBUG
# ============================================================

func _input(event):
	# Debug click positions
	if event is InputEventMouseButton and event.pressed:
		print("=== CLICK DEBUG ===")
		print("Mouse position: ", event.position)
		print("Global mouse: ", get_global_mouse_position())
		print("Viewport size: ", get_viewport().get_visible_rect().size)
		print("Window size: ", DisplayServer.window_get_size())
	
	# Keyboard shortcuts
	if event is InputEventKey and event.pressed:
		# F9 for debug status
		if event.keycode == KEY_F9:
			_debug_status()
			get_viewport().set_input_as_handled()
		# F10 for achievement debug (if available)
		if event.keycode == KEY_F10 and has_achievements:
			Achievements.debug_status()
			get_viewport().set_input_as_handled()

func _debug_status():
	"""Print debug status"""
	print("")
	print("========================================")
	print("         Game Debug Status             ")
	print("========================================")
	print(" Score:        %d" % current_score)
	print(" Level:        %d / %d" % [current_level, MAX_LEVEL])
	print(" Max Level:    %d" % max_level_reached)
	print(" Next Level:   %s" % (_get_next_level_threshold()))
	print(" Combo:        x%d (count: %d)" % [combo_multiplier, combo_count])
	print(" Max Combo:    x%d" % max_combo)
	print(" Hits:         %d" % total_hits)
	print(" Misses:       %d" % total_misses)
	print("----------------------------------------")
	print(" Time Left:    %.1fs / %.1fs max" % [time_remaining, MAX_TIME])
	print(" Time Bonuses: +%.2fs/hit, +%.1fs/level" % [TIME_BONUS_PER_HIT, TIME_BONUS_PER_LEVEL])
	print("----------------------------------------")
	print(" Targets:      %d / %d" % [active_targets.size(), _get_level_max_targets()])
	print(" Speed Mult:   %.2fx" % _get_level_speed_mult())
	print(" Size Mult:    %.2fx" % _get_level_size_mult())
	print(" Spawn Time:   %.2fs" % spawn_timer.wait_time)
	print("----------------------------------------")
	print(" Platform:     %s" % OS.get_name())
	print(" SDK Ready:    %s" % CheddaBoards.is_ready())
	print(" Authenticated: %s" % CheddaBoards.is_authenticated())
	print(" Achievements: %s" % ("enabled" if has_achievements else "disabled"))
	if has_achievements:
		print(" Games Played: %d" % Achievements.get_games_played())
		print(" Unlocked:     %d / %d" % [Achievements.get_unlocked_count(), Achievements.get_total_count()])
	print("========================================")
	print("")

func _get_next_level_threshold() -> String:
	"""Get points needed for next level"""
	if current_level >= MAX_LEVEL:
		return "MAX"
	var next_threshold = LEVEL_THRESHOLDS[current_level]
	var points_needed = next_threshold - current_score
	return "%d pts to Level %d" % [points_needed, current_level + 1]
