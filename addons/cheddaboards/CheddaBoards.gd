# CheddaBoards.gd v2.0.0
# CheddaBoards integration for Godot 4.x
# https://github.com/cheddatech/CheddaBoards-Godot
# https://cheddaboards.com
#
# HTTP-ONLY SDK: All platforms use the REST API
# - Anonymous login: API key + persistent device ID
# - Social login (Google, Apple, II): Device Code Auth flow
#   Player authenticates on their phone at cheddaboards.com/link
# - Score submissions, play sessions, achievements: all via HTTP API
#
# v2.0.0: HTTP-only SDK. Removed JavaScript bridge / web SDK dependency.
#          All platforms use the same REST API paths.
#          Social login via Device Code Auth (works everywhere).
# v1.9.0: Device Code Auth - cross-platform social login via REST API.
# v1.8.2: Achievement sync is now non-blocking (async/fire-and-forget).
# v1.8.1: Fixed achievements not syncing - score submitted FIRST (creates player),
#          then achievements sent one-at-a-time.
# v1.7.0: Fixed post-upgrade scores creating ghost anonymous accounts
# v1.6.0: Fixed end_play_session body field (token → playSessionToken)
# v1.5.9: Persistent device IDs - anonymous players keep same identity across sessions
#
# Add to Project Settings > Autoload as "CheddaBoards"

extends Node

# ============================================================
# QUICK START
# ============================================================
# 1. Add this script to Project Settings > Autoload as "CheddaBoards"
# 2. Set your API key: CheddaBoards.set_api_key("cb_xxx")
# 3. Set your game ID: CheddaBoards.set_game_id("your-game")
#
# Anonymous login:
#    func _ready():
#        await CheddaBoards.wait_until_ready()
#        CheddaBoards.login_success.connect(_on_login)
#        CheddaBoards.login_anonymous("PlayerName")
#
# Social login (Google/Apple via device code):
#    func _ready():
#        await CheddaBoards.wait_until_ready()
#        CheddaBoards.device_code_received.connect(_on_code)
#        CheddaBoards.device_code_approved.connect(_on_approved)
#        CheddaBoards.login_with_device_code()
#
#    func _on_code(user_code: String, url: String):
#        $CodeLabel.text = "Go to %s\nEnter code: %s" % [url, user_code]
#
#    func _on_approved(nickname: String):
#        print("Welcome %s!" % nickname)
#
# Score submission:
#    func _on_game_over(score: int, streak: int):
#        CheddaBoards.submit_score(score, streak)
#
# ============================================================

# ============================================================
# SIGNALS
# ============================================================

# --- Initialization ---
signal sdk_ready()
signal init_error(reason: String)

# --- Authentication ---
signal login_success(nickname: String)
signal login_failed(reason: String)
signal logout_success()
signal auth_error(reason: String)

# --- Profile ---
signal profile_loaded(nickname: String, score: int, streak: int, achievements: Array)
signal no_profile()
signal nickname_changed(new_nickname: String)
signal nickname_error(reason: String)

# --- Scores & Leaderboards (Legacy) ---
signal score_submitted(score: int, streak: int)
signal score_error(reason: String)
signal leaderboard_loaded(entries: Array)
signal player_rank_loaded(rank: int, score: int, streak: int, total_players: int)
signal rank_error(reason: String)

# --- Scoreboards (Time-based) ---
signal scoreboards_loaded(scoreboards: Array)
signal scoreboard_loaded(scoreboard_id: String, config: Dictionary, entries: Array)
signal scoreboard_rank_loaded(scoreboard_id: String, rank: int, score: int, streak: int, total: int)
signal scoreboard_error(reason: String)

# --- Scoreboard Archives ---
signal archives_list_loaded(scoreboard_id: String, archives: Array)
signal archived_scoreboard_loaded(archive_id: String, config: Dictionary, entries: Array)
signal archive_stats_loaded(total_archives: int, by_scoreboard: Array)
signal archive_error(reason: String)

# --- Achievements ---
signal achievement_unlocked(achievement_id: String)
signal achievements_loaded(achievements: Array)

# --- HTTP API ---
signal request_failed(endpoint: String, error: String)

# --- Play Sessions (Time Validation) ---
signal play_session_started(token: String)
signal play_session_error(reason: String)

# --- Account Upgrade (Anonymous → Verified) ---
signal account_upgraded(profile: Dictionary, migration: Dictionary)
signal account_upgrade_failed(reason: String)

# --- Device Code Auth (Cross-platform login) ---
signal device_code_received(user_code: String, verification_url: String)
signal device_code_approved(nickname: String)
signal device_code_expired()
signal device_code_error(reason: String)

# ============================================================
# CONFIGURATION
# ============================================================

## Set to true to enable verbose logging
var debug_logging: bool = true

## HTTP API Configuration
const API_BASE_URL = "https://api.cheddaboards.com"
var api_key: String = ""  ## Your API key (set via set_api_key())
var game_id: String = ""  ## Your game ID (set via set_game_id())
var _player_id: String = ""
var _session_token: String = ""  ## For OAuth session-based auth
var _play_session_token: String = ""  ## For time validation

# ============================================================
# INTERNAL STATE
# ============================================================

var _init_complete: bool = false
var _auth_type: String = ""
var _cached_profile: Dictionary = {}
var _nickname_just_changed: bool = false
var _nickname: String = ""

# ============================================================
# PERFORMANCE OPTIMIZATION
# ============================================================

var _is_refreshing_profile: bool = false
var _is_submitting_score: bool = false
var _last_profile_refresh: float = 0.0
const PROFILE_REFRESH_COOLDOWN: float = 2.0

# ============================================================
# PENDING SCORE SUBMISSION VALUES
# ============================================================

var _pending_score: int = 0
var _pending_streak: int = 0

# ============================================================
# DEVICE CODE AUTH STATE
# ============================================================

var _device_code: String = ""
var _device_user_code: String = ""
var _device_code_poll_timer: Timer = null
var _device_code_poll_interval: float = 5.0
var _device_code_expires_at: float = 0.0
var _is_polling_device_code: bool = false
var _device_code_poll_in_flight: bool = false
var _device_code_approved: bool = false

# ============================================================
# HTTP REQUEST
# ============================================================

var _http_request: HTTPRequest
var _current_endpoint: String = ""
var _current_meta: Dictionary = {}
var _http_busy: bool = false
var _request_queue: Array = []

# Deferred achievement tracking (sent after score succeeds)
var _deferred_achievement_ids: Array = []
var _deferred_achievements_remaining: int = 0
var _deferred_achievements_synced: Array = []

# ============================================================
# PERSISTENT DEVICE ID
# ============================================================

const DEVICE_ID_PATH = "user://cheddaboards_device.cfg"

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_setup_http_client()
	_log("Initializing CheddaBoards v2.0.0 (HTTP API Mode)...")
	_init_complete = true
	call_deferred("_emit_sdk_ready")

func _emit_sdk_ready() -> void:
	sdk_ready.emit()

func _setup_http_client() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_http_request_completed)

## Fire-and-forget HTTP request (non-blocking, doesn't use queue)
## Used for achievements so they don't block leaderboard loading
func _make_http_request_async(endpoint: String, method: int, body: Dictionary, request_type: String) -> void:
	if api_key.is_empty() and _session_token.is_empty():
		_log("No credentials - skipping async request to %s" % endpoint)
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = _build_headers(request_type)
	var url = API_BASE_URL + endpoint
	var json_body = JSON.stringify(body) if body.size() > 0 else ""
	
	_log("HTTP async %s: %s" % [request_type, endpoint])
	
	http.request_completed.connect(func(result, code, _headers, response_body):
		if code >= 200 and code < 300:
			_log("Async %s complete (HTTP %d)" % [request_type, code])
		else:
			_log("Async %s failed (HTTP %d)" % [request_type, code])
		http.queue_free()
	)
	
	var error = http.request(url, headers, method, json_body)
	if error != OK:
		_log("Async request failed to start: %s" % error)
		http.queue_free()

# ============================================================
# HTTP HELPERS
# ============================================================

## Build headers for an HTTP request based on auth state
func _build_headers(request_type: String = "") -> PackedStringArray:
	var headers: PackedStringArray = ["Content-Type: application/json"]
	
	# Session token takes priority over API key (mutually exclusive)
	# EXCEPT: play sessions always use API key (game-level operation, skip_validation)
	var force_api_key = request_type in ["start_play_session", "end_play_session"] and _session_token.is_empty()
	if not _session_token.is_empty() and not force_api_key:
		headers.append("X-Session-Token: " + _session_token)
	elif not api_key.is_empty():
		headers.append("X-API-Key: " + api_key)
	
	if not game_id.is_empty():
		headers.append("X-Game-ID: " + game_id)
	
	return headers

# ============================================================
# HTTP RESPONSE HANDLER
# ============================================================

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[CheddaBoards] Request failed with result %d" % result)
		request_failed.emit(_current_endpoint, "Network error")
		_emit_http_failure("Network error")
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		push_error("[CheddaBoards] Failed to parse JSON response")
		request_failed.emit(_current_endpoint, "Invalid JSON response")
		_emit_http_failure("Invalid JSON response")
		return
	
	var response = json.data
	
	if response_code != 200:
		var error_msg = response.get("error", "Unknown error")
		# 404 on profile lookup is expected for new players
		if response_code == 404 and _current_endpoint == "player_profile":
			_log("Player profile not found (new player) - normal for first-time players")
			_is_refreshing_profile = false
			no_profile.emit()
			_current_meta = {}
			_http_busy = false
			_process_next_request()
			return
		# 404 on end play session - already consumed or expired
		if response_code == 404 and _current_endpoint == "end_play_session":
			_log("Play session already ended or expired - normal")
			_current_meta = {}
			_http_busy = false
			_process_next_request()
			return
		# Migration errors are non-fatal
		if _current_endpoint == "migrate_account":
			_log("Migration note: %s (non-fatal, continuing)" % error_msg)
			_current_meta = {}
			_http_busy = false
			_process_next_request()
			return
		push_error("[CheddaBoards] API error (%d): %s" % [response_code, error_msg])
		request_failed.emit(_current_endpoint, error_msg)
		_emit_http_failure(error_msg)
		return
	
	if not response.get("ok", false):
		var error_msg = response.get("error", "Unknown error")
		request_failed.emit(_current_endpoint, error_msg)
		_emit_http_failure(error_msg)
		return
	
	var data = response.get("data", {})
	_emit_http_success(data)

func _emit_http_success(data) -> void:
	match _current_endpoint:
		"submit_score":
			_is_submitting_score = false
			_log("Score submission successful: %d points, %d streak" % [_pending_score, _pending_streak])
			score_submitted.emit(_pending_score, _pending_streak)
			_flush_deferred_achievements()
		
		"leaderboard":
			var entries = data.get("leaderboard", [])
			leaderboard_loaded.emit(entries)
		
		"player_rank":
			var rank = _safe_int(data.get("rank", 0))
			var score_val = _safe_int(data.get("score", 0))
			var streak_val = _safe_int(data.get("streak", 0))
			var total = _safe_int(data.get("totalPlayers", 0))
			player_rank_loaded.emit(rank, score_val, streak_val, total)
		
		"player_profile":
			_is_refreshing_profile = false
			if data and not data.is_empty():
				_update_cached_profile(data)
			else:
				no_profile.emit()
		
		"change_nickname":
			var new_nick = str(data.get("nickname", ""))
			if new_nick != "":
				_nickname = new_nick
				_nickname_just_changed = true
				if not _cached_profile.is_empty():
					_cached_profile["nickname"] = new_nick
				nickname_changed.emit(new_nick)
				_log("Nickname changed to: %s" % new_nick)
		
		"change_nickname_anonymous":
			var new_nick = str(data.get("nickname", ""))
			if new_nick != "":
				_nickname = new_nick
				_nickname_just_changed = true
				if not _cached_profile.is_empty():
					_cached_profile["nickname"] = new_nick
				nickname_changed.emit(new_nick)
				_log("Anonymous nickname changed to: %s" % new_nick)
			get_player_profile()
		
		"unlock_achievement":
			var ach_id = str(data.get("achievementId", ""))
			achievement_unlocked.emit(ach_id)
			if _deferred_achievements_remaining > 0:
				_deferred_achievements_synced.append(ach_id)
				_deferred_achievements_remaining -= 1
				_log("Achievement synced: %s (%d remaining)" % [ach_id, _deferred_achievements_remaining])
				if _deferred_achievements_remaining <= 0:
					_log("All deferred achievements done: %d synced" % _deferred_achievements_synced.size())
					achievements_loaded.emit(_deferred_achievements_synced.duplicate())
					_deferred_achievements_synced.clear()
		
		"unlock_achievement_batch":
			var synced = data.get("synced", 0)
			var results = data.get("results", [])
			_log("Batch achievement sync complete: %d synced" % synced)
			for result in results:
				if result.get("success", false):
					var ach_id = str(result.get("achievementId", ""))
					_deferred_achievements_synced.append(ach_id)
					achievement_unlocked.emit(ach_id)
			achievements_loaded.emit(_deferred_achievements_synced.duplicate())
			_deferred_achievements_synced.clear()
			_deferred_achievements_remaining = 0
		
		"achievements":
			var achievements = data.get("achievements", [])
			achievements_loaded.emit(achievements)
		
		"list_scoreboards":
			var scoreboards = data.get("scoreboards", [])
			scoreboards_loaded.emit(scoreboards)
			_log("Loaded %d scoreboards" % scoreboards.size())
		
		"get_scoreboard":
			var sb_id = _current_meta.get("scoreboard_id", "")
			var config = data.get("config", {})
			var entries = data.get("entries", [])
			scoreboard_loaded.emit(sb_id, config, entries)
			_log("Loaded scoreboard '%s' with %d entries" % [sb_id, entries.size()])
		
		"scoreboard_rank":
			var sb_id = _current_meta.get("scoreboard_id", "")
			var found = data.get("found", false)
			if found:
				var rank = _safe_int(data.get("rank", 0))
				var score_val = _safe_int(data.get("score", 0))
				var streak_val = _safe_int(data.get("streak", 0))
				var total = _safe_int(data.get("totalPlayers", 0))
				scoreboard_rank_loaded.emit(sb_id, rank, score_val, streak_val, total)
			else:
				scoreboard_rank_loaded.emit(sb_id, 0, 0, 0, _safe_int(data.get("totalPlayers", 0)))
		
		"list_archives":
			var sb_id = _current_meta.get("scoreboard_id", "")
			var archives = data.get("archives", [])
			archives_list_loaded.emit(sb_id, archives)
			_log("Loaded %d archives for '%s'" % [archives.size(), sb_id])
		
		"get_archive", "get_last_archive":
			var archive_id = data.get("archiveId", _current_meta.get("archive_id", ""))
			var config = data.get("config", {})
			var entries = data.get("entries", [])
			archived_scoreboard_loaded.emit(archive_id, config, entries)
			_log("Loaded archive '%s' with %d entries" % [archive_id, entries.size()])
		
		"archive_stats":
			var total = _safe_int(data.get("totalArchives", 0))
			var by_sb = data.get("byScoreboard", [])
			archive_stats_loaded.emit(total, by_sb)
			_log("Archive stats: %d total archives" % total)
		
		"game_info", "game_stats", "health":
			_log("API response: %s" % str(data))
		
		"start_play_session":
			if data.has("ok"):
				_play_session_token = str(data.get("ok", ""))
			elif data.has("token"):
				_play_session_token = str(data.get("token", ""))
			else:
				var err = str(data.get("err", data.get("error", "Unknown error")))
				_log("Play session error: %s" % err)
				play_session_error.emit(err)
				_current_meta = {}
				_http_busy = false
				_process_next_request()
				return
			_log("Play session started: %s" % _play_session_token.left(30))
			play_session_started.emit(_play_session_token)
		
		"end_play_session":
			_log("Play session ended on server successfully")
		
		"migrate_account":
			var migrated_games = _safe_int(data.get("migratedGames", 0))
			var migrated_sb = _safe_int(data.get("migratedScoreboards", 0))
			_log("Migration complete: %d games, %d scoreboards migrated" % [migrated_games, migrated_sb])
			refresh_profile()
			account_upgraded.emit(_cached_profile, {
				"migratedGames": migrated_games,
				"migratedScoreboards": migrated_sb,
			})
		
		"device_code_request":
			var dc = str(data.get("device_code", ""))
			var uc = str(data.get("user_code", ""))
			var url = str(data.get("verification_url", ""))
			var url_complete = str(data.get("verification_url_complete", ""))
			var expires_in = _safe_int(data.get("expires_in", 300))
			var interval = _safe_int(data.get("interval", 5))
			
			_device_code = dc
			_device_user_code = uc
			_device_code_poll_interval = float(interval)
			_device_code_expires_at = Time.get_unix_time_from_system() + float(expires_in)
			
			_log("Device code received: %s (expires in %ds)" % [uc, expires_in])
			device_code_received.emit(uc, url_complete if url_complete != "" else url)
			_start_device_code_polling()
		
		"device_code_token":
			pass  # Handled in custom polling function
	
	_current_meta = {}
	_http_busy = false
	_process_next_request()

func _emit_http_failure(error: String) -> void:
	match _current_endpoint:
		"submit_score":
			_is_submitting_score = false
			score_error.emit(error)
		"leaderboard":
			leaderboard_loaded.emit([])
		"player_rank":
			rank_error.emit(error)
		"player_profile":
			_is_refreshing_profile = false
			no_profile.emit()
		"change_nickname", "change_nickname_anonymous":
			nickname_error.emit(error)
		"unlock_achievement":
			if _deferred_achievements_remaining > 0:
				_deferred_achievements_remaining -= 1
				_log("Achievement unlock failed (%d remaining)" % _deferred_achievements_remaining)
				if _deferred_achievements_remaining <= 0:
					achievements_loaded.emit(_deferred_achievements_synced.duplicate())
					_deferred_achievements_synced.clear()
		"unlock_achievement_batch":
			_log("Batch achievement sync failed: %s" % error)
			achievements_loaded.emit([])
			_deferred_achievements_synced.clear()
			_deferred_achievements_remaining = 0
		"achievements":
			achievements_loaded.emit([])
		"list_scoreboards":
			scoreboards_loaded.emit([])
			scoreboard_error.emit(error)
		"get_scoreboard":
			var sb_id = _current_meta.get("scoreboard_id", "")
			scoreboard_loaded.emit(sb_id, {}, [])
			scoreboard_error.emit(error)
		"scoreboard_rank":
			var sb_id = _current_meta.get("scoreboard_id", "")
			scoreboard_rank_loaded.emit(sb_id, 0, 0, 0, 0)
			scoreboard_error.emit(error)
		"list_archives":
			var sb_id = _current_meta.get("scoreboard_id", "")
			archives_list_loaded.emit(sb_id, [])
			archive_error.emit(error)
		"get_archive", "get_last_archive":
			var archive_id = _current_meta.get("archive_id", "")
			archived_scoreboard_loaded.emit(archive_id, {}, [])
			archive_error.emit(error)
		"start_play_session":
			_log("Play session error: %s" % error)
			play_session_error.emit(error)
		"end_play_session":
			_log("End play session error (ignored): %s" % error)
		"device_code_request":
			_log("Device code request failed: %s" % error)
			device_code_error.emit(error)
		"archive_stats":
			archive_stats_loaded.emit(0, [])
			archive_error.emit(error)
	
	_current_meta = {}
	_http_busy = false
	_process_next_request()

func _make_http_request(endpoint: String, method: int, body: Dictionary, request_type: String, meta: Dictionary = {}) -> void:
	if api_key.is_empty() and _session_token.is_empty():
		_log("No credentials set - skipping HTTP request to %s" % endpoint)
		match request_type:
			"submit_score":
				score_error.emit("No credentials set")
			"player_profile":
				no_profile.emit()
			"leaderboard":
				leaderboard_loaded.emit([])
			"player_rank":
				rank_error.emit("No credentials set")
			"list_scoreboards", "get_scoreboard":
				scoreboard_error.emit("No credentials set")
			"list_archives", "get_archive", "get_last_archive", "archive_stats":
				archive_error.emit("No credentials set")
		return
	
	var request_data = {
		"endpoint": endpoint,
		"method": method,
		"body": body,
		"request_type": request_type,
		"meta": meta
	}
	
	if _http_busy:
		_log("HTTP busy, queuing request: %s" % request_type)
		_request_queue.append(request_data)
		return
	
	_execute_http_request(request_data)

func _execute_http_request(request_data: Dictionary) -> void:
	_http_busy = true
	_current_endpoint = request_data.request_type
	_current_meta = request_data.get("meta", {})
	
	var headers = _build_headers(_current_endpoint)
	var url = API_BASE_URL + request_data.endpoint
	var json_body = JSON.stringify(request_data.body) if request_data.body.size() > 0 else ""
	
	var method_str = "GET"
	if request_data.method == HTTPClient.METHOD_POST:
		method_str = "POST"
	elif request_data.method == HTTPClient.METHOD_PUT:
		method_str = "PUT"
	elif request_data.method == HTTPClient.METHOD_DELETE:
		method_str = "DELETE"
	_log("HTTP %s: %s" % [method_str, url])
	
	var error = _http_request.request(url, headers, request_data.method, json_body)
	if error != OK:
		push_error("[CheddaBoards] HTTP request failed to start: %s" % error)
		request_failed.emit(request_data.endpoint, "Request failed to start: %s" % error)
		_http_busy = false
		_process_next_request()

func _process_next_request() -> void:
	if _request_queue.is_empty():
		return
	
	var next_request = _request_queue.pop_front()
	_log("Processing queued request: %s" % next_request.request_type)
	_execute_http_request(next_request)

# ============================================================
# PROFILE MANAGEMENT
# ============================================================

func _update_cached_profile(profile: Dictionary) -> void:
	if profile.is_empty():
		return

	# Preserve nickname from recent rename - backend may return stale data
	if _nickname_just_changed and not _nickname.is_empty():
		profile["nickname"] = _nickname
		_log("Preserving renamed nickname '%s' over stale backend data" % _nickname)
		_nickname_just_changed = false

	_cached_profile = profile

	var nickname: String = str(profile.get("nickname", profile.get("username", _get_default_nickname())))
	
	# Handle nested gameProfile from API
	var game_profile = profile.get("gameProfile", {})
	var score: int = 0
	var streak: int = 0
	var achievements: Array = []
	var play_count: int = 0
	
	if game_profile and not game_profile.is_empty():
		score = _safe_int(game_profile.get("score", 0))
		streak = _safe_int(game_profile.get("streak", 0))
		achievements = game_profile.get("achievements", [])
		if achievements == null:
			achievements = []
		play_count = _safe_int(game_profile.get("playCount", 0))
		_cached_profile["score"] = score
		_cached_profile["streak"] = streak
		_cached_profile["achievements"] = achievements
		_cached_profile["playCount"] = play_count
	else:
		score = _safe_int(profile.get("score", profile.get("highScore", 0)))
		streak = _safe_int(profile.get("streak", profile.get("bestStreak", 0)))
		achievements = profile.get("achievements", [])
		if achievements == null:
			achievements = []
		play_count = _safe_int(profile.get("playCount", profile.get("plays", 0)))
	
	_nickname = nickname
	profile_loaded.emit(nickname, score, streak, achievements)

# ============================================================
# LOGGING
# ============================================================

func _log(message: String) -> void:
	if debug_logging:
		print("[CheddaBoards] %s" % message)

# ============================================================
# PUBLIC API - UTILITIES
# ============================================================

func is_ready() -> bool:
	return _init_complete

func can_connect() -> bool:
	return _init_complete and (not api_key.is_empty() or not _session_token.is_empty())

func wait_until_ready() -> void:
	if is_ready():
		return
	await sdk_ready

func _safe_int(value) -> int:
	"""Safely convert any value to int. Handles null, float, string, etc."""
	if value == null:
		return 0
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		if value.is_valid_int():
			return value.to_int()
		if value.is_valid_float():
			return int(value.to_float())
		return 0
	return 0

func _get_default_nickname() -> String:
	return "Player_" + get_player_id().left(6)

func get_nickname() -> String:
	if _nickname != "" and not _nickname.begins_with("Player_p_"):
		return _nickname
	
	if not _cached_profile.is_empty():
		var profile_nick = str(_cached_profile.get("nickname", ""))
		if profile_nick != "" and not profile_nick.begins_with("Player_p_"):
			return profile_nick
	
	if _nickname != "":
		return _nickname
	
	return _get_default_nickname()

func get_high_score() -> int:
	if _cached_profile.is_empty():
		return 0
	if _cached_profile.has("score"):
		return _safe_int(_cached_profile.get("score", 0))
	var gp = _cached_profile.get("gameProfile", {})
	if gp and not gp.is_empty():
		return _safe_int(gp.get("score", 0))
	return 0

func get_best_streak() -> int:
	if _cached_profile.is_empty():
		return 0
	if _cached_profile.has("streak"):
		return _safe_int(_cached_profile.get("streak", 0))
	var gp = _cached_profile.get("gameProfile", {})
	if gp and not gp.is_empty():
		return _safe_int(gp.get("streak", 0))
	return 0

func get_play_count() -> int:
	if _cached_profile.is_empty():
		return 0
	if _cached_profile.has("playCount"):
		return _safe_int(_cached_profile.get("playCount", 0))
	var gp = _cached_profile.get("gameProfile", {})
	if gp and not gp.is_empty():
		return _safe_int(gp.get("playCount", 0))
	return 0

func get_cached_profile() -> Dictionary:
	return _cached_profile

func get_auth_type() -> String:
	return _auth_type

# ============================================================
# PUBLIC API - CONFIGURATION
# ============================================================

func set_api_key(key: String) -> void:
	api_key = key
	_log("API key set")

func set_game_id(id: String) -> void:
	game_id = id
	_log("Game ID set: %s" % id)

func set_session_token(token: String) -> void:
	_session_token = token
	_log("Session token set")

func set_player_id(player_id: String) -> void:
	_player_id = _sanitize_player_id(player_id)
	_log("Player ID set: %s" % _player_id)

func get_player_id() -> String:
	if not _player_id.is_empty():
		return _player_id
	
	# Try loading saved device ID from disk
	var saved_id = _load_device_id()
	if saved_id != "":
		_player_id = saved_id
		_log("Loaded persistent device ID: %s" % _player_id.left(12))
		return _player_id
	
	# Generate new persistent device ID (first launch only)
	randomize()
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "")
	var random_part = "%08x" % (randi() & 0x7FFFFFFF)
	_player_id = "dev_" + timestamp + "_" + random_part
	_save_device_id(_player_id)
	_log("Generated new persistent device ID: %s" % _player_id)
	return _player_id

func _save_device_id(device_id: String) -> void:
	var config = ConfigFile.new()
	config.set_value("device", "id", device_id)
	config.set_value("device", "created", Time.get_unix_time_from_system())
	var err = config.save(DEVICE_ID_PATH)
	if err == OK:
		_log("Device ID saved to %s" % DEVICE_ID_PATH)
	else:
		_log("WARNING: Failed to save device ID (error %d)" % err)

func _load_device_id() -> String:
	var config = ConfigFile.new()
	var err = config.load(DEVICE_ID_PATH)
	if err == OK:
		return config.get_value("device", "id", "")
	return ""

func _sanitize_player_id(raw_id: String) -> String:
	if raw_id.is_empty():
		return get_player_id()
	
	var sanitized = ""
	for c in raw_id:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			sanitized += c
	
	if sanitized.is_empty():
		randomize()
		return "p_" + str(abs(raw_id.hash()))
	
	if sanitized[0] >= "0" and sanitized[0] <= "9":
		sanitized = "p_" + sanitized
	
	if sanitized.length() > 100:
		sanitized = sanitized.left(100)
	
	return sanitized

# ============================================================
# PUBLIC API - AUTHENTICATION
# ============================================================

## Anonymous login - uses API key + persistent device ID
func login_anonymous(nickname: String = "") -> void:
	if api_key.is_empty():
		login_failed.emit("API key not set. Call set_api_key() first.")
		return
	
	_nickname = nickname if nickname != "" else _get_default_nickname()
	_auth_type = "anonymous"
	login_success.emit(_nickname)
	_log("Anonymous login: %s (player: %s)" % [_nickname, get_player_id()])

## Social login (Google, Apple, etc.) via Device Code Auth
## Use login_with_device_code() instead - works on all platforms
func login_google() -> void:
	_log("Google login → use login_with_device_code() for cross-platform social login")
	login_with_device_code()

## Social login (Google, Apple, etc.) via Device Code Auth
## Use login_with_device_code() instead - works on all platforms
func login_apple() -> void:
	_log("Apple login → use login_with_device_code() for cross-platform social login")
	login_with_device_code()

## Internet Identity login via Device Code Auth
## Use login_with_device_code() instead - works on all platforms
func login_internet_identity(nickname: String = "") -> void:
	_log("II login → use login_with_device_code() for cross-platform social login")
	login_with_device_code()

## Alias for login_internet_identity
func login_chedda_id(nickname: String = "") -> void:
	login_internet_identity(nickname)

func logout() -> void:
	_cached_profile = {}
	_auth_type = ""
	_nickname = ""
	_session_token = ""
	_play_session_token = ""
	logout_success.emit()
	_log("Logged out")

func is_authenticated() -> bool:
	if _auth_type == "anonymous":
		return true
	return not _session_token.is_empty()

func is_anonymous() -> bool:
	return _auth_type == "anonymous" or _session_token.is_empty()

func has_account() -> bool:
	return is_authenticated() and not is_anonymous()

func refresh_profile() -> void:
	if _is_refreshing_profile:
		return
	
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_profile_refresh < PROFILE_REFRESH_COOLDOWN:
		return
	
	_is_refreshing_profile = true
	_last_profile_refresh = current_time
	get_player_profile()
	_log("Profile refresh requested")

func change_nickname(new_nickname: String) -> void:
	if new_nickname.is_empty() or new_nickname.length() < 2:
		nickname_error.emit("Nickname must be at least 2 characters")
		return
	
	# Anonymous players who haven't submitted a score yet don't exist on backend
	if is_anonymous() and _cached_profile.is_empty():
		_nickname = new_nickname
		_log("Nickname set locally (no backend profile yet): %s" % new_nickname)
		nickname_changed.emit(new_nickname)
		return
	
	if not _session_token.is_empty():
		# Authenticated users - session token path
		var body = {"nickname": new_nickname}
		_make_http_request("/profile/nickname", HTTPClient.METHOD_PUT, body, "change_nickname")
		_log("Nickname change requested (session) -> %s" % new_nickname)
	elif not api_key.is_empty():
		# Anonymous/API-key users
		var pid = get_player_id()
		if pid.is_empty():
			nickname_error.emit("No player ID set")
			return
		var body = {"nickname": new_nickname}
		var url = "/players/%s/nickname" % pid.uri_encode()
		_make_http_request(url, HTTPClient.METHOD_PUT, body, "change_nickname_anonymous")
		_log("Nickname change requested (API) for: %s -> %s" % [pid, new_nickname])
	else:
		nickname_error.emit("Not authenticated")

# ============================================================
# PUBLIC API - DEVICE CODE AUTH (Cross-platform social login)
# ============================================================
# Works on ANY platform. No browser popup, no Google/Apple SDK needed.
#
# Usage:
#   CheddaBoards.device_code_received.connect(_on_device_code)
#   CheddaBoards.device_code_approved.connect(_on_device_approved)
#   CheddaBoards.device_code_expired.connect(_on_device_expired)
#   CheddaBoards.device_code_error.connect(_on_device_error)
#   CheddaBoards.login_with_device_code()
#
#   func _on_device_code(user_code: String, url: String):
#       $CodeLabel.text = "Go to %s\nEnter code: %s" % [url, user_code]
#
#   func _on_device_approved(nickname: String):
#       print("Welcome %s!" % nickname)

## Start device code login flow.
## Emits device_code_received with the code to show the player.
## Automatically polls for approval and emits device_code_approved on success.
func login_with_device_code() -> void:
	if not _init_complete:
		device_code_error.emit("CheddaBoards not ready")
		return
	
	if game_id.is_empty():
		device_code_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	_stop_device_code_polling()
	
	_log("Requesting device code for game: %s" % game_id)
	var body = {"gameId": game_id}
	_make_http_request("/auth/device/code", HTTPClient.METHOD_POST, body, "device_code_request")

## Cancel an in-progress device code login.
func cancel_device_code() -> void:
	_stop_device_code_polling()
	_device_code = ""
	_device_user_code = ""
	_log("Device code login cancelled")

## Get the current user code (for display purposes).
func get_device_user_code() -> String:
	return _device_user_code

## Check if a device code login is in progress.
func is_device_code_pending() -> bool:
	return _is_polling_device_code and _device_code != ""

# ============================================================
# DEVICE CODE POLLING (Internal)
# ============================================================

func _start_device_code_polling() -> void:
	_stop_device_code_polling()
	_is_polling_device_code = true
	_device_code_poll_in_flight = false
	_device_code_approved = false
	
	_device_code_poll_timer = Timer.new()
	_device_code_poll_timer.wait_time = _device_code_poll_interval
	_device_code_poll_timer.autostart = true
	_device_code_poll_timer.timeout.connect(_poll_device_code_token)
	add_child(_device_code_poll_timer)
	_log("Device code polling started (every %ds)" % int(_device_code_poll_interval))

func _stop_device_code_polling() -> void:
	_is_polling_device_code = false
	_device_code_poll_in_flight = false
	if _device_code_poll_timer:
		_device_code_poll_timer.stop()
		_device_code_poll_timer.queue_free()
		_device_code_poll_timer = null

func _poll_device_code_token() -> void:
	if not _is_polling_device_code or _device_code.is_empty():
		_stop_device_code_polling()
		return
	
	if _device_code_poll_in_flight:
		return
	
	# Check expiry
	if Time.get_unix_time_from_system() >= _device_code_expires_at:
		_log("Device code expired: %s" % _device_user_code)
		_stop_device_code_polling()
		_device_code = ""
		_device_user_code = ""
		device_code_expired.emit()
		return
	
	_device_code_poll_in_flight = true
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if not game_id.is_empty():
		headers.append("X-Game-ID: " + game_id)
	
	var body = JSON.stringify({"device_code": _device_code})
	var url = API_BASE_URL + "/auth/device/token"
	
	http.request_completed.connect(func(result, code, _headers, response_body):
		_device_code_poll_in_flight = false
		_handle_device_code_poll_response(result, code, response_body)
		http.queue_free()
	)
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_log("Device code poll request failed to start")
		_device_code_poll_in_flight = false
		http.queue_free()

func _handle_device_code_poll_response(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_log("Device code poll: network error")
		return
	
	if _device_code_approved:
		_log("Device code poll: ignoring response (already approved)")
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_log("Device code poll: invalid JSON")
		return
	
	var response = json.data
	
	# 428 = authorization_pending (keep polling)
	if response_code == 428:
		return
	
	# 410 = expired
	if response_code == 410:
		_log("Device code expired (server confirmed)")
		_stop_device_code_polling()
		_device_code = ""
		_device_user_code = ""
		device_code_expired.emit()
		return
	
	# 200 = approved!
	if response_code == 200 and response.get("ok", false):
		_device_code_approved = true
		_stop_device_code_polling()
		
		var data = response.get("data", {})
		var session_id = str(data.get("sessionId", ""))
		var nickname = str(data.get("nickname", "Player"))
		var email = str(data.get("email", ""))
		
		_log("Device code approved! User: %s (%s)" % [nickname, email])
		
		# Save anonymous player ID BEFORE switching auth — needed for migration
		var previous_anonymous_id = _player_id
		var was_anonymous = _auth_type == "anonymous" and not previous_anonymous_id.is_empty()
		
		# Set session state
		_session_token = session_id
		_nickname = nickname
		_auth_type = "google"  # Provider determined by what they chose on the page
		
		# Clear stale anonymous play session
		if _play_session_token != "":
			_log("Clearing stale anonymous play session after device code auth")
			_play_session_token = ""
		
		# Cache profile data
		var game_profile = data.get("gameProfile", null)
		if game_profile and game_profile is Dictionary:
			_update_cached_profile({
				"nickname": nickname,
				"gameProfile": game_profile,
			})
		else:
			_cached_profile = {"nickname": nickname}
			profile_loaded.emit(nickname, 0, 0, [])
		
		# Clear device code state
		_device_code = ""
		_device_user_code = ""
		
		# Emit both signals so existing login flows work
		device_code_approved.emit(nickname)
		login_success.emit(nickname)
		
		# Auto-migrate anonymous data → new account
		if was_anonymous:
			_migrate_anonymous_account(previous_anonymous_id)
		
		return
	
	# 404 = invalid code (or already consumed)
	if response_code == 404:
		if _device_code_approved or _device_code.is_empty():
			_log("Device code poll: 404 after approval (ignoring)")
			return
		_log("Device code invalid or expired")
		_stop_device_code_polling()
		_device_code = ""
		_device_user_code = ""
		device_code_error.emit("Invalid or expired code")
		return
	
	# Other errors - log but keep polling
	var error_msg = str(response.get("error", "Unknown error"))
	_log("Device code poll error (%d): %s" % [response_code, error_msg])

# ============================================================
# ACCOUNT MIGRATION (Anonymous → Verified)
# ============================================================

func _migrate_anonymous_account(anonymous_device_id: String) -> void:
	if anonymous_device_id.is_empty() or _session_token.is_empty():
		_log("Migration skipped: missing device ID or session token")
		return
	
	_log("Migrating anonymous data: %s → authenticated account" % anonymous_device_id)
	var body = {"deviceId": anonymous_device_id}
	_make_http_request("/migrate-account", HTTPClient.METHOD_POST, body, "migrate_account")

## Public method: manually trigger migration if needed
func migrate_anonymous_to_current(anonymous_device_id: String) -> void:
	_migrate_anonymous_account(anonymous_device_id)

# ============================================================
# PUBLIC API - SCORES
# ============================================================

func submit_score(score: int, streak: int = 0) -> void:
	if not is_authenticated():
		_log("Not authenticated, cannot submit")
		score_error.emit("Not authenticated")
		return
	
	if _is_submitting_score:
		_log("Score submission already in progress")
		return
	
	_is_submitting_score = true
	_pending_score = score
	_pending_streak = streak
	
	var body = {
		"playerId": get_player_id(),
		"gameId": game_id,
		"score": score,
		"streak": streak,
		"nickname": _nickname if _nickname != "" else _get_default_nickname()
	}
	if _play_session_token != "":
		body["playSessionToken"] = _play_session_token
	_log("Submitting: score=%d, streak=%d, nickname=%s, gameId=%s, playerId=%s, session=%s" % [score, streak, body.nickname, game_id, body.playerId, _play_session_token.left(20)])
	_make_http_request("/scores", HTTPClient.METHOD_POST, body, "submit_score")

func submit_score_with_achievements(score: int, streak: int, achievements: Array) -> void:
	if not is_authenticated():
		_log("Not authenticated, cannot submit")
		score_error.emit("Not authenticated")
		return
	if _is_submitting_score:
		_log("Score submission already in progress")
		return
	_is_submitting_score = true
	_pending_score = score
	_pending_streak = streak
	
	var ach_ids: Array = []
	for ach in achievements:
		if typeof(ach) == TYPE_STRING:
			ach_ids.append(ach)
		elif typeof(ach) == TYPE_DICTIONARY:
			var ach_id = str(ach.get("id", ""))
			if ach_id != "":
				ach_ids.append(ach_id)
	
	_log("Submitting score with %d achievements (HTTP API)" % ach_ids.size())
	
	# Store achievement IDs - queued AFTER score succeeds
	_deferred_achievement_ids = ach_ids.duplicate()
	_deferred_achievements_remaining = 0
	_deferred_achievements_synced = []
	
	# Submit score FIRST (creates/updates player profile on backend)
	var score_body = {
		"playerId": get_player_id(),
		"gameId": game_id,
		"score": score,
		"streak": streak,
		"nickname": _nickname if _nickname != "" else _get_default_nickname()
	}
	if _play_session_token != "":
		score_body["playSessionToken"] = _play_session_token
	_log("Submitting: score=%d, streak=%d, nickname=%s, gameId=%s, playerId=%s, session=%s" % [score, streak, score_body.nickname, game_id, score_body.playerId, _play_session_token.left(20)])
	_make_http_request("/scores", HTTPClient.METHOD_POST, score_body, "submit_score")

# ============================================================
# PUBLIC API - PLAY SESSIONS (Time Validation)
# ============================================================

func start_play_session() -> void:
	_play_session_token = ""
	
	var body = {
		"gameId": game_id,
		"playerId": get_player_id()
	}
	_make_http_request("/play-sessions/start", HTTPClient.METHOD_POST, body, "start_play_session")
	_log("Play session requested for game: %s, player: %s" % [game_id, get_player_id()])

func get_play_session_token() -> String:
	return _play_session_token

func has_play_session() -> bool:
	return _play_session_token != ""

func end_play_session() -> void:
	if _play_session_token == "" or _play_session_token.begins_with("fallback_"):
		_log("No active server session to end")
		_play_session_token = ""
		return
	
	_log("Ending play session on server: %s" % _play_session_token.left(30))
	var body = {"playSessionToken": _play_session_token}
	_make_http_request("/play-sessions/end", HTTPClient.METHOD_POST, body, "end_play_session")
	_play_session_token = ""

func clear_play_session() -> void:
	if _play_session_token != "" and not _play_session_token.begins_with("fallback_"):
		end_play_session()
	else:
		_play_session_token = ""
		_log("Play session cleared (local only)")

# ============================================================
# PUBLIC API - LEADERBOARDS
# ============================================================

func get_leaderboard(sort_by: String = "score", limit: int = 1000) -> void:
	var url = "/leaderboard?sort=%s&limit=%d" % [sort_by, limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "leaderboard")
	_log("Leaderboard requested (sort: %s, limit: %d)" % [sort_by, limit])

func get_player_rank(sort_by: String = "score") -> void:
	var url = "/players/%s/rank?sort=%s" % [get_player_id().uri_encode(), sort_by]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "player_rank")
	_log("Player rank requested (sort: %s)" % sort_by)

func get_player_profile(player_id: String = "") -> void:
	if not _session_token.is_empty():
		# Authenticated users - use session profile endpoint
		_make_http_request("/auth/profile", HTTPClient.METHOD_GET, {}, "player_profile")
		_log("Player profile requested (session)")
	else:
		# Anonymous/API-key users
		var pid = player_id if player_id != "" else get_player_id()
		if pid.is_empty():
			_log("No player ID for profile fetch")
			no_profile.emit()
			return
		var url = "/players/%s/profile" % pid.uri_encode()
		_make_http_request(url, HTTPClient.METHOD_GET, {}, "player_profile")
		_log("Player profile requested for: %s" % pid)

# ============================================================
# PUBLIC API - SCOREBOARDS (Time-based Leaderboards)
# ============================================================

func get_scoreboards(for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		scoreboard_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/scoreboards" % gid.uri_encode()
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "list_scoreboards")
	_log("Scoreboards list requested for game: %s" % gid)

func get_scoreboard(scoreboard_id: String, limit: int = 100, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		scoreboard_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/scoreboards/%s?limit=%d" % [gid.uri_encode(), scoreboard_id.uri_encode(), limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "get_scoreboard", {"scoreboard_id": scoreboard_id})
	_log("Scoreboard '%s' requested (limit: %d)" % [scoreboard_id, limit])

func get_scoreboard_rank(scoreboard_id: String, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		scoreboard_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	if _session_token.is_empty():
		scoreboard_error.emit("Session token required for rank lookup")
		return
	
	var url = "/games/%s/scoreboards/%s/rank" % [gid.uri_encode(), scoreboard_id.uri_encode()]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "scoreboard_rank", {"scoreboard_id": scoreboard_id})
	_log("Scoreboard rank requested for '%s'" % scoreboard_id)

func get_weekly_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("weekly-scoreboard", limit, for_game_id)

func get_daily_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("daily", limit, for_game_id)

func get_alltime_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("all-time-new", limit, for_game_id)

func get_monthly_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("monthly", limit, for_game_id)

# ============================================================
# PUBLIC API - SCOREBOARD ARCHIVES
# ============================================================

func get_scoreboard_archives(scoreboard_id: String, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		archive_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/scoreboards/%s/archives" % [gid.uri_encode(), scoreboard_id.uri_encode()]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "list_archives", {"scoreboard_id": scoreboard_id})
	_log("Archives list requested for '%s'" % scoreboard_id)

func get_last_archived_scoreboard(scoreboard_id: String, limit: int = 100, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		archive_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/scoreboards/%s/archives/latest?limit=%d" % [gid.uri_encode(), scoreboard_id.uri_encode(), limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "get_last_archive", {"scoreboard_id": scoreboard_id})
	_log("Last archive requested for '%s'" % scoreboard_id)

func get_archived_scoreboard(archive_id: String, limit: int = 100) -> void:
	var url = "/archives/%s?limit=%d" % [archive_id.uri_encode(), limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "get_archive", {"archive_id": archive_id})
	_log("Archive '%s' requested" % archive_id)

func get_archives_in_range(scoreboard_id: String, after_timestamp: int, before_timestamp: int, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		archive_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/scoreboards/%s/archives?after=%d&before=%d" % [
		gid.uri_encode(), 
		scoreboard_id.uri_encode(), 
		after_timestamp, 
		before_timestamp
	]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "list_archives", {"scoreboard_id": scoreboard_id})
	_log("Archives in range requested for '%s'" % scoreboard_id)

func get_archive_stats(for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		archive_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/archives/stats" % gid.uri_encode()
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "archive_stats")
	_log("Archive stats requested for game: %s" % gid)

func get_last_week_scoreboard(limit: int = 100, for_game_id: String = "") -> void:
	get_last_archived_scoreboard("weekly", limit, for_game_id)

func get_last_month_scoreboard(limit: int = 100, for_game_id: String = "") -> void:
	get_last_archived_scoreboard("monthly", limit, for_game_id)

func get_yesterday_scoreboard(limit: int = 100, for_game_id: String = "") -> void:
	get_last_archived_scoreboard("daily", limit, for_game_id)

# ============================================================
# PUBLIC API - ACHIEVEMENTS
# ============================================================

func unlock_achievement(achievement_id: String, _achievement_name: String = "", _achievement_desc: String = "") -> void:
	var body = {
		"playerId": get_player_id(),
		"achievementId": achievement_id
	}
	_make_http_request_async("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement")
	_log("Achievement unlock (async): %s" % achievement_id)

func unlock_achievements_batch(achievement_ids: Array) -> void:
	"""Unlock multiple achievements in a single request."""
	if achievement_ids.is_empty():
		return
	
	_log("Batch unlocking %d achievements..." % achievement_ids.size())
	_deferred_achievements_remaining = 1
	_deferred_achievements_synced = []
	
	var body = {
		"playerId": get_player_id(),
		"achievementIds": achievement_ids
	}
	_make_http_request_async("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement_batch")

func get_achievements(player_id: String = "") -> void:
	var pid = player_id if player_id != "" else get_player_id()
	var url = "/players/%s/achievements" % pid.uri_encode()
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "achievements")
	_log("Achievements requested for: %s" % pid)

func _flush_deferred_achievements() -> void:
	"""Send all deferred achievements in a single batch request."""
	if _deferred_achievement_ids.is_empty():
		return
	var count = _deferred_achievement_ids.size()
	_deferred_achievements_remaining = 1
	_deferred_achievements_synced = []
	_log("Batch syncing %d achievements..." % count)
	
	var body = {
		"playerId": get_player_id(),
		"achievementIds": _deferred_achievement_ids.duplicate()
	}
	_make_http_request_async("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement_batch")
	_deferred_achievement_ids.clear()

# ============================================================
# PUBLIC API - ANALYTICS
# ============================================================

func track_event(event_type: String, metadata: Dictionary = {}) -> void:
	# TODO: POST to analytics endpoint when available
	_log("Event tracked (local): %s %s" % [event_type, str(metadata)])

# ============================================================
# PUBLIC API - GAME INFO
# ============================================================

func get_game_info() -> void:
	_make_http_request("/game", HTTPClient.METHOD_GET, {}, "game_info")

func get_game_stats() -> void:
	_make_http_request("/game/stats", HTTPClient.METHOD_GET, {}, "game_stats")

func health_check() -> void:
	_make_http_request("/health", HTTPClient.METHOD_GET, {}, "health")

# ============================================================
# DEBUG
# ============================================================

func debug_status() -> void:
	print("")
	print("╔══════════════════════════════════════════════╗")
	print("║        CheddaBoards Debug Status v2.0.0      ║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Configuration                                ║")
	print("║  - Platform:         %s" % OS.get_name().rpad(24) + "║")
	print("║  - Init Complete:    %s" % str(_init_complete).rpad(24) + "║")
	print("║  - Game ID:          %s" % game_id.left(20).rpad(24) + "║")
	print("║  - API Key Set:      %s" % str(not api_key.is_empty()).rpad(24) + "║")
	print("║  - Session Token:    %s" % str(not _session_token.is_empty()).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Authentication                               ║")
	print("║  - Authenticated:    %s" % str(is_authenticated()).rpad(24) + "║")
	print("║  - Auth Type:        %s" % _auth_type.rpad(24) + "║")
	print("║  - Player ID:        %s" % get_player_id().left(20).rpad(24) + "║")
	print("║  - Anonymous:        %s" % str(is_anonymous()).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Profile                                      ║")
	print("║  - Nickname:         %s" % get_nickname().rpad(24) + "║")
	print("║  - High Score:       %s" % str(get_high_score()).rpad(24) + "║")
	print("║  - Best Streak:      %s" % str(get_best_streak()).rpad(24) + "║")
	print("║  - Play Count:       %s" % str(get_play_count()).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ State                                        ║")
	print("║  - Refreshing:       %s" % str(_is_refreshing_profile).rpad(24) + "║")
	print("║  - Submitting:       %s" % str(_is_submitting_score).rpad(24) + "║")
	print("║  - HTTP Busy:        %s" % str(_http_busy).rpad(24) + "║")
	print("║  - Queue Size:       %s" % str(_request_queue.size()).rpad(24) + "║")
	print("║  - Play Session:     %s" % str(has_play_session()).rpad(24) + "║")
	print("║  - Device Code:      %s" % (_device_user_code if _device_user_code != "" else "none").rpad(24) + "║")
	print("║  - DC Polling:       %s" % str(_is_polling_device_code).rpad(24) + "║")
	print("╚══════════════════════════════════════════════╝")
	print("")

# ============================================================
# CLEANUP
# ============================================================

func _exit_tree() -> void:
	_stop_device_code_polling()
