# CheddaBoards.gd v2.2.3 (Godot 3.6 Backport)
# CheddaBoards integration for Godot 3.x
# https://github.com/cheddatech/CheddaBoards-Godot
# https://cheddaboards.com
#
# HTTP-ONLY SDK: All platforms use the REST API
# - Anonymous login: API key + persistent device ID
# - Social login (Google, Apple, II): Device Code Auth flow
#   Player authenticates on their phone at cheddaboards.com/link
# - Score submissions, play sessions, achievements: all via HTTP API
#
# v2.2.3-3x: Backport of v2.2.3 session persistence + the v2.2.4 nickname
#             validation. The session token from device code auth is saved to
#             user://cheddaboards_session.cfg and restored on startup, so
#             logged-in players stay logged in across restarts. New
#             session_expired signal fires when the server rejects the stored
#             token (401/403); the saved session is cleared and logout_success
#             also fires so existing menus fall back to their login screen
#             unchanged. logout() clears the saved session file.
#             change_nickname() now enforces the canonical nickname rule
#             client-side (3-16 chars, letters/numbers/underscores), matching
#             proxy and canister validation.
# v2.2.1-3x: Backported submit_score_to_board(scoreboard_id, score, streak)
#             for targeted "category" scoreboards (per-level / per-mode boards).
#             Writes to one board only; does not fan out or touch the player's
#             profile total. Emits score_submitted_to_board on success. The
#             board must be configured as targeted in the dashboard.
#             This port is now at full feature parity with the Godot 4.x v2.2.1
#             SDK — identical signals, public methods, and response handling.
# v2.2.0-3x: Backport of the v2.2.0 batch — profile_loaded emits play_count as
#             a 5th argument (breaking change for 4-arg handlers); SDK keeps
#             processing while the tree is paused (PAUSE_MODE_PROCESS); debug
#             logging defaults OFF (set debug_logging = true); device codes and
#             emails redacted in logs; device-code polling fires an immediate
#             poll on focus regain; empty nicknames preserved (UIs show "Guest");
#             get_nickname() filters Player_dev_* / Player_p_* placeholders;
#             refresh_profile() allows the first call before the cooldown applies;
#             404 on scoreboard lookups treated as non-fatal.
# v2.1.0-3x: Godot 3.6 backport of the HTTP-only v2.1.0 SDK.
#             Identical API surface to the Godot 4.x version.
#             GD4 syntax (await, typed signals, lambdas, PackedArrays)
#             converted to GD3 equivalents (yield, untyped signals,
#             named callbacks, PoolArrays).
#
# v2.1.0: device_code_received now emits qr_data_url as third argument.
# v2.0.0: HTTP-only SDK. Removed JavaScript bridge / web SDK dependency.
# v1.9.0: Device Code Auth - cross-platform social login via REST API.
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
# Anonymous login (play immediately):
#    func _ready():
#        yield(CheddaBoards.wait_until_ready(), "completed")
#        CheddaBoards.connect("login_success", self, "_on_login")
#        CheddaBoards.login_anonymous("PlayerName")
#
# Social login (Google/Apple via device code):
#    func _ready():
#        yield(CheddaBoards.wait_until_ready(), "completed")
#        CheddaBoards.connect("device_code_received", self, "_on_code")
#        CheddaBoards.connect("device_code_approved", self, "_on_approved")
#        CheddaBoards.login_with_device_code()
#
#    func _on_code(user_code, url, qr_data_url):
#        $CodeLabel.text = "Go to %s\nEnter code: %s" % [url, user_code]
#
#    func _on_approved(nickname):
#        print("Welcome %s!" % nickname)
#
# Score submission:
#    func _on_game_over(score, streak):
#        CheddaBoards.submit_score(score, streak)
#
# ============================================================

# ============================================================
# SIGNALS
# ============================================================

# --- Initialization ---
signal sdk_ready()
signal init_error(reason)

# --- Authentication ---
signal login_success(nickname)
signal login_failed(reason)
signal logout_success()
signal session_expired()
signal auth_error(reason)

# --- Profile ---
signal profile_loaded(nickname, score, streak, achievements, play_count)
signal no_profile()
signal nickname_changed(new_nickname)
signal nickname_error(reason)

# --- Scores & Leaderboards (Legacy) ---
signal score_submitted(score, streak)
signal score_submitted_to_board(scoreboard_id, score, streak)
signal score_error(reason)
signal leaderboard_loaded(entries)
signal player_rank_loaded(rank, score, streak, total_players)
signal rank_error(reason)

# --- Scoreboards (Time-based) ---
signal scoreboards_loaded(scoreboards)
signal scoreboard_loaded(scoreboard_id, config, entries)
signal scoreboard_rank_loaded(scoreboard_id, rank, score, streak, total)
signal scoreboard_error(reason)

# --- Scoreboard Archives ---
signal archives_list_loaded(scoreboard_id, archives)
signal archived_scoreboard_loaded(archive_id, config, entries)
signal archive_stats_loaded(total_archives, by_scoreboard)
signal archive_error(reason)

# --- Achievements ---
signal achievement_unlocked(achievement_id)
signal achievements_loaded(achievements)

# --- HTTP API ---
signal request_failed(endpoint, error)

# --- Play Sessions (Time Validation) ---
signal play_session_started(token)
signal play_session_error(reason)

# --- Account Upgrade (Anonymous -> Verified) ---
signal account_upgraded(profile, migration)
signal account_upgrade_failed(reason)

# --- Device Code Auth (Cross-platform login) ---
signal device_code_received(user_code, verification_url, qr_data_url)
signal device_code_approved(nickname)
signal device_code_expired()
signal device_code_error(reason)

# ============================================================
# CONFIGURATION
# ============================================================

## Verbose logging toggle. Off by default in the public SDK so integrating
## games don't get noisy stdout out of the box. Flip to true while developing
## or when investigating an issue:
##     CheddaBoards.debug_logging = true
## All _log() calls are gated by this flag; push_error / push_warning for
## genuine failures fire regardless.
var debug_logging: bool = false

## HTTP API Configuration
const API_BASE_URL = "https://api.cheddaboards.com"
## Your API key from the CheddaBoards developer dashboard.
## Set via set_api_key() at runtime, or paste below for quick prototyping.
## ⚠️ PRE-PUBLISH: clear this to "" before pushing the SDK to GitHub —
##    these are The Cheese Game's credentials, not for public distribution.
var api_key: String = "cb_your-game_xxxxxxxxxx"
## Your game ID from the developer dashboard.
## Set via set_game_id() at runtime, or paste below for quick prototyping.
## ⚠️ PRE-PUBLISH: clear this to "" before pushing the SDK to GitHub.
var game_id: String = "the-cheese-game"
var _player_id: String = ""
var _session_token: String = ""    ## For OAuth session-based auth
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
# HTTP REQUEST (queue-based, single main HTTPRequest)
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
const SESSION_PATH = "user://cheddaboards_session.cfg"

# ============================================================
# INITIALIZATION
# ============================================================

func _ready():
	# SDK must keep running when the game pauses the scene tree (e.g.
	# during a game-over continue screen). Otherwise HTTP responses
	# land silently, signals never fire, and in-flight submits appear
	# to hang indefinitely.
	pause_mode = Node.PAUSE_MODE_PROCESS
	_setup_http_client()
	_log("Initializing CheddaBoards v2.2.3-3x (HTTP API Mode)...")
	_load_saved_session()
	_init_complete = true
	call_deferred("_emit_sdk_ready")

func _emit_sdk_ready():
	emit_signal("sdk_ready")

func _setup_http_client():
	_http_request = HTTPRequest.new()
	_http_request.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_http_request)
	_http_request.connect("request_completed", self, "_on_http_request_completed")

# ============================================================
# ASYNC HTTP (fire-and-forget, for achievements)
# ============================================================

func _make_http_request_async(endpoint: String, method: int, body: Dictionary, request_type: String) -> void:
	if api_key.empty() and _session_token.empty():
		_log("No credentials - skipping async request to %s" % endpoint)
		return

	var http = HTTPRequest.new()
	http.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(http)

	var headers = _build_headers(request_type)
	var url = API_BASE_URL + endpoint
	var json_body = to_json(body) if body.size() > 0 else ""

	_log("HTTP async %s: %s" % [request_type, endpoint])

	# GD3: can't use lambdas, use bind + named callback
	http.connect("request_completed", self, "_on_async_request_completed", [http, request_type])

	var error = http.request(url, headers, true, method, json_body)
	if error != OK:
		_log("Async request failed to start: %s" % error)
		http.queue_free()

func _on_async_request_completed(_result: int, code: int, _headers: PoolStringArray, _body: PoolByteArray, http: HTTPRequest, request_type: String) -> void:
	if code >= 200 and code < 300:
		_log("Async %s complete (HTTP %d)" % [request_type, code])
	else:
		_log("Async %s failed (HTTP %d)" % [request_type, code])
	if is_instance_valid(http):
		http.queue_free()

# ============================================================
# HTTP HELPERS
# ============================================================

func _build_headers(request_type: String = "") -> PoolStringArray:
	var headers: PoolStringArray = PoolStringArray()
	headers.append("Content-Type: application/json")

	# Session token takes priority over API key (mutually exclusive)
	# EXCEPT: play sessions always use API key (game-level operation)
	var force_api_key = request_type in ["start_play_session", "end_play_session"] and _session_token.empty()
	if not _session_token.empty() and not force_api_key:
		headers.append("X-Session-Token: " + _session_token)
	elif not api_key.empty():
		headers.append("X-API-Key: " + api_key)

	if not game_id.empty():
		headers.append("X-Game-ID: " + game_id)

	return headers

# ============================================================
# HTTP RESPONSE HANDLER
# ============================================================

func _on_http_request_completed(result: int, response_code: int, _headers: PoolStringArray, body: PoolByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[CheddaBoards] Request failed with result %d" % result)
		emit_signal("request_failed", _current_endpoint, "Network error")
		_emit_http_failure("Network error")
		return

	var json_result = JSON.parse(body.get_string_from_utf8())

	if json_result.error != OK:
		push_error("[CheddaBoards] Failed to parse JSON response")
		emit_signal("request_failed", _current_endpoint, "Invalid JSON response")
		_emit_http_failure("Invalid JSON response")
		return

	var response = json_result.result

	if response_code != 200:
		var error_msg = response.get("error", "Unknown error") if typeof(response) == TYPE_DICTIONARY else "Unknown error"
		# Server rejected our session token - expire it so the game
		# falls back to the login screen instead of erroring forever
		if response_code in [401, 403] and not _session_token.empty():
			_expire_session()
			_emit_http_failure(error_msg)
			_current_meta = {}
			_http_busy = false
			_process_next_request()
			return
		# 404 on profile lookup is expected for new players
		if response_code == 404 and _current_endpoint == "player_profile":
			_log("Player profile not found (new player) - normal for first-time players")
			_is_refreshing_profile = false
			emit_signal("no_profile")
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
		# 404 on scoreboard lookup - scoreboard doesn't exist for this game (non-fatal)
		if response_code == 404 and _current_endpoint in ["get_scoreboard", "scoreboard_rank", "list_scoreboards"]:
			_log("Scoreboard not found (404) - may not be configured for this game")
			_emit_http_failure(error_msg)
			return
		push_error("[CheddaBoards] API error (%d): %s" % [response_code, error_msg])
		emit_signal("request_failed", _current_endpoint, error_msg)
		_emit_http_failure(error_msg)
		return

	if not response.get("ok", false):
		var error_msg = response.get("error", "Unknown error")
		emit_signal("request_failed", _current_endpoint, error_msg)
		_emit_http_failure(error_msg)
		return

	var data = response.get("data", {})
	_emit_http_success(data)

func _emit_http_success(data) -> void:
	match _current_endpoint:
		"submit_score":
			_is_submitting_score = false
			_log("Score submission successful: %d points, %d streak" % [_pending_score, _pending_streak])
			emit_signal("score_submitted", _pending_score, _pending_streak)
			_flush_deferred_achievements()

		"submit_score_to_board":
			var sb_id = _current_meta.get("scoreboard_id", "")
			var sb_score = _safe_int(_current_meta.get("score", 0))
			var sb_streak = _safe_int(_current_meta.get("streak", 0))
			_log("Targeted submit to '%s' successful: %d points, %d streak" % [sb_id, sb_score, sb_streak])
			emit_signal("score_submitted_to_board", sb_id, sb_score, sb_streak)

		"leaderboard":
			var entries = data.get("leaderboard", [])
			emit_signal("leaderboard_loaded", entries)

		"player_rank":
			var rank = _safe_int(data.get("rank", 0))
			var score_val = _safe_int(data.get("score", 0))
			var streak_val = _safe_int(data.get("streak", 0))
			var total = _safe_int(data.get("totalPlayers", 0))
			emit_signal("player_rank_loaded", rank, score_val, streak_val, total)

		"player_profile":
			_is_refreshing_profile = false
			if data and not data.empty():
				_update_cached_profile(data)
			else:
				emit_signal("no_profile")

		"change_nickname":
			var new_nick = str(data.get("nickname", ""))
			if new_nick != "":
				_nickname = new_nick
				_nickname_just_changed = true
				if not _cached_profile.empty():
					_cached_profile["nickname"] = new_nick
				emit_signal("nickname_changed", new_nick)
				_log("Nickname changed to: %s" % new_nick)

		"change_nickname_anonymous":
			var new_nick = str(data.get("nickname", ""))
			if new_nick != "":
				_nickname = new_nick
				_nickname_just_changed = true
				if not _cached_profile.empty():
					_cached_profile["nickname"] = new_nick
				emit_signal("nickname_changed", new_nick)
				_log("Anonymous nickname changed to: %s" % new_nick)
			get_player_profile()

		"unlock_achievement":
			var ach_id = str(data.get("achievementId", ""))
			emit_signal("achievement_unlocked", ach_id)
			if _deferred_achievements_remaining > 0:
				_deferred_achievements_synced.append(ach_id)
				_deferred_achievements_remaining -= 1
				_log("Achievement synced: %s (%d remaining)" % [ach_id, _deferred_achievements_remaining])
				if _deferred_achievements_remaining <= 0:
					_log("All deferred achievements done: %d synced" % _deferred_achievements_synced.size())
					emit_signal("achievements_loaded", _deferred_achievements_synced.duplicate())
					_deferred_achievements_synced.clear()

		"unlock_achievement_batch":
			var synced = data.get("synced", 0)
			var results = data.get("results", [])
			_log("Batch achievement sync complete: %d synced" % synced)
			for result in results:
				if result.get("success", false):
					var ach_id = str(result.get("achievementId", ""))
					_deferred_achievements_synced.append(ach_id)
					emit_signal("achievement_unlocked", ach_id)
			emit_signal("achievements_loaded", _deferred_achievements_synced.duplicate())
			_deferred_achievements_synced.clear()
			_deferred_achievements_remaining = 0

		"achievements":
			var achievements = data.get("achievements", [])
			emit_signal("achievements_loaded", achievements)

		"list_scoreboards":
			var scoreboards = data.get("scoreboards", [])
			emit_signal("scoreboards_loaded", scoreboards)
			_log("Loaded %d scoreboards" % scoreboards.size())

		"get_scoreboard":
			var sb_id = _current_meta.get("scoreboard_id", "")
			var config = data.get("config", {})
			var entries = data.get("entries", [])
			emit_signal("scoreboard_loaded", sb_id, config, entries)
			_log("Loaded scoreboard '%s' with %d entries" % [sb_id, entries.size()])

		"scoreboard_rank":
			var sb_id = _current_meta.get("scoreboard_id", "")
			var found = data.get("found", false)
			if found:
				var rank = _safe_int(data.get("rank", 0))
				var score_val = _safe_int(data.get("score", 0))
				var streak_val = _safe_int(data.get("streak", 0))
				var total = _safe_int(data.get("totalPlayers", 0))
				emit_signal("scoreboard_rank_loaded", sb_id, rank, score_val, streak_val, total)
			else:
				emit_signal("scoreboard_rank_loaded", sb_id, 0, 0, 0, _safe_int(data.get("totalPlayers", 0)))

		"list_archives":
			var sb_id = _current_meta.get("scoreboard_id", "")
			var archives = data.get("archives", [])
			emit_signal("archives_list_loaded", sb_id, archives)
			_log("Loaded %d archives for '%s'" % [archives.size(), sb_id])

		"get_archive", "get_last_archive":
			var archive_id = data.get("archiveId", _current_meta.get("archive_id", ""))
			var config = data.get("config", {})
			var entries = data.get("entries", [])
			emit_signal("archived_scoreboard_loaded", archive_id, config, entries)
			_log("Loaded archive '%s' with %d entries" % [archive_id, entries.size()])

		"archive_stats":
			var total = _safe_int(data.get("totalArchives", 0))
			var by_sb = data.get("byScoreboard", [])
			emit_signal("archive_stats_loaded", total, by_sb)
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
				emit_signal("play_session_error", err)
				_current_meta = {}
				_http_busy = false
				_process_next_request()
				return
			_log("Play session started: %s" % _play_session_token.left(30))
			emit_signal("play_session_started", _play_session_token)

		"end_play_session":
			_log("Play session ended on server successfully")

		"migrate_account":
			var migrated_games = _safe_int(data.get("migratedGames", 0))
			var migrated_sb = _safe_int(data.get("migratedScoreboards", 0))
			_log("Migration complete: %d games, %d scoreboards migrated" % [migrated_games, migrated_sb])
			refresh_profile()
			emit_signal("account_upgraded", _cached_profile, {
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
			_device_code_expires_at = OS.get_unix_time() + float(expires_in)

			var qr_data_url = str(data.get("qr_data_url", ""))

			_log("Device code received: %s (expires in %ds)" % [_redact_code(uc), expires_in])
			emit_signal("device_code_received", uc, url_complete if url_complete != "" else url, qr_data_url)
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
			emit_signal("score_error", error)
		"submit_score_to_board":
			var sb_id = _current_meta.get("scoreboard_id", "")
			_log("Targeted submit to '%s' failed: %s" % [sb_id, error])
			emit_signal("score_error", error)
		"leaderboard":
			emit_signal("leaderboard_loaded", [])
		"player_rank":
			emit_signal("rank_error", error)
		"player_profile":
			_is_refreshing_profile = false
			emit_signal("no_profile")
		"change_nickname", "change_nickname_anonymous":
			emit_signal("nickname_error", error)
		"unlock_achievement":
			if _deferred_achievements_remaining > 0:
				_deferred_achievements_remaining -= 1
				_log("Achievement unlock failed (%d remaining)" % _deferred_achievements_remaining)
				if _deferred_achievements_remaining <= 0:
					emit_signal("achievements_loaded", _deferred_achievements_synced.duplicate())
					_deferred_achievements_synced.clear()
		"unlock_achievement_batch":
			_log("Batch achievement sync failed: %s" % error)
			emit_signal("achievements_loaded", [])
			_deferred_achievements_synced.clear()
			_deferred_achievements_remaining = 0
		"achievements":
			emit_signal("achievements_loaded", [])
		"list_scoreboards":
			emit_signal("scoreboards_loaded", [])
			emit_signal("scoreboard_error", error)
		"get_scoreboard":
			var sb_id = _current_meta.get("scoreboard_id", "")
			emit_signal("scoreboard_loaded", sb_id, {}, [])
			emit_signal("scoreboard_error", error)
		"scoreboard_rank":
			var sb_id = _current_meta.get("scoreboard_id", "")
			emit_signal("scoreboard_rank_loaded", sb_id, 0, 0, 0, 0)
			emit_signal("scoreboard_error", error)
		"list_archives":
			var sb_id = _current_meta.get("scoreboard_id", "")
			emit_signal("archives_list_loaded", sb_id, [])
			emit_signal("archive_error", error)
		"get_archive", "get_last_archive":
			var archive_id = _current_meta.get("archive_id", "")
			emit_signal("archived_scoreboard_loaded", archive_id, {}, [])
			emit_signal("archive_error", error)
		"start_play_session":
			_log("Play session error: %s" % error)
			emit_signal("play_session_error", error)
		"end_play_session":
			_log("End play session error (ignored): %s" % error)
		"device_code_request":
			_log("Device code request failed: %s" % error)
			emit_signal("device_code_error", error)
		"archive_stats":
			emit_signal("archive_stats_loaded", 0, [])
			emit_signal("archive_error", error)

	_current_meta = {}
	_http_busy = false
	_process_next_request()

func _make_http_request(endpoint: String, method: int, body: Dictionary, request_type: String, meta: Dictionary = {}) -> void:
	if api_key.empty() and _session_token.empty():
		_log("No credentials set - skipping HTTP request to %s" % endpoint)
		match request_type:
			"submit_score", "submit_score_to_board":
				emit_signal("score_error", "No credentials set")
			"player_profile":
				emit_signal("no_profile")
			"leaderboard":
				emit_signal("leaderboard_loaded", [])
			"player_rank":
				emit_signal("rank_error", "No credentials set")
			"list_scoreboards", "get_scoreboard":
				emit_signal("scoreboard_error", "No credentials set")
			"list_archives", "get_archive", "get_last_archive", "archive_stats":
				emit_signal("archive_error", "No credentials set")
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
	var json_body = to_json(request_data.body) if request_data.body.size() > 0 else ""

	var method_str = "GET"
	if request_data.method == HTTPClient.METHOD_POST:
		method_str = "POST"
	elif request_data.method == HTTPClient.METHOD_PUT:
		method_str = "PUT"
	elif request_data.method == HTTPClient.METHOD_DELETE:
		method_str = "DELETE"
	_log("HTTP %s: %s" % [method_str, url])

	var error: int
	if request_data.method == HTTPClient.METHOD_GET:
		error = _http_request.request(url, headers, true, request_data.method)
	else:
		error = _http_request.request(url, headers, true, request_data.method, json_body)

	if error != OK:
		push_error("[CheddaBoards] HTTP request failed to start: %s" % error)
		emit_signal("request_failed", request_data.endpoint, "Request failed to start: %s" % error)
		_http_busy = false
		_process_next_request()

func _process_next_request() -> void:
	if _request_queue.empty():
		return

	var next_request = _request_queue.pop_front()
	_log("Processing queued request: %s" % next_request.request_type)
	_execute_http_request(next_request)

# ============================================================
# PROFILE MANAGEMENT
# ============================================================

func _update_cached_profile(profile: Dictionary) -> void:
	if profile.empty():
		return

	# Preserve nickname from recent rename - backend may return stale data
	if _nickname_just_changed and not _nickname.empty():
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

	if game_profile and not game_profile.empty():
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
	emit_signal("profile_loaded", nickname, score, streak, achievements, play_count)

# ============================================================
# LOGGING
# ============================================================

func _log(message: String) -> void:
	if debug_logging:
		print("[CheddaBoards] %s" % message)

# Redact a user-facing device code for logging. Shows the first 3 chars
# so a developer can still correlate logs with what they see on screen,
# but doesn't reveal the full code which is what an attacker would
# brute-force during the 5-minute approval window.
func _redact_code(code: String) -> String:
	if code.length() <= 3:
		return "***"
	return code.left(3) + "***"

# Redact an email address for logging. Keeps the first character of the
# local part and the full domain so developers can still tell which user
# they're looking at without exposing the full address.
func _redact_email(email: String) -> String:
	if email.empty():
		return "(none)"
	var at_idx = email.find("@")
	if at_idx <= 1:
		return "***" + email.substr(at_idx) if at_idx > 0 else "***"
	return email.left(1) + "***" + email.substr(at_idx)

# ============================================================
# PUBLIC API - UTILITIES
# ============================================================

func is_ready() -> bool:
	return _init_complete

func can_connect() -> bool:
	return _init_complete and (not api_key.empty() or not _session_token.empty())

func wait_until_ready():
	"""Coroutine: yield(CheddaBoards.wait_until_ready(), 'completed')"""
	if is_ready():
		return
	yield(self, "sdk_ready")

func _safe_int(value) -> int:
	if value == null:
		return 0
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_REAL:
		return int(value)
	if typeof(value) == TYPE_STRING:
		if value.is_valid_integer():
			return int(value)
		if value.is_valid_float():
			return int(float(value))
		return 0
	return 0

func _get_default_nickname() -> String:
	return "Player_" + get_player_id().left(6)

func get_nickname() -> String:
	if _nickname != "" and not _nickname.begins_with("Player_p_") and not _nickname.begins_with("Player_dev_"):
		return _nickname

	if not _cached_profile.empty():
		var profile_nick = str(_cached_profile.get("nickname", ""))
		if profile_nick != "" and not profile_nick.begins_with("Player_p_") and not profile_nick.begins_with("Player_dev_"):
			return profile_nick

	# Return empty string — callers should show "Guest" for unnamed anonymous players
	return ""

func get_high_score() -> int:
	if _cached_profile.empty():
		return 0
	if _cached_profile.has("score"):
		return _safe_int(_cached_profile.get("score", 0))
	var gp = _cached_profile.get("gameProfile", {})
	if gp and not gp.empty():
		return _safe_int(gp.get("score", 0))
	return 0

func get_best_streak() -> int:
	if _cached_profile.empty():
		return 0
	if _cached_profile.has("streak"):
		return _safe_int(_cached_profile.get("streak", 0))
	var gp = _cached_profile.get("gameProfile", {})
	if gp and not gp.empty():
		return _safe_int(gp.get("streak", 0))
	return 0

func get_play_count() -> int:
	if _cached_profile.empty():
		return 0
	if _cached_profile.has("playCount"):
		return _safe_int(_cached_profile.get("playCount", 0))
	var gp = _cached_profile.get("gameProfile", {})
	if gp and not gp.empty():
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
	_save_session()

func set_player_id(player_id: String) -> void:
	_player_id = _sanitize_player_id(player_id)
	_log("Player ID set: %s" % _player_id)

func get_player_id() -> String:
	if not _player_id.empty():
		return _player_id

	# Try loading saved device ID from disk
	var saved_id = _load_device_id()
	if saved_id != "":
		_player_id = saved_id
		_log("Loaded persistent device ID: %s" % _player_id.left(12))
		return _player_id

	# Generate new persistent device ID (first launch only)
	randomize()
	var timestamp = str(OS.get_unix_time()).replace(".", "")
	var random_part = "%08x" % (randi() & 0x7FFFFFFF)
	_player_id = "dev_" + timestamp + "_" + random_part
	_save_device_id(_player_id)
	_log("Generated new persistent device ID: %s" % _player_id)
	return _player_id

func _save_device_id(device_id: String) -> void:
	var config = ConfigFile.new()
	config.set_value("device", "id", device_id)
	config.set_value("device", "created", OS.get_unix_time())
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

# ============================================================
# SESSION PERSISTENCE (v2.2.3-3x)
# ============================================================
# The device-code session token is saved so players stay signed in
# across restarts. The stored token is validated lazily: it is
# restored optimistically and cleared if the server rejects it
# (401/403 -> session_expired).

func _save_session() -> void:
	if _session_token.empty():
		return
	var config = ConfigFile.new()
	config.set_value("session", "token", _session_token)
	config.set_value("session", "nickname", _nickname)
	config.set_value("session", "auth_type", _auth_type)
	config.set_value("session", "saved_at", OS.get_unix_time())
	var err = config.save(SESSION_PATH)
	if err == OK:
		_log("Session saved to %s" % SESSION_PATH)
	else:
		_log("WARNING: Failed to save session (error %d)" % err)

func _load_saved_session() -> void:
	var config = ConfigFile.new()
	var err = config.load(SESSION_PATH)
	if err != OK:
		return
	var token = str(config.get_value("session", "token", ""))
	if token.empty():
		return
	_session_token = token
	_nickname = str(config.get_value("session", "nickname", ""))
	_auth_type = str(config.get_value("session", "auth_type", "google"))
	_cached_profile = {"nickname": _nickname}
	_log("Restored saved session for %s (validated on first request)" % _nickname)

func _clear_saved_session() -> void:
	var file = File.new()
	if file.file_exists(SESSION_PATH):
		var dir = Directory.new()
		if dir.open("user://") == OK:
			dir.remove(SESSION_PATH.trim_prefix("user://"))
			_log("Saved session cleared")

func _expire_session() -> void:
	# Server rejected the stored session token - clear everything
	# and tell the game so it can return to its login screen.
	_log("Session expired or rejected by server - clearing")
	_session_token = ""
	_auth_type = ""
	_nickname = ""
	_cached_profile = {}
	_clear_saved_session()
	emit_signal("session_expired")
	emit_signal("logout_success")

func _sanitize_player_id(raw_id: String) -> String:
	if raw_id.empty():
		return get_player_id()

	var sanitized = ""
	for c in raw_id:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			sanitized += c

	if sanitized.empty():
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
	if api_key.empty():
		emit_signal("login_failed", "API key not set. Call set_api_key() first.")
		return

	# Only store a nickname if one was explicitly provided.
	# Do NOT auto-generate a placeholder — the UI will show "Guest" instead.
	_nickname = nickname if nickname != "" else ""
	_auth_type = "anonymous"
	emit_signal("login_success", _nickname)
	_log("Anonymous login: player=%s" % get_player_id())

## Social login (Google, Apple, etc.) via Device Code Auth
## Use login_with_device_code() instead - works on all platforms
func login_google(_id_token: String = "", _nickname: String = "") -> void:
	_log("Google login -> use login_with_device_code() for cross-platform social login")
	login_with_device_code()

## Social login (Google, Apple, etc.) via Device Code Auth
func login_apple(_identity_token: String = "", _auth_code: String = "", _user_info: Dictionary = {}, _nickname: String = "") -> void:
	_log("Apple login -> use login_with_device_code() for cross-platform social login")
	login_with_device_code()

## Internet Identity login via Device Code Auth
func login_internet_identity(_nickname: String = "") -> void:
	_log("II login -> use login_with_device_code() for cross-platform social login")
	login_with_device_code()

## Alias for login_internet_identity
func login_chedda_id(_nickname: String = "") -> void:
	login_internet_identity(_nickname)

func logout() -> void:
	_cached_profile = {}
	_auth_type = ""
	_nickname = ""
	_session_token = ""
	_play_session_token = ""
	_clear_saved_session()
	emit_signal("logout_success")
	_log("Logged out")

func is_authenticated() -> bool:
	if _auth_type == "anonymous":
		return true
	return not _session_token.empty()

func is_anonymous() -> bool:
	return _auth_type == "anonymous" or _session_token.empty()

func has_account() -> bool:
	return is_authenticated() and not is_anonymous()

## Convenience alias for MainMenu compatibility
func is_logged_in() -> bool:
	return is_authenticated()

func refresh_profile() -> void:
	if _is_refreshing_profile:
		return

	var current_time: float = OS.get_ticks_msec() / 1000.0
	# Skip cooldown on first-ever call (_last_profile_refresh == 0.0)
	if _last_profile_refresh > 0.0 and current_time - _last_profile_refresh < PROFILE_REFRESH_COOLDOWN:
		return

	_is_refreshing_profile = true
	_last_profile_refresh = current_time
	get_player_profile()
	_log("Profile refresh requested")

func change_nickname(new_nickname: String = "") -> void:
	# Canonical rule (matches proxy + canister): 3-16 chars, letters/numbers/underscores.
	if new_nickname.empty() or new_nickname.length() < 3:
		emit_signal("nickname_error", "Nickname must be at least 3 characters")
		return
	if new_nickname.length() > 16:
		emit_signal("nickname_error", "Nickname must be 16 characters or less")
		return
	for c in new_nickname:
		if "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".find(c) == -1:
			emit_signal("nickname_error", "Nickname can only contain letters, numbers, and underscores")
			return

	# Anonymous players who haven't submitted a score yet don't exist on backend
	if is_anonymous() and _cached_profile.empty():
		_nickname = new_nickname
		_log("Nickname set locally (no backend profile yet): %s" % new_nickname)
		emit_signal("nickname_changed", new_nickname)
		return

	if not _session_token.empty():
		# Authenticated users - session token path
		var body = {"nickname": new_nickname}
		_make_http_request("/profile/nickname", HTTPClient.METHOD_PUT, body, "change_nickname")
		_log("Nickname change requested (session) -> %s" % new_nickname)
	elif not api_key.empty():
		# Anonymous/API-key users
		var pid = get_player_id()
		if pid.empty():
			emit_signal("nickname_error", "No player ID set")
			return
		var body = {"nickname": new_nickname}
		var url = "/players/%s/nickname" % pid.percent_encode()
		_make_http_request(url, HTTPClient.METHOD_PUT, body, "change_nickname_anonymous")
		_log("Nickname change requested (API) for: %s -> %s" % [pid, new_nickname])
	else:
		emit_signal("nickname_error", "Not authenticated")

# ============================================================
# PUBLIC API - DEVICE CODE AUTH (Cross-platform social login)
# ============================================================

func login_with_device_code() -> void:
	if not _init_complete:
		emit_signal("device_code_error", "CheddaBoards not ready")
		return

	if game_id.empty():
		emit_signal("device_code_error", "Game ID not set. Call set_game_id() first.")
		return

	_stop_device_code_polling()

	_log("Requesting device code for game: %s" % game_id)
	var body = {"gameId": game_id}
	_make_http_request("/auth/device/code", HTTPClient.METHOD_POST, body, "device_code_request")

func cancel_device_code() -> void:
	_stop_device_code_polling()
	_device_code = ""
	_device_user_code = ""
	_log("Device code login cancelled")

func get_device_user_code() -> String:
	return _device_user_code

func is_device_code_pending() -> bool:
	return _is_polling_device_code and _device_code != ""

# ============================================================
# DEVICE CODE POLLING (Internal)
# ============================================================

# When the app regains focus (e.g. user comes back to the game after
# completing the link.html flow on a phone browser or second window),
# fire an immediate poll. Without this, the next poll could be up to
# _device_code_poll_interval seconds away (default 5s), so the user
# experiences a "popup still hanging" delay after successful linking.
# Standard RFC 8628 polling cadence allows out-of-schedule polls.
#
# Notification IDs used here:
#   1004 = NOTIFICATION_WM_FOCUS_IN     (desktop/web window regained focus)
#   1014 = NOTIFICATION_APP_RESUMED     (mobile app foregrounded)
# Using raw integers for forward-compat across Godot 3.x patch versions.
func _notification(what: int) -> void:
	if not _is_polling_device_code:
		return
	if what == 1004 or what == 1014:
		_log("App regained focus during device code linking — polling immediately")
		# Restart the timer so the next scheduled poll is N seconds from
		# *now*, not from the last paused scheduled tick.
		if _device_code_poll_timer and is_instance_valid(_device_code_poll_timer):
			_device_code_poll_timer.start()
		# Fire one immediate poll out-of-cadence.
		call_deferred("_poll_device_code_token")

func _start_device_code_polling() -> void:
	_stop_device_code_polling()
	_is_polling_device_code = true
	_device_code_poll_in_flight = false
	_device_code_approved = false

	_device_code_poll_timer = Timer.new()
	_device_code_poll_timer.pause_mode = Node.PAUSE_MODE_PROCESS
	_device_code_poll_timer.wait_time = _device_code_poll_interval
	_device_code_poll_timer.autostart = true
	_device_code_poll_timer.connect("timeout", self, "_poll_device_code_token")
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
	if not _is_polling_device_code or _device_code.empty():
		_stop_device_code_polling()
		return

	if _device_code_poll_in_flight:
		return

	# Check expiry
	if OS.get_unix_time() >= _device_code_expires_at:
		_log("Device code expired: %s" % _redact_code(_device_user_code))
		_stop_device_code_polling()
		_device_code = ""
		_device_user_code = ""
		emit_signal("device_code_expired")
		return

	_device_code_poll_in_flight = true

	var http = HTTPRequest.new()
	http.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(http)

	var headers: PoolStringArray = PoolStringArray()
	headers.append("Content-Type: application/json")
	if not game_id.empty():
		headers.append("X-Game-ID: " + game_id)

	var body = to_json({"device_code": _device_code})
	var url = API_BASE_URL + "/auth/device/token"

	# GD3: named callback with bind
	http.connect("request_completed", self, "_on_device_code_poll_completed", [http])

	var error = http.request(url, headers, true, HTTPClient.METHOD_POST, body)
	if error != OK:
		_log("Device code poll request failed to start")
		_device_code_poll_in_flight = false
		http.queue_free()

func _on_device_code_poll_completed(result: int, response_code: int, _headers: PoolStringArray, body: PoolByteArray, http: HTTPRequest) -> void:
	_device_code_poll_in_flight = false
	_handle_device_code_poll_response(result, response_code, body)
	if is_instance_valid(http):
		http.queue_free()

func _handle_device_code_poll_response(result: int, response_code: int, body: PoolByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_log("Device code poll: network error")
		return

	if _device_code_approved:
		_log("Device code poll: ignoring response (already approved)")
		return

	var json_result = JSON.parse(body.get_string_from_utf8())
	if json_result.error != OK:
		_log("Device code poll: invalid JSON")
		return

	var response = json_result.result

	# 428 = authorization_pending (keep polling)
	if response_code == 428:
		return

	# 410 = expired
	if response_code == 410:
		_log("Device code expired (server confirmed)")
		_stop_device_code_polling()
		_device_code = ""
		_device_user_code = ""
		emit_signal("device_code_expired")
		return

	# 200 = approved!
	if response_code == 200 and response.get("ok", false):
		_device_code_approved = true
		_stop_device_code_polling()

		var data = response.get("data", {})
		var session_id = str(data.get("sessionId", ""))
		var nickname = str(data.get("nickname", "Player"))
		var email = str(data.get("email", ""))

		_log("Device code approved! User: %s (%s)" % [nickname, _redact_email(email)])

		# Save anonymous player ID BEFORE switching auth - needed for migration
		var previous_anonymous_id = _player_id
		var was_anonymous = _auth_type == "anonymous" and not previous_anonymous_id.empty()

		# Set session state
		_session_token = session_id
		_nickname = nickname
		_auth_type = "google"  # Provider determined by what they chose on the page
		_save_session()

		# Clear stale anonymous play session
		if _play_session_token != "":
			_log("Clearing stale anonymous play session after device code auth")
			_play_session_token = ""

		# Cache profile data
		var game_profile = data.get("gameProfile", null)
		if game_profile and typeof(game_profile) == TYPE_DICTIONARY:
			_update_cached_profile({
				"nickname": nickname,
				"gameProfile": game_profile,
			})
		else:
			_cached_profile = {"nickname": nickname}
			emit_signal("profile_loaded", nickname, 0, 0, [], 0)

		# Clear device code state
		_device_code = ""
		_device_user_code = ""

		# Emit both signals so existing login flows work
		emit_signal("device_code_approved", nickname)
		emit_signal("login_success", nickname)

		# Auto-migrate anonymous data -> new account
		if was_anonymous:
			_migrate_anonymous_account(previous_anonymous_id)

		return

	# 404 = invalid code (or already consumed)
	if response_code == 404:
		if _device_code_approved or _device_code.empty():
			_log("Device code poll: 404 after approval (ignoring)")
			return
		_log("Device code invalid or expired")
		_stop_device_code_polling()
		_device_code = ""
		_device_user_code = ""
		emit_signal("device_code_error", "Invalid or expired code")
		return

	# Other errors - log but keep polling
	var error_msg = str(response.get("error", "Unknown error"))
	_log("Device code poll error (%d): %s" % [response_code, error_msg])

# ============================================================
# ACCOUNT MIGRATION (Anonymous -> Verified)
# ============================================================

func _migrate_anonymous_account(anonymous_device_id: String) -> void:
	if anonymous_device_id.empty() or _session_token.empty():
		_log("Migration skipped: missing device ID or session token")
		return

	_log("Migrating anonymous data: %s -> authenticated account" % anonymous_device_id)
	var body = {"deviceId": anonymous_device_id}
	_make_http_request("/migrate-account", HTTPClient.METHOD_POST, body, "migrate_account")

func migrate_anonymous_to_current(anonymous_device_id: String) -> void:
	_migrate_anonymous_account(anonymous_device_id)

# ============================================================
# PUBLIC API - SCORES
# ============================================================

func submit_score(score: int, streak: int = 0) -> void:
	if not is_authenticated():
		_log("Not authenticated, cannot submit")
		emit_signal("score_error", "Not authenticated")
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
		emit_signal("score_error", "Not authenticated")
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
	_make_http_request("/scores", HTTPClient.METHOD_POST, score_body, "submit_score")

## Submit a score to ONE specific (targeted) scoreboard, by ID.
##
## Unlike submit_score(), this does NOT fan out to your all-time / weekly /
## daily boards and does NOT update the player's overall profile total. It
## writes to the named board only. The board must exist AND be configured as
## a "targeted" board in the dashboard, otherwise the backend returns an error.
##
## Use it for per-level, per-mode, or category leaderboards:
##     CheddaBoards.submit_score_to_board("level-14", score, streak)
##
## If the game has time validation enabled, start a play session first
## (start_play_session) exactly as you would for submit_score — the active
## play-session token is attached automatically when present.
##
## Emits score_submitted_to_board(scoreboard_id, score, streak) on success,
## or score_error(reason) on failure. Safe to call several times in a row for
## different boards; each call queues with its own values (it carries score /
## streak / board id in request meta rather than the shared _pending_* fields,
## so queued submits don't clobber each other).
func submit_score_to_board(scoreboard_id: String, score: int, streak: int = 0) -> void:
	if not is_authenticated():
		_log("Not authenticated, cannot submit to board")
		emit_signal("score_error", "Not authenticated")
		return

	if scoreboard_id.empty():
		emit_signal("score_error", "scoreboard_id is required")
		return

	var body = {
		"playerId": get_player_id(),
		"gameId": game_id,
		"score": score,
		"streak": streak,
		"nickname": _nickname if _nickname != "" else _get_default_nickname(),
		"scoreboardId": scoreboard_id
	}
	if _play_session_token != "":
		body["playSessionToken"] = _play_session_token

	_log("Submitting to board '%s': score=%d, streak=%d, player=%s" % [scoreboard_id, score, streak, body.playerId])
	_make_http_request("/scores", HTTPClient.METHOD_POST, body, "submit_score_to_board", {
		"scoreboard_id": scoreboard_id,
		"score": score,
		"streak": streak
	})

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
	var url = "/players/%s/rank?sort=%s" % [get_player_id().percent_encode(), sort_by]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "player_rank")
	_log("Player rank requested (sort: %s)" % sort_by)

func get_player_profile(player_id: String = "") -> void:
	if not _session_token.empty():
		# Authenticated users - use session profile endpoint
		_make_http_request("/auth/profile", HTTPClient.METHOD_GET, {}, "player_profile")
		_log("Player profile requested (session)")
	else:
		# Anonymous/API-key users
		var pid = player_id if player_id != "" else get_player_id()
		if pid.empty():
			_log("No player ID for profile fetch")
			emit_signal("no_profile")
			return
		var url = "/players/%s/profile" % pid.percent_encode()
		_make_http_request(url, HTTPClient.METHOD_GET, {}, "player_profile")
		_log("Player profile requested for: %s" % pid)

# ============================================================
# PUBLIC API - SCOREBOARDS (Time-based Leaderboards)
# ============================================================

func get_scoreboards(for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.empty():
		emit_signal("scoreboard_error", "Game ID not set. Call set_game_id() first.")
		return

	var url = "/games/%s/scoreboards" % gid.percent_encode()
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "list_scoreboards")
	_log("Scoreboards list requested for game: %s" % gid)

func get_scoreboard(scoreboard_id: String, limit: int = 100, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.empty():
		emit_signal("scoreboard_error", "Game ID not set. Call set_game_id() first.")
		return

	var url = "/games/%s/scoreboards/%s?limit=%d" % [gid.percent_encode(), scoreboard_id.percent_encode(), limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "get_scoreboard", {"scoreboard_id": scoreboard_id})
	_log("Scoreboard '%s' requested (limit: %d)" % [scoreboard_id, limit])

func get_scoreboard_rank(scoreboard_id: String, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.empty():
		emit_signal("scoreboard_error", "Game ID not set. Call set_game_id() first.")
		return

	if _session_token.empty():
		emit_signal("scoreboard_error", "Session token required for rank lookup")
		return

	var url = "/games/%s/scoreboards/%s/rank" % [gid.percent_encode(), scoreboard_id.percent_encode()]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "scoreboard_rank", {"scoreboard_id": scoreboard_id})
	_log("Scoreboard rank requested for '%s'" % scoreboard_id)

func get_weekly_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("weekly", limit, for_game_id)

func get_daily_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("daily", limit, for_game_id)

func get_alltime_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("all-time", limit, for_game_id)

func get_monthly_leaderboard(limit: int = 100, for_game_id: String = "") -> void:
	get_scoreboard("monthly", limit, for_game_id)

# ============================================================
# PUBLIC API - SCOREBOARD ARCHIVES
# ============================================================

func get_scoreboard_archives(scoreboard_id: String, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.empty():
		emit_signal("archive_error", "Game ID not set. Call set_game_id() first.")
		return

	var url = "/games/%s/scoreboards/%s/archives" % [gid.percent_encode(), scoreboard_id.percent_encode()]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "list_archives", {"scoreboard_id": scoreboard_id})
	_log("Archives list requested for '%s'" % scoreboard_id)

func get_last_archived_scoreboard(scoreboard_id: String, limit: int = 100, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.empty():
		emit_signal("archive_error", "Game ID not set. Call set_game_id() first.")
		return

	var url = "/games/%s/scoreboards/%s/archives/latest?limit=%d" % [gid.percent_encode(), scoreboard_id.percent_encode(), limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "get_last_archive", {"scoreboard_id": scoreboard_id})
	_log("Last archive requested for '%s'" % scoreboard_id)

func get_archived_scoreboard(archive_id: String, limit: int = 100) -> void:
	var url = "/archives/%s?limit=%d" % [archive_id.percent_encode(), limit]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "get_archive", {"archive_id": archive_id})
	_log("Archive '%s' requested" % archive_id)

func get_archives_in_range(scoreboard_id: String, after_timestamp: int, before_timestamp: int, for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.empty():
		emit_signal("archive_error", "Game ID not set. Call set_game_id() first.")
		return

	var url = "/games/%s/scoreboards/%s/archives?after=%d&before=%d" % [
		gid.percent_encode(),
		scoreboard_id.percent_encode(),
		after_timestamp,
		before_timestamp
	]
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "list_archives", {"scoreboard_id": scoreboard_id})
	_log("Archives in range requested for '%s'" % scoreboard_id)

func get_archive_stats(for_game_id: String = "") -> void:
	var gid = for_game_id if for_game_id != "" else game_id
	if gid.empty():
		emit_signal("archive_error", "Game ID not set. Call set_game_id() first.")
		return

	var url = "/games/%s/archives/stats" % gid.percent_encode()
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
	if achievement_ids.empty():
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
	var url = "/players/%s/achievements" % pid.percent_encode()
	_make_http_request(url, HTTPClient.METHOD_GET, {}, "achievements")
	_log("Achievements requested for: %s" % pid)

func _flush_deferred_achievements() -> void:
	if _deferred_achievement_ids.empty():
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
# BACKWARDS COMPATIBILITY ALIASES (old 3.x SDK method names)
# ============================================================

func sync_achievements(achievement_ids: Array) -> void:
	unlock_achievements_batch(achievement_ids)

func submit_score_external(player_id: String, score: int, streak: int = 0, _rounds: int = -1, nickname: String = "") -> void:
	"""Submit score for external player (API key mode)"""
	if api_key.empty():
		emit_signal("score_error", "API key not set")
		return
	var body = {
		"playerId": player_id,
		"score": score,
		"streak": streak,
		"gameId": game_id
	}
	if nickname != "":
		body["nickname"] = nickname
	_make_http_request("/scores", HTTPClient.METHOD_POST, body, "submit_score")

func unlock_achievement_external(player_id: String, achievement_id: String) -> void:
	"""Unlock achievement for external player (API key mode)"""
	if api_key.empty():
		return
	var body = {"playerId": player_id, "achievementId": achievement_id}
	_make_http_request_async("/achievements", HTTPClient.METHOD_POST, body, "unlock_achievement")

func login_as_guest(nickname: String = "") -> void:
	"""Alias for login_anonymous (old 3.x name)"""
	login_anonymous(nickname)

func login_ii() -> void:
	"""Alias for login_with_device_code (old 3.x name)"""
	login_with_device_code()

func get_profile() -> void:
	"""Alias for refresh_profile (old 3.x name)"""
	refresh_profile()

func get_current_user() -> Dictionary:
	"""Alias for get_cached_profile (old 3.x name)"""
	return get_cached_profile()

func get_session_id() -> String:
	"""Alias for session token (old 3.x name)"""
	return _session_token

func configure(p_game_id: String) -> void:
	"""Old 3.x configure method"""
	set_game_id(p_game_id)

func prompt_guest_name() -> void:
	"""Stub - no longer uses browser prompt. Override in your menu scene."""
	_log("prompt_guest_name() is deprecated. Use a LineEdit dialog in your scene instead.")

# ============================================================
# PUBLIC API - ANALYTICS
# ============================================================

func track_event(event_type: String, metadata: Dictionary = {}) -> void:
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

## Developer diagnostic dump. Prints current SDK state to stdout.
## Opt-in tool — call this from your own code when investigating a bug.
## Output is intentionally always printed (does not respect debug_logging),
## but sensitive values (device codes, tokens) are redacted.
func debug_status() -> void:
	print("")
	print("==============================================")
	print("   CheddaBoards Debug Status v2.2.1-3x")
	print("==============================================")
	print("  Platform:         %s" % OS.get_name())
	print("  Init Complete:    %s" % str(_init_complete))
	print("  Game ID:          %s" % game_id.left(20))
	print("  API Key Set:      %s" % str(not api_key.empty()))
	print("  Session Token:    %s" % str(not _session_token.empty()))
	print("----------------------------------------------")
	print("  Authenticated:    %s" % str(is_authenticated()))
	print("  Auth Type:        %s" % _auth_type)
	print("  Player ID:        %s" % get_player_id().left(20))
	print("  Anonymous:        %s" % str(is_anonymous()))
	print("----------------------------------------------")
	print("  Nickname:         %s" % get_nickname())
	print("  High Score:       %s" % str(get_high_score()))
	print("  Best Streak:      %s" % str(get_best_streak()))
	print("  Play Count:       %s" % str(get_play_count()))
	print("----------------------------------------------")
	print("  Refreshing:       %s" % str(_is_refreshing_profile))
	print("  Submitting:       %s" % str(_is_submitting_score))
	print("  HTTP Busy:        %s" % str(_http_busy))
	print("  Queue Size:       %s" % str(_request_queue.size()))
	print("  Play Session:     %s" % str(has_play_session()))
	print("  Device Code:      %s" % (_redact_code(_device_user_code) if _device_user_code != "" else "none"))
	print("  DC Polling:       %s" % str(_is_polling_device_code))
	print("==============================================")
	print("")

# ============================================================
# CLEANUP
# ============================================================

func _exit_tree():
	_stop_device_code_polling()