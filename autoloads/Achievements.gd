# Achievements.gd v2.2.0
# Achievement tracking for CheddaClick - CheddaBoards Template
# Add as Autoload: Project → Project Settings → Autoload → "Achievements"
# (AFTER the CheddaBoards autoload, so the SDK exists when this wires up)
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
# v2.2.0: Identity-scoped save slots + automatic backend sync.
#         - Unlocks are now saved per identity ("anon" vs "account"), so
#           guest progress no longer leaks into whoever signs in next on
#           the same device, and logging out hands the device to a clean
#           guest. An existing user://achievements.save from older
#           versions is migrated into the anon slot automatically.
#         - The SDK's signals are wired up automatically: unlocks push to
#           the backend AFTER login settles (pushing at menu load ran
#           before the player identity was set and could store unlocks
#           against the wrong player), remote unlocks merge in whenever a
#           profile loads, and linking an anonymous account folds guest
#           progress into it.
#         You no longer need to call force_sync_pending() or
#         sync_from_profile() yourself — both still exist for manual use.
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
#   Backend sync on login/logout/account-link is automatic.

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

# Identity-scoped save slots. Guest progress lives in the "anon" slot,
# signed-in progress in the "account" slot. Keeping them separate means
# a shared device never leaks one player's unlocks into another's
# profile - the #1 support headache with a single shared save file.
const SLOT_ANON := "anon"
const SLOT_ACCOUNT := "account"
const LEGACY_SAVE_PATH := "user://achievements.save"
var _slot: String = SLOT_ANON

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	_migrate_legacy_save()
	_load_slot(SLOT_ANON)
	is_ready = true
	print("[Achievements] Loaded slot '%s': %d unlocked" % [_slot, unlocked_achievements.size()])
	achievements_ready.emit()
	# Wire up the SDK once the autoload order has settled. If the
	# CheddaBoards autoload isn't present, everything still works
	# offline - sync just never fires.
	_connect_sdk.call_deferred()

func _save_path(slot: String) -> String:
	return "user://achievements_%s.save" % slot

func _migrate_legacy_save():
	# Pre-v2.2.0 saved everything (guest or signed-in) to one shared
	# file. Adopt it as the anon slot once, so nobody loses progress
	# on upgrade.
	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(_save_path(SLOT_ANON)):
		var dir = DirAccess.open("user://")
		if dir:
			dir.rename(LEGACY_SAVE_PATH.get_file(), _save_path(SLOT_ANON).get_file())
			print("[Achievements] Migrated legacy save into '%s' slot" % SLOT_ANON)

func _read_slot_file(slot: String) -> Dictionary:
	if not FileAccess.file_exists(_save_path(slot)):
		return {}
	var file = FileAccess.open(_save_path(slot), FileAccess.READ)
	var data = file.get_var()
	file.close()
	return data if data is Dictionary else {}

func _load_slot(slot: String):
	_slot = slot
	var data = _read_slot_file(slot)
	unlocked_achievements = data.get("unlocked", [])
	total_games_played = data.get("games_played", 0)

func _save_local_achievements():
	var file = FileAccess.open(_save_path(_slot), FileAccess.WRITE)
	file.store_var({
		"unlocked": unlocked_achievements,
		"games_played": total_games_played
	})
	file.close()

func _switch_slot(slot: String):
	if slot == _slot:
		return
	_save_local_achievements()  # persist the slot we're leaving
	_load_slot(slot)
	print("[Achievements] Switched to slot '%s' (%d unlocked)" % [_slot, unlocked_achievements.size()])

# ============================================================
# SDK WIRING (automatic backend sync)
# ============================================================
# All connections are optional and defensive: the template works with any
# CheddaBoards SDK version, and offline, without modification.

func _connect_sdk():
	var sdk = get_node_or_null("/root/CheddaBoards")
	if sdk == null:
		return
	_connect_if_present(sdk, "login_success", _on_sdk_login)
	_connect_if_present(sdk, "logout_success", _on_sdk_logout)
	_connect_if_present(sdk, "profile_loaded", _on_sdk_profile_loaded)
	_connect_if_present(sdk, "account_upgraded", _on_sdk_account_upgraded)

func _connect_if_present(sdk: Node, sig: String, callable: Callable):
	if sdk.has_signal(sig) and not sdk.is_connected(sig, callable):
		sdk.connect(sig, callable)

func _on_sdk_login(_nickname: String):
	var sdk = get_node_or_null("/root/CheddaBoards")
	if sdk and sdk.has_method("has_account") and sdk.has_account():
		_switch_slot(SLOT_ACCOUNT)
		# Identity is settled and authenticated NOW - this is the reliable
		# moment to reconcile local unlocks up to the backend. Do NOT push
		# at menu load instead: that runs before login completes and can
		# go out under a fallback/device ID, storing unlocks against the
		# wrong player.
		force_sync_pending()
	else:
		_switch_slot(SLOT_ANON)

func _on_sdk_logout():
	# Persist the account's progress, then hand the device to a genuinely
	# fresh guest: wipe the anon slot so nothing leaks between players.
	if _slot == SLOT_ACCOUNT:
		_save_local_achievements()
	if FileAccess.file_exists(_save_path(SLOT_ANON)):
		DirAccess.remove_absolute(_save_path(SLOT_ANON))
	_load_slot(SLOT_ANON)
	print("[Achievements] Logout: anon slot wiped, fresh start")

func _on_sdk_profile_loaded(_nickname: String, _score: int, _streak: int,
		remote_achievements: Array, play_count: int):
	# The server is the reconciliation point: merge its unlocks in and
	# adopt its play count when it's ahead (e.g. same account played
	# from another device).
	var changed := false
	for ach_id in remote_achievements:
		var id := str(ach_id)
		if id not in unlocked_achievements and achievements.has(id):
			unlocked_achievements.append(id)
			changed = true
	if play_count > total_games_played:
		total_games_played = play_count
		changed = true
	if changed:
		_save_local_achievements()
		print("[Achievements] Merged remote progress: %d unlocked" % unlocked_achievements.size())

func _on_sdk_account_upgraded(_profile: Dictionary, _migration: Dictionary):
	# The player just linked their anonymous identity to a real account.
	# The server migrated their backend data; fold their local anon
	# progress into the account slot too.
	#
	# SIGNAL ORDER: login_success fires before account_upgraded, so
	# _on_sdk_login has usually already switched us to the account slot -
	# the anon progress is sitting in its file on disk, saved by that
	# switch. If the upgrade somehow arrives first, memory IS the anon
	# progress; switching slots saves it to disk before we read it back.
	if _slot == SLOT_ANON:
		_switch_slot(SLOT_ACCOUNT)
	var anon_snapshot := _read_slot_file(SLOT_ANON)
	
	var grew := false
	for ach_id in anon_snapshot.get("unlocked", []):
		var id := str(ach_id)
		if id not in unlocked_achievements and achievements.has(id):
			unlocked_achievements.append(id)
			grew = true
	total_games_played = max(total_games_played, int(anon_snapshot.get("games_played", 0)))
	_save_local_achievements()
	print("[Achievements] Folded anon progress into account: %d unlocked" % unlocked_achievements.size())
	
	# The anon slot's contents belong to this account now - wipe it so
	# the next guest on this device starts clean.
	if FileAccess.file_exists(_save_path(SLOT_ANON)):
		DirAccess.remove_absolute(_save_path(SLOT_ANON))
	
	# The fold may have grown the set beyond what either side had -
	# push the reconciled set to the backend under the new session.
	if grew:
		force_sync_pending()

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
# SYNC FUNCTIONS (automatic since v2.2.0 - kept for manual use)
# ============================================================

func force_sync_pending():
	"""Force-sync all unlocked achievements to CheddaBoards in one batch.

	Called automatically after login and after account linking. The player
	must already exist on the backend (i.e. a score has been submitted at
	least once), or the unlocks are ignored. The normal in-game path is
	submit_with_score()."""
	if unlocked_achievements.is_empty():
		return
	print("[Achievements] Syncing %d achievements" % unlocked_achievements.size())
	CheddaBoards.unlock_achievements_batch(unlocked_achievements)

func sync_from_profile(profile: Dictionary):
	"""Merge achievements from a loaded profile dictionary.

	Since v2.2.0 this happens automatically via the SDK's profile_loaded
	signal - kept for projects that fetch profiles manually."""
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
	print("       Achievements Debug v2.2.0       ")
	print("========================================")
	print(" Slot:           %s" % _slot)
	print(" Games Played:   %d" % total_games_played)
	print(" Unlocked:       %d / %d" % [get_unlocked_count(), get_total_count()])
	print(" Percentage:     %.1f%%" % get_unlocked_percentage())
	print("----------------------------------------")
	print(" Unlocked IDs:   %s" % str(unlocked_achievements))
	print("========================================")
	print("")
