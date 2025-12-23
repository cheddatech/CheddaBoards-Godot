# CheeseCatch.gd
# A tiny game demonstrating CheddaBoards integration
# Click falling cheese to score points! Miss 3 and it's game over.
extends Control

# ============================================================
# CONFIGURATION
# ============================================================

const CHEESE_EMOJI := "🧀"
const MISS_PENALTY := 3
const SPAWN_INTERVAL_START := 1.5
const SPAWN_INTERVAL_MIN := 0.4
const FALL_SPEED_START := 200.0
const FALL_SPEED_MAX := 600.0

# ============================================================
# STATE
# ============================================================

var score: int = 0
var streak: int = 0
var best_streak: int = 0
var misses: int = 0
var is_playing: bool = false
var spawn_interval: float = SPAWN_INTERVAL_START
var fall_speed: float = FALL_SPEED_START

# ============================================================
# NODES
# ============================================================

var score_label: Label
var streak_label: Label
var status_label: Label
var start_button: Button
var leaderboard_button: Button
var cheese_container: Node
var spawn_timer: Timer

# Name entry nodes
var name_overlay: ColorRect
var name_panel: PanelContainer
var name_input: LineEdit
var name_confirm_button: Button

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	randomize()
	
	# Build the UI
	_build_ui()
	_build_name_panel()
	
	# Wait for CheddaBoards
	status_label.text = "Connecting..."
	start_button.disabled = true
	
	await CheddaBoards.wait_until_ready()
	
	# Connect signals
	CheddaBoards.login_success.connect(_on_login_success)
	CheddaBoards.score_submitted.connect(_on_score_submitted)
	CheddaBoards.score_error.connect(_on_score_error)
	CheddaBoards.leaderboard_loaded.connect(_on_leaderboard_loaded)
	
	# Prompt for name
	_prompt_for_name()

func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Title
	var title = Label.new()
	title.text = "🧀 CHEESE CATCH 🧀"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(get_viewport_rect().size.x, 50)
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)
	
	# Score label
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.position = Vector2(20, 80)
	score_label.add_theme_font_size_override("font_size", 24)
	add_child(score_label)
	
	# Streak label
	streak_label = Label.new()
	streak_label.text = "Streak: 0"
	streak_label.position = Vector2(20, 110)
	streak_label.add_theme_font_size_override("font_size", 20)
	streak_label.add_theme_color_override("font_color", Color.ORANGE)
	add_child(streak_label)
	
	# Status label (center)
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.set_anchors_preset(Control.PRESET_CENTER)
	status_label.position.y = -50
	status_label.add_theme_font_size_override("font_size", 28)
	add_child(status_label)
	
	# Start button
	start_button = Button.new()
	start_button.text = "START GAME"
	start_button.set_anchors_preset(Control.PRESET_CENTER)
	start_button.position = Vector2(-75, 0)
	start_button.size = Vector2(150, 50)
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)
	
	# Leaderboard button
	leaderboard_button = Button.new()
	leaderboard_button.text = "LEADERBOARD"
	leaderboard_button.set_anchors_preset(Control.PRESET_CENTER)
	leaderboard_button.position = Vector2(-75, 60)
	leaderboard_button.size = Vector2(150, 40)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	add_child(leaderboard_button)
	
	# Cheese container
	cheese_container = Node.new()
	cheese_container.name = "CheeseContainer"
	add_child(cheese_container)
	
	# Spawn timer
	spawn_timer = Timer.new()
	spawn_timer.timeout.connect(_spawn_cheese)
	add_child(spawn_timer)

func _build_name_panel():
	# Semi-transparent overlay
	name_overlay = ColorRect.new()
	name_overlay.color = Color(0, 0, 0, 0.7)
	name_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_overlay.visible = false
	add_child(name_overlay)
	
	# Panel container
	name_panel = PanelContainer.new()
	name_panel.set_anchors_preset(Control.PRESET_CENTER)
	name_panel.position = Vector2(-150, -80)
	name_panel.size = Vector2(300, 160)
	name_panel.visible = false
	add_child(name_panel)
	
	# Margin container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	name_panel.add_child(margin)
	
	# VBox for content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title label
	var title = Label.new()
	title.text = "Enter Your Name"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# Name input
	name_input = LineEdit.new()
	name_input.placeholder_text = "Your name..."
	name_input.max_length = 16
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.add_theme_font_size_override("font_size", 20)
	name_input.text_submitted.connect(_on_name_submitted)
	vbox.add_child(name_input)
	
	# Confirm button
	name_confirm_button = Button.new()
	name_confirm_button.text = "PLAY!"
	name_confirm_button.add_theme_font_size_override("font_size", 20)
	name_confirm_button.pressed.connect(_on_name_confirm_pressed)
	vbox.add_child(name_confirm_button)

# ============================================================
# NAME ENTRY
# ============================================================

func _prompt_for_name():
	var default_name = "Player_%04d" % (randi() % 10000)
	
	if OS.get_name() == "Web":
		# Web: use browser prompt for better mobile keyboard support
		var result = JavaScriptBridge.eval("prompt('Enter your name:', '%s')" % default_name, true)
		if result == null or str(result) == "null" or str(result).strip_edges() == "":
			result = default_name
		_login_with_name(str(result).strip_edges())
	else:
		# Native: show in-game panel
		_show_name_panel(default_name)

func _show_name_panel(default_name: String):
	# Hide game UI
	start_button.visible = false
	leaderboard_button.visible = false
	status_label.text = ""
	
	# Show name panel
	name_overlay.visible = true
	name_panel.visible = true
	name_input.text = default_name
	name_input.grab_focus()
	name_input.select_all()

func _hide_name_panel():
	name_overlay.visible = false
	name_panel.visible = false

func _on_name_submitted(_text: String):
	_on_name_confirm_pressed()

func _on_name_confirm_pressed():
	var nickname = name_input.text.strip_edges()
	
	# Validate
	if nickname.length() < 2:
		name_input.placeholder_text = "Too short! (min 2)"
		name_input.text = ""
		return
	
	if nickname.length() > 16:
		nickname = nickname.substr(0, 16)
	
	_hide_name_panel()
	_login_with_name(nickname)

func _login_with_name(nickname: String):
	status_label.text = "Logging in..."
	CheddaBoards.change_nickname_to(nickname)
	CheddaBoards.login_anonymous(nickname)

# ============================================================
# GAME LOGIC
# ============================================================

func _on_start_pressed():
	_start_game()

func _start_game():
	score = 0
	streak = 0
	best_streak = 0
	misses = 0
	spawn_interval = SPAWN_INTERVAL_START
	fall_speed = FALL_SPEED_START
	is_playing = true
	
	# Clear old cheese
	for child in cheese_container.get_children():
		child.queue_free()
	
	# Update UI
	_update_labels()
	status_label.text = ""
	start_button.visible = false
	leaderboard_button.visible = false
	
	# Start spawning
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()
	_spawn_cheese()

func _spawn_cheese():
	if not is_playing:
		return
	
	var cheese = _create_cheese()
	cheese_container.add_child(cheese)
	
	# Speed up over time
	spawn_interval = max(SPAWN_INTERVAL_MIN, spawn_interval - 0.02)
	fall_speed = min(FALL_SPEED_MAX, fall_speed + 5)
	spawn_timer.wait_time = spawn_interval

func _create_cheese() -> Button:
	var cheese = Button.new()
	cheese.text = CHEESE_EMOJI
	cheese.add_theme_font_size_override("font_size", 48)
	cheese.flat = true
	cheese.size = Vector2(60, 60)
	
	# Random X position
	var screen_width = get_viewport_rect().size.x
	cheese.position = Vector2(
		randf_range(30, screen_width - 90),
		-60
	)
	
	# Click handler
	cheese.pressed.connect(_on_cheese_clicked.bind(cheese))
	
	# Store fall speed on the cheese
	cheese.set_meta("speed", fall_speed)
	
	return cheese

func _process(delta):
	if not is_playing:
		return
	
	var screen_height = get_viewport_rect().size.y
	
	for cheese in cheese_container.get_children():
		var speed = cheese.get_meta("speed", fall_speed)
		cheese.position.y += speed * delta
		
		# Missed!
		if cheese.position.y > screen_height:
			cheese.queue_free()
			_on_cheese_missed()

func _on_cheese_clicked(cheese: Button):
	if not is_playing:
		return
	
	# Score!
	streak += 1
	best_streak = max(best_streak, streak)
	
	# Bonus points for streak
	var points = 10 + (streak * 2)
	score += points
	
	# Visual feedback
	_show_points(cheese.position, points)
	cheese.queue_free()
	
	_update_labels()

func _on_cheese_missed():
	streak = 0
	misses += 1
	
	_update_labels()
	
	# Flash screen red
	var flash = ColorRect.new()
	flash.color = Color(1, 0, 0, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)
	
	# Game over?
	if misses >= MISS_PENALTY:
		_game_over()

func _game_over():
	is_playing = false
	spawn_timer.stop()
	
	# Clear remaining cheese
	for child in cheese_container.get_children():
		child.queue_free()
	
	# Show game over
	status_label.text = "GAME OVER!\nScore: %d\nBest Streak: %d" % [score, best_streak]
	start_button.text = "PLAY AGAIN"
	start_button.visible = true
	leaderboard_button.visible = true
	
	# Submit score to CheddaBoards!
	_submit_score()

func _submit_score():
	print("[Game] Submitting score: %d, streak: %d" % [score, best_streak])
	CheddaBoards.submit_score(score, best_streak)

func _show_points(pos: Vector2, points: int):
	var label = Label.new()
	label.text = "+%d" % points
	label.position = pos
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.YELLOW)
	add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 50, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)

func _update_labels():
	score_label.text = "Score: %d" % score
	streak_label.text = "Streak: %d  ❤️ %d" % [streak, MISS_PENALTY - misses]

# ============================================================
# CHEDDABOARDS CALLBACKS
# ============================================================

func _on_login_success(nickname: String):
	print("[Game] Logged in as: %s" % nickname)
	status_label.text = "Welcome, %s!\nClick cheese to catch it!\nMiss %d and it's over!" % [nickname, MISS_PENALTY]
	start_button.disabled = false
	start_button.visible = true
	leaderboard_button.visible = true

func _on_score_submitted(_submitted_score: int, _submitted_streak: int):
	print("[Game] Score saved: %d" % score)
	status_label.text += "\n\n✅ Score Saved!"

func _on_score_error(reason: String):
	print("[Game] Score error: %s" % reason)
	status_label.text += "\n\n❌ " + reason

func _on_leaderboard_pressed():
	status_label.text = "Loading leaderboard..."
	CheddaBoards.get_leaderboard("score", 10)

func _on_leaderboard_loaded(entries: Array):
	var text = "🏆 TOP 10 🏆\n\n"
	for entry in entries:
		var medal = ""
		match entry.rank:
			1: medal = "🥇 "
			2: medal = "🥈 "
			3: medal = "🥉 "
		text += "%s#%d %s - %d pts\n" % [medal, entry.rank, entry.nickname, entry.score]
	
	if entries.is_empty():
		text += "No scores yet!\nBe the first!"
	
	status_label.text = text
