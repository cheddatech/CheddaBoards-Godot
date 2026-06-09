# Achievements.gd v2.1.1
# Achievement tracking for CheddaClick - CheddaBoards Template
# Add as Autoload: Project → Project Settings → Autoload → "Achievements"
#
# ============================================================
# ⚠  EXAMPLE CONTENT — REPLACE BEFORE YOU SHIP
# ============================================================
# The achievement DEFINITIONS and the unlock CONDITIONS in this file are
# CheddaClick's, shipped as a working example. They are NOT generic.
#
# Making achievements your own means changing TWO things, not one:
#   1. The `achievements` dictionary below (ids, names, descriptions, icons)
#   2. The unlock logic in check_score / check_combo / check_level /
#      check_game_over — these fire on CheddaClick's concepts (score, combo,
#      hits, level, time-remaining). If your game has no combos or levels,
#      rewrite these to call _unlock(...) on whatever YOUR game tracks.
#
# If you ship this file unchanged, your players will unlock CheddaClick's
# achievements and those ids get written to their CheddaBoards profile.
#
# Everything else here — the unlock/save/sync engine — is generic and safe
# to keep as-is. Only the definitions and the check_* conditions are example.
# ============================================================
#
# v2.1.1: submit_with_score() now actually pushes achievements to the
#         backend via CheddaBoards.submit_score_with_achievements()
#         (previously it gathered the IDs but only submitted the score,
#         so unlocks never synced). force_sync_pending() now performs a
#         real batch sync instead of being a no-op stub.
#
# Usage:
#   - Call Achievements.start_session() at game start (optional)
#   - Call Achievements.increment_games_played() at game end
#   - Call Achievements.check_game_over(score, hits, max_combo) at end
#   - Call Achievements.check_level(level, time_remaining) on level up
#   - Call Achievements.submit_with_score(score, streak) to submit

extends Node

signal achievement_unlocked(id: String, name: String)
signal achievements_ready()

# ============================================================
# ACHIEVEMENT DEFINITIONS  —  ⚠ EXAMPLE, REPLACE THESE
# ============================================================
# CheddaClick's achievements. Swap the whole dictionary for your own game's
# (and update the check_* conditions further down to match).

var achievements = {
	# Score achievements
	"score_1000": {
		"name": "Getting Started",
		"description": "Score 1,000 points",
		"icon": "🧀"
	},
	"score_5000": {
		"name": "Cheese Hunter",
		"description": "Score 5,000 points",
		"icon": "🧀🧀"
	},
	"score_10000": {
		"name": "Cheese Master",
		"description": "Score 10,000 points",
		"icon": "👑"
	},
	"score_25000": {
		"name": "Cheese Legend",
		"description": "Score 25,000 points",
		"icon": "🏆"
	},
	
	# Combo achievements
	"combo_5": {
		"name": "Combo Starter",
		"description": "Reach a x5 combo",
		"icon": "⚡"
	},
	"combo_10": {
		"name": "Combo King",
		"description": "Reach a x10 combo",
		"icon": "👑"
	},
	
	# Level achievements
	"level_3": {
		"name": "Level Up!",
		"description": "Reach Level 3",
		"icon": "⬆️"
	},
	"level_5": {
		"name": "Max Level",
		"description": "Reach Level 5",
		"icon": "🔥"
	},
	
	# Accuracy achievements
	"hits_50": {
		"name": "Sharp Shooter",
		"description": "Hit 50 targets in one game",
		"icon": "🎯"
	},
	"hits_100": {
		"name": "Precision Expert",
		"description": "Hit 100 targets in one game",
		"icon": "💎"
	},
	
	# Games played achievements
	"games_10": {
		"name": "Dedicated Player",
		"description": "Play 10 games",
		"icon": "🎮"
	},
	"games_50": {
		"name": "CheddaClick Addict",
		"description": "Play 50 games",
		"icon": "❤️"
	},
	
	# Speed achievements
	"fast_level": {
		"name": "Speed Runner",
		"description": "Reach Level 3 with 20+ seconds remaining",
		"icon": "⏱️"
	}
}

# ============================================================
# STATE
# ============================================================

var is_ready: bool = false
var unlocked_achievements: Array = []
var total_games_played: int = 0

# Session tracking
var session_score: int = 0
var session_hits: int = 0
var session_max_combo: int = 0
var session_max_level: int = 1

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	_load_local_achievements()
	is_ready = true
	print("[Achievements] Loaded %d unlocked achievements" % unlocked_achievements.size())
	achievements_ready.emit()

func _load_local_achievements():
	if FileAccess.file_exists("user://achievements.save"):
		var file = FileAccess.open("user://achievements.save", FileAccess.READ)
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			unlocked_achievements = data.get("unlocked", [])
			total_games_played = data.get("games_played", 0)

func _save_local_achievements():
	var file = FileAccess.open("user://achievements.save", FileAccess.WRITE)
	file.store_var({
		"unlocked": unlocked_achievements,
		"games_played": total_games_played
	})
	file.close()

# ============================================================
# SESSION TRACKING + UNLOCK CONDITIONS  —  ⚠ EXAMPLE, REPLACE THESE
# ============================================================
# increment_games_played() and the check_* functions below contain
# CheddaClick's unlock rules (score/combo/level/hits/time thresholds).
# This is the "second thing" to replace — rewrite these to fire
# _unlock("your_id") on whatever your own game actually tracks.
# ============================================================

func start_session():
	"""Call at start of each game (optional)"""
	session_score = 0
	session_hits = 0
	session_max_combo = 0
	session_max_level = 1

func increment_games_played():
	"""Call at end of each game"""
	total_games_played += 1
	_save_local_achievements()
	
	if total_games_played >= 10:
		_unlock("games_10")
	if total_games_played >= 50:
		_unlock("games_50")

func get_games_played() -> int:
	"""Get total games played"""
	return total_games_played

func check_level(level: int, time_remaining: float = 0.0):
	"""Check level-related achievements"""
	if level > session_max_level:
		session_max_level = level
	
	if level >= 3:
		_unlock("level_3")
		# Speed achievement - reach level 3 with lots of time left
		if time_remaining >= 20.0:
			_unlock("fast_level")
	
	if level >= 5:
		_unlock("level_5")

func check_score(score: int):
	"""Check score achievements during gameplay"""
	if score >= 1000:
		_unlock("score_1000")
	if score >= 5000:
		_unlock("score_5000")
	if score >= 10000:
		_unlock("score_10000")
	if score >= 25000:
		_unlock("score_25000")

func check_combo(combo: int):
	"""Check combo achievements during gameplay"""
	if combo >= 5:
		_unlock("combo_5")
	if combo >= 10:
		_unlock("combo_10")

func check_game_over(score: int, hits: int, max_combo: int):
	"""Check end-of-game achievements"""
	session_score = score
	session_hits = hits
	session_max_combo = max_combo
	
	# Score achievements
	if score >= 1000:
		_unlock("score_1000")
	if score >= 5000:
		_unlock("score_5000")
	if score >= 10000:
		_unlock("score_10000")
	if score >= 25000:
		_unlock("score_25000")
	
	# Combo achievements
	if max_combo >= 5:
		_unlock("combo_5")
	if max_combo >= 10:
		_unlock("combo_10")
	
	# Hits achievements
	if hits >= 50:
		_unlock("hits_50")
	if hits >= 100:
		_unlock("hits_100")

# ============================================================
# UNLOCK LOGIC
# ============================================================

func _unlock(achievement_id: String):
	if achievement_id in unlocked_achievements:
		return  # Already unlocked
	
	if not achievements.has(achievement_id):
		push_warning("[Achievements] Unknown achievement: %s" % achievement_id)
		return
	
	unlocked_achievements.append(achievement_id)
	_save_local_achievements()
	
	var ach = achievements[achievement_id]
	print("[Achievements] 🏆 Unlocked: %s %s" % [ach.icon, ach.name])
	
	achievement_unlocked.emit(achievement_id, ach.name)

func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in unlocked_achievements

# ============================================================
# SCORE SUBMISSION WITH ACHIEVEMENTS
# ============================================================

func submit_with_score(score: int, streak: int):
	"""Submit score along with any unlocked achievements.

	Uses the SDK's combined call, which submits the score first (this
	creates/updates the player on the backend) and then batch-syncs the
	achievements once the score succeeds. Passing the score alone would
	never push the achievements."""
	CheddaBoards.submit_score_with_achievements(score, streak, unlocked_achievements)
	print("[Achievements] Submitting score %d with %d achievements" % [score, unlocked_achievements.size()])

# ============================================================
# QUERIES
# ============================================================

func get_unlocked_count() -> int:
	return unlocked_achievements.size()

func get_total_count() -> int:
	return achievements.size()

func get_unlocked_percentage() -> float:
	if achievements.size() == 0:
		return 0.0
	return (float(unlocked_achievements.size()) / float(achievements.size())) * 100.0

func get_all_achievements() -> Array:
	"""Return all achievements as array with unlock status for AchievementsView"""
	var result: Array = []
	for id in achievements.keys():
		var ach = achievements[id]
		result.append({
			"id": id,
			"name": ach.get("name", id),
			"description": ach.get("description", ""),
			"icon": ach.get("icon", ""),
			"unlocked": id in unlocked_achievements,
			"progress": {
				"current": 0,
				"total": 1
			}
		})
	return result

func get_achievement(id: String) -> Dictionary:
	"""Get a single achievement by ID"""
	if not achievements.has(id):
		return {}
	var ach = achievements[id]
	return {
		"id": id,
		"name": ach.get("name", id),
		"description": ach.get("description", ""),
		"icon": ach.get("icon", ""),
		"unlocked": id in unlocked_achievements
	}

func get_unlocked_achievements() -> Array:
	return unlocked_achievements

# ============================================================
# SYNC FUNCTIONS (Called by MainMenu/other scenes)
# ============================================================

func force_sync_pending():
	"""Force-sync all unlocked achievements to CheddaBoards in one batch.

	Note: the player must already exist on the backend (i.e. a score has
	been submitted at least once), or the unlocks are ignored. The normal
	path is submit_with_score(); use this only to re-push existing unlocks
	(e.g. after a profile load)."""
	if unlocked_achievements.is_empty():
		return
	print("[Achievements] Syncing %d achievements" % unlocked_achievements.size())
	CheddaBoards.unlock_achievements_batch(unlocked_achievements)

func sync_from_profile(profile: Dictionary):
	"""Sync achievements from a loaded profile"""
	var remote_achievements = profile.get("achievements", [])
	if remote_achievements is Array:
		for ach_id in remote_achievements:
			if ach_id not in unlocked_achievements:
				unlocked_achievements.append(ach_id)
		_save_local_achievements()
		print("[Achievements] Synced from profile: %d total" % unlocked_achievements.size())

# ============================================================
# DEBUG
# ============================================================

func debug_status():
	"""Print debug information"""
	print("")
	print("========================================")
	print("       Achievements Debug v2.1.1       ")
	print("========================================")
	print(" Games Played:   %d" % total_games_played)
	print(" Unlocked:       %d / %d" % [get_unlocked_count(), get_total_count()])
	print(" Percentage:     %.1f%%" % get_unlocked_percentage())
	print("----------------------------------------")
	print(" Unlocked IDs:   %s" % str(unlocked_achievements))
	print("========================================")
	print("")
