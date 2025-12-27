# CheddaBoards.gd v1.2.1
# CheddaBoards integration for Godot 4.x
# https://github.com/cheddatech/CheddaBoards-Godot
# https://cheddaboards.com
#
# HYBRID SDK: Supports both Web (JavaScript Bridge) and Native (HTTP API)
# - Web exports use JavaScript bridge for ICP authentication
# - Native exports (Windows/Mac/Linux/Mobile) use HTTP API
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

# --- Scores & Leaderboards ---
signal score_submitted(score: int, streak: int)
signal score_error(reason: String)
signal leaderboard_loaded(entries: Array)
signal player_rank_loaded(rank: int, score: int, streak: int, total_players: int)
signal rank_error(reason: String)

# --- Achievements ---
signal achievement_unlocked(achievement_id: String)
signal achievements_loaded(achievements: Array)

# --- HTTP API Specific ---
signal request_failed(endpoint: String, error: String)

# ============================================================
# CONFIGURATION
# ============================================================

## Set to true to enable verbose logging
var debug_logging: bool = true  # Enabled for debugging

## HTTP API Configuration (for native builds)
const API_BASE_URL = "https://api.cheddaboards.com"
var api_key: String = ""                                     ## add api key here
var _player_id: String = ""  # For native API auth

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
var _http_busy: bool = false
var _request_queue: Array = []  # Queue of pending requests

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_is_web = OS.get_name() == "Web"
	_is_native = not _is_web
	
	# Always set up HTTP client (used for anonymous on both platforms)
	_setup_http_client()
	
	if _is_web:
		_log("Initializing CheddaBoards v1.2.1 (Web Mode)...")
		_start_polling()
		_check_chedda_ready()
	else:
		_log("Initializing CheddaBoards v1.2.1 (Native/HTTP API Mode)...")
		# Initialize player ID early (sanitizes OS.get_unique_id())
		var pid = get_player_id()
		_log("Device player ID: %s" % pid)
		# For native, SDK is ready once HTTP client is set up
		_init_complete = true
		call_deferred("_emit_sdk_ready")

func _emit_sdk_ready() -> void:
	sdk_ready.emit()

func _setup_http_client() -> void:
	"""Setup HTTP client for native builds"""
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_http_request_completed)

# ============================================================
# SDK READY CHECK (Web Only)
# ============================================================

func _check_chedda_ready() -> void:
	"""Check if CheddaBoards SDK is loaded and ready (Web)"""
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
	"""Start polling for responses from JavaScript"""
	if _poll_timer:
		return

	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_check_for_responses)
	add_child(_poll_timer)
	_log("Started polling timer (interval: %ss)" % POLL_INTERVAL)

func _check_for_responses() -> void:
	"""Poll JavaScript for queued responses"""
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
	"""Process responses from JavaScript bridge"""
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
				var scored: int = int(response.get("score", 0))
				var streakd: int = int(response.get("streak", 0))
				_log("Score submitted successfully: %d points, %d streak" % [scored, streakd])
				score_submitted.emit(scored, streakd)
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
				# JS bridge sends "entries", HTTP API sends "leaderboard"
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
	"""Handle HTTP API responses for native builds"""
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
	"""Emit appropriate success signal for HTTP responses"""
	match _current_endpoint:
		"submit_score":
			_is_submitting_score = false
			var score_val = int(data.get("score", 0))
			var streak_val = int(data.get("streak", 0))
			score_submitted.emit(score_val, streak_val)
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
		"game_info", "game_stats", "health":
			_log("API response: %s" % str(data))
	
	# Process next queued request
	_http_busy = false
	_process_next_request()

func _emit_http_failure(error: String) -> void:
	"""Emit appropriate failure signal for HTTP responses"""
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
	
	# Process next queued request
	_http_busy = false
	_process_next_request()

func _make_http_request(endpoint: String, method: int, body: Dictionary, request_type: String) -> void:
	"""Make HTTP request for native builds (queued)"""
	if api_key.is_empty():
		_log("API key not set - skipping HTTP request to %s" % endpoint)
		# Emit appropriate error signal based on request type
		match request_type:
			"submit_score":
				score_error.emit("API key not set")
			"player_profile":
				no_profile.emit()
			"leaderboard":
				leaderboard_loaded.emit([])
			"player_rank":
				rank_error.emit("API key not set")
		return
	
	# Queue the request
	var request_data = {
		"endpoint": endpoint,
		"method": method,
		"body": body,
		"request_type": request_type
	}
	
	if _http_busy:
		_log("HTTP busy, queuing request: %s" % request_type)
		_request_queue.append(request_data)
		return
	
	_execute_http_request(request_data)

func _execute_http_request(request_data: Dictionary) -> void:
	"""Actually execute an HTTP request"""
	_http_busy = true
	_current_endpoint = request_data.request_type
	
	var headers = [
		"Content-Type: application/json",
		"X-API-Key: " + api_key
	]
	
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
	"""Process next queued request if any"""
	if _request_queue.is_empty():
		return
	
	var next_request = _request_queue.pop_front()
	_log("Processing queued request: %s" % next_request.request_type)
	_execute_http_request(next_request)

# ============================================================
# PROFILE MANAGEMENT
# ============================================================

func _update_cached_profile(profile: Dictionary) -> void:
	"""Update the cached profile and emit signal"""
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
	"""Start timeout timer for login attempts"""
	_clear_login_timeout()
	
	_login_timeout_timer = Timer.new()
	_login_timeout_timer.wait_time = LOGIN_TIMEOUT_DURATION
	_login_timeout_timer.one_shot = true
	_login_timeout_timer.timeout.connect(_on_login_timeout)
	add_child(_login_timeout_timer)
	_login_timeout_timer.start()
	_log("Login timeout started (%.1fs)" % LOGIN_TIMEOUT_DURATION)

func _clear_login_timeout() -> void:
	"""Clear login timeout timer"""
	if _login_timeout_timer:
		_login_timeout_timer.stop()
		_login_timeout_timer.queue_free()
		_login_timeout_timer = null

func _on_login_timeout() -> void:
	"""Handle login timeout"""
	_log("Login timeout - no response received")
	login_timeout.emit()
	_login_timeout_timer = null

# ============================================================
# LOGGING
# ============================================================

func _log(message: String) -> void:
	"""Print log message if debug logging is enabled"""
	if debug_logging:
		print("[CheddaBoards] %s" % message)

# ============================================================
# PUBLIC API - UTILITIES
# ============================================================

## Check if CheddaBoards is fully initialized and ready
func is_ready() -> bool:
	if _is_web:
		return _is_web and _init_complete
	else:
		return _init_complete

## Check if SDK can communicate with backend (has credentials)
func can_connect() -> bool:
	if _is_web:
		return _init_complete
	else:
		return _init_complete and not api_key.is_empty()

## Wait until SDK is ready (use with await)
func wait_until_ready() -> void:
	if is_ready():
		return
	await sdk_ready

## Generate a unique default nickname using player ID
func _get_default_nickname() -> String:
	return "Player_" + get_player_id().left(6)

## Get current player's nickname
func get_nickname() -> String:
	if _cached_profile.is_empty():
		return _nickname if _nickname != "" else _get_default_nickname()
	return str(_cached_profile.get("nickname", _get_default_nickname()))

## Get current player's high score
func get_high_score() -> int:
	if _cached_profile.is_empty():
		return 0
	return int(_cached_profile.get("score", 0))

## Get current player's best streak
func get_best_streak() -> int:
	if _cached_profile.is_empty():
		return 0
	return int(_cached_profile.get("streak", 0))

## Get the cached profile data
func get_cached_profile() -> Dictionary:
	return _cached_profile

## Get the authentication type
func get_auth_type() -> String:
	return _auth_type

# ============================================================
# PUBLIC API - CONFIGURATION (Native)
# ============================================================

## Set the API key for HTTP API (native builds)
func set_api_key(key: String) -> void:
	api_key = key
	_log("API key set")

## Set player ID for HTTP API authentication
func set_player_id(player_id: String) -> void:
	_player_id = _sanitize_player_id(player_id)
	_log("Player ID set: %s" % _player_id)

## Get current player ID (for native builds)
func get_player_id() -> String:
	if _player_id.is_empty():
		if _is_web:
			# Web: Try to get device ID from JS template, fallback to random
			var js_device_id = JavaScriptBridge.eval("window.deviceId || ''", true)
			if js_device_id and str(js_device_id) != "":
				_player_id = _sanitize_player_id(str(js_device_id))
			else:
				_player_id = "player_" + str(randi() % 1000000000)
		else:
			# Native: Use device unique ID
			var raw_id = OS.get_unique_id()
			_player_id = _sanitize_player_id(raw_id)
		_log("Generated player ID: %s" % _player_id)
	return _player_id

func _sanitize_player_id(raw_id: String) -> String:
	if raw_id.is_empty():
		randomize()
		return "player_" + str(randi() % 1000000000)
	
	# Remove invalid characters (keep only alphanumeric, underscore, hyphen)
	var sanitized = ""
	for c in raw_id:
		# Check if alphanumeric, underscore, or hyphen
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			sanitized += c
	
	# If empty after sanitizing, generate fallback
	if sanitized.is_empty():
		randomize()
		return "player_" + str(abs(raw_id.hash()))
	
	# Ensure it starts with a letter or underscore (not a number)
	if sanitized[0] >= "0" and sanitized[0] <= "9":
		sanitized = "p_" + sanitized
	
	# Truncate to 100 characters max
	if sanitized.length() > 100:
		sanitized = sanitized.left(100)
	
	return sanitized

# ============================================================
# PUBLIC API - AUTHENTICATION
# ============================================================

## Log in with Internet Identity (Web only - passwordless)
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
		# Native: Use API key auth with player ID
		if api_key.is_empty():
			login_failed.emit("API key not set")
			return
		_nickname = nickname if nickname != "" else _get_default_nickname()
		_auth_type = "api_key"
		login_success.emit(_nickname)
		_log("Native login (API key mode)")

## Alias for login_internet_identity
func login_chedda_id(nickname: String = "") -> void:
	login_internet_identity(nickname)

## Log in with Google (Web only)
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

## Log in with Apple (Web only)
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

## Log out the current user
func logout() -> void:
	if _is_web:
		if not _init_complete:
			return
		JavaScriptBridge.eval("chedda_logout()", true)
		_log("Logout requested")
	else:
		_cached_profile = {}
		_auth_type = ""
		_nickname = ""
		logout_success.emit()
		_log("Native logout")

## Check if user is currently authenticated (any type including anonymous)
func is_authenticated() -> bool:
	if _is_web:
		if not _init_complete:
			return false
		var result: Variant = JavaScriptBridge.eval("chedda_is_auth()", true)
		return bool(result)
	else:
		# Native: Check if we have API key and player ID
		return not api_key.is_empty()

## Check if user has a REAL account (Google/Apple/Chedda - not anonymous)
func has_account() -> bool:
	if _is_web:
		if not _init_complete:
			return false
		var result: Variant = JavaScriptBridge.eval("chedda_has_account()", true)
		return bool(result)
	else:
		# Native: Check API key AND real auth type
		return not api_key.is_empty() and _auth_type != "device" and _auth_type != "anonymous" and _auth_type != ""

## Check if using anonymous/device authentication
func is_anonymous() -> bool:
	if _is_web:
		if not _init_complete:
			return true  # Default to anonymous if not ready
		var result: Variant = JavaScriptBridge.eval("chedda_is_anonymous()", true)
		return bool(result)
	else:
		return _auth_type == "device" or _auth_type == "anonymous" or _auth_type == ""

## Get device ID for anonymous play (Web)
func get_device_id() -> String:
	if _is_web:
		var result: Variant = JavaScriptBridge.eval("chedda_get_device_id()", true)
		return str(result) if result else ""
	else:
		return get_player_id()

# ============================================================
# PUBLIC API - AUTHENTICATION
# ============================================================

## Login anonymously with device ID (no account required)
## Optionally provide a custom nickname for leaderboard display
## Uses HTTP API for both web and native (simpler, no JS SDK needed for anonymous)
func login_anonymous(nickname: String = "") -> void:
	# For anonymous users, always use HTTP API (works on both web and native)
	_auth_type = "device"
	var player_id = get_player_id()
	
	# Use provided nickname or generate one
	if nickname != "":
		_nickname = nickname
	else:
		_nickname = "Player_" + player_id.left(6)
	
	_cached_profile = {
		"nickname": _nickname,
		"score": 0,
		"streak": 0,
		"playCount": 0,
		"achievements": [],
		"deviceId": player_id
	}
	
	_log("Anonymous login: %s (ID: %s)" % [_nickname, player_id])
	login_success.emit(_nickname)
	profile_loaded.emit(_nickname, 0, 0, [])

## Set up anonymous player without emitting login signals
## Useful when you just want to configure the player before gameplay
func setup_anonymous_player(player_id: String = "", nickname: String = "") -> void:
	if player_id != "":
		set_player_id(player_id)
	
	var pid = get_player_id()
	_auth_type = "device"
	
	if nickname != "":
		_nickname = nickname
	else:
		_nickname = "Player_" + pid.left(6)
	
	_cached_profile = {
		"nickname": _nickname,
		"score": 0,
		"streak": 0,
		"playCount": 0,
		"achievements": [],
		"deviceId": pid
	}
	
	_log("Anonymous player configured: %s (ID: %s)" % [_nickname, pid])

# ============================================================
# PUBLIC API - PROFILE MANAGEMENT
# ============================================================

## Refresh profile data from server
func refresh_profile() -> void:
	if _is_web:
		if not _init_complete:
			return
		if _is_refreshing_profile:
			_log("Profile refresh already in progress")
			return
		var current_time: float = Time.get_ticks_msec() / 1000.0
		if current_time - _last_profile_refresh < PROFILE_REFRESH_COOLDOWN:
			_log("Profile refresh on cooldown")
			return
		_is_refreshing_profile = true
		_last_profile_refresh = current_time
		JavaScriptBridge.eval("chedda_refresh_profile()", true)
		_log("Profile refresh requested")
	else:
		# Native: Use HTTP API
		get_player_profile(get_player_id())

## Open the nickname change prompt (Web only)
func change_nickname() -> void:
	if _is_web:
		if not _init_complete:
			return
		JavaScriptBridge.eval("chedda_change_nickname_prompt()", true)
		_log("Nickname change requested")
	else:
		# Native: Emit error - use change_nickname_to() instead
		nickname_error.emit("Use change_nickname_to() for native builds")

## Change nickname directly via HTTP API (for anonymous/native players)
func change_nickname_to(new_nickname: String) -> void:
	if new_nickname.length() < 2 or new_nickname.length() > 20:
		nickname_error.emit("Nickname must be 2-20 characters")
		return
	
	# Anonymous users always use HTTP API
	if is_anonymous() or _is_native:
		var url = "/players/%s/nickname" % get_player_id().uri_encode()
		var body = { "nickname": new_nickname }
		_make_http_request(url, HTTPClient.METHOD_PUT, body, "change_nickname")
		_log("Nickname change requested (HTTP): %s" % new_nickname)
	else:
		# Authenticated web users - update locally (they use JS SDK popup)
		_nickname = new_nickname
		if not _cached_profile.is_empty():
			_cached_profile["nickname"] = new_nickname
		nickname_changed.emit(new_nickname)

## Set nickname directly (for anonymous players)
func set_nickname(new_nickname: String) -> void:
	_nickname = new_nickname
	if not _cached_profile.is_empty():
		_cached_profile["nickname"] = new_nickname
	_log("Nickname set to: %s" % new_nickname)

# ============================================================
# PUBLIC API - SCORES & LEADERBOARDS
# ============================================================

## Submit score and streak to leaderboard
## For anonymous players, nickname is included in the request
func submit_score(score: int, streak: int = 0, rounds: int = -1) -> void:
	if _is_submitting_score:
		_log("Score submission already in progress")
		return
	
	# Anonymous users always use HTTP API (both web and native)
	if is_anonymous():
		_is_submitting_score = true
		var body = {
			"playerId": get_player_id(),
			"score": score,
			"streak": streak,
			"nickname": _nickname if _nickname != "" else _get_default_nickname()
		}
		if rounds >= 0:
			body["rounds"] = rounds
		_make_http_request("/scores", HTTPClient.METHOD_POST, body, "submit_score")
		_log("Score submission (HTTP): %d points, %d streak, nickname: %s" % [score, streak, body["nickname"]])
		return
	
	# Authenticated users on web use JS SDK
	if _is_web:
		if not _init_complete:
			_log("SDK not ready, waiting...")
			await get_tree().create_timer(0.5).timeout
			if not _init_complete:
				score_error.emit("CheddaBoards not ready")
				return
		_is_submitting_score = true
		var js_code: String = "chedda_submit_score(%d, %d)" % [score, streak]
		_log("Calling JS: %s" % js_code)
		JavaScriptBridge.eval(js_code, true)
		_log("Score submission: %d points, %d streak" % [score, streak])
	else:
		# Native authenticated - use HTTP API
		_is_submitting_score = true
		var body = {
			"playerId": get_player_id(),
			"score": score,
			"streak": streak,
			"nickname": _nickname if _nickname != "" else _get_default_nickname()
		}
		if rounds >= 0:
			body["rounds"] = rounds
		_make_http_request("/scores", HTTPClient.METHOD_POST, body, "submit_score")
		_log("Score submission (HTTP): %d points, %d streak" % [score, streak])

## Get leaderboard data
func get_leaderboard(sort_by: String = "score", limit: int = 100) -> void:
	# Anonymous users or native: use HTTP API
	if is_anonymous() or _is_native:
		var url = "/leaderboard?limit=%d&sort=%s" % [limit, sort_by]
		_make_http_request(url, HTTPClient.METHOD_GET, {}, "leaderboard")
		_log("Leaderboard requested (HTTP)")
		return
	
	# Authenticated web users: use JS SDK
	if _is_web:
		if not _init_complete:
			return
		var js_code: String = "chedda_get_leaderboard('%s', %d)" % [sort_by, limit]
		JavaScriptBridge.eval(js_code, true)
		_log("Leaderboard requested (sort: %s, limit: %d)" % [sort_by, limit])

## Get current player's rank on leaderboard
func get_player_rank(sort_by: String = "score") -> void:
	# Anonymous users or native: use HTTP API
	if is_anonymous() or _is_native:
		var url = "/players/%s/rank?sort=%s" % [get_player_id().uri_encode(), sort_by]
		_make_http_request(url, HTTPClient.METHOD_GET, {}, "player_rank")
		_log("Player rank requested (HTTP)")
		return
	
	# Authenticated web users: use JS SDK
	if _is_web:
		if not _init_complete:
			return
		var js_code: String = "chedda_get_player_rank('%s')" % sort_by
		JavaScriptBridge.eval(js_code, true)
		_log("Player rank requested (sort: %s)" % sort_by)

## Get a player's full profile (Native API)
func get_player_profile(player_id: String = "") -> void:
	var pid = player_id if player_id != "" else get_player_id()
	if _is_web:
		# Web uses refresh_profile instead
		refresh_profile()
	else:
		var url = "/players/%s/profile" % pid.uri_encode()
		_make_http_request(url, HTTPClient.METHOD_GET, {}, "player_profile")
		_log("Player profile requested (HTTP)")

# ============================================================
# PUBLIC API - ACHIEVEMENTS
# ============================================================

## Unlock a single achievement
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
		# Native: Use HTTP API
		var body = {
			"playerId": get_player_id(),
			"achievementId": achievement_id
		}
		_make_http_request("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement")
		_log("Achievement unlock (HTTP): %s" % achievement_id)

## Get all achievements for a player
func get_achievements(player_id: String = "") -> void:
	var pid = player_id if player_id != "" else get_player_id()
	if _is_web:
		# Web: achievements come with profile
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
	
	# Build achievement IDs array
	var ach_ids: Array = []
	for ach in achievements:
		if typeof(ach) == TYPE_STRING:
			ach_ids.append(ach)
		elif typeof(ach) == TYPE_DICTIONARY:
			var ach_id = str(ach.get("id", ""))
			if ach_id != "":
				ach_ids.append(ach_id)
	
	# Anonymous users (web or native): just submit score via HTTP, skip achievements for now
	if is_anonymous():
		_log("Anonymous user - submitting score only (achievements disabled)")
		var score_body = {
			"playerId": get_player_id(),
			"score": score,
			"streak": streak,
			"nickname": _nickname if _nickname != "" else _get_default_nickname()
		}
		_make_http_request("/scores", HTTPClient.METHOD_POST, score_body, "submit_score")
		return
	
	# Authenticated web: use JS bridge with achievements
	if _is_web:
		_log("Submitting score with %d achievements" % ach_ids.size())
		var ach_json = JSON.stringify(ach_ids)
		var js_code = "chedda_submit_score(%d, %d, %s)" % [score, streak, ach_json]
		_log("Calling JS: %s" % js_code)
		JavaScriptBridge.eval(js_code, true)
		return
	
	# Authenticated native: use HTTP with achievements
	_log("Submitting score with %d achievements (HTTP)" % ach_ids.size())
	for ach_id in ach_ids:
		var body = {
			"playerId": get_player_id(),
			"achievementId": ach_id
		}
		_make_http_request("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement")
	
	var score_body = {
		"playerId": get_player_id(),
		"score": score,
		"streak": streak,
		"nickname": _nickname if _nickname != "" else _get_default_nickname()
	}
	_make_http_request("/scores", HTTPClient.METHOD_POST, score_body, "submit_score")
# ============================================================
# PUBLIC API - ANALYTICS
# ============================================================

## Track a custom event (for analytics)
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
		# Native: Could implement event tracking endpoint
		_log("Event tracked (local): %s" % event_type)

# ============================================================
# PUBLIC API - GAME INFO (Native HTTP API)
# ============================================================

## Get game info
func get_game_info() -> void:
	if _is_native:
		_make_http_request("/game", HTTPClient.METHOD_GET, {}, "game_info")

## Get game statistics
func get_game_stats() -> void:
	if _is_native:
		_make_http_request("/game/stats", HTTPClient.METHOD_GET, {}, "game_stats")

## Health check - verify API connection
func health_check() -> void:
	if _is_native:
		_make_http_request("/health", HTTPClient.METHOD_GET, {}, "health")

# ============================================================
# HELPER FUNCTIONS
# ============================================================

## Force check for pending events or auth status (Web only)
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

## Get profile data directly from JavaScript cache (Web only)
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

## Print debug information to console
func debug_status() -> void:
	print("")
	print("╔══════════════════════════════════════════════╗")
	print("║        CheddaBoards Debug Status v1.2.1      ║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Environment                                  ║")
	print("║  - Platform:         %s" % ("Web" if _is_web else "Native").rpad(24) + "║")
	print("║  - Init Complete:    %s" % str(_init_complete).rpad(24) + "║")
	print("║  - Init Attempts:    %s" % str(_init_attempts).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Authentication                               ║")
	print("║  - Authenticated:    %s" % str(is_authenticated()).rpad(24) + "║")
	print("║  - Auth Type:        %s" % _auth_type.rpad(24) + "║")
	if _is_native:
		print("║  - API Key Set:      %s" % str(not api_key.is_empty()).rpad(24) + "║")
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
	print("║  - Login Timeout:    %s" % str(_login_timeout_timer != null).rpad(24) + "║")
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
	"""Clean up timers on exit"""
	if _poll_timer:
		_poll_timer.stop()
		_poll_timer.queue_free()
	_clear_login_timeout()
