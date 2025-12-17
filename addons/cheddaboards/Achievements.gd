# Achievements.gd v1.3.0 - CheddaClick Edition
# Backend-first achievement system with local caching
# https://github.com/cheddatech/CheddaBoards-SDK
# https://cheddaboards.com
#
# Add to Project Settings > Autoload as "Achievements"
#
# ============================================================
# USAGE
# ============================================================
# 1. Define your achievements in the ACHIEVEMENTS constant below
# 2. Call check methods during gameplay:
#
#    # During game
#    Achievements.check_score(current_score)
#    Achievements.check_clicks(total_clicks)
#    Achievements.check_combo(current_combo)
#
#    # At game over
#    Achievements.check_game_over(score, clicks, max_combo)
#    Achievements.increment_games_played()
#    Achievements.submit_with_score(score, streak)
#
# 3. Connect to signals for UI notifications:
#
#    Achievements.achievement_unlocked.connect(_show_notification)
#
# ============================================================

extends Node

# ============================================================
# SIGNALS
# ============================================================

## Emitted when an achievement is unlocked
signal achievement_unlocked(achievement_id: String, achievement_name: String)

## Emitted when progress towards an achievement is updated
signal progress_updated(achievement_id: String, current: int, total: int)

## Emitted when achievements are synced from backend
signal achievements_synced()

## Emitted when achievements are ready to display (after initial load)
signal achievements_ready()

# ============================================================
# ACHIEVEMENT DEFINITIONS
# ============================================================
# Define your game's achievements here.
# Backend stores unlock status, these are just display definitions.
#
# Format:
#   "achievement_id": {
#       "name": "Display Name",
#       "description": "How to unlock this achievement"
#   }
# ============================================================

const ACHIEVEMENTS = {
	# ========================================
	# GAMES PLAYED (6)
	# ========================================
	"games_1": {
		"name": "First Click",
		"description": "Complete your very first clicking session."
	},
	"games_5": {
		"name": "Getting Clicky",
		"description": "Play 5 games — the clicking addiction begins."
	},
	"games_10": {
		"name": "Click Curious",
		"description": "Play 10 games — developing a taste for chedda."
	},
	"games_20": {
		"name": "Click Devotee",
		"description": "Play 20 games — officially hooked on cheese."
	},
	"games_30": {
		"name": "Click Fanatic",
		"description": "Play 30 games — cheese runs through your veins."
	},
	"games_50": {
		"name": "Click Legend",
		"description": "Play 50 games — a true master of the wheel."
	},
	
	# ========================================
	# SCORE MILESTONES (6)
	# ========================================
	"score_1000": {
		"name": "Cheese Nibbler",
		"description": "Score 1,000 points in a single game."
	},
	"score_2500": {
		"name": "Chedda Chaser",
		"description": "Score 2,500 points — warming up nicely."
	},
	"score_5000": {
		"name": "Gouda Grabber",
		"description": "Score 5,000 points — now we're cooking."
	},
	"score_10000": {
		"name": "Brie Boss",
		"description": "Score 10,000 points — serious cheese skills."
	},
	"score_25000": {
		"name": "Parmesan Pro",
		"description": "Score 25,000 points — elite tier unlocked."
	},
	"score_50000": {
		"name": "The Big Cheese",
		"description": "Score 50,000 points — absolute dairy dominance."
	},
	
	# ========================================
	# CLICK COUNT ACHIEVEMENTS (5)
	# Total clicks in a single game
	# ========================================
	"clicks_100": {
		"name": "Finger Warmer",
		"description": "Click 100 times in a single game."
	},
	"clicks_250": {
		"name": "Button Masher",
		"description": "Click 250 times in a single game."
	},
	"clicks_500": {
		"name": "Click Machine",
		"description": "Click 500 times in a single game."
	},
	"clicks_1000": {
		"name": "Carpal Tunnel",
		"description": "Click 1,000 times in a single game. RIP your mouse."
	},
	"clicks_2000": {
		"name": "Inhuman Clicker",
		"description": "Click 2,000 times in a single game. Are you okay?"
	},
	
	# ========================================
	# COMBO ACHIEVEMENTS (5)
	# Max combo reached in a single game
	# ========================================
	"combo_10": {
		"name": "Combo Starter",
		"description": "Reach a 10x combo."
	},
	"combo_25": {
		"name": "Combo Builder",
		"description": "Reach a 25x combo."
	},
	"combo_50": {
		"name": "Combo Master",
		"description": "Reach a 50x combo."
	},
	"combo_100": {
		"name": "Combo King",
		"description": "Reach a 100x combo. Unstoppable!"
	},
	"combo_200": {
		"name": "Combo God",
		"description": "Reach a 200x combo. Legendary clicking."
	},
}

# ============================================================
# STATE
# ============================================================

## Currently unlocked achievements (synced from backend)
var unlocked_achievements: Array = []

## Local progress tracking (not synced to backend)
var progress_tracking: Dictionary = {}

## Achievements waiting to be synced to backend
var pending_achievements: Array = []

## Notification queue for UI (display one at a time)
var notification_queue: Array = []

## Whether we've synced with backend at least once
var backend_synced: bool = false

## Whether achievements are ready to use
var is_ready: bool = false

## Games played counter (persisted locally, synced via profile)
var games_played: int = 0

const SAVE_PATH = "user://achievements_cache.save"
const CACHE_VERSION = 4  # Bumped for CheddaClick

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# Load local cache first (for offline support)
	_load_local_cache()
	
	# Connect to CheddaBoards signals
	CheddaBoards.profile_loaded.connect(_on_profile_loaded)
	CheddaBoards.logout_success.connect(_on_logout)
	CheddaBoards.sdk_ready.connect(_on_sdk_ready)
	
	_log("Initialized - %d cached achievements, %d games played" % [unlocked_achievements.size(), games_played])
	
	# If SDK already ready, check auth status
	if CheddaBoards.is_ready():
		_on_sdk_ready()

func _on_sdk_ready():
	"""Called when CheddaBoards SDK is ready"""
	is_ready = true
	
	if CheddaBoards.is_authenticated():
		_log("SDK ready, user authenticated - syncing...")
		sync_from_backend()
	else:
		_log("SDK ready, not authenticated - using local cache")
		achievements_ready.emit()

func _on_logout():
	"""Called when user logs out - clear achievements"""
	_log("User logged out - clearing achievements")
	clear_local_cache()

# ============================================================
# BACKEND SYNC
# ============================================================

func sync_from_backend():
	"""Download achievements from backend (source of truth)"""
	if not CheddaBoards.is_authenticated():
		_log("Not authenticated - using local cache only")
		achievements_ready.emit()
		return
	
	_log("🔄 Syncing from backend...")
	
	var profile = CheddaBoards.get_cached_profile()
	
	if profile.is_empty():
		_log("Profile empty, requesting refresh...")
		CheddaBoards.refresh_profile()
		return
	
	# Sync games_played from backend
	var backend_play_count = profile.get("playCount", 0)
	if backend_play_count != games_played:
		_log("🔄 Syncing games_played: local=%d → backend=%d" % [games_played, backend_play_count])
		games_played = backend_play_count
	
	var backend_achievements = profile.get("achievements", [])
	_process_backend_achievements(backend_achievements)

func _on_profile_loaded(_nickname: String, _score: int, _streak: int, achievements: Array):
	"""Called when CheddaBoards profile is loaded"""
	_log("📊 Profile loaded with %d achievements" % achievements.size())
	
	# Sync games_played from backend profile
	var profile = CheddaBoards.get_cached_profile()
	if not profile.is_empty():
		var backend_play_count = profile.get("playCount", 0)
		if backend_play_count != games_played:
			_log("🔄 Profile sync games_played: local=%d → backend=%d" % [games_played, backend_play_count])
			games_played = backend_play_count
	
	_process_backend_achievements(achievements)

func _process_backend_achievements(backend_achievements: Array):
	"""Process achievements from backend, merge with local"""
	_log("Processing %d backend achievements" % backend_achievements.size())
	
	# Backend is source of truth - start with backend list
	var merged = backend_achievements.duplicate()
	
	# Add any pending local achievements not yet on backend
	for local_id in pending_achievements:
		if not merged.has(local_id):
			merged.append(local_id)
			_log("➕ Adding pending local: %s" % local_id)
	
	unlocked_achievements = merged
	backend_synced = true
	_save_local_cache()
	
	_log("✅ Sync complete: %d total achievements" % unlocked_achievements.size())
	achievements_synced.emit()
	achievements_ready.emit()

# ============================================================
# CORE ACHIEVEMENT METHODS
# ============================================================

func unlock(achievement_id: String):
	"""Unlock an achievement (locally, synced on next score submit)"""
	if not ACHIEVEMENTS.has(achievement_id):
		_log("⚠️ Unknown achievement: %s" % achievement_id)
		return
	
	if is_unlocked(achievement_id):
		return  # Already unlocked
	
	_log("🏆 UNLOCKED: %s" % achievement_id)
	
	# Add to unlocked list
	unlocked_achievements.append(achievement_id)
	
	# Add to pending (to sync with backend on next submit)
	if not pending_achievements.has(achievement_id):
		pending_achievements.append(achievement_id)
	
	# Save locally
	_save_local_cache()
	
	# Get achievement name for signal
	var achievement_name = ACHIEVEMENTS[achievement_id].get("name", achievement_id)
	
	# Queue notification
	notification_queue.append({
		"id": achievement_id,
		"name": achievement_name
	})
	
	# Emit signal
	achievement_unlocked.emit(achievement_id, achievement_name)

func is_unlocked(achievement_id: String) -> bool:
	"""Check if an achievement is unlocked"""
	return unlocked_achievements.has(achievement_id)

func get_unlocked_count() -> int:
	"""Get number of unlocked achievements"""
	return unlocked_achievements.size()

func get_total_count() -> int:
	"""Get total number of achievements"""
	return ACHIEVEMENTS.size()

func get_unlocked_percentage() -> float:
	"""Get percentage of achievements unlocked"""
	if get_total_count() == 0:
		return 0.0
	return (float(get_unlocked_count()) / float(get_total_count())) * 100.0

# ============================================================
# PROGRESS TRACKING
# ============================================================

func set_progress(achievement_id: String, current: int, total: int):
	"""Set progress for a progressive achievement"""
	if is_unlocked(achievement_id):
		return  # Already unlocked
	
	progress_tracking[achievement_id] = {
		"current": current,
		"total": total
	}
	
	progress_updated.emit(achievement_id, current, total)
	
	# Auto-unlock if complete
	if current >= total:
		unlock(achievement_id)

func get_progress(achievement_id: String) -> Dictionary:
	"""Get progress for an achievement"""
	return progress_tracking.get(achievement_id, {"current": 0, "total": 0})

# ============================================================
# NOTIFICATION QUEUE
# ============================================================

func has_pending_notification() -> bool:
	"""Check if there are notifications to show"""
	return notification_queue.size() > 0

func get_next_notification() -> Dictionary:
	"""Get and remove next notification from queue"""
	if notification_queue.is_empty():
		return {}
	return notification_queue.pop_front()

func clear_notifications():
	"""Clear all pending notifications"""
	notification_queue.clear()

# ============================================================
# SCORE SUBMISSION WITH ACHIEVEMENTS
# ============================================================

func submit_with_score(score: int, streak: int = 0):
	"""Submit score along with any pending achievements"""
	if pending_achievements.is_empty():
		_log("📤 Submitting score (no pending achievements)")
		CheddaBoards.submit_score(score, streak)
	else:
		_log("📤 Submitting score with %d achievements: %s" % [
			pending_achievements.size(), 
			str(pending_achievements)
		])
		CheddaBoards.submit_score_with_achievements(score, streak, pending_achievements.duplicate())
		
		# Clear pending after submit
		pending_achievements.clear()
		_save_local_cache()

# ============================================================
# CHECK METHODS - Call these during gameplay
# ============================================================

func increment_games_played():
	"""Increment games played and check related achievements"""
	games_played += 1
	_log("🎮 Games played: %d" % games_played)
	_save_local_cache()
	check_games_played()

func check_games_played():
	"""Check and unlock games-played achievements"""
	# Update progress for games achievements
	set_progress("games_50", games_played, 50)
	set_progress("games_30", games_played, 30)
	set_progress("games_20", games_played, 20)
	set_progress("games_10", games_played, 10)
	set_progress("games_5", games_played, 5)
	
	# Unlock in reverse order (highest first)
	if games_played >= 50:
		unlock("games_50")
	if games_played >= 30:
		unlock("games_30")
	if games_played >= 20:
		unlock("games_20")
	if games_played >= 10:
		unlock("games_10")
	if games_played >= 5:
		unlock("games_5")
	if games_played >= 1:
		unlock("games_1")

func check_score(score: int):
	"""Check and unlock score-based achievements"""
	if score >= 50000:
		unlock("score_50000")
	if score >= 25000:
		unlock("score_25000")
	if score >= 10000:
		unlock("score_10000")
	if score >= 5000:
		unlock("score_5000")
	if score >= 2500:
		unlock("score_2500")
	if score >= 1000:
		unlock("score_1000")

func check_clicks(clicks: int):
	"""Check and unlock click-based achievements"""
	if clicks >= 2000:
		unlock("clicks_2000")
	if clicks >= 1000:
		unlock("clicks_1000")
	if clicks >= 500:
		unlock("clicks_500")
	if clicks >= 250:
		unlock("clicks_250")
	if clicks >= 100:
		unlock("clicks_100")

func check_combo(combo: int):
	"""Check and unlock combo-based achievements"""
	if combo >= 200:
		unlock("combo_200")
	if combo >= 100:
		unlock("combo_100")
	if combo >= 50:
		unlock("combo_50")
	if combo >= 25:
		unlock("combo_25")
	if combo >= 10:
		unlock("combo_10")

func check_game_over(score: int, clicks: int = 0, max_combo: int = 0):
	"""Check all end-of-game achievements at once"""
	check_score(score)
	
	if clicks > 0:
		check_clicks(clicks)
	
	if max_combo > 0:
		check_combo(max_combo)

# ============================================================
# GAMES PLAYED HELPERS
# ============================================================

func get_games_played() -> int:
	"""Get total games played"""
	return games_played

func set_games_played(count: int):
	"""Set games played (use when syncing from backend profile)"""
	games_played = count
	_save_local_cache()

# ============================================================
# GETTING ACHIEVEMENT DATA
# ============================================================

func get_achievement(achievement_id: String) -> Dictionary:
	"""Get data for a specific achievement"""
	if not ACHIEVEMENTS.has(achievement_id):
		return {}
	
	var data = ACHIEVEMENTS[achievement_id].duplicate()
	data["id"] = achievement_id
	data["unlocked"] = is_unlocked(achievement_id)
	data["progress"] = get_progress(achievement_id)
	return data

func get_all_achievements() -> Array:
	"""Get data for all achievements"""
	var all_achievements = []
	for achievement_id in ACHIEVEMENTS.keys():
		all_achievements.append(get_achievement(achievement_id))
	return all_achievements

func get_locked_achievements() -> Array:
	"""Get data for achievements that are still locked"""
	var locked = []
	for achievement_id in ACHIEVEMENTS.keys():
		if not is_unlocked(achievement_id):
			locked.append(get_achievement(achievement_id))
	return locked

func get_unlocked_achievements() -> Array:
	"""Get data for unlocked achievements"""
	var unlocked = []
	for achievement_id in unlocked_achievements:
		unlocked.append(get_achievement(achievement_id))
	return unlocked

func get_achievements_by_category(prefix: String) -> Array:
	"""Get achievements by category prefix (e.g., 'games_', 'score_', 'clicks_', 'combo_')"""
	var filtered = []
	for achievement_id in ACHIEVEMENTS.keys():
		if achievement_id.begins_with(prefix):
			filtered.append(get_achievement(achievement_id))
	return filtered

## Alias for get_achievement
func get_achievement_data(achievement_id: String) -> Dictionary:
	return get_achievement(achievement_id)

# ============================================================
# LOCAL CACHE (Offline Support)
# ============================================================

func _save_local_cache():
	"""Save local cache for offline play"""
	var cache_data: Dictionary = {
		"unlocked": unlocked_achievements,
		"progress": progress_tracking,
		"pending": pending_achievements,
		"synced": backend_synced,
		"games_played": games_played,
		"version": CACHE_VERSION
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(cache_data)
		file.close()

func _load_local_cache():
	"""Load local cache"""
	if not FileAccess.file_exists(SAVE_PATH):
		_log("No cache found - starting fresh")
		_reset_state()
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_reset_state()
		return
	
	var cache_data = file.get_var()
	file.close()
	
	if typeof(cache_data) != TYPE_DICTIONARY:
		_reset_state()
		return
	
	# Check cache version
	var version = cache_data.get("version", 1)
	if version < CACHE_VERSION:
		_log("Cache version outdated - resetting")
		_reset_state()
		return
	
	unlocked_achievements = cache_data.get("unlocked", [])
	progress_tracking = cache_data.get("progress", {})
	pending_achievements = cache_data.get("pending", [])
	backend_synced = cache_data.get("synced", false)
	games_played = cache_data.get("games_played", 0)
	
	_log("📂 Loaded cache: %d unlocked, %d pending, %d games" % [
		unlocked_achievements.size(), 
		pending_achievements.size(),
		games_played
	])

func _reset_state():
	"""Reset all state to defaults"""
	unlocked_achievements = []
	progress_tracking = {}
	pending_achievements = []
	notification_queue = []
	backend_synced = false
	games_played = 0

func clear_local_cache():
	"""Clear local cache (for logout or testing)"""
	_reset_state()
	_save_local_cache()
	_log("🗑️ Local cache cleared")

# ============================================================
# LOGGING
# ============================================================

## Set to true to enable verbose logging
var debug_logging: bool = true

func _log(message: String):
	"""Print log message if debug logging enabled"""
	if debug_logging:
		print("[Achievements] %s" % message)

# ============================================================
# DEBUG
# ============================================================

func debug_status():
	"""Print debug info to console"""
	var profile = CheddaBoards.get_cached_profile()
	var backend_play_count = profile.get("playCount", 0) if not profile.is_empty() else 0
	
	print("")
	print("╔══════════════════════════════════════════════╗")
	print("║      Achievements Debug v1.3.0 (Click)       ║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Status                                       ║")
	print("║  - Ready:            %s" % str(is_ready).rpad(24) + "║")
	print("║  - Backend Synced:   %s" % str(backend_synced).rpad(24) + "║")
	print("║  - Authenticated:    %s" % str(CheddaBoards.is_authenticated()).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Stats                                        ║")
	print("║  - Games (Local):    %s" % str(games_played).rpad(24) + "║")
	print("║  - Games (Backend):  %s" % str(backend_play_count).rpad(24) + "║")
	print("║  - Total Achievs:    %s" % str(get_total_count()).rpad(24) + "║")
	print("║  - Unlocked:         %s" % str(get_unlocked_count()).rpad(24) + "║")
	print("║  - Pending Sync:     %s" % str(pending_achievements.size()).rpad(24) + "║")
	print("║  - Notifications:    %s" % str(notification_queue.size()).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Unlocked IDs                                 ║")
	for ach_id in unlocked_achievements:
		print("║  - %s" % ach_id.rpad(40) + "║")
	if unlocked_achievements.is_empty():
		print("║  (none)                                      ║")
	print("╚══════════════════════════════════════════════╝")
	print("")

func debug_unlock_all():
	"""Debug: Unlock all achievements (for testing)"""
	for achievement_id in ACHIEVEMENTS.keys():
		unlock(achievement_id)
	_log("🔓 DEBUG: All achievements unlocked")

func debug_reset():
	"""Debug: Reset all achievements (for testing)"""
	clear_local_cache()
	_log("🔄 DEBUG: All achievements reset")

func debug_add_games(count: int = 10):
	"""Debug: Add games to counter (for testing)"""
	games_played += count
	_save_local_cache()
	check_games_played()
	_log("🎮 DEBUG: Added %d games, total: %d" % [count, games_played])
