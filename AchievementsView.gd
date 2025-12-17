# AchievementsView.gd v1.1.0 - CheddaClick Edition
# Displays all achievements with unlock status and progress
# https://github.com/cheddatech/CheddaBoards-SDK
#
# ============================================================
# USAGE
# ============================================================
# Pair with AchievementsView.tscn
# Navigate to this scene from your main menu
# ============================================================

extends Control

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var progress_label = $MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel
@onready var achievements_list = $MarginContainer/VBoxContainer/AchievementsScroll/AchievementsList
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

# ============================================================
# INITIALIZATION
# ============================================================
func _ready():
	# Connect button
	back_button.pressed.connect(_on_back_pressed)
	
	# Connect to achievement signals for live updates
	Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
	Achievements.achievements_ready.connect(_on_achievements_ready)
	
	# Load and display achievements
	_load_achievements()
	
	print("[AchievementsView] Loaded")

func _on_achievements_ready():
	"""Refresh when achievements sync from backend"""
	_load_achievements()

func _on_achievement_unlocked(_id: String, _name: String):
	"""Refresh when a new achievement unlocks"""
	_load_achievements()

# ============================================================
# LOAD ACHIEVEMENTS
# ============================================================
func _load_achievements():
	"""Load all achievements and populate the list"""
	# Clear existing items
	for child in achievements_list.get_children():
		child.queue_free()
	
	# Get all achievements from the manager
	var all_achievements = Achievements.get_all_achievements()
	
	# Update progress label
	var unlocked_count = Achievements.get_unlocked_count()
	var total_count = Achievements.get_total_count()
	var percentage = Achievements.get_unlocked_percentage()
	
	progress_label.text = "%d / %d Unlocked (%.0f%%)" % [unlocked_count, total_count, percentage]
	
	# Sort: Unlocked first, then by name
	all_achievements.sort_custom(_sort_achievements)
	
	# Create UI for each achievement
	for achievement in all_achievements:
		var achievement_item = _create_achievement_item(achievement)
		achievements_list.add_child(achievement_item)
	
	print("[AchievementsView] Loaded %d achievements (%d unlocked)" % [all_achievements.size(), unlocked_count])

func _sort_achievements(a, b):
	"""Sort achievements: unlocked first, then alphabetically"""
	if a.unlocked != b.unlocked:
		return a.unlocked  # Unlocked achievements first
	return a.name < b.name  # Then alphabetically

# ============================================================
# CREATE ACHIEVEMENT UI
# ============================================================
func _create_achievement_item(achievement: Dictionary) -> PanelContainer:
	"""Create a single achievement item UI"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 100)
	
	# Dim if locked
	if not achievement.unlocked:
		panel.modulate = Color(0.6, 0.6, 0.6, 1.0)
	
	# Margin container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	# Main horizontal layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	margin.add_child(hbox)
	
	# Icon (if available) or status indicator
	var icon_container = _create_icon(achievement)
	hbox.add_child(icon_container)
	
	# Content (name, description, progress)
	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 5)
	hbox.add_child(content_vbox)
	
	# Achievement name
	var name_label = Label.new()
	name_label.text = achievement.name
	name_label.add_theme_font_size_override("font_size", 24)
	if achievement.unlocked:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Gold
	content_vbox.add_child(name_label)
	
	# Achievement description
	var desc_label = Label.new()
	desc_label.text = achievement.description
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_vbox.add_child(desc_label)
	
	# Progress bar (if has progress and not unlocked)
	if not achievement.unlocked and achievement.progress.current > 0:
		var progress_bar = _create_progress_bar(achievement.progress)
		content_vbox.add_child(progress_bar)
	
	# Status label
	var status_label = Label.new()
	if achievement.unlocked:
		status_label.text = "✓ UNLOCKED"
		status_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))  # Green
	else:
		status_label.text = "🔒 Locked"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(status_label)
	
	return panel

func _create_icon(achievement: Dictionary) -> Control:
	"""Create icon or placeholder for achievement"""
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Try to load icon
	var icon_path = achievement.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	else:
		# Placeholder: colored square based on unlock status
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(64, 64)
		if achievement.unlocked:
			color_rect.color = Color(1.0, 0.84, 0.0, 0.3)  # Gold tint
		else:
			color_rect.color = Color(0.3, 0.3, 0.3, 0.5)  # Gray
		return color_rect
	
	return icon_rect

func _create_progress_bar(progress: Dictionary) -> VBoxContainer:
	"""Create progress bar UI"""
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	
	# Progress label
	var label = Label.new()
	label.text = "Progress: %d / %d" % [progress.current, progress.total]
	label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(label)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 20)
	progress_bar.max_value = progress.total
	progress_bar.value = progress.current
	progress_bar.show_percentage = false
	vbox.add_child(progress_bar)
	
	return vbox

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_back_pressed():
	"""Return to main menu"""
	print("[AchievementsView] Back to menu")
	get_tree().change_scene_to_file("res://MainMenu.tscn")

# ============================================================
# REFRESH
# ============================================================
func refresh():
	"""Refresh the achievements list"""
	_load_achievements()

