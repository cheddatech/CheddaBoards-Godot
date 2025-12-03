# AchievementNotification.gd
# Displays achievement unlock notifications with slide-in animation
extends CanvasLayer

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var panel = $PanelContainer
@onready var title_label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var name_label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var description_label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/DescriptionLabel
@onready var icon_rect = $PanelContainer/MarginContainer/HBoxContainer/IconRect

# ============================================================
# STATE
# ============================================================
var tween: Tween
var notification_queue: Array = []
var is_showing: bool = false

# ============================================================
# INITIALIZATION
# ============================================================
func _ready():
	# Wait for layout to be calculated
	await get_tree().process_frame
	
	# Start off-screen (to the right, vertically centered)
	var viewport_size = get_viewport().size
	panel.position = Vector2(viewport_size.x, viewport_size.y / 2 - panel.size.y / 2)
	visible = false
	print("[AchievementNotification] Ready")

# ============================================================
# SHOW ACHIEVEMENT
# ============================================================
func show_achievement(achievement_name: String, icon_path: String = "", description: String = ""):
	"""Display achievement notification"""
	print("[AchievementNotification] Showing: %s" % achievement_name)
	
	# Add to queue
	notification_queue.append({
		"name": achievement_name,
		"icon": icon_path,
		"description": description
	})
	
	# Show next if not already showing
	if not is_showing:
		_show_next()

func _show_next():
	"""Show next achievement in queue"""
	if notification_queue.is_empty():
		is_showing = false
		return
	
	is_showing = true
	var achievement = notification_queue.pop_front()
	
	# Set text
	name_label.text = achievement.name
	
	# Set description if provided
	if achievement.description != "":
		description_label.text = achievement.description
		description_label.visible = true
	else:
		description_label.visible = false
	
	# Load icon if provided
	if achievement.icon != "":
		var texture = load(achievement.icon)
		if texture:
			icon_rect.texture = texture
			icon_rect.visible = true
		else:
			icon_rect.visible = false
	else:
		icon_rect.visible = false
	
	# Make visible and animate
	visible = true
	_animate_in()

# ============================================================
# ANIMATIONS
# ============================================================
func _animate_in():
	"""Slide in from right-middle"""
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Calculate positions
	var viewport_size = get_viewport().size
	var target_x = viewport_size.x - panel.size.x - 20  # 20px from right edge
	var center_y = viewport_size.y / 2 - panel.size.y / 2  # Vertically centered
	
	# Start from off-screen right, vertically centered
	panel.position = Vector2(viewport_size.x, center_y)
	
	# Animate to target position (right side, centered)
	tween.tween_property(panel, "position", Vector2(target_x, center_y), 0.5)
	
	# Wait 3 seconds
	tween.tween_interval(1.0)
	
	# Slide out
	tween.tween_callback(_animate_out)

func _animate_out():
	"""Slide out to bottom"""
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Animate down off-screen (keep x position, move y down)
	var viewport_height = get_viewport().size.y
	var current_x = panel.position.x
	tween.tween_property(panel, "position", Vector2(current_x, viewport_height), 0.5)
	
	# When done, hide and show next
	tween.tween_callback(_on_animation_complete)

func _on_animation_complete():
	"""Called when animation finishes"""
	visible = false
	
	# Show next achievement if any
	_show_next()
