# AchievementNotification.gd v2.0.0
# Shows achievement unlock notifications during gameplay
# - STACKED display: shows up to 4 achievements at once
# - Fast timing: 1.5s per achievement (was 3s)
# - Grouped mode: collapses many achievements into summary
# https://github.com/cheddatech/CheddaBoards-Godot

extends Control

# ============================================================
# CONFIGURATION
# ============================================================

## How long to show each notification (reduced from 3.0)
@export var display_duration: float = 1.5

## Animation duration for slide in/out (faster)
@export var animation_duration: float = 0.2

## Offset from top of screen when hidden
@export var hidden_offset: float = -150.0

## Maximum achievements to show at once before grouping
@export var max_visible_stacked: int = 4

## Spacing between stacked notifications
@export var stack_spacing: float = 70.0

# ============================================================
# NODE REFERENCES
# ============================================================

@onready var panel = $Panel
@onready var name_label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var description_label = $Panel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var icon = $Panel/MarginContainer/VBoxContainer/Icon

# ============================================================
# STATE
# ============================================================

var is_showing: bool = false
var queue: Array = []
var original_position: Vector2
var active_panels: Array = []  # For stacked display
var panel_pool: Array = []  # Reusable panel instances

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# Store original position
	original_position = panel.position
	
	# Hide initially (move off screen)
	panel.position.y = hidden_offset
	panel.visible = false
	
	# Connect to Achievements signals
	Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
	
	print("[AchievementNotification] Ready")

# ============================================================
# ACHIEVEMENT UNLOCKED - Now with batch handling
# ============================================================

func _on_achievement_unlocked(achievement_id: String, achievement_name: String):
	"""Queue an achievement notification"""
	var achievement_data = Achievements.get_achievement(achievement_id)
	
	queue.append({
		"id": achievement_id,
		"name": achievement_name,
		"description": achievement_data.get("description", ""),
		"icon": achievement_data.get("icon", "")
	})
	
	# Start showing if not already - with small delay to batch rapid unlocks
	if not is_showing:
		_start_batch_display()

func _start_batch_display():
	"""Start display with small delay to collect rapid unlocks"""
	is_showing = true
	
	# Wait a tiny bit to collect any rapid-fire achievements
	var timer = get_tree().create_timer(0.1)
	await timer.timeout
	
	_show_batch()

func _show_batch():
	"""Show a batch of achievements (stacked or grouped)"""
	if queue.is_empty():
		is_showing = false
		return
	
	var batch_count = queue.size()
	
	if batch_count > max_visible_stacked:
		# Too many - show grouped summary
		_show_grouped(batch_count)
	elif batch_count > 1:
		# Multiple - show stacked
		_show_stacked()
	else:
		# Single - show normally
		_show_single()

func _show_single():
	"""Show a single achievement notification"""
	if queue.is_empty():
		is_showing = false
		return
	
	var achievement = queue.pop_front()
	
	# Update UI
	name_label.text = achievement.name
	description_label.text = achievement.description
	
	# Load icon if available
	if achievement.icon != "" and ResourceLoader.exists(achievement.icon):
		icon.texture = load(achievement.icon)
		icon.visible = true
	else:
		icon.visible = false
	
	# Show and animate
	panel.visible = true
	_animate_panel_in(panel, 0)
	
	# Schedule hide
	var timer = get_tree().create_timer(display_duration)
	await timer.timeout
	
	_animate_panel_out(panel, func():
		panel.visible = false
		# Show next batch
		if not queue.is_empty():
			_show_batch()
		else:
			is_showing = false
	)

func _show_stacked():
	"""Show multiple achievements stacked vertically"""
	var to_show = min(queue.size(), max_visible_stacked)
	var panels_to_animate: Array = []
	
	for i in range(to_show):
		var achievement = queue.pop_front()
		var p = _get_or_create_panel()
		_configure_panel(p, achievement, i)
		panels_to_animate.append(p)
	
	# Animate all in with stagger
	for i in range(panels_to_animate.size()):
		var p = panels_to_animate[i]
		var delay = i * 0.08  # Slight stagger
		_animate_panel_in_delayed(p, i, delay)
	
	# Schedule batch hide
	var total_time = display_duration + (to_show * 0.08)
	var timer = get_tree().create_timer(total_time)
	await timer.timeout
	
	# Animate all out
	for i in range(panels_to_animate.size()):
		var p = panels_to_animate[i]
		_animate_panel_out(p, func():
			p.visible = false
			_return_panel_to_pool(p)
		)
	
	# Wait for animations then show next
	var out_timer = get_tree().create_timer(animation_duration + 0.1)
	await out_timer.timeout
	
	if not queue.is_empty():
		_show_batch()
	else:
		is_showing = false

func _show_grouped(total_count: int):
	"""Show a grouped summary when many achievements unlock at once"""
	# Clear the queue but remember the count
	var first_few: Array = []
	for i in range(min(3, queue.size())):
		first_few.append(queue[i].name)
	queue.clear()
	
	# Update UI with summary
	name_label.text = "🏆 %d Achievements!" % total_count
	
	if first_few.size() > 0:
		var names_text = first_few.slice(0, 2).reduce(func(a, b): return a + ", " + b)
		if total_count > 2:
			names_text += " & %d more" % (total_count - 2)
		description_label.text = names_text
	else:
		description_label.text = "Great progress!"
	
	icon.visible = false
	
	# Show with slightly longer duration for summary
	panel.visible = true
	_animate_panel_in(panel, 0)
	
	var timer = get_tree().create_timer(display_duration * 1.5)
	await timer.timeout
	
	_animate_panel_out(panel, func():
		panel.visible = false
		is_showing = false
	)

# ============================================================
# PANEL MANAGEMENT
# ============================================================

func _get_or_create_panel() -> Control:
	"""Get a panel from pool or create new one"""
	if panel_pool.size() > 0:
		return panel_pool.pop_back()
	
	# Duplicate the template panel
	var new_panel = panel.duplicate()
	new_panel.visible = false
	panel.get_parent().add_child(new_panel)
	return new_panel

func _return_panel_to_pool(p: Control):
	"""Return panel to pool for reuse"""
	if p != panel and not panel_pool.has(p):
		panel_pool.append(p)

func _configure_panel(p: Control, achievement: Dictionary, stack_index: int):
	"""Configure a panel for display"""
	var name_lbl = p.get_node("MarginContainer/VBoxContainer/NameLabel")
	var desc_lbl = p.get_node("MarginContainer/VBoxContainer/DescriptionLabel")
	var ico = p.get_node("MarginContainer/VBoxContainer/Icon")
	
	name_lbl.text = achievement.name
	desc_lbl.text = achievement.description
	
	if achievement.icon != "" and ResourceLoader.exists(achievement.icon):
		ico.texture = load(achievement.icon)
		ico.visible = true
	else:
		ico.visible = false
	
	# Position for stacking
	p.position = Vector2(original_position.x, hidden_offset)
	p.visible = true

# ============================================================
# ANIMATIONS
# ============================================================

func _animate_panel_in(p: Control, stack_index: int):
	"""Animate panel sliding in"""
	var target_y = original_position.y + (stack_index * stack_spacing)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	p.modulate.a = 0.0
	tween.set_parallel(true)
	tween.tween_property(p, "position:y", target_y, animation_duration)
	tween.tween_property(p, "modulate:a", 1.0, animation_duration * 0.7)

func _animate_panel_in_delayed(p: Control, stack_index: int, delay: float):
	"""Animate panel in with delay"""
	var timer = get_tree().create_timer(delay)
	await timer.timeout
	_animate_panel_in(p, stack_index)

func _animate_panel_out(p: Control, on_complete: Callable):
	"""Animate panel sliding out"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(p, "position:y", hidden_offset, animation_duration)
	tween.tween_property(p, "modulate:a", 0.0, animation_duration * 0.7)
	tween.set_parallel(false)
	tween.tween_callback(on_complete)

# ============================================================
# MANUAL CONTROL
# ============================================================

func show_notification(achievement_name: String, description: String):
	"""Manually show a notification"""
	queue.append({
		"id": "",
		"name": achievement_name,
		"description": description,
		"icon": ""
	})
	
	if not is_showing:
		_start_batch_display()

func clear_queue():
	"""Clear all pending notifications"""
	queue.clear()
