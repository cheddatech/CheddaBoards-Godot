# CheddaBoards.gd v1.8.2
# CheddaBoards integration for Godot 4.x
# https://github.com/cheddatech/CheddaBoards-Godot
# https://cheddaboards.com
#
# HYBRID SDK: Supports both Web (JavaScript Bridge) and Native (HTTP API)
# - OAuth login (Google, Apple, II) uses JavaScript bridge on web
# - OAuth score submissions use JS bridge (knows ICP identity)
# - Anonymous/Native score submissions use HTTP API
# - Play sessions use HTTP API for ALL users
#
# v1.8.2: Achievement sync is now non-blocking (async/fire-and-forget).
#          Fixes leaderboard timeout from achievement queue blocking.
#          Added unlock_achievements_batch() for efficient batch sync.
# v1.8.1: Fixed achievements not syncing - score submitted FIRST (creates player),
#          then achievements sent one-at-a-time (batch endpoint doesn't exist).
#          Fixed anonymous nickname PUT 400 on first play (player doesn't exist yet).
# v1.7.0: Fixed post-upgrade scores creating ghost anonymous accounts
#          Session token captured from login/upgrade/profile responses
#          HTTP requests use session token OR API key (not both) so proxy routes correctly
#          Play sessions always use API key (game-level op, skip_validation)
#          Nickname changes route through HTTP API for all auth types
#          Session token cleared on logout (prevents stale auth on anonymous play)
# v1.6.0: Fixed end_play_session body field (token → playSessionToken)
#          Fixed 404 on profile lookup for new anonymous players (graceful handling)
# v1.5.9: Persistent device IDs - anonymous players keep same identity across sessions
#          Device ID saved to user://cheddaboards_device.cfg
#          Fixes nickname conflicts when same player gets new random ID on restart
# v1.5.6: OAuth users submit scores via JS bridge (fixes scores not saving)
# v1.5.5: Batch achievement unlocks (single request instead of N requests)
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

# --- Account Upgrade (Anonymous → Verified) ---
signal account_upgraded(profile: Dictionary, migration: Dictionary)
signal account_upgrade_failed(reason: String)

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
var _nickname_just_changed: bool = false
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

# Deferred achievement tracking (sent one-at-a-time after score succeeds)
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
	_is_web = OS.get_name() == "Web"
	_is_native = not _is_web
	
	_setup_http_client()
	
	if _is_web:
		_log("Initializing CheddaBoards v1.8.1 (Web Mode)...")
		_start_polling()
		_check_chedda_ready()
	else:
		_log("Initializing CheddaBoards v1.8.1 (Native/HTTP API Mode)...")
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
	
	# Create a temporary HTTPRequest node
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = ["Content-Type: application/json"]
	
	# Use session token if available, otherwise API key
	var force_api_key = request_type in ["start_play_session", "end_play_session"]
	if not _session_token.is_empty() and not force_api_key:
		headers.append("X-Session-Token: " + _session_token)
	elif not api_key.is_empty():
		headers.append("X-API-Key: " + api_key)
	
	if not game_id.is_empty():
		headers.append("X-Game-ID: " + game_id)
	
	var url = API_BASE_URL + endpoint
	var json_body = JSON.stringify(body) if body.size() > 0 else ""
	
	_log("HTTP async %s: %s" % [request_type, endpoint])
	
	# Connect completion handler that cleans up the node
	http.request_completed.connect(func(result, code, _headers, response_body):
		if code >= 200 and code < 300:
			_log("Async %s complete (HTTP %d)" % [request_type, code])
		else:
			_log("Async %s failed (HTTP %d)" % [request_type, code])
		http.queue_free()  # Clean up
	)
	
	var error = http.request(url, headers, method, json_body)
	if error != OK:
		_log("Async request failed to start: %s" % error)
		http.queue_free()

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
				# Capture session token if provided (for HTTP API session-based routing)
				var token = str(response.get("sessionToken", ""))
				if token != "":
					_session_token = token
					_log("Session token captured from login")
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
				# Capture session token if provided (bridge includes it)
				var token = str(response.get("sessionToken", ""))
				if token != "" and _session_token.is_empty():
					_session_token = token
					_log("Session token captured from profile refresh")
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
				_nickname = new_nickname
				_nickname_just_changed = true
				if not _cached_profile.is_empty():
					_cached_profile["nickname"] = new_nickname
				nickname_changed.emit(new_nickname)
			elif bool(response.get("cancelled", false)):
				pass
			else:
				var error: String = str(response.get("error", "Unknown error"))
				nickname_error.emit(error)

		"upgradeToGoogle", "upgradeToApple", "upgradeToII":
			if success:
				var profile: Dictionary = response.get("profile", {})
				var migration: Dictionary = response.get("migration", {})
				_log("Account upgrade success: %s" % action)
				if profile and not profile.is_empty():
					_update_cached_profile(profile)
					_auth_type = str(response.get("authType", "google"))
				# Capture session token (for HTTP API session-based routing post-upgrade)
				var token = str(response.get("sessionToken", ""))
				if token != "":
					_session_token = token
					_log("Session token captured from upgrade")
				account_upgraded.emit(profile, migration)
			else:
				var error: String = str(response.get("error", "Upgrade failed"))
				_log("Account upgrade failed: %s" % error)
				account_upgrade_failed.emit(error)

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
		# 404 on profile lookup is expected for new players who haven't submitted yet
		if response_code == 404 and _current_endpoint == "player_profile":
			_log("Player profile not found (new player) - this is normal for first-time anonymous users")
			_is_refreshing_profile = false
			no_profile.emit()
			_current_meta = {}
			_http_busy = false
			_process_next_request()
			return
		# 404 on end play session is expected - session was already consumed by score submission or expired
		if response_code == 404 and _current_endpoint == "end_play_session":
			_log("Play session already ended or expired - this is normal")
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
			# Use the pending values we stored before the request
			_log("Score submission successful: %d points, %d streak" % [_pending_score, _pending_streak])
			score_submitted.emit(_pending_score, _pending_streak)
			# After score succeeds (player now exists on backend), flush deferred achievements
			_flush_deferred_achievements()
		
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
			# Also refresh profile to get updated data
			get_player_profile()
		
		"unlock_achievement":
			var ach_id = str(data.get("achievementId", ""))
			achievement_unlocked.emit(ach_id)
			# Track deferred achievement completion
			if _deferred_achievements_remaining > 0:
				_deferred_achievements_synced.append(ach_id)
				_deferred_achievements_remaining -= 1
				_log("Achievement synced: %s (%d remaining)" % [ach_id, _deferred_achievements_remaining])
				if _deferred_achievements_remaining <= 0:
					_log("All deferred achievements done: %d synced" % _deferred_achievements_synced.size())
					achievements_loaded.emit(_deferred_achievements_synced.duplicate())
					_deferred_achievements_synced.clear()
		
		"unlock_achievement_batch":
			# Batch response - all achievements synced in one request
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
		
		"end_play_session":
			_log("Play session ended on server successfully")
	
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
			# Track deferred achievement completion even on failure
			if _deferred_achievements_remaining > 0:
				_deferred_achievements_remaining -= 1
				_log("Achievement unlock failed (%d remaining)" % _deferred_achievements_remaining)
				if _deferred_achievements_remaining <= 0:
					achievements_loaded.emit(_deferred_achievements_synced.duplicate())
					_deferred_achievements_synced.clear()
		"unlock_achievement_batch":
			# Batch failed - emit empty result
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
		"end_play_session":
			_log("End play session HTTP error (ignored): %s" % error)
			# Don't emit error - ending session is best-effort
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
	
	var headers = [
		"Content-Type: application/json"
	]
	
	# Session token takes priority over API key (mutually exclusive)
	# EXCEPT: play sessions always use API key (game-level operation, skip_validation)
	# Proxy routes: sessionToken && !apiKey → session handlers (authenticated user)
	#               apiKey (no sessionToken) → external handlers (anonymous/API)
	var force_api_key = _current_endpoint in ["start_play_session", "end_play_session"]
	if not _session_token.is_empty() and not force_api_key:
		headers.append("X-Session-Token: " + _session_token)
		_log("Using session token for auth")
	elif not api_key.is_empty():
		headers.append("X-API-Key: " + api_key)
	
	# Add game ID header if set
	if not game_id.is_empty():
		headers.append("X-Game-ID: " + game_id)
	
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

	# Preserve nickname from recent rename - backend/JS cache may return stale data
	if _nickname_just_changed and not _nickname.is_empty():
		profile["nickname"] = _nickname
		_log("Preserving renamed nickname '%s' over stale backend data" % _nickname)
		_nickname_just_changed = false

	_cached_profile = profile

	var nickname: String = str(profile.get("nickname", profile.get("username", _get_default_nickname())))
	
	# Handle nested gameProfile from API (GET /players/:id/profile returns gameProfile object)
	var game_profile = profile.get("gameProfile", {})
	var score: int = 0
	var streak: int = 0
	var achievements: Array = []
	var play_count: int = 0
	
	if game_profile and not game_profile.is_empty():
		score = int(game_profile.get("score", 0))
		streak = int(game_profile.get("streak", 0))
		achievements = game_profile.get("achievements", [])
		play_count = int(game_profile.get("playCount", 0))
		# Store flattened for easier access
		_cached_profile["score"] = score
		_cached_profile["streak"] = streak
		_cached_profile["achievements"] = achievements
		_cached_profile["playCount"] = play_count
	else:
		# Fallback to direct fields (JS bridge format)
		score = int(profile.get("score", profile.get("highScore", 0)))
		streak = int(profile.get("streak", profile.get("bestStreak", 0)))
		achievements = profile.get("achievements", [])
		play_count = int(profile.get("playCount", profile.get("plays", 0)))
	
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
	# Check flattened field first, then nested gameProfile
	if _cached_profile.has("score"):
		return int(_cached_profile.get("score", 0))
	var gp = _cached_profile.get("gameProfile", {})
	if gp and not gp.is_empty():
		return int(gp.get("score", 0))
	return 0

func get_best_streak() -> int:
	if _cached_profile.is_empty():
		return 0
	# Check flattened field first, then nested gameProfile
	if _cached_profile.has("streak"):
		return int(_cached_profile.get("streak", 0))
	var gp = _cached_profile.get("gameProfile", {})
	if gp and not gp.is_empty():
		return int(gp.get("streak", 0))
	return 0

func get_play_count() -> int:
	if _cached_profile.is_empty():
		return 0
	# Check flattened field first, then nested gameProfile
	if _cached_profile.has("playCount"):
		return int(_cached_profile.get("playCount", 0))
	var gp = _cached_profile.get("gameProfile", {})
	if gp and not gp.is_empty():
		return int(gp.get("playCount", 0))
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
	# Note: Don't reset _nickname here - MainMenu sets it separately

func get_player_id() -> String:
	if not _player_id.is_empty():
		return _player_id
	
	# 1. Try web localStorage (browser persistence)
	if _is_web:
		var js_device_id = JavaScriptBridge.eval("chedda_get_device_id()", true)
		if js_device_id and str(js_device_id) != "":
			_player_id = str(js_device_id)
			_save_device_id(_player_id)
			return _player_id
	
	# 2. Try loading saved device ID from disk
	var saved_id = _load_device_id()
	if saved_id != "":
		_player_id = saved_id
		_log("Loaded persistent device ID: %s" % _player_id.left(12))
		return _player_id
	
	# 3. Generate new persistent device ID (first launch only)
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
		# Use persistent device ID instead of random throwaway
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
		_session_token = ""  # Clear session token so anonymous play uses API key path
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
	
	if _is_web and not is_anonymous():
		# OAuth users on web - use JS bridge
		if not _init_complete:
			_is_refreshing_profile = false
			return
		JavaScriptBridge.eval("chedda_refresh_profile()", true)
		_log("Profile refresh requested (JS)")
	else:
		# Anonymous or native - use API
		get_player_profile()
		_log("Profile refresh requested (API)")

func change_nickname(new_nickname: String = "") -> void:
	if new_nickname == "":
		if _is_web:
			# Show JS prompt for web users
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
			_log("Nickname change requested (JS prompt)")
		else:
			nickname_error.emit("Nickname required - use change_nickname('name')")
		return
	
	# All nickname changes go through HTTP API with proper auth routing
	# EXCEPT: Anonymous players who haven't submitted a score yet don't exist
	# on the backend - the PUT would return 400 "User not found".
	# Just set locally; the nickname is included in the score submission body.
	if is_anonymous() and _cached_profile.is_empty():
		_nickname = new_nickname
		_log("Nickname set locally (no backend profile yet): %s" % new_nickname)
		nickname_changed.emit(new_nickname)
		return
	
	if not _session_token.is_empty():
		# OAuth users - session token path: PUT /profile/nickname
		var body = {"nickname": new_nickname}
		_make_http_request("/profile/nickname", HTTPClient.METHOD_PUT, body, "change_nickname")
		_log("Nickname change requested (session) -> %s" % new_nickname)
	elif not api_key.is_empty():
		# Anonymous/API-key users - API key path: PUT /players/{id}/nickname
		var pid = get_player_id()
		if pid.is_empty():
			nickname_error.emit("No player ID set")
			return
		var body = {"nickname": new_nickname}
		var url = "/players/%s/nickname" % pid.uri_encode()
		_make_http_request(url, HTTPClient.METHOD_PUT, body, "change_nickname_anonymous")
		_log("Nickname change requested (HTTP API) for: %s -> %s" % [pid, new_nickname])
	else:
		nickname_error.emit("Not authenticated")
			
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

## End the play session on the server (call when game cancelled without score submission)
func end_play_session() -> void:
	if _play_session_token == "" or _play_session_token.begins_with("fallback_"):
		_log("No active server session to end")
		_play_session_token = ""
		return
	
	_log("Ending play session on server: %s" % _play_session_token.left(30))
	var body = {
		"playSessionToken": _play_session_token
	}
	# Fire and forget - don't wait for response
	_make_http_request("/play-sessions/end", HTTPClient.METHOD_POST, body, "end_play_session")
	_play_session_token = ""  # Clear locally immediately

## Clear the play session (also ends it on server if active)
func clear_play_session() -> void:
	if _play_session_token != "" and not _play_session_token.begins_with("fallback_"):
		end_play_session()
	else:
		_play_session_token = ""
		_log("Play session cleared (local only)")

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
	if _is_web and not is_anonymous():
		# OAuth users on web - use JS bridge
		refresh_profile()
	elif not _session_token.is_empty():
		# OAuth session users (native) - use /auth/profile
		_make_http_request("/auth/profile", HTTPClient.METHOD_GET, {}, "player_profile")
		_log("Player profile requested (session)")
	else:
		# Anonymous/API-key users - fetch from API!
		var pid = player_id if player_id != "" else get_player_id()
		if pid.is_empty():
			_log("No player ID for profile fetch")
			no_profile.emit()
			return
		var url = "/players/%s/profile" % pid.uri_encode()
		_make_http_request(url, HTTPClient.METHOD_GET, {}, "player_profile")
		_log("Player profile requested (HTTP API) for: %s" % pid)

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
		# Use async request so achievements don't block leaderboard loading
		_make_http_request_async("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement")
		_log("Achievement unlock (HTTP async): %s" % achievement_id)

func unlock_achievements_batch(achievement_ids: Array) -> void:
	"""Unlock multiple achievements in a single request (more efficient than individual calls)."""
	if achievement_ids.is_empty():
		return
	
	_log("Batch unlocking %d achievements..." % achievement_ids.size())
	_deferred_achievements_remaining = 1  # Single batch request
	_deferred_achievements_synced = []
	
	var body = {
		"playerId": get_player_id(),
		"achievementIds": achievement_ids
	}
	# Use async request so achievements don't block leaderboard loading
	_make_http_request_async("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement_batch")

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
	
	# Route based on auth type:
	# - OAuth users on web → JS bridge (knows their identity)
	# - Anonymous users on web → HTTP API (device ID)
	# - Native → HTTP API
	
	if _is_web and not is_anonymous():
		# OAuth users: use JS bridge which knows their ICP identity
		_log("Submitting score with %d achievements (JS Bridge - OAuth user)" % ach_ids.size())
		var ach_json = JSON.stringify(ach_ids)
		var js_code = """
			(function() {
				window.chedda_submit_score(%d, %d, %s)
					.then(function(result) {
						console.log('[CheddaBoards] JS Bridge score submitted:', result);
					})
					.catch(function(error) {
						console.error('[CheddaBoards] JS Bridge score error:', error);
					});
			})();
		""" % [score, streak, ach_json]
		JavaScriptBridge.eval(js_code, true)
		# The response will come through the polling mechanism
		# Set a timer to reset _is_submitting_score after a delay
		get_tree().create_timer(2.0).timeout.connect(func():
			if _is_submitting_score:
				_is_submitting_score = false
				score_submitted.emit(_pending_score, _pending_streak)
		)
	else:
		# Anonymous or native: use HTTP API
		_log("Submitting score with %d achievements (HTTP API)" % ach_ids.size())
		
		# Store achievement IDs - they'll be queued AFTER score succeeds
		# (score submission creates the player profile on the backend)
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
		# Include play session token if available
		if _play_session_token != "":
			score_body["playSessionToken"] = _play_session_token
			_log("Submitting: score=%d, streak=%d, nickname=%s, gameId=%s, playerId=%s, session=%s..." % [score, streak, score_body.nickname, game_id, score_body.playerId, _play_session_token.substr(0, 25)])
		else:
			_log("Submitting: score=%d, streak=%d, nickname=%s, gameId=%s, playerId=%s (no session)" % [score, streak, score_body.nickname, game_id, score_body.playerId])
		_make_http_request("/scores", HTTPClient.METHOD_POST, score_body, "submit_score")
		# Achievement unlocks will be queued by _flush_deferred_achievements()
		# called from the score success handler

# ============================================================
# PUBLIC API - ANALYTICS
# ============================================================

func _flush_deferred_achievements() -> void:
	"""Send all deferred achievements in a single batch request."""
	if _deferred_achievement_ids.is_empty():
		return
	var count = _deferred_achievement_ids.size()
	_deferred_achievements_remaining = 1  # Just one batch request now
	_deferred_achievements_synced = []
	_log("Batch syncing %d achievements..." % count)
	
	# Send all achievements in one request using achievementIds array
	var body = {
		"playerId": get_player_id(),
		"achievementIds": _deferred_achievement_ids.duplicate()  # Array of IDs
	}
	# Use async so it doesn't block leaderboard loading
	_make_http_request_async("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement_batch")
	_deferred_achievement_ids.clear()

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
	print("║        CheddaBoards Debug Status v1.8.1      ║")
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
