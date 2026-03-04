# Leaderboard.gd v2.0.0
# Redesigned leaderboard showcasing CheddaBoards features
# Tabs: All Time | Weekly | Daily with archive dropdown for timed scoreboards
# https://github.com/cheddatech/CheddaBoards-Godot
#
# ============================================================
# SETUP
# ============================================================
# Required Autoloads:
#   - CheddaBoards
#   - MobileUI
#
# ============================================================

extends Control

# ============================================================
# CONFIGURATION
# ============================================================

## How many entries to load per page
const LEADERBOARD_LIMIT: int = 1000

## How long to wait before timing out
const LOAD_TIMEOUT_SECONDS: float = 15.0

## Scene paths (adjust to match your project structure)
const SCENE_MAIN_MENU: String = "res://scenes/MainMenu.tscn"
const SCENE_GAME: String = "res://scenes/Game.tscn"

## Scoreboard IDs — update these to match your canister config
const SCOREBOARD_ALL_TIME: String = "all-time"
const SCOREBOARD_WEEKLY: String = "weekly"
const SCOREBOARD_DAILY: String = "daily"

## Tab index constants
const TAB_ALL_TIME: int = 0
const TAB_WEEKLY: int = 1
const TAB_DAILY: int = 2

## Which tab to show by default
@export var default_tab: int = TAB_WEEKLY

# ============================================================
# COLORS — CheddaBoards brand palette
# ============================================================

const COLOR_BG: Color = Color("0f0f0f")
const COLOR_PANEL: Color = Color("1a1a2e")
const COLOR_ACCENT: Color = Color("f5a623")         # CheddaBoards gold/cheese
const COLOR_ACCENT_DIM: Color = Color("c4841d")
const COLOR_TAB_ACTIVE: Color = Color("f5a623")
const COLOR_TAB_INACTIVE: Color = Color("555555")
const COLOR_TAB_HOVER: Color = Color("888888")
const COLOR_TEXT: Color = Color("e0e0e0")
const COLOR_TEXT_DIM: Color = Color("888888")
const COLOR_HIGHLIGHT_PLAYER: Color = Color(0.2, 0.5, 0.2, 0.4)
const COLOR_HIGHLIGHT_GOLD: Color = Color(0.5, 0.4, 0.1, 0.5)
const COLOR_HIGHLIGHT_SILVER: Color = Color(0.4, 0.4, 0.45, 0.3)
const COLOR_HIGHLIGHT_BRONZE: Color = Color(0.4, 0.25, 0.1, 0.3)
const COLOR_SEPARATOR: Color = Color("333333")
const COLOR_DROPDOWN_BG: Color = Color("222240")

# ============================================================
# NODE REFERENCES
# ============================================================

@onready var margin_container: MarginContainer = $MarginContainer
@onready var title_label: Label = $MarginContainer/VBox/HeaderContainer/TitleRow/TitleLabel
@onready var refresh_button: Button = $MarginContainer/VBox/HeaderContainer/TitleRow/RefreshButton

# Tabs
@onready var tab_bar: HBoxContainer = $MarginContainer/VBox/HeaderContainer/TabBar
@onready var tab_all_time: Button = $MarginContainer/VBox/HeaderContainer/TabBar/AllTimeTab
@onready var tab_weekly: Button = $MarginContainer/VBox/HeaderContainer/TabBar/WeeklyTab
@onready var tab_daily: Button = $MarginContainer/VBox/HeaderContainer/TabBar/DailyTab

# Archive dropdown row
@onready var archive_row: HBoxContainer = $MarginContainer/VBox/HeaderContainer/ArchiveRow
@onready var archive_label: Label = $MarginContainer/VBox/HeaderContainer/ArchiveRow/ArchiveLabel
@onready var archive_dropdown: OptionButton = $MarginContainer/VBox/HeaderContainer/ArchiveRow/ArchiveDropdown

# Sort row
@onready var sort_row: HBoxContainer = $MarginContainer/VBox/HeaderContainer/SortRow
@onready var sort_score_btn: Button = $MarginContainer/VBox/HeaderContainer/SortRow/SortByScoreButton
@onready var sort_streak_btn: Button = $MarginContainer/VBox/HeaderContainer/SortRow/SortByStreakButton

# Leaderboard display
@onready var column_header: HBoxContainer = $MarginContainer/VBox/ColumnHeader
@onready var leaderboard_scroll: ScrollContainer = $MarginContainer/VBox/LeaderboardScroll
@onready var leaderboard_list: VBoxContainer = $MarginContainer/VBox/LeaderboardScroll/LeaderboardList

# Footer
@onready var your_rank_label: Label = $MarginContainer/VBox/FooterContainer/YourRankPanel/YourRankMargin/YourRankLabel
@onready var your_rank_panel: PanelContainer = $MarginContainer/VBox/FooterContainer/YourRankPanel
@onready var status_label: Label = $MarginContainer/VBox/FooterContainer/StatusLabel
@onready var back_button: Button = $MarginContainer/VBox/FooterContainer/ButtonsContainer/BackButton
@onready var play_again_button: Button = $MarginContainer/VBox/FooterContainer/ButtonsContainer/PlayAgainButton
@onready var powered_label: Label = $MarginContainer/VBox/FooterContainer/PoweredByLabel

# ============================================================
# STATE
# ============================================================

## Currently active tab index
var active_tab: int = TAB_WEEKLY

## Scoreboard ID for each tab
var tab_scoreboard_ids: Array[String] = [SCOREBOARD_ALL_TIME, SCOREBOARD_WEEKLY, SCOREBOARD_DAILY]

## Current scoreboard ID being viewed
var scoreboard_id: String = SCOREBOARD_WEEKLY

## "score" or "streak"
var current_sort_by: String = "score"

## Whether we're loading
var is_loading: bool = false

## Load timeout timer
var load_timeout_timer: Timer = null

## Current player nickname for highlighting
var current_player_nickname: String = ""

## Archive mode: false = current period, true = viewing an archive
var viewing_archive: bool = false

## Cached list of archive metadata for the dropdown
## Each entry: { "id": String, "label": String, "periodStart": int, "periodEnd": int }
var archive_list: Array = []

## Currently selected archive index in dropdown (-1 = "Current")
var selected_archive_index: int = -1

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	_scale_ui()
	
	# Wait for CheddaBoards
	if not CheddaBoards.is_ready():
		status_label.text = "Connecting to CheddaBoards..."
		await CheddaBoards.wait_until_ready()
	
	current_player_nickname = _get_player_nickname()
	
	# Connect tab buttons
	tab_all_time.pressed.connect(_on_tab_pressed.bind(TAB_ALL_TIME))
	tab_weekly.pressed.connect(_on_tab_pressed.bind(TAB_WEEKLY))
	tab_daily.pressed.connect(_on_tab_pressed.bind(TAB_DAILY))
	
	# Connect archive dropdown
	archive_dropdown.item_selected.connect(_on_archive_selected)
	
	# Connect sort buttons
	sort_score_btn.pressed.connect(_on_sort_pressed.bind("score"))
	sort_streak_btn.pressed.connect(_on_sort_pressed.bind("streak"))
	
	# Connect other buttons
	refresh_button.pressed.connect(_on_refresh_pressed)
	back_button.pressed.connect(_on_back_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)
	
	# Connect CheddaBoards signals
	CheddaBoards.scoreboard_loaded.connect(_on_scoreboard_loaded)
	CheddaBoards.scoreboard_rank_loaded.connect(_on_scoreboard_rank_loaded)
	CheddaBoards.scoreboard_error.connect(_on_scoreboard_error)
	CheddaBoards.archived_scoreboard_loaded.connect(_on_archived_scoreboard_loaded)
	CheddaBoards.archive_error.connect(_on_archive_error)
	
	# Set default tab
	active_tab = default_tab
	scoreboard_id = tab_scoreboard_ids[active_tab]
	
	_update_ui()
	_load_leaderboard()
	_load_archive_list()
	
	print("[Leaderboard] v2.0.0 initialized (Mobile: %s, Scale: %.2f)" % [MobileUI.is_mobile, MobileUI.ui_scale])

# ============================================================
# UI SCALING
# ============================================================

func _scale_ui():
	if margin_container:
		MobileUI.scale_container_margins(margin_container, 16)
	
	MobileUI.scale_label(title_label, 32)
	MobileUI.scale_button(refresh_button, 14, 36)
	
	# Tabs
	for tab_btn in [tab_all_time, tab_weekly, tab_daily]:
		MobileUI.scale_button(tab_btn, 16, 44)
	
	# Archive row
	MobileUI.scale_label(archive_label, 14)
	# OptionButton doesn't have a direct MobileUI helper — scale font manually
	archive_dropdown.add_theme_font_size_override("font_size", MobileUI.get_font_size(14))
	archive_dropdown.custom_minimum_size = Vector2(MobileUI.get_size(200), MobileUI.get_touch_size(40))
	
	# Sort
	MobileUI.scale_button(sort_score_btn, 13, 36)
	MobileUI.scale_button(sort_streak_btn, 13, 36)
	
	# Rank + status
	MobileUI.scale_label(your_rank_label, 18)
	MobileUI.scale_label(status_label, 14)
	if your_rank_panel:
		your_rank_panel.custom_minimum_size.y = MobileUI.get_touch_size(48)
	
	# Nav buttons
	MobileUI.scale_button(back_button, 16, 44)
	MobileUI.scale_button(play_again_button, 18, 48)
	
	# Powered by
	MobileUI.scale_label(powered_label, 11)

# ============================================================
# TAB MANAGEMENT
# ============================================================

func _on_tab_pressed(tab_index: int):
	if tab_index == active_tab and not viewing_archive:
		return
	
	active_tab = tab_index
	scoreboard_id = tab_scoreboard_ids[active_tab]
	viewing_archive = false
	selected_archive_index = -1
	
	_update_ui()
	_load_leaderboard()
	_load_archive_list()

func _update_tab_styles():
	"""Style tabs — active tab gets accent color, others are dimmed"""
	var tabs = [tab_all_time, tab_weekly, tab_daily]
	
	for i in range(tabs.size()):
		var tab: Button = tabs[i]
		if i == active_tab:
			# Active tab styling
			var active_style = StyleBoxFlat.new()
			active_style.bg_color = COLOR_TAB_ACTIVE
			active_style.set_corner_radius_all(int(MobileUI.get_size(6)))
			tab.add_theme_stylebox_override("normal", active_style)
			tab.add_theme_stylebox_override("hover", active_style)
			tab.add_theme_stylebox_override("pressed", active_style)
			tab.add_theme_color_override("font_color", Color("0f0f0f"))
			tab.add_theme_color_override("font_hover_color", Color("0f0f0f"))
			tab.add_theme_color_override("font_pressed_color", Color("0f0f0f"))
			tab.disabled = false  # Keep clickable for refresh behavior
		else:
			# Inactive tab styling
			var inactive_style = StyleBoxFlat.new()
			inactive_style.bg_color = Color("2a2a2a")
			inactive_style.set_corner_radius_all(int(MobileUI.get_size(6)))
			inactive_style.border_color = COLOR_TAB_INACTIVE
			inactive_style.set_border_width_all(1)
			tab.add_theme_stylebox_override("normal", inactive_style)
			
			var hover_style = StyleBoxFlat.new()
			hover_style.bg_color = Color("3a3a3a")
			hover_style.set_corner_radius_all(int(MobileUI.get_size(6)))
			tab.add_theme_stylebox_override("hover", hover_style)
			
			tab.add_theme_color_override("font_color", COLOR_TEXT_DIM)
			tab.add_theme_color_override("font_hover_color", COLOR_TEXT)
			tab.disabled = is_loading

# ============================================================
# ARCHIVE DROPDOWN
# ============================================================

func _load_archive_list():
	"""Set up archive dropdown for the current scoreboard.
	Currently only 'Current' and 'Previous Period' are available.
	When CheddaBoards adds archive listing, this will populate dynamically."""
	# All Time has no archives
	if active_tab == TAB_ALL_TIME:
		archive_row.visible = false
		return
	
	archive_row.visible = true
	_populate_archive_dropdown_fallback()

func _on_archive_list_loaded(sb_id: String, archives: Array):
	"""Called when the archive list comes back from CheddaBoards"""
	if sb_id != scoreboard_id:
		return
	
	archive_list = archives
	_populate_archive_dropdown(archives)

func _populate_archive_dropdown(archives: Array):
	"""Fill the dropdown with archive periods"""
	archive_dropdown.clear()
	
	# First item is always "Current"
	archive_dropdown.add_item("Current", 0)
	
	# Add each archive period
	for i in range(archives.size()):
		var archive = archives[i]
		var label = _format_archive_label(archive)
		archive_dropdown.add_item(label, i + 1)
	
	# If no archives exist yet, add a disabled hint
	if archives.is_empty():
		archive_dropdown.add_item("No archives yet", 1)
		archive_dropdown.set_item_disabled(1, true)
	
	# Reset selection to current
	archive_dropdown.selected = 0

func _populate_archive_dropdown_fallback():
	"""Fallback dropdown when archive listing isn't available"""
	archive_dropdown.clear()
	archive_dropdown.add_item("Current", 0)
	archive_dropdown.add_item("Previous Period", 1)
	archive_dropdown.selected = 0 if not viewing_archive else 1

func _format_archive_label(archive: Dictionary) -> String:
	"""Format an archive entry for the dropdown label"""
	var period_start = archive.get("periodStart", 0)
	var period_end = archive.get("periodEnd", 0)
	var start_str = _format_timestamp(period_start)
	var end_str = _format_timestamp(period_end)
	
	if start_str != "" and end_str != "":
		return "%s — %s" % [start_str, end_str]
	
	# Fallback to archive ID
	return archive.get("id", "Archive")

func _on_archive_selected(index: int):
	"""Handle archive dropdown selection"""
	if index == 0:
		# "Current" selected
		if not viewing_archive:
			return  # Already on current
		viewing_archive = false
		selected_archive_index = -1
		_update_ui()
		_load_leaderboard()
	else:
		# An archive period selected
		viewing_archive = true
		selected_archive_index = index - 1  # Offset by 1 because index 0 = "Current"
		_update_ui()
		_load_archive_by_index(selected_archive_index)

func _load_archive_by_index(idx: int):
	"""Load an archived period for the current scoreboard"""
	# Currently the SDK only supports fetching the last archived period.
	# When archive listing is added to CheddaBoards, this can be expanded
	# to fetch specific archives by ID.
	_set_loading(true)
	status_label.text = "Loading previous period..."
	print("[Leaderboard] Loading last archive for '%s'" % scoreboard_id)
	CheddaBoards.get_last_archived_scoreboard(scoreboard_id, LEADERBOARD_LIMIT)

# ============================================================
# LOADING
# ============================================================

func _load_leaderboard():
	if is_loading:
		return
	
	_set_loading(true)
	_clear_leaderboard()
	status_label.text = "Loading..."
	status_label.add_theme_color_override("font_color", COLOR_TEXT)
	
	_start_load_timeout()
	
	if viewing_archive:
		_load_archive_by_index(selected_archive_index)
	else:
		print("[Leaderboard] Requesting scoreboard '%s'" % scoreboard_id)
		CheddaBoards.get_scoreboard(scoreboard_id, LEADERBOARD_LIMIT)
		
		if CheddaBoards.has_account():
			your_rank_label.text = "Loading your rank..."
			CheddaBoards.get_scoreboard_rank(scoreboard_id)
		else:
			your_rank_label.text = "Sign in to see your rank"
			your_rank_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)

func _set_loading(loading: bool):
	is_loading = loading
	refresh_button.disabled = loading
	archive_dropdown.disabled = loading
	_update_tab_styles()
	_update_sort_buttons()

func _clear_leaderboard():
	for child in leaderboard_list.get_children():
		child.queue_free()

# ============================================================
# SIGNAL HANDLERS — SCOREBOARDS
# ============================================================

func _on_scoreboard_loaded(sb_id: String, config: Dictionary, entries: Array):
	if sb_id != scoreboard_id or viewing_archive:
		return
	_update_title_from_config(config)
	_display_entries(entries)

func _on_scoreboard_rank_loaded(sb_id: String, rank: int, score: int, streak: int, total: int):
	if sb_id != scoreboard_id:
		return
	_display_player_rank(rank, score, streak, total)

func _on_scoreboard_error(reason: String):
	print("[Leaderboard] Error: %s" % reason)
	_clear_load_timeout()
	_set_loading(false)
	status_label.text = "Error loading leaderboard"
	status_label.add_theme_color_override("font_color", Color.RED)

# ============================================================
# SIGNAL HANDLERS — ARCHIVES
# ============================================================

func _on_archived_scoreboard_loaded(archive_id: String, config: Dictionary, entries: Array):
	print("[Leaderboard] Archive loaded: %s (%d entries)" % [archive_id, entries.size()])
	_update_title_for_archive(config)
	_display_entries(entries)

func _on_archive_error(reason: String):
	print("[Leaderboard] Archive error: %s" % reason)
	_clear_load_timeout()
	_set_loading(false)
	status_label.text = "No archived data available yet"
	status_label.add_theme_color_override("font_color", Color.YELLOW)

# ============================================================
# TITLE UPDATES
# ============================================================

func _update_title_from_config(config: Dictionary):
	var name = config.get("name", _get_tab_display_name())
	var sort_suffix = " — By Streak" if current_sort_by == "streak" else ""
	title_label.text = "%s%s" % [name, sort_suffix]

func _get_tab_display_name() -> String:
	match active_tab:
		TAB_ALL_TIME: return "All Time"
		TAB_WEEKLY: return "Weekly"
		TAB_DAILY: return "Daily"
		_: return "Leaderboard"

func _update_title_for_archive(config: Dictionary):
	var name = config.get("name", _get_tab_display_name())
	var period_start = config.get("periodStart", 0)
	var period_end = config.get("periodEnd", 0)
	var start_str = _format_timestamp(period_start)
	var end_str = _format_timestamp(period_end)
	
	if start_str != "" and end_str != "":
		title_label.text = "%s: %s — %s" % [name, start_str, end_str]
	else:
		title_label.text = "%s (Archived)" % name

func _format_timestamp(timestamp_ns: int) -> String:
	if timestamp_ns == 0:
		return ""
	var timestamp_s = timestamp_ns / 1_000_000_000
	var dt = Time.get_datetime_dict_from_unix_time(timestamp_s)
	return "%02d/%02d/%d" % [dt.day, dt.month, dt.year]

# ============================================================
# DISPLAY ENTRIES
# ============================================================

func _display_entries(entries: Array):
	_clear_load_timeout()
	_set_loading(false)
	
	if entries.is_empty():
		status_label.text = "No scores yet — be the first!" if not viewing_archive else "No archived data for this period"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
		return
	
	status_label.text = "%d players" % entries.size()
	status_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	
	_clear_leaderboard()
	
	var sorted_entries = _sort_entries(entries)
	
	for i in range(sorted_entries.size()):
		_add_leaderboard_entry(i + 1, sorted_entries[i])

func _sort_entries(entries: Array) -> Array:
	var sorted = entries.duplicate()
	sorted.sort_custom(func(a, b):
		return _get_sort_value(a) > _get_sort_value(b)
	)
	return sorted

func _get_sort_value(entry) -> int:
	if typeof(entry) == TYPE_ARRAY:
		if current_sort_by == "streak":
			return entry[2] if entry.size() > 2 else 0
		return entry[1] if entry.size() > 1 else 0
	elif typeof(entry) == TYPE_DICTIONARY:
		if current_sort_by == "streak":
			return entry.get("streak", entry.get("bestStreak", 0))
		return entry.get("score", entry.get("highScore", 0))
	return 0

func _add_leaderboard_entry(rank: int, entry) -> void:
	# Parse entry data
	var nickname: String
	var score: int
	var streak: int
	
	if typeof(entry) == TYPE_ARRAY:
		nickname = str(entry[0]) if entry.size() > 0 else "Unknown"
		score = entry[1] if entry.size() > 1 else 0
		streak = entry[2] if entry.size() > 2 else 0
	elif typeof(entry) == TYPE_DICTIONARY:
		nickname = str(entry.get("nickname", entry.get("username", "Unknown")))
		score = entry.get("score", entry.get("highScore", 0))
		streak = entry.get("streak", entry.get("bestStreak", 0))
	else:
		return
	
	var is_current_player = (nickname == current_player_nickname) and current_player_nickname != "" and not viewing_archive
	
	# Entry container
	var entry_container = PanelContainer.new()
	entry_container.custom_minimum_size = Vector2(0, MobileUI.get_touch_size(44))
	
	# Row styling
	var stylebox = StyleBoxFlat.new()
	stylebox.set_corner_radius_all(int(MobileUI.get_size(4)))
	
	if is_current_player:
		stylebox.bg_color = COLOR_HIGHLIGHT_PLAYER
	elif rank == 1:
		stylebox.bg_color = COLOR_HIGHLIGHT_GOLD
	elif rank == 2:
		stylebox.bg_color = COLOR_HIGHLIGHT_SILVER
	elif rank == 3:
		stylebox.bg_color = COLOR_HIGHLIGHT_BRONZE
	else:
		# Alternating row colors for readability
		stylebox.bg_color = Color("1a1a2e") if rank % 2 == 1 else Color("16162a")
	
	entry_container.add_theme_stylebox_override("panel", stylebox)
	
	# Margin
	var margin = MarginContainer.new()
	var h_margin = int(MobileUI.get_size(12))
	var v_margin = int(MobileUI.get_size(4))
	margin.add_theme_constant_override("margin_left", h_margin)
	margin.add_theme_constant_override("margin_right", h_margin)
	margin.add_theme_constant_override("margin_top", v_margin)
	margin.add_theme_constant_override("margin_bottom", v_margin)
	entry_container.add_child(margin)
	
	# HBox
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(MobileUI.get_size(12)))
	margin.add_child(hbox)
	
	# Rank
	var rank_label = Label.new()
	rank_label.custom_minimum_size = Vector2(MobileUI.get_size(44), 0)
	rank_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(18))
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	match rank:
		1:
			rank_label.text = "#1"
			rank_label.add_theme_color_override("font_color", Color.GOLD)
		2:
			rank_label.text = "#2"
			rank_label.add_theme_color_override("font_color", Color.SILVER)
		3:
			rank_label.text = "#3"
			rank_label.add_theme_color_override("font_color", Color("#CD7F32"))
		_:
			rank_label.text = "#%d" % rank
			rank_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	
	hbox.add_child(rank_label)
	
	# Nickname
	var name_label = Label.new()
	name_label.text = nickname
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(18))
	name_label.add_theme_color_override("font_color", Color.WHITE if is_current_player else COLOR_TEXT)
	name_label.clip_text = true
	hbox.add_child(name_label)
	
	# Value
	var value_label = Label.new()
	if current_sort_by == "streak":
		value_label.text = "%d combo" % streak
	else:
		value_label.text = _format_score(score)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(MobileUI.get_size(90), 0)
	value_label.add_theme_font_size_override("font_size", MobileUI.get_font_size(18))
	value_label.add_theme_color_override("font_color", COLOR_ACCENT if rank <= 3 else COLOR_TEXT)
	hbox.add_child(value_label)
	
	leaderboard_list.add_child(entry_container)

func _format_score(value: int) -> String:
	"""Format score with commas for readability"""
	var s = str(value)
	if s.length() <= 3:
		return s
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

# ============================================================
# PLAYER RANK
# ============================================================

func _display_player_rank(rank: int, score: int, streak: int, total_players: int):
	if rank == 0:
		your_rank_label.text = "Not ranked yet — play to get on the board!"
		your_rank_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		return
	
	var text = "Your Rank: #%d of %d" % [rank, total_players]
	if current_sort_by == "score":
		text += "  •  %s pts" % _format_score(score)
	else:
		text += "  •  %d combo" % streak
	
	if rank == 1:
		text += "  👑"
	elif rank <= 3:
		text += "  🏆"
	elif rank <= 10:
		text += "  ⭐"
	
	your_rank_label.text = text
	your_rank_label.add_theme_color_override("font_color", Color.WHITE)

# ============================================================
# SORT
# ============================================================

func _on_sort_pressed(sort_by: String):
	if current_sort_by == sort_by:
		return
	current_sort_by = sort_by
	_update_ui()
	_load_leaderboard()

func _update_sort_buttons():
	sort_score_btn.disabled = is_loading or current_sort_by == "score"
	sort_streak_btn.disabled = is_loading or current_sort_by == "streak"
	
	# Style active sort button
	for btn in [sort_score_btn, sort_streak_btn]:
		var is_active = (btn == sort_score_btn and current_sort_by == "score") or \
						(btn == sort_streak_btn and current_sort_by == "streak")
		if is_active:
			btn.add_theme_color_override("font_color", COLOR_ACCENT)
		else:
			btn.add_theme_color_override("font_color", COLOR_TEXT_DIM)

# ============================================================
# UI UPDATE (called after any state change)
# ============================================================

func _update_ui():
	_update_tab_styles()
	_update_sort_buttons()
	
	# Archive row visibility — hidden for All Time
	archive_row.visible = (active_tab != TAB_ALL_TIME)
	
	# Update archive dropdown selection
	if not viewing_archive:
		archive_dropdown.selected = 0

# ============================================================
# BUTTON HANDLERS
# ============================================================

func _on_refresh_pressed():
	if viewing_archive:
		_load_archive_by_index(selected_archive_index)
	else:
		_load_leaderboard()

func _on_back_pressed():
	get_tree().change_scene_to_file(SCENE_MAIN_MENU)

func _on_play_again_pressed():
	get_tree().change_scene_to_file(SCENE_GAME)

# ============================================================
# PLAYER NICKNAME
# ============================================================

func _get_player_nickname() -> String:
	var nickname = CheddaBoards.get_nickname()
	if nickname == "Player" or nickname.is_empty():
		var save_path = "user://player_data.save"
		if FileAccess.file_exists(save_path):
			var file = FileAccess.open(save_path, FileAccess.READ)
			if file:
				var data = file.get_var()
				file.close()
				if data is Dictionary and data.has("nickname"):
					var saved = data.get("nickname", "")
					if not saved.is_empty():
						return saved
	return nickname

# ============================================================
# TIMEOUT
# ============================================================

func _start_load_timeout():
	_clear_load_timeout()
	load_timeout_timer = Timer.new()
	load_timeout_timer.wait_time = LOAD_TIMEOUT_SECONDS
	load_timeout_timer.one_shot = true
	load_timeout_timer.timeout.connect(_on_load_timeout)
	add_child(load_timeout_timer)
	load_timeout_timer.start()

func _clear_load_timeout():
	if load_timeout_timer:
		load_timeout_timer.stop()
		load_timeout_timer.queue_free()
		load_timeout_timer = null

func _on_load_timeout():
	if is_loading:
		_set_loading(false)
		status_label.text = "Timed out — tap Refresh to retry"
		status_label.add_theme_color_override("font_color", Color.RED)

# ============================================================
# PUBLIC API
# ============================================================

func set_scoreboard(new_id: String):
	scoreboard_id = new_id
	viewing_archive = false
	_update_ui()
	_load_leaderboard()

func show_current():
	viewing_archive = false
	_update_ui()
	_load_leaderboard()

# ============================================================
# CLEANUP
# ============================================================

func _exit_tree():
	_clear_load_timeout()
