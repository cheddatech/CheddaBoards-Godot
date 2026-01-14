# CheddaBoards.gd v1.5.4
# CheddaBoards integration for Godot 4.x
# https://github.com/cheddatech/CheddaBoards-Godot
# https://cheddaboards.com
#
# HYBRID SDK: Supports both Web (JavaScript Bridge) and Native (HTTP API)
# - OAuth login (Google, Apple, II) uses JavaScript bridge on web
# - ALL score submissions use HTTP API (simpler, works with play sessions)
# - Play sessions use HTTP API for ALL users
# - Native exports (Windows/Mac/Linux/Mobile) use HTTP API
#
# v1.5.4: ALL score submissions now use HTTP API (fixes play session validation)
# v1.5.3: ALL users now use HTTP API for play sessions (fixes web auth issues)
# v1.5.2: Play sessions for anonymous users now use HTTP API on web
# v1.5.1: Anonymous login now uses HTTP API on web builds (bypasses JS bridge)
# v1.5.0: Added play session support for time validation anti-cheat
#
# Add to Project Settings > Autoload as "CheddaBoards"

extends Node

# ============================================================
# QUICK START
# ============================================================
# 1. Add this script to Project Settings > Autoload as "CheddaBoards"
# 2. For WEB: Configure your HTML template with your Game ID
# 3. For NATIVE: Set your API key: CheddaBoards.set_api_key("cb_xxx")
#
# Example:
#    func _ready():
#        await CheddaBoards.wait_until_ready()
#        CheddaBoards.login_success.connect(_on_login_success)
#        CheddaBoards.score_submitted.connect(_on_score_submitted)
#
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
signal login_timeout()
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

# --- Scoreboards (NEW - Time-based) ---
signal scoreboards_loaded(scoreboards: Array)
signal scoreboard_loaded(scoreboard_id: String, config: Dictionary, entries: Array)
signal scoreboard_rank_loaded(scoreboard_id: String, rank: int, score: int, streak: int, total: int)
signal scoreboard_error(reason: String)

# --- Scoreboard Archives (NEW v1.4.0) ---
signal archives_list_loaded(scoreboard_id: String, archives: Array)
signal archived_scoreboard_loaded(archive_id: String, config: Dictionary, entries: Array)
signal archive_stats_loaded(total_archives: int, by_scoreboard: Array)
signal archive_error(reason: String)

# --- Achievements ---
signal achievement_unlocked(achievement_id: String)
signal achievements_loaded(achievements: Array)

# --- HTTP API Specific ---
signal request_failed(endpoint: String, error: String)

# --- Play Sessions (Time Validation) ---
signal play_session_started(token: String)
signal play_session_error(reason: String)

# ============================================================
# CONFIGURATION
# ============================================================

## Set to true to enable verbose logging
var debug_logging: bool = true

## HTTP API Configuration (for native builds)
const API_BASE_URL = "https://api.cheddaboards.com"
var api_key: String = "cb_test-game_350355445"  ## Your API key
var game_id: String = "test-game"  ## Your game ID for scoreboard operations
var _player_id: String = ""
var _session_token: String = ""  ## For OAuth session-based auth
var _play_session_token: String = ""  ## For time validation

# ============================================================
# PLATFORM DETECTION
# ============================================================

var _is_web: bool = false
var _is_native: bool = false
var _init_complete: bool = false
var _init_attempts: int = 0

# ============================================================
# INTERNAL STATE (Shared)
# ============================================================

var _auth_type: String = ""
var _cached_profile: Dictionary = {}
var _nickname: String = ""

# ============================================================
# PERFORMANCE OPTIMIZATION
# ============================================================

var _is_checking_auth: bool = false
var _is_refreshing_profile: bool = false
var _is_submitting_score: bool = false
var _last_response_check: float = 0.0
var _last_profile_refresh: float = 0.0

# ============================================================
# PENDING SCORE SUBMISSION VALUES
# ============================================================

var _pending_score: int = 0
var _pending_streak: int = 0

# ============================================================
# TIMEOUT MANAGEMENT
# ============================================================

var _login_timeout_timer: Timer = null
const LOGIN_TIMEOUT_DURATION: float = 35.0
const MAX_INIT_ATTEMPTS: int = 50

# ============================================================
# POLLING CONFIGURATION (Web only)
# ============================================================

var _poll_timer: Timer = null
const POLL_INTERVAL: float = 0.1
const MIN_RESPONSE_CHECK_INTERVAL: float = 0.3
const PROFILE_REFRESH_COOLDOWN: float = 2.0

# ============================================================
# HTTP REQUEST (Native only)
# ============================================================

var _http_request: HTTPRequest
var _current_endpoint: String = ""
var _current_meta: Dictionary = {}  # Extra metadata for response handling
var _http_busy: bool = false
var _request_queue: Array = []

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_is_web = OS.get_name() == "Web"
	_is_native = not _is_web
	
	_setup_http_client()
	
	if _is_web:
		_log("Initializing CheddaBoards v1.5.4 (Web Mode)...")
		_start_polling()
		_check_chedda_ready()
	else:
		_log("Initializing CheddaBoards v1.5.4 (Native/HTTP API Mode)...")
		_init_complete = true
		call_deferred("_emit_sdk_ready")

func _emit_sdk_ready() -> void:
	sdk_ready.emit()

func _setup_http_client() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_http_request_completed)

# ============================================================
# SDK READY CHECK (Web Only)
# ============================================================

func _check_chedda_ready() -> void:
	if not _is_web or _is_checking_auth:
		return

	_is_checking_auth = true
	_init_attempts += 1

	if _init_attempts > MAX_INIT_ATTEMPTS:
		_is_checking_auth = false
		push_error("[CheddaBoards] SDK failed to load after %d attempts" % MAX_INIT_ATTEMPTS)
		init_error.emit("CheddaBoards SDK failed to load. Check your HTML template configuration.")
		return

	var js_check: String = """
		(function() {
			if (window.CheddaBoards && window.chedda) {
				return true;
			}
			return false;
		})();
	"""

	var ready: Variant = JavaScriptBridge.eval(js_check, true)

	if ready:
		_log("SDK confirmed ready")
		_init_complete = true
		_is_checking_auth = false
		sdk_ready.emit()
		force_check_events()
	else:
		_is_checking_auth = false
		if _init_attempts % 10 == 0:
			_log("SDK not ready, attempt %d/%d..." % [_init_attempts, MAX_INIT_ATTEMPTS])
		await get_tree().create_timer(0.1).timeout
		_check_chedda_ready()

# ============================================================
# POLLING SYSTEM (Web Only)
# ============================================================

func _start_polling() -> void:
	if _poll_timer:
		return

	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_check_for_responses)
	add_child(_poll_timer)
	_log("Started polling timer (interval: %ss)" % POLL_INTERVAL)

func _check_for_responses() -> void:
	if not _is_web or not _init_complete:
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_response_check < MIN_RESPONSE_CHECK_INTERVAL:
		return

	_last_response_check = current_time

	var resp: Variant = JavaScriptBridge.eval("chedda_get_response()", true)
	if resp == null:
		return
	
	var response_str: String = str(resp)
	if response_str == "" or response_str.to_lower() == "null":
		return

	var json := JSON.new()
	var parse_result: int = json.parse(response_str)
	if parse_result == OK:
		var response: Dictionary = json.data
		_handle_web_response(response)

# ============================================================
# WEB RESPONSE HANDLER
# ============================================================

func _handle_web_response(response: Dictionary) -> void:
	var action: String = str(response.get("action", ""))
	var success: bool = bool(response.get("success", false))

	_log("Received response: %s (success: %s)" % [action, success])

	match action:
		"init":
			if success:
				var authenticated: bool = bool(response.get("authenticated", false))
				if authenticated:
					_auth_type = str(response.get("authType", ""))
					var profile: Dictionary = response.get("profile", {})
					if profile and not profile.is_empty():
						_update_cached_profile(profile)
				else:
					no_profile.emit()

		"loginGoogle", "loginApple", "loginCheddaId", "loginInternetIdentity", "loginAnonymous":
			_clear_login_timeout()
			if success:
				_auth_type = str(response.get("authType", ""))
				var profile: Dictionary = response.get("profile", {})
				if profile and not profile.is_empty():
					_update_cached_profile(profile)
					var nickname: String = str(profile.get("nickname", _get_default_nickname()))
					login_success.emit(nickname)
				else:
					login_success.emit(_get_default_nickname())
			else:
				var error: String = str(response.get("error", "Unknown error"))
				login_failed.emit(error)

		"submitScore":
			_is_submitting_score = false
			_log("submitScore response received - success: %s" % success)
			if success:
				# Use pending values we stored before the request
				_log("Score submitted successfully: %d points, %d streak" % [_pending_score, _pending_streak])
				score_submitted.emit(_pending_score, _pending_streak)
				if response.has("profile"):
					var p: Dictionary = response.get("profile")
					_update_cached_profile(p)
			else:
				var error: String = str(response.get("error", "Unknown error"))
				_log("Score submission FAILED: %s" % error)
				score_error.emit(error)

		"getProfile":
			_is_refreshing_profile = false
			if success:
				var profile: Dictionary = response.get("profile", {})
				if profile and not profile.is_empty():
					_update_cached_profile(profile)
				else:
					no_profile.emit()
			else:
				no_profile.emit()

		"getLeaderboard":
			if success:
				var leaderboard: Array = response.get("leaderboard", response.get("entries", []))
				leaderboard_loaded.emit(leaderboard)

		"getPlayerRank":
			if success:
				var rank: int = int(response.get("rank", 0))
				var score_val: int = int(response.get("score", 0))
				var streak_val: int = int(response.get("streak", 0))
				var total: int = int(response.get("totalPlayers", 0))
				player_rank_loaded.emit(rank, score_val, streak_val, total)
			else:
				var error: String = str(response.get("error", "Unknown error"))
				rank_error.emit(error)

		"logout":
			if success:
				_cached_profile = {}
				_auth_type = ""
				logout_success.emit()

		"changeNickname":
			if success:
				var new_nickname: String = str(response.get("nickname", ""))
				if not _cached_profile.is_empty():
					_cached_profile["nickname"] = new_nickname
				nickname_changed.emit(new_nickname)
			elif bool(response.get("cancelled", false)):
				pass
			else:
				var error: String = str(response.get("error", "Unknown error"))
				nickname_error.emit(error)

# ============================================================
# HTTP RESPONSE HANDLER (Native Only)
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
			# Use the pending values we stored before the request
			_log("Score submission successful: %d points, %d streak" % [_pending_score, _pending_streak])
			score_submitted.emit(_pending_score, _pending_streak)
		
		"leaderboard":
			var entries = data.get("leaderboard", [])
			leaderboard_loaded.emit(entries)
		
		"player_rank":
			var rank = int(data.get("rank", 0))
			var score_val = int(data.get("score", 0))
			var streak_val = int(data.get("streak", 0))
			var total = int(data.get("totalPlayers", 0))
			player_rank_loaded.emit(rank, score_val, streak_val, total)
		
		"player_profile":
			if data and not data.is_empty():
				_update_cached_profile(data)
			else:
				no_profile.emit()
		
		"change_nickname":
			var new_nick = str(data.get("nickname", ""))
			if new_nick != "":
				_nickname = new_nick
				if not _cached_profile.is_empty():
					_cached_profile["nickname"] = new_nick
				nickname_changed.emit(new_nick)
				_log("Nickname changed to: %s" % new_nick)
		
		"unlock_achievement":
			var ach_id = str(data.get("achievementId", ""))
			achievement_unlocked.emit(ach_id)
		
		"achievements":
			var achievements = data.get("achievements", [])
			achievements_loaded.emit(achievements)
		
		# --- SCOREBOARD RESPONSES ---
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
				var rank = int(data.get("rank", 0))
				var score_val = int(data.get("score", 0))
				var streak_val = int(data.get("streak", 0))
				var total = int(data.get("totalPlayers", 0))
				scoreboard_rank_loaded.emit(sb_id, rank, score_val, streak_val, total)
			else:
				scoreboard_rank_loaded.emit(sb_id, 0, 0, 0, int(data.get("totalPlayers", 0)))
		
		# --- ARCHIVE RESPONSES (NEW v1.4.0) ---
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
			var total = int(data.get("totalArchives", 0))
			var by_sb = data.get("byScoreboard", [])
			archive_stats_loaded.emit(total, by_sb)
			_log("Archive stats: %d total archives" % total)
		
		"game_info", "game_stats", "health":
			_log("API response: %s" % str(data))
		
		"start_play_session":
			if data.has("ok"):
				_play_session_token = str(data.get("ok", ""))
				_log("Play session started (HTTP): %s" % _play_session_token.left(30))
				play_session_started.emit(_play_session_token)
			elif data.has("token"):
				_play_session_token = str(data.get("token", ""))
				_log("Play session started (HTTP): %s" % _play_session_token.left(30))
				play_session_started.emit(_play_session_token)
			else:
				var err = str(data.get("err", data.get("error", "Unknown error")))
				_log("Play session error (HTTP): %s" % err)
				play_session_error.emit(err)
	
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
			no_profile.emit()
		"change_nickname":
			nickname_error.emit(error)
		"unlock_achievement":
			pass
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
		# --- ARCHIVE FAILURES (NEW v1.4.0) ---
		"list_archives":
			var sb_id = _current_meta.get("scoreboard_id", "")
			archives_list_loaded.emit(sb_id, [])
			archive_error.emit(error)
		"get_archive", "get_last_archive":
			var archive_id = _current_meta.get("archive_id", "")
			archived_scoreboard_loaded.emit(archive_id, {}, [])
			archive_error.emit(error)
		# --- PLAY SESSION FAILURES ---
		"start_play_session":
			_log("Play session HTTP error: %s" % error)
			play_session_error.emit(error)
		"archive_stats":
			archive_stats_loaded.emit(0, [])
			archive_error.emit(error)
	
	_current_meta = {}
	_http_busy = false
	_process_next_request()

func _make_http_request(endpoint: String, method: int, body: Dictionary, request_type: String, meta: Dictionary = {}) -> void:
	if api_key.is_empty():
		_log("API key not set - skipping HTTP request to %s" % endpoint)
		match request_type:
			"submit_score":
				score_error.emit("API key not set")
			"player_profile":
				no_profile.emit()
			"leaderboard":
				leaderboard_loaded.emit([])
			"player_rank":
				rank_error.emit("API key not set")
			"list_scoreboards", "get_scoreboard":
				scoreboard_error.emit("API key not set")
			"list_archives", "get_archive", "get_last_archive", "archive_stats":
				archive_error.emit("API key not set")
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
	
	var headers = [
		"Content-Type: application/json",
		"X-API-Key: " + api_key
	]
	
	# Add session token if available (for OAuth users)
	if not _session_token.is_empty():
		headers.append("X-Session-Token: " + _session_token)
	
	# Add game ID header if set
	if not game_id.is_empty():
		headers.append("X-Game-ID: " + game_id)
	
	var url = API_BASE_URL + request_data.endpoint
	var json_body = JSON.stringify(request_data.body) if request_data.body.size() > 0 else ""
	
	_log("HTTP %s: %s" % ["POST" if request_data.method == HTTPClient.METHOD_POST else "GET", url])
	
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

	_cached_profile = profile

	var nickname: String = str(profile.get("nickname", profile.get("username", _get_default_nickname())))
	var score: int = int(profile.get("score", profile.get("highScore", 0)))
	var streak: int = int(profile.get("streak", profile.get("bestStreak", 0)))
	var achievements: Array = profile.get("achievements", [])
	
	_nickname = nickname

	profile_loaded.emit(nickname, score, streak, achievements)

# ============================================================
# TIMEOUT MANAGEMENT
# ============================================================

func _start_login_timeout() -> void:
	_clear_login_timeout()
	
	_login_timeout_timer = Timer.new()
	_login_timeout_timer.wait_time = LOGIN_TIMEOUT_DURATION
	_login_timeout_timer.one_shot = true
	_login_timeout_timer.timeout.connect(_on_login_timeout)
	add_child(_login_timeout_timer)
	_login_timeout_timer.start()
	_log("Login timeout started (%.1fs)" % LOGIN_TIMEOUT_DURATION)

func _clear_login_timeout() -> void:
	if _login_timeout_timer:
		_login_timeout_timer.stop()
		_login_timeout_timer.queue_free()
		_login_timeout_timer = null

func _on_login_timeout() -> void:
	_log("Login timeout - no response received")
	login_timeout.emit()
	_login_timeout_timer = null

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
	if _is_web:
		return _is_web and _init_complete
	else:
		return _init_complete

func can_connect() -> bool:
	if _is_web:
		return _init_complete
	else:
		return _init_complete and not api_key.is_empty()

func wait_until_ready() -> void:
	if is_ready():
		return
	await sdk_ready

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
	
	# Fallback: Generate default (only if nothing else set)
	return _get_default_nickname()

func get_high_score() -> int:
	if _cached_profile.is_empty():
		return 0
	return int(_cached_profile.get("score", 0))

func get_best_streak() -> int:
	if _cached_profile.is_empty():
		return 0
	return int(_cached_profile.get("streak", 0))

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
	# Note: Don't reset _nickname here - MainMenu sets it separately

func get_player_id() -> String:
	if not _player_id.is_empty():
		return _player_id
	
	if _is_web:
		var js_device_id = JavaScriptBridge.eval("chedda_get_device_id()", true)
		if js_device_id and str(js_device_id) != "":
			_player_id = str(js_device_id)
			return _player_id
	
	randomize()
	_player_id = "player_" + str(randi() % 1000000000)
	return _player_id

func _sanitize_player_id(raw_id: String) -> String:
	if raw_id.is_empty():
		randomize()
		return "player_" + str(randi() % 1000000000)
	
	var sanitized = ""
	for c in raw_id:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			sanitized += c
	
	if sanitized.is_empty():
		randomize()
		return "player_" + str(abs(raw_id.hash()))
	
	if sanitized[0] >= "0" and sanitized[0] <= "9":
		sanitized = "p_" + sanitized
	
	if sanitized.length() > 100:
		sanitized = sanitized.left(100)
	
	return sanitized

# ============================================================
# PUBLIC API - AUTHENTICATION
# ============================================================

func login_internet_identity(nickname: String = "") -> void:
	if _is_web:
		if not _init_complete:
			login_failed.emit("CheddaBoards not ready")
			return
		var safe_nickname: String = nickname.replace("'", "\\'").replace('"', '\\"')
		JavaScriptBridge.eval("chedda_login_ii('%s')" % safe_nickname, true)
		_log("Internet Identity login requested")
		_start_login_timeout()
	else:
		if api_key.is_empty():
			login_failed.emit("API key not set")
			return
		_nickname = nickname if nickname != "" else _get_default_nickname()
		_auth_type = "api_key"
		login_success.emit(_nickname)
		_log("Native login (API key mode)")

func login_chedda_id(nickname: String = "") -> void:
	login_internet_identity(nickname)

func login_google() -> void:
	if _is_web:
		if not _init_complete:
			login_failed.emit("CheddaBoards not ready")
			return
		JavaScriptBridge.eval("chedda_login_google()", true)
		_log("Google login requested")
		_start_login_timeout()
	else:
		login_failed.emit("Google login only available in web builds")

func login_apple() -> void:
	if _is_web:
		if not _init_complete:
			login_failed.emit("CheddaBoards not ready")
			return
		JavaScriptBridge.eval("chedda_login_apple()", true)
		_log("Apple login requested")
		_start_login_timeout()
	else:
		login_failed.emit("Apple login only available in web builds")

func login_anonymous(nickname: String = "") -> void:
	# Anonymous login uses HTTP API on ALL platforms (bypasses JS bridge on web)
	# This ensures consistent behavior between web and native builds
	
	if _is_web:
		if not _init_complete:
			login_failed.emit("CheddaBoards not ready")
			return
		# Get device ID from JS (for localStorage persistence) but don't use JS bridge for login
		var js_device_id = JavaScriptBridge.eval("chedda_get_device_id()", true)
		if js_device_id and str(js_device_id) != "":
			_player_id = str(js_device_id)
			_log("Using device ID from browser: %s" % _player_id.left(12))
	
	# Set local state (same as native) - HTTP API will be used for score submission
	_nickname = nickname if nickname != "" else _get_default_nickname()
	_auth_type = "anonymous"
	login_success.emit(_nickname)
	_log("Anonymous login (HTTP API mode)")

func logout() -> void:
	if _is_web:
		if not _init_complete:
			return
		# Clear local state first (for anonymous HTTP API mode)
		_cached_profile = {}
		_auth_type = ""
		_nickname = ""
		# Also call JS logout for OAuth users
		JavaScriptBridge.eval("chedda_logout()", true)
		_log("Logout requested")
		logout_success.emit()
	else:
		_cached_profile = {}
		_auth_type = ""
		_session_token = ""
		logout_success.emit()
		_log("Logged out (native)")

func is_authenticated() -> bool:
	# Check local auth type first (for anonymous HTTP API mode on web)
	if _auth_type == "anonymous":
		return true
	
	if _is_web:
		if not _init_complete:
			return false
		var result: Variant = JavaScriptBridge.eval("chedda_is_auth()", true)
		return bool(result)
	else:
		return not api_key.is_empty() or not _session_token.is_empty()

func is_anonymous() -> bool:
	# Check local auth type first (works for both web and native anonymous login)
	if _auth_type == "anonymous":
		return true
	
	if _is_web:
		if not _init_complete:
			return true
		# Only check JS bridge if we haven't set local auth type
		if _auth_type == "":
			var result: Variant = JavaScriptBridge.eval("chedda_is_anonymous()", true)
			return bool(result)
		# If auth type is set but not "anonymous", user has a real account
		return false
	else:
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
	
	if _is_web:
		if not _init_complete:
			_is_refreshing_profile = false
			return
		JavaScriptBridge.eval("chedda_refresh_profile()", true)
		_log("Profile refresh requested")
	else:
		get_player_profile()

func change_nickname(new_nickname: String = "") -> void:
	if _is_web:
		if not _init_complete:
			nickname_error.emit("CheddaBoards not ready")
			return
		
		if new_nickname == "":
			# No argument - show JS prompt
			var current = get_nickname().replace("'", "\\'").replace('"', '\\"')
			var js_code = """
				(function() {
					var result = prompt('Enter new nickname:', '%s');
					if (result && result.trim().length >= 2) {
						chedda_change_nickname(result.trim());
					}
				})();
			""" % current
			JavaScriptBridge.eval(js_code, true)
		else:
			# Argument provided - change directly
			var safe_nickname: String = new_nickname.replace("'", "\\'").replace('"', '\\"')
			JavaScriptBridge.eval("chedda_change_nickname('%s')" % safe_nickname, true)
		_log("Nickname change requested")
	else:
		# Native - requires nickname argument
		if new_nickname == "":
			nickname_error.emit("Nickname required - use change_nickname('name')")
			return
		
		if _session_token.is_empty():
			_nickname = new_nickname
			if not _cached_profile.is_empty():
				_cached_profile["nickname"] = new_nickname
			nickname_changed.emit(new_nickname)
			_log("Nickname changed locally: %s" % new_nickname)
		else:
			var body = {"nickname": new_nickname}
			_make_http_request("/auth/profile/nickname", HTTPClient.METHOD_POST, body, "change_nickname")
			
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
	
	# ALL users submit via HTTP API (simpler, works with play sessions)
	var body = {
		"playerId": get_player_id(),
		"gameId": game_id,
		"score": score,
		"streak": streak,
		"nickname": _nickname if _nickname != "" else _get_default_nickname()
	}
	# Include play session token if available (for time validation)
	if _play_session_token != "":
		body["playSessionToken"] = _play_session_token
	_log("Submitting: score=%d, streak=%d, nickname=%s, gameId=%s, playerId=%s, session=%s" % [score, streak, body.nickname, game_id, body.playerId, _play_session_token.left(20)])
	_make_http_request("/scores", HTTPClient.METHOD_POST, body, "submit_score")

# ============================================================
# PUBLIC API - PLAY SESSIONS (Time Validation)
# ============================================================

## Start a play session for time validation anti-cheat
## Call this when the game STARTS, before any score submission
## The server tracks how long the session lasts to validate scores
func start_play_session() -> void:
	_play_session_token = ""
	
	# ALL users use HTTP API for play sessions (simpler, works everywhere)
	# This includes web authenticated users, web anonymous, and native
	var body = {
		"gameId": game_id,
		"playerId": get_player_id()
	}
	_make_http_request("/play-sessions/start", HTTPClient.METHOD_POST, body, "start_play_session")
	_log("Play session requested (HTTP API) for game: %s, player: %s" % [game_id, get_player_id()])

func _poll_play_session_result() -> void:
	# Wait a moment for async JS to complete
	await get_tree().create_timer(0.3).timeout
	_check_play_session_result_web()

func _check_play_session_result_web() -> void:
	var result = JavaScriptBridge.eval("JSON.stringify(window._cheddaPlaySession || null)", true)
	
	if result == null or str(result) == "null":
		# Not ready yet, try again
		await get_tree().create_timer(0.2).timeout
		result = JavaScriptBridge.eval("JSON.stringify(window._cheddaPlaySession || null)", true)
	
	if result != null and str(result) != "null":
		var json := JSON.new()
		if json.parse(str(result)) == OK:
			var data: Dictionary = json.data
			if data.get("success", false):
				_play_session_token = str(data.get("token", ""))
				_log("Play session started: %s" % _play_session_token.left(30))
				play_session_started.emit(_play_session_token)
			else:
				var error = str(data.get("error", "Unknown error"))
				_log("Play session failed: %s" % error)
				play_session_error.emit(error)
		else:
			_log("Play session: Failed to parse response")
			play_session_error.emit("Failed to parse response")
		# Clear the JS variable
		JavaScriptBridge.eval("window._cheddaPlaySession = null;", true)
	else:
		# Fallback - use local token so game can continue
		_play_session_token = "fallback_%d" % Time.get_unix_time_from_system()
		_log("Play session fallback: %s" % _play_session_token)
		play_session_started.emit(_play_session_token)

## Get the current play session token
func get_play_session_token() -> String:
	return _play_session_token

## Check if a play session is active
func has_play_session() -> bool:
	return _play_session_token != ""

## Clear the play session (call after score submitted or game cancelled)
func clear_play_session() -> void:
	_play_session_token = ""
	_log("Play session cleared")

func get_leaderboard(sort_by: String = "score", limit: int = 100) -> void:
	if is_anonymous() or _is_native:
		var url = "/leaderboard?sort=%s&limit=%d" % [sort_by, limit]
		_make_http_request(url, HTTPClient.METHOD_GET, {}, "leaderboard")
		_log("Leaderboard requested (HTTP)")
		return
	
	if _is_web:
		if not _init_complete:
			return
		var js_code: String = "chedda_get_leaderboard('%s', %d)" % [sort_by, limit]
		JavaScriptBridge.eval(js_code, true)
		_log("Leaderboard requested (sort: %s, limit: %d)" % [sort_by, limit])

func get_player_rank(sort_by: String = "score") -> void:
	if is_anonymous() or _is_native:
		var url = "/players/%s/rank?sort=%s" % [get_player_id().uri_encode(), sort_by]
		_make_http_request(url, HTTPClient.METHOD_GET, {}, "player_rank")
		_log("Player rank requested (HTTP)")
		return
	
	if _is_web:
		if not _init_complete:
			return
		var js_code: String = "chedda_get_player_rank('%s')" % sort_by
		JavaScriptBridge.eval(js_code, true)
		_log("Player rank requested (sort: %s)" % sort_by)

func get_player_profile(player_id: String = "") -> void:
	if _is_web:
		refresh_profile()
	else:
		# OAuth session users - use /auth/profile
		if not _session_token.is_empty():
			_make_http_request("/auth/profile", HTTPClient.METHOD_GET, {}, "player_profile")
			_log("Player profile requested (session)")
		else:
			# Anonymous/API-key users - use cached profile
			# There's no server-side profile, scores are submitted with nickname
			_log("Using cached profile (no server profile for API-key mode)")
			if not _cached_profile.is_empty():
				profile_loaded.emit(_nickname, get_high_score(), get_best_streak(), _cached_profile.get("achievements", []))
			else:
				no_profile.emit()

# ============================================================
# PUBLIC API - SCOREBOARDS (Time-based Leaderboards)
# ============================================================

## List all scoreboards for a game
## Emits: scoreboards_loaded(scoreboards: Array)
func get_scoreboards(for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		scoreboard_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/scoreboards" % gid.uri_encode()
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "list_scoreboards")
	_log("Scoreboards list requested for game: %s" % gid)

## Get a specific scoreboard's entries
## Emits: scoreboard_loaded(scoreboard_id, config, entries)
## @param scoreboard_id - e.g. "weekly", "all-time", "daily"
## @param limit - max entries to return (1-1000)
func get_scoreboard(scoreboard_id: String, limit: int = 100, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		scoreboard_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/scoreboards/%s?limit=%d" % [gid.uri_encode(), scoreboard_id.uri_encode(), limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "get_scoreboard", {"scoreboard_id": scoreboard_id})
	_log("Scoreboard '%s' requested (limit: %d)" % [scoreboard_id, limit])

## Get current player's rank on a specific scoreboard
## Emits: scoreboard_rank_loaded(scoreboard_id, rank, score, streak, total)
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

## Convenience: Get weekly leaderboard
func get_weekly_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("weekly-scoreboard", limit, for_game_id)

## Convenience: Get daily leaderboard
func get_daily_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("daily", limit, for_game_id)

## Convenience: Get all-time leaderboard
func get_alltime_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("all-time-new", limit, for_game_id)

## Convenience: Get monthly leaderboard
func get_monthly_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("monthly", limit, for_game_id)

# ============================================================
# PUBLIC API - SCOREBOARD ARCHIVES (NEW v1.4.0)
# ============================================================

## Get list of available archives for a scoreboard
## Emits: archives_list_loaded(scoreboard_id, archives: Array)
## Each archive: {archiveId, scoreboardId, periodStart, periodEnd, entryCount, topPlayer, topScore}
func get_scoreboard_archives(scoreboard_id: String, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		archive_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/scoreboards/%s/archives" % [gid.uri_encode(), scoreboard_id.uri_encode()]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "list_archives", {"scoreboard_id": scoreboard_id})
	_log("Archives list requested for '%s'" % scoreboard_id)

## Get the most recent archived scoreboard (e.g., "last week's results")
## Emits: archived_scoreboard_loaded(archive_id, config, entries)
## Config includes: name, period, sortBy, periodStart, periodEnd
func get_last_archived_scoreboard(scoreboard_id: String, limit: int = 100, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		archive_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/scoreboards/%s/archives/latest?limit=%d" % [gid.uri_encode(), scoreboard_id.uri_encode(), limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "get_last_archive", {"scoreboard_id": scoreboard_id})
	_log("Last archive requested for '%s'" % scoreboard_id)

## Get a specific archived scoreboard by its archive ID
## Emits: archived_scoreboard_loaded(archive_id, config, entries)
## Archive ID format: "gameId:scoreboardId:timestamp"
func get_archived_scoreboard(archive_id: String, limit: int = 100) -> void:
	var url = "/archives/%s?limit=%d" % [archive_id.uri_encode(), limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "get_archive", {"archive_id": archive_id})
	_log("Archive '%s' requested" % archive_id)

## Get archives within a specific date range
## Emits: archives_list_loaded(scoreboard_id, archives: Array)
## @param after_timestamp - Unix timestamp in milliseconds (start of range)
## @param before_timestamp - Unix timestamp in milliseconds (end of range)
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

## Get archive statistics for a game
## Emits: archive_stats_loaded(total_archives, by_scoreboard: Array)
func get_archive_stats(for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.is_empty():
		archive_error.emit("Game ID not set. Call set_game_id() first.")
		return
	
	var url = "/games/%s/archives/stats" % gid.uri_encode()
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "archive_stats")
	_log("Archive stats requested for game: %s" % gid)

## Convenience: Get last week's scoreboard
func get_last_week_scoreboard(limit: int = 100, for_game_id: String = "") -> void:
	get_last_archived_scoreboard("weekly", limit, for_game_id)

## Convenience: Get last month's scoreboard  
func get_last_month_scoreboard(limit: int = 100, for_game_id: String = "") -> void:
	get_last_archived_scoreboard("monthly", limit, for_game_id)

## Convenience: Get yesterday's scoreboard
func get_yesterday_scoreboard(limit: int = 100, for_game_id: String = "") -> void:
	get_last_archived_scoreboard("daily", limit, for_game_id)

# ============================================================
# PUBLIC API - ACHIEVEMENTS
# ============================================================

func unlock_achievement(achievement_id: String, achievement_name: String = "", achievement_desc: String = "") -> void:
	if _is_web:
		if not _init_complete:
			return
		var safe_id: String = achievement_id.replace("'", "\\'").replace('"', '\\"')
		var safe_name: String = achievement_name.replace("'", "\\'").replace('"', '\\"')
		var safe_desc: String = achievement_desc.replace("'", "\\'").replace('"', '\\"')
		var js_code: String = """
			(function() {
				try {
					if (window.chedda && window.chedda.unlockAchievement) {
						window.chedda.unlockAchievement('%s', '%s', '%s')
							.then(result => console.log('[CheddaBoards] Achievement unlocked:', result))
							.catch(error => console.error('[CheddaBoards] Achievement error:', error));
					}
				} catch(e) {
					console.error('[CheddaBoards] Achievement unlock failed:', e);
				}
			})();
		""" % [safe_id, safe_name, safe_desc]
		JavaScriptBridge.eval(js_code, true)
		_log("Achievement unlock: %s" % achievement_name)
	else:
		var body = {
			"playerId": get_player_id(),
			"achievementId": achievement_id
		}
		_make_http_request("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement")
		_log("Achievement unlock (HTTP): %s" % achievement_id)

func get_achievements(player_id: String = "") -> void:
	var pid = player_id if player_id != "" else get_player_id()
	if _is_web:
		refresh_profile()
	else:
		var url = "/players/%s/achievements" % pid.uri_encode()
		_make_http_request(url, HTTPClient.METHOD_GET, {}, "achievements")
		_log("Achievements requested (HTTP)")

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
	
	# ALL users submit via HTTP API
	_log("Submitting score with %d achievements (HTTP API)" % ach_ids.size())
	
	# Unlock achievements first (if not anonymous)
	if not is_anonymous():
		for ach_id in ach_ids:
			var body = {
				"playerId": get_player_id(),
				"achievementId": ach_id
			}
			_make_http_request("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement")
	
	# Submit score
	var score_body = {
		"playerId": get_player_id(),
		"gameId": game_id,
		"score": score,
		"streak": streak,
		"nickname": _nickname if _nickname != "" else _get_default_nickname()
	}
	# Include play session token if available
	if _play_session_token != "":
		score_body["playSessionToken"] = _play_session_token
		_log("Submitting: score=%d, streak=%d, nickname=%s, gameId=%s, playerId=%s, session=%s..." % [score, streak, score_body.nickname, game_id, score_body.playerId, _play_session_token.substr(0, 25)])
	else:
		_log("Submitting: score=%d, streak=%d, nickname=%s, gameId=%s, playerId=%s (no session)" % [score, streak, score_body.nickname, game_id, score_body.playerId])
	_make_http_request("/scores", HTTPClient.METHOD_POST, score_body, "submit_score")

# ============================================================
# PUBLIC API - ANALYTICS
# ============================================================

func track_event(event_type: String, metadata: Dictionary = {}) -> void:
	if _is_web:
		if not _init_complete:
			return
		var meta_json: String = JSON.stringify(metadata)
		var js_code: String = """
			if (window.chedda && window.chedda.trackEvent) {
				window.chedda.trackEvent('%s', %s);
			}
		""" % [event_type, meta_json]
		JavaScriptBridge.eval(js_code, true)
		_log("Event tracked: %s" % event_type)
	else:
		_log("Event tracked (local): %s" % event_type)

# ============================================================
# PUBLIC API - GAME INFO
# ============================================================

func get_game_info() -> void:
	if _is_native:
		_make_http_request("/game", HTTPClient.METHOD_GET, {}, "game_info")

func get_game_stats() -> void:
	if _is_native:
		_make_http_request("/game/stats", HTTPClient.METHOD_GET, {}, "game_stats")

func health_check() -> void:
	if _is_native:
		_make_http_request("/health", HTTPClient.METHOD_GET, {}, "health")

# ============================================================
# HELPER FUNCTIONS
# ============================================================

func force_check_events() -> void:
	if not _is_web or _is_checking_auth or not _init_complete:
		return

	_is_checking_auth = true
	_log("Force checking auth status...")

	var is_auth: bool = is_authenticated()

	if is_auth:
		_log("User is authenticated, checking profile...")
		var js_profile: Dictionary = _get_profile_from_js()
		if js_profile and not js_profile.is_empty():
			_update_cached_profile(js_profile)
		else:
			refresh_profile()
	else:
		_log("User not authenticated")
		no_profile.emit()

	_is_checking_auth = false

func _get_profile_from_js() -> Dictionary:
	if not _is_web or not _init_complete:
		return {}

	var pvar: Variant = JavaScriptBridge.eval("chedda_get_profile()", true)
	if pvar == null:
		return {}

	var profile_str: String = str(pvar)
	if profile_str == "" or profile_str.to_lower() == "null":
		return {}

	var json := JSON.new()
	var parse_result: int = json.parse(profile_str)
	if parse_result == OK:
		return json.data
	return {}

func debug_status() -> void:
	print("")
	print("╔══════════════════════════════════════════════╗")
	print("║        CheddaBoards Debug Status v1.5.4      ║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Environment                                  ║")
	print("║  - Platform:         %s" % ("Web" if _is_web else "Native").rpad(24) + "║")
	print("║  - Init Complete:    %s" % str(_init_complete).rpad(24) + "║")
	print("║  - Init Attempts:    %s" % str(_init_attempts).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Configuration                                ║")
	print("║  - Game ID:          %s" % game_id.left(20).rpad(24) + "║")
	print("║  - API Key Set:      %s" % str(not api_key.is_empty()).rpad(24) + "║")
	print("║  - Session Token:    %s" % str(not _session_token.is_empty()).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Authentication                               ║")
	print("║  - Authenticated:    %s" % str(is_authenticated()).rpad(24) + "║")
	print("║  - Auth Type:        %s" % _auth_type.rpad(24) + "║")
	print("║  - Player ID:        %s" % get_player_id().left(20).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Profile                                      ║")
	print("║  - Nickname:         %s" % get_nickname().rpad(24) + "║")
	print("║  - High Score:       %s" % str(get_high_score()).rpad(24) + "║")
	print("║  - Best Streak:      %s" % str(get_best_streak()).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ State Flags                                  ║")
	print("║  - Checking Auth:    %s" % str(_is_checking_auth).rpad(24) + "║")
	print("║  - Refreshing:       %s" % str(_is_refreshing_profile).rpad(24) + "║")
	print("║  - Submitting:       %s" % str(_is_submitting_score).rpad(24) + "║")
	print("║  - HTTP Busy:        %s" % str(_http_busy).rpad(24) + "║")
	print("║  - Queue Size:       %s" % str(_request_queue.size()).rpad(24) + "║")
	print("║  - Pending Score:    %s" % str(_pending_score).rpad(24) + "║")
	print("║  - Pending Streak:   %s" % str(_pending_streak).rpad(24) + "║")
	print("╚══════════════════════════════════════════════╝")

	if _is_web:
		print("")
		print("JavaScript Status:")
		var js_status: Variant = JavaScriptBridge.eval("""
			(function() {
				return JSON.stringify({
					sdkLoaded: window.CheddaBoards !== undefined,
					instanceReady: window.chedda !== undefined,
					isAuth: window.chedda_is_auth ? window.chedda_is_auth() : false
				}, null, 2);
			})();
		""", true)
		print(js_status)
	print("")

# ============================================================
# CLEANUP
# ============================================================

func _exit_tree() -> void:
	if _poll_timer:
		_poll_timer.stop()
		_poll_timer.queue_free()
	_clear_login_timeout()
