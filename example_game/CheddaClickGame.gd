# CheddaClickGame.gd v1.0.0
# Standalone clicker game - works with GameWrapper
# Emits signals that GameWrapper listens to for CheddaBoards integration
#
# ============================================================
# SIGNALS (required by GameWrapper)
# ============================================================
# score_changed(score: int, combo: int) - when score updates
# stats_changed(hits: int, misses: int, level: int) - when stats update
# time_changed(time_remaining: float, max_time: float) - for time display
# game_over(final_score: int, stats: Dictionary) - when game ends
#
# ============================================================

extends Control

# ============================================================
# SIGNALS - GameWrapper listens to these
# ============================================================

signal score_changed(score: int, combo: int)
signal stats_changed(hits: int, misses: int, level: int)
signal time_changed(time_remaining: float, max_time: float)
signal game_over(final_score: int, stats: Dictionary)

# ============================================================
# CONFIGURATION
# ============================================================

const GAME_DURATION: float = 30.0
const BASE_POINTS: int = 100
const COMBO_DECAY_TIME: float = 2.0
const MAX_COMBO_MULTIPLIER: int = 10
const QUICK_CLICK_BONUS: float = 0.5

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

# Level system
const LEVEL_THRESHOLDS: Array[int] = [0, 1000, 2500, 5000, 8000]
const LEVEL_SPEED_MULT: Array[float] = [1.0, 1.1, 1.2, 1.35, 1.5]
const LEVEL_SPAWN_MULT: Array[float] = [1.0, 0.85, 0.7, 0.55, 0.4]
const LEVEL_SIZE_MULT: Array[float] = [1.0, 0.95, 0.9, 0.85, 0.8]
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

var current_level: int = 1
var max_level_reached: int = 1

var active_targets: Array = []
var target_texture: Texture2D = null

# ============================================================
# NODE REFERENCES
# ============================================================

@onready var game_area = $GameArea
@onready var spawn_timer = $SpawnTimer

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# Load target texture
	target_texture = load("res://example_game/cheese.png")
	if not target_texture:
		push_warning("[CheddaClick] Target texture not found")
	
	# Connect timer
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Connect game area for misses
	game_area.gui_input.connect(_on_game_area_input)
	
	print("[CheddaClick] Game ready!")
	_start_game()

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
	last_hit_time = 0.0
	combo_timer = 0.0
	
	_clear_all_targets()
	
	spawn_timer.wait_time = SPAWN_TIME_MAX
	spawn_timer.start()
	
	# Emit initial state
	score_changed.emit(current_score, combo_multiplier)
	stats_changed.emit(total_hits, total_misses, current_level)
	time_changed.emit(time_remaining, MAX_TIME)
	
	print("[CheddaClick] Game started!")

## Called by GameWrapper when Play Again is pressed
func restart():
	"""Restart the game (called by GameWrapper)"""
	_start_game()

# ============================================================
# GAME LOOP
# ============================================================

func _process(delta):
	if not game_started or is_game_over:
		return
	
	# Update time
	time_remaining -= delta
	time_changed.emit(time_remaining, MAX_TIME)
	
	# Update combo decay
	if combo_count > 0:
		combo_timer += delta
		if combo_timer >= COMBO_DECAY_TIME:
			_reset_combo()
	
	# Check game over
	if time_remaining <= 0:
		time_remaining = 0
		_end_game()

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
		
		var age = target.get_meta("age") + delta
		target.set_meta("age", age)
		
		var lifetime = target.get_meta("lifetime")
		if age >= lifetime:
			targets_to_remove.append(target)
			_on_target_missed(target)
			continue
		
		var speed = target.get_meta("speed")
		var direction = target.get_meta("direction")
		target.position += direction * speed * delta
		
		var target_size = target.custom_minimum_size
		if target.position.x <= 0 or target.position.x + target_size.x >= game_rect.size.x:
			direction.x *= -1
			target.set_meta("direction", direction)
			target.position.x = clamp(target.position.x, 0, game_rect.size.x - target_size.x)
		
		if target.position.y <= 0 or target.position.y + target_size.y >= game_rect.size.y:
			direction.y *= -1
			target.set_meta("direction", direction)
			target.position.y = clamp(target.position.y, 0, game_rect.size.y - target_size.y)
		
		var fade_start = lifetime * 0.7
		if age > fade_start:
			var fade_progress = (age - fade_start) / (lifetime - fade_start)
			target.modulate.a = 1.0 - fade_progress
	
	for target in targets_to_remove:
		_remove_target(target)

# ============================================================
# TARGET SPAWNING
# ============================================================

func _on_spawn_timer_timeout():
	if is_game_over or active_targets.size() >= _get_level_max_targets():
		return
	_spawn_target()

func _spawn_target():
	var target = _create_target()
	game_area.add_child(target)
	active_targets.append(target)

func _create_target() -> Control:
	var target = TextureRect.new()
	
	if target_texture:
		target.texture = target_texture
	
	var size_mult = _get_level_size_mult()
	var size_range = (TARGET_MAX_SIZE - TARGET_MIN_SIZE) * size_mult
	var target_size = TARGET_MIN_SIZE + (size_range * randf())
	target.custom_minimum_size = Vector2(target_size, target_size)
	target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var game_rect = game_area.get_rect()
	var margin = target_size / 2
	var pos_x = randf_range(margin, game_rect.size.x - target_size - margin)
	var pos_y = randf_range(margin, game_rect.size.y - target_size - margin)
	target.position = Vector2(pos_x, pos_y)
	
	var speed_mult = _get_level_speed_mult()
	var speed = randf_range(TARGET_MIN_SPEED, TARGET_MAX_SPEED) * speed_mult
	var direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var lifetime = randf_range(TARGET_MIN_LIFETIME, TARGET_MAX_LIFETIME)
	
	target.set_meta("speed", speed)
	target.set_meta("direction", direction)
	target.set_meta("lifetime", lifetime)
	target.set_meta("age", 0.0)
	target.set_meta("points", _calculate_target_points(target_size))
	
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	target.gui_input.connect(_on_target_input.bind(target))
	
	return target

func _calculate_target_points(size: float) -> int:
	var size_factor = 1.0 - ((size - TARGET_MIN_SIZE) / (TARGET_MAX_SIZE - TARGET_MIN_SIZE))
	var level_bonus = 1.0 + (current_level - 1) * 0.1
	return int(BASE_POINTS * (1 + size_factor) * level_bonus)

func _remove_target(target: Control):
	if target in active_targets:
		active_targets.erase(target)
	if is_instance_valid(target):
		target.queue_free()

func _clear_all_targets():
	for target in active_targets:
		if is_instance_valid(target):
			target.queue_free()
	active_targets.clear()

# ============================================================
# INPUT HANDLING
# ============================================================

func _on_target_input(event: InputEvent, target: Control):
	if is_game_over:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hit_target(target)
		get_viewport().set_input_as_handled()

func _on_game_area_input(event: InputEvent):
	if is_game_over:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_register_miss()

func _hit_target(target: Control):
	if not is_instance_valid(target):
		return
	
	var base_points = target.get_meta("points")
	var current_time = Time.get_ticks_msec() / 1000.0
	
	var time_bonus = 1.0
	if last_hit_time > 0 and (current_time - last_hit_time) < QUICK_CLICK_BONUS:
		time_bonus = 1.5
	
	combo_count += 1
	combo_timer = 0.0
	combo_multiplier = min(1 + (combo_count / 3), MAX_COMBO_MULTIPLIER)
	
	if combo_multiplier > max_combo:
		max_combo = combo_multiplier
	
	var points = int(base_points * combo_multiplier * time_bonus)
	current_score += points
	total_hits += 1
	last_hit_time = current_time
	
	_add_time(TIME_BONUS_PER_HIT)
	_check_level_up()
	
	# Show floating score
	_show_score_popup(target.position + target.custom_minimum_size / 2, points, time_bonus > 1.0)
	
	_remove_target(target)
	
	# Emit signals for GameWrapper
	score_changed.emit(current_score, combo_multiplier)
	stats_changed.emit(total_hits, total_misses, current_level)

func _on_target_missed(target: Control):
	total_misses += 1
	_reset_combo()
	stats_changed.emit(total_hits, total_misses, current_level)

func _register_miss():
	total_misses += 1
	_reset_combo()
	stats_changed.emit(total_hits, total_misses, current_level)

func _reset_combo():
	combo_count = 0
	combo_multiplier = 1
	combo_timer = 0.0
	score_changed.emit(current_score, combo_multiplier)

# ============================================================
# LEVEL SYSTEM
# ============================================================

func _check_level_up():
	if current_level >= MAX_LEVEL:
		return
	
	var next_level = current_level + 1
	var threshold = LEVEL_THRESHOLDS[next_level - 1]
	
	if current_score >= threshold:
		_level_up(next_level)

func _level_up(new_level: int):
	current_level = new_level
	if current_level > max_level_reached:
		max_level_reached = current_level
	
	var time_added = _add_time(TIME_BONUS_PER_LEVEL)
	
	var spawn_mult = LEVEL_SPAWN_MULT[current_level - 1]
	spawn_timer.wait_time = SPAWN_TIME_MAX * spawn_mult
	
	_show_level_up_popup(time_added)
	
	# Check level achievements (if Achievements autoload exists)
	var achievements = get_node_or_null("/root/Achievements")
	if achievements:
		achievements.check_level(current_level, time_remaining)
	
	stats_changed.emit(total_hits, total_misses, current_level)
	print("[CheddaClick] ★★★ LEVEL %d ★★★" % current_level)

func _get_level_speed_mult() -> float:
	return LEVEL_SPEED_MULT[current_level - 1]

func _get_level_size_mult() -> float:
	return LEVEL_SIZE_MULT[current_level - 1]

func _get_level_max_targets() -> int:
	return LEVEL_MAX_TARGETS[current_level - 1]

func _add_time(amount: float) -> float:
	var old_time = time_remaining
	time_remaining = min(time_remaining + amount, MAX_TIME)
	return time_remaining - old_time

# ============================================================
# VISUAL FEEDBACK
# ============================================================

func _show_score_popup(pos: Vector2, points: int, is_bonus: bool):
	var popup = Label.new()
	popup.text = "+%d" % points
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.position = pos - Vector2(50, 25)
	
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
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", pos.y - 80, 0.8)
	tween.tween_property(popup, "modulate:a", 0, 0.8)
	tween.chain().tween_callback(popup.queue_free)

func _show_level_up_popup(time_added: float = 0.0):
	var popup = Label.new()
	if time_added > 0:
		popup.text = "LEVEL %d!\n+%.1fs" % [current_level, time_added]
	else:
		popup.text = "LEVEL %d!" % current_level
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 64)
	
	match current_level:
		2: popup.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		3: popup.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		4: popup.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		5: popup.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_: popup.add_theme_color_override("font_color", Color.WHITE)
	
	var viewport_size = get_viewport().get_visible_rect().size
	popup.position = Vector2(viewport_size.x / 2 - 150, viewport_size.y / 2 - 60)
	popup.custom_minimum_size = Vector2(300, 120)
	
	add_child(popup)
	
	popup.scale = Vector2(0.5, 0.5)
	popup.pivot_offset = Vector2(150, 60)
	
	var tween = create_tween()
	tween.tween_property(popup, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_interval(0.5)
	tween.tween_property(popup, "modulate:a", 0, 0.4)
	tween.tween_callback(popup.queue_free)

# ============================================================
# GAME OVER
# ============================================================

func _end_game():
	if is_game_over:
		return
	
	is_game_over = true
	game_started = false
	spawn_timer.stop()
	
	_clear_all_targets()
	
	var total_clicks = total_hits + total_misses
	var accuracy = 0
	if total_clicks > 0:
		accuracy = int((float(total_hits) / total_clicks) * 100)
	
	print("[CheddaClick] GAME OVER - Score: %d" % current_score)
	
	# Emit game_over signal with stats for GameWrapper
	game_over.emit(current_score, {
		"hits": total_hits,
		"misses": total_misses,
		"max_combo": max_combo,
		"level": max_level_reached,
		"accuracy": accuracy
	})
