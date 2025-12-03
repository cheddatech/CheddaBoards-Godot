# Achievements.gd v1.2.0
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
#    Achievements.check_clutch(current_score, time_remaining)
#
#    # At game over
#    Achievements.check_game_over(score, time_remaining)
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
		"name": "First Slice",
		"description": "Complete your very first cheese run."
	},
	"games_5": {
		"name": "Getting Hungry",
		"description": "Play 5 games — the cheese addiction begins."
	},
	"games_10": {
		"name": "Cheese Curious",
		"description": "Play 10 games — developing a taste for chedda."
	},
	"games_20": {
		"name": "Dairy Devotee",
		"description": "Play 20 games — officially hooked on cheese."
	},
	"games_30": {
		"name": "Fromage Fanatic",
		"description": "Play 30 games — cheese runs through your veins."
	},
	"games_50": {
		"name": "Cheese Legend",
		"description": "Play 50 games — a true master of the wheel."
	},
	
	# ========================================
	# SCORE MILESTONES (6)
	# ========================================
	"score_1000": {
		"name": "Cheese Nibbler",
		"description": "Score 1,000 points in a single game."
	},
	"score_2000": {
		"name": "Chedda Chaser",
		"description": "Score 2,000 points — warming up nicely."
	},
	"score_3000": {
		"name": "Gouda Grabber",
		"description": "Score 3,000 points — now we're cooking."
	},
	"score_5000": {
		"name": "Brie Boss",
		"description": "Score 5,000 points — serious cheese skills."
	},
	"score_7500": {
		"name": "Parmesan Pro",
		"description": "Score 7,500 points — elite tier unlocked."
	},
	"score_10000": {
		"name": "The Big Cheese",
		"description": "Score 10,000 points — absolute dairy dominance."
	},
	
	# ========================================
	# CLUTCH ACHIEVEMENTS (5)
	# Score X points with 5 seconds or less remaining
	# ========================================
	"clutch_500": {
		"name": "Close Call Chedda",
		"description": "Finish with 500+ points and ≤5 seconds left."
	},
	"clutch_1000": {
		"name": "Last Bite",
		"description": "Finish with 1,000+ points and ≤5 seconds left."
	},
	"clutch_2000": {
		"name": "Buzzer Beater Brie",
		"description": "Finish with 2,000+ points and ≤5 seconds left."
	},
	"clutch_3000": {
		"name": "Photo Finish Fromage",
		"description": "Finish with 3,000+ points and ≤5 seconds left."
	},
	"clutch_5000": {
		"name": "Miraculous Mozzarella",
		"description": "Finish with 5,000+ points and ≤5 seconds left. Legendary."
	},
	
	# ========================================
	# STREAK / SPECIAL (Reserved for future)
	# ========================================
	# Add streak or special achievements here when ready
	# Examples:
	# "perfect_level": { "name": "Spotless", "description": "Complete a level collecting every cheese." },
	# "speed_demon": { "name": "Speed Demon", "description": "Score 1000 points in the first 30 seconds." },
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
const CACHE_VERSION = 3  # Bumped for new structure

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
			_log("🔄 Syncing games_played: local=%d → backend=%d" % [games_played, backend_play_count])
			games_played = backend_play_count
	
	_process_backend_achievements(achievements)

func _process_backend_achievements(achievements: Array):
	"""Process achievements array from backend"""
	unlocked_achievements.clear()
	
	for ach in achievements:
		var ach_id: String = ""
		
		if typeof(ach) == TYPE_DICTIONARY:
			ach_id = str(ach.get("id", ""))
		elif typeof(ach) == TYPE_STRING:
			ach_id = ach
		
		if ach_id != "" and ACHIEVEMENTS.has(ach_id):
			unlocked_achievements.append(ach_id)
	
	backend_synced = true
	
	# Save to cache (includes games_played which was synced earlier)
	_save_local_cache()
	
	_log("✅ Synced %d achievements, %d games from backend" % [unlocked_achievements.size(), games_played])
	achievements_synced.emit()
	achievements_ready.emit()

# ============================================================
# ACHIEVEMENT UNLOCKING
# ============================================================

func unlock(achievement_id: String) -> bool:
	"""Unlock a single achievement"""
	if not ACHIEVEMENTS.has(achievement_id):
		push_warning("[Achievements] Unknown achievement: %s" % achievement_id)
		return false
	
	if is_unlocked(achievement_id):
		return false
	
	# Add to local unlocked list
	unlocked_achievements.append(achievement_id)
	
	var achievement = ACHIEVEMENTS[achievement_id]
	var achievement_name = achievement.get("name", achievement_id)
	var achievement_desc = achievement.get("description", "")
	
	_log("🏆 Unlocked: %s" % achievement_name)
	
	# Add to notification queue
	notification_queue.append({
		"id": achievement_id,
		"name": achievement_name,
		"description": achievement_desc
	})
	
	# Emit signal
	achievement_unlocked.emit(achievement_id, achievement_name)
	
	# Add to pending queue for backend submission
	# NOTE: Don't send to backend immediately - new users won't have a profile yet
	# All achievements are batched and sent with submit_with_score() at game over
	pending_achievements.append({
		"id": achievement_id,
		"name": achievement_name,
		"description": achievement_desc
	})
	
	# Save local cache
	_save_local_cache()
	
	return true

## Alias for unlock() - more explicit name
func unlock_achievement(achievement_id: String) -> bool:
	return unlock(achievement_id)

# ============================================================
# NOTIFICATION QUEUE (For UI)
# ============================================================

func has_pending_notifications() -> bool:
	"""Check if there are achievement notifications to display"""
	return not notification_queue.is_empty()

func get_next_notification() -> Dictionary:
	"""Get next achievement notification (call this from your UI)"""
	if notification_queue.is_empty():
		return {}
	return notification_queue.pop_front()

func get_all_pending_notifications() -> Array:
	"""Get all pending notifications and clear the queue"""
	var notifications = notification_queue.duplicate()
	notification_queue.clear()
	return notifications

func clear_notifications():
	"""Clear all pending notifications"""
	notification_queue.clear()

# ============================================================
# BATCH SUBMISSION (GAME OVER)
# ============================================================

func submit_with_score(score: int, streak: int):
	"""Submit score - achievements are synced separately after profile exists"""
	if not CheddaBoards.is_authenticated():
		_log("Not authenticated - achievements cached locally")
		CheddaBoards.submit_score(score, streak)
		return
	
	_log("📤 Submitting score: %d (pending achievements: %d)" % [score, pending_achievements.size()])
	
	# Just submit the score - achievements will be synced via sync_pending_to_backend()
	# after the score_submitted callback confirms the profile exists
	CheddaBoards.submit_score(score, streak)

## Alias for submit_with_score
func submit_achievements_with_score(score: int, streak: int):
	submit_with_score(score, streak)

func sync_pending_to_backend():
	"""Sync all pending achievements to backend - call this AFTER score submission succeeds"""
	if not CheddaBoards.is_authenticated():
		_log("Not authenticated - cannot sync achievements")
		return
	
	if pending_achievements.is_empty():
		_log("No pending achievements to sync")
		return
	
	_log("🔄 Syncing %d achievements to backend..." % pending_achievements.size())
	
	# Send each achievement to backend
	for ach in pending_achievements:
		CheddaBoards.unlock_achievement(ach.id, ach.name, ach.description)
	
	_log("✅ Sent %d achievements to backend" % pending_achievements.size())
	
	# Clear pending queue
	pending_achievements.clear()
	_save_local_cache()

# ============================================================
# PROGRESS TRACKING
# ============================================================

func update_progress(achievement_id: String, current: int, total: int):
	"""Update progress towards an achievement"""
	if is_unlocked(achievement_id):
		return
	
	progress_tracking[achievement_id] = {
		"current": current,
		"total": total
	}
	
	progress_updated.emit(achievement_id, current, total)
	
	# Auto-unlock if target reached
	if current >= total:
		unlock(achievement_id)

func get_progress(achievement_id: String) -> Dictionary:
	"""Get progress for an achievement"""
	return progress_tracking.get(achievement_id, {"current": 0, "total": 1})

# ============================================================
# CHECKING ACHIEVEMENTS
# ============================================================

func is_unlocked(achievement_id: String) -> bool:
	"""Check if achievement is unlocked"""
	return unlocked_achievements.has(achievement_id)

func get_unlocked_count() -> int:
	"""Get number of unlocked achievements"""
	return unlocked_achievements.size()

func get_total_count() -> int:
	"""Get total number of achievements"""
	return ACHIEVEMENTS.size()

func get_unlocked_percentage() -> float:
	"""Get percentage of achievements unlocked (0-100)"""
	if ACHIEVEMENTS.is_empty():
		return 0.0
	return (float(unlocked_achievements.size()) / float(ACHIEVEMENTS.size())) * 100.0

func get_unlocked_ids() -> Array:
	"""Get array of unlocked achievement IDs"""
	return unlocked_achievements.duplicate()

# ============================================================
# AUTOMATIC ACHIEVEMENT CHECKERS
# ============================================================

## Call this at the END of each game to increment and check games played
func increment_games_played():
	"""Increment games played counter and check achievements"""
	games_played += 1
	_save_local_cache()
	_log("🎮 Games played: %d" % games_played)
	check_games_played()

func check_games_played():
	"""Check and unlock games played achievements"""
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
	if score >= 10000:
		unlock("score_10000")
	if score >= 7500:
		unlock("score_7500")
	if score >= 5000:
		unlock("score_5000")
	if score >= 3000:
		unlock("score_3000")
	if score >= 2000:
		unlock("score_2000")
	if score >= 1000:
		unlock("score_1000")

func check_clutch(score: int, time_remaining: float):
	"""Check and unlock clutch achievements (score with ≤5 seconds left)"""
	if time_remaining > 5.0:
		return  # Not a clutch situation
	
	_log("⏱️ Clutch check: %d points with %.1fs remaining" % [score, time_remaining])
	
	if score >= 5000:
		unlock("clutch_5000")
	if score >= 3000:
		unlock("clutch_3000")
	if score >= 2000:
		unlock("clutch_2000")
	if score >= 1000:
		unlock("clutch_1000")
	if score >= 500:
		unlock("clutch_500")

func check_game_over(score: int, time_remaining: float = -1.0):
	"""Check all end-of-game achievements at once"""
	check_score(score)
	
	# Check clutch if time was provided
	if time_remaining >= 0.0:
		check_clutch(score, time_remaining)

## Legacy alias for backward compatibility
func check_score_achievements(score: int):
	check_score(score)

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
	"""Get achievements by category prefix (e.g., 'games_', 'score_', 'clutch_')"""
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
var debug_logging: bool = true  # Enabled by default for debugging sync issues

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
	print("║         Achievements Debug v1.2.0            ║")
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
