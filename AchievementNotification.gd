# AchievementNotification.gd v1.0.0
# Shows achievement unlock notifications during gameplay
# https://github.com/cheddatech/CheddaBoards-SDK
#
# ============================================================
# USAGE
# ============================================================
# 1. Add AchievementNotification.tscn to your Game scene
# 2. It auto-connects to Achievements signals
# 3. Notifications appear when achievements unlock
# ============================================================

extends Control

# ============================================================
# CONFIGURATION
# ============================================================

## How long to show each notification
@export var display_duration: float = 3.0

## Animation duration for slide in/out
@export var animation_duration: float = 0.3

## Offset from top of screen when hidden
@export var hidden_offset: float = -150.0

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
# ACHIEVEMENT UNLOCKED
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
	
	# Start showing if not already
	if not is_showing:
		_show_next()

func _show_next():
	"""Show the next queued notification"""
	if queue.is_empty():
		is_showing = false
		return
	
	is_showing = true
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
	_animate_in()

func _animate_in():
	"""Animate panel sliding in from top"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "position:y", original_position.y, animation_duration)
	tween.tween_callback(_start_display_timer)

func _start_display_timer():
	"""Wait for display duration then animate out"""
	await get_tree().create_timer(display_duration).timeout
	_animate_out()

func _animate_out():
	"""Animate panel sliding out to top"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "position:y", hidden_offset, animation_duration)
	tween.tween_callback(_on_hide_complete)

func _on_hide_complete():
	"""Called when hide animation completes"""
	panel.visible = false
	
	# Show next in queue (if any)
	_show_next()

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
		_show_next()

func clear_queue():
	"""Clear all pending notifications"""
	queue.clear()
