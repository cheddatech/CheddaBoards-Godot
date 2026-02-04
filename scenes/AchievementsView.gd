# AchievementsView.gd v1.2.0
# Displays all achievements with unlock status and progress
# v1.2.0: Added MobileUI scaling for mobile devices
# https://github.com/cheddatech/CheddaBoards-Godot
#
# ============================================================
# USAGE
# ============================================================
# Pair with AchievementsView.tscn
# Navigate to this scene from your main menu
# Required Autoloads: Achievements, MobileUI
# ============================================================

extends Control

# ============================================================
# NODE REFERENCES
# ============================================================
@onready var margin_container = $MarginContainer
@onready var header_container = $MarginContainer/VBoxContainer/HeaderContainer
@onready var title_label = $MarginContainer/VBoxContainer/HeaderContainer/TitleLabel if has_node("MarginContainer/VBoxContainer/HeaderContainer/TitleLabel") else null
@onready var progress_label = $MarginContainer/VBoxContainer/HeaderContainer/ProgressLabel
@onready var achievements_scroll = $MarginContainer/VBoxContainer/AchievementsScroll
@onready var achievements_list = $MarginContainer/VBoxContainer/AchievementsScroll/AchievementsList
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

# ============================================================
# INITIALIZATION
# ============================================================
func _ready():
	# Scale UI for mobile
	_scale_ui()
	
	# Connect button
	back_button.pressed.connect(_on_back_pressed)
	
	# Connect to achievement signals for live updates
	Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
	Achievements.achievements_ready.connect(_on_achievements_ready)
	
	# Load and display achievements
	_load_achievements()
	
	print("[AchievementsView] v1.2.0 loaded (Mobile: %s, Scale: %.2f)" % [MobileUI.is_mobile, MobileUI.ui_scale])

# ============================================================
# UI SCALING
# ============================================================
func _scale_ui():
	"""Scale all UI elements for mobile"""
	# Scale main margin container
	if margin_container:
		MobileUI.scale_container_margins(margin_container, 16)
	
	# Title label (if exists)
	if title_label:
		MobileUI.scale_label(title_label, 28)
		title_label.add_theme_color_override("font_outline_color", Color.BLACK)
		title_label.add_theme_constant_override("outline_size", int(MobileUI.get_size(2)))
	
	# Progress label
	MobileUI.scale_label(progress_label, 20)
	progress_label.add_theme_color_override("font_outline_color", Color.BLACK)
	progress_label.add_theme_constant_override("outline_size", int(MobileUI.get_size(1)))
	
	# Back button
	MobileUI.scale_button(back_button, 18, 52)
	
	# Scale list spacing
	if achievements_list:
		achievements_list.add_theme_constant_override("separation", int(MobileUI.get_size(8)))

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
	panel.custom_minimum_size = Vector2(0, MobileUI.get_touch_size(90))
	
	# Style the panel
	var style = StyleBoxFlat.new()
	if achievement.unlocked:
		style.bg_color = Color(0.15, 0.2, 0.1, 0.8)  # Dark green tint
		style.border_color = Color(0.4, 0.6, 0.2, 0.8)
	else:
		style.bg_color = Color(0.12, 0.12, 0.12, 0.8)  # Dark gray
		style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	var corner = int(MobileUI.get_size(8))
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	style.border_width_bottom = int(MobileUI.get_size(2))
	panel.add_theme_stylebox_override("panel", style)
	
	# Margin container
	var margin = MarginContainer.new()
	var margin_size = int(MobileUI.get_size(12))
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_top", margin_size)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_bottom", margin_size)
	panel.add_child(margin)
	
	# Main horizontal layout
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(MobileUI.get_size(12)))
	margin.add_child(hbox)
	
	# Icon (if available) or status indicator
	var icon_container = _create_icon(achievement)
	hbox.add_child(icon_container)
	
	# Content (name, description, progress)
	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", int(MobileUI.get_size(4)))
	hbox.add_child(content_vbox)
	
	# Achievement name
	var name_label = Label.new()
	name_label.text = achievement.name
	name_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(20))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", int(MobileUI.get_size(1)))
	if achievement.unlocked:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Gold
	else:
		name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	content_vbox.add_child(name_label)
	
	# Achievement description
	var desc_label = Label.new()
	desc_label.text = achievement.description
	desc_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(14))
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content_vbox.add_child(desc_label)
	
	# Progress bar (if has progress and not unlocked)
	if not achievement.unlocked and achievement.progress.current > 0:
		var progress_bar = _create_progress_bar(achievement.progress)
		content_vbox.add_child(progress_bar)
	
	# Status indicator on right
	var status_container = VBoxContainer.new()
	status_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(status_container)
	
	var status_label = Label.new()
	if achievement.unlocked:
		status_label.text = "o"
		status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Bright green
	else:
		status_label.text = "x"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(28))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_container.add_child(status_label)
	
	return panel

func _create_icon(achievement: Dictionary) -> Control:
	"""Create icon or placeholder for achievement"""
	var icon_size = MobileUI.get_size(48)
	
	# Try to load icon
	var icon_path = achievement.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = load(icon_path)
		return icon_rect
	
	# Placeholder: colored square based on unlock status
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	if achievement.unlocked:
		color_rect.color = Color(1.0, 0.84, 0.0, 0.4)  # Gold tint
	else:
		color_rect.color = Color(0.3, 0.3, 0.3, 0.5)  # Gray
	return color_rect

func _create_progress_bar(progress: Dictionary) -> HBoxContainer:
	"""Create progress bar UI"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(MobileUI.get_size(8)))
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(MobileUI.get_size(120), MobileUI.get_size(16))
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.max_value = progress.total
	progress_bar.value = progress.current
	progress_bar.show_percentage = false
	
	# Style the progress bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = int(MobileUI.get_size(4))
	bg_style.corner_radius_top_right = int(MobileUI.get_size(4))
	bg_style.corner_radius_bottom_left = int(MobileUI.get_size(4))
	bg_style.corner_radius_bottom_right = int(MobileUI.get_size(4))
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.6, 0.2, 0.9)  # Green
	fill_style.corner_radius_top_left = int(MobileUI.get_size(4))
	fill_style.corner_radius_top_right = int(MobileUI.get_size(4))
	fill_style.corner_radius_bottom_left = int(MobileUI.get_size(4))
	fill_style.corner_radius_bottom_right = int(MobileUI.get_size(4))
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	hbox.add_child(progress_bar)
	
	# Progress label
	var label = Label.new()
	label.text = "%d/%d" % [progress.current, progress.total]
	label.add_theme_font_size_override("font_size", MobileUI.get_font_size(12))
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	label.custom_minimum_size.x = MobileUI.get_size(50)
	hbox.add_child(label)
	
	return hbox

# ============================================================
# BUTTON HANDLERS
# ============================================================
func _on_back_pressed():
	"""Return to main menu"""
	print("[AchievementsView] Back to menu")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# ============================================================
# REFRESH
# ============================================================
func refresh():
	"""Refresh the achievements list"""
	_load_achievements()
