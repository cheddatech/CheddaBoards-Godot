# CheddaBoards.gd v1.1.0
# CheddaBoards integration for Godot 4.x
# https://github.com/cheddatech/CheddaBoards-SDK
# https://cheddaboards.com
#
# Add to Project Settings > Autoload as "CheddaBoards"

extends Node

# ============================================================
# QUICK START
# ============================================================
# 1. Add this script to Project Settings > Autoload as "CheddaBoards"
# 2. Configure your HTML template with your Game ID
# 3. In your script:
#
#    func _ready():
#        # Wait for SDK to be ready
#        await CheddaBoards.wait_until_ready()
#        
#        # Connect signals
#        CheddaBoards.login_success.connect(_on_login_success)
#        CheddaBoards.score_submitted.connect(_on_score_submitted)
#        CheddaBoards.profile_loaded.connect(_on_profile_loaded)
#
#    func _on_login_button_pressed():
#        CheddaBoards.login_google()  # or login_apple() or login_internet_identity()
#
#    func _on_login_success(nickname: String):
#        print("Welcome, ", nickname)
#
#    func _on_game_over(score: int, streak: int):
#        CheddaBoards.submit_score(score, streak)
#
#    func _on_score_submitted(score: int, streak: int):
#        print("Score saved!")
#
# ============================================================

# ============================================================
# SIGNALS
# ============================================================

# --- Initialization ---

## Emitted when SDK is fully initialized and ready to use
signal sdk_ready()

## Emitted if SDK fails to initialize after max retries
signal init_error(reason: String)

# --- Authentication ---

## Emitted when a user successfully logs in
signal login_success(nickname: String)

## Emitted when login fails
signal login_failed(reason: String)

## Emitted when login times out (user didn't complete login)
signal login_timeout()

## Emitted when user logs out
signal logout_success()

## Emitted for general authentication errors
signal auth_error(reason: String)

# --- Profile ---

## Emitted when profile data is loaded
## Parameters: nickname, high score, best streak, achievements array
signal profile_loaded(nickname: String, score: int, streak: int, achievements: Array)

## Emitted when no profile is available (not logged in)
signal no_profile()

## Emitted when nickname is successfully changed
signal nickname_changed(new_nickname: String)

## Emitted when nickname change fails
signal nickname_error(reason: String)

# --- Scores & Leaderboards ---

## Emitted when score is successfully submitted
signal score_submitted(score: int, streak: int)

## Emitted when score submission fails
signal score_error(reason: String)

## Emitted when leaderboard data is loaded
## Parameter: Array of [nickname, score] entries
signal leaderboard_loaded(entries: Array)

## Emitted when player rank is loaded
signal player_rank_loaded(rank: int, score: int, streak: int, total_players: int)

## Emitted when rank fetch fails
signal rank_error(reason: String)

# ============================================================
# CONFIGURATION
# ============================================================

## Set to true to enable verbose logging
var debug_logging: bool = false

# Internal state
var _is_web: bool = false
var _init_complete: bool = false
var _init_attempts: int = 0
var _auth_type: String = ""
var _cached_profile: Dictionary = {}

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
# POLLING CONFIGURATION
# ============================================================

var _poll_timer: Timer = null
const POLL_INTERVAL: float = 0.1
const MIN_RESPONSE_CHECK_INTERVAL: float = 0.3
const PROFILE_REFRESH_COOLDOWN: float = 2.0

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_is_web = OS.get_name() == "Web"

	if not _is_web:
		push_warning("[CheddaBoards] Not running in web environment - CheddaBoards features disabled")
		return

	_log("Initializing CheddaBoards v1.1.0...")
	_start_polling()
	_check_chedda_ready()

# ============================================================
# SDK READY CHECK
# ============================================================

func _check_chedda_ready() -> void:
	"""Check if CheddaBoards SDK is loaded and ready"""
	if not _is_web or _is_checking_auth:
		return

	_is_checking_auth = true
	_init_attempts += 1

	# Check if we've exceeded max attempts
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
# POLLING SYSTEM
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

	# Rate limiting
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_response_check < MIN_RESPONSE_CHECK_INTERVAL:
		return

	_last_response_check = current_time

	# Get response from JavaScript
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
		_handle_response(response)

# ============================================================
# RESPONSE HANDLER
# ============================================================

func _handle_response(response: Dictionary) -> void:
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
					var nickname: String = str(profile.get("nickname", "Player"))
					login_success.emit(nickname)
				else:
					login_success.emit("Player")
			else:
				var error: String = str(response.get("error", "Unknown error"))
				login_failed.emit(error)

		"submitScore":
			_is_submitting_score = false
			if success:
				var scored: int = int(response.get("score", 0))
				var streakd: int = int(response.get("streak", 0))
				score_submitted.emit(scored, streakd)
				# Update cached profile if returned
				if response.has("profile"):
					var p: Dictionary = response.get("profile")
					_update_cached_profile(p)
			else:
				var error: String = str(response.get("error", "Unknown error"))
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
				var leaderboard: Array = response.get("leaderboard", [])
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
				# User cancelled - no error needed
				pass
			else:
				var error: String = str(response.get("error", "Unknown error"))
				nickname_error.emit(error)

# ============================================================
# PROFILE MANAGEMENT
# ============================================================

func _update_cached_profile(profile: Dictionary) -> void:
	"""Update the cached profile and emit signal"""
	if profile.is_empty():
		return

	_cached_profile = profile

	var nickname: String = str(profile.get("nickname", profile.get("username", "Player")))
	var score: int = int(profile.get("score", profile.get("highScore", 0)))
	var streak: int = int(profile.get("streak", profile.get("bestStreak", 0)))
	var achievements: Array = profile.get("achievements", [])

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
	return _is_web and _init_complete

## Wait until SDK is ready (use with await)
## Example: await CheddaBoards.wait_until_ready()
func wait_until_ready() -> void:
	if is_ready():
		return
	await sdk_ready

## Get current player's nickname (or "Player" if not logged in)
func get_nickname() -> String:
	if _cached_profile.is_empty():
		return "Player"
	return str(_cached_profile.get("nickname", "Player"))

## Get current player's high score (or 0 if not logged in)
func get_high_score() -> int:
	if _cached_profile.is_empty():
		return 0
	return int(_cached_profile.get("score", 0))

## Get current player's best streak (or 0 if not logged in)
func get_best_streak() -> int:
	if _cached_profile.is_empty():
		return 0
	return int(_cached_profile.get("streak", 0))

# ============================================================
# PUBLIC API - AUTHENTICATION
# ============================================================

## Log in with Internet Identity (passwordless authentication)
## This is the primary login method - works without OAuth setup
func login_internet_identity(nickname: String = "") -> void:
	if not _is_web or not _init_complete:
		login_failed.emit("CheddaBoards not ready")
		return

	var safe_nickname: String = nickname.replace("'", "\\'").replace('"', '\\"')
	JavaScriptBridge.eval("chedda_login_ii('%s')" % safe_nickname, true)
	_log("Internet Identity login requested")
	_start_login_timeout()

## Alias for login_internet_identity (legacy name)
func login_chedda_id(nickname: String = "") -> void:
	login_internet_identity(nickname)

## Log in with Google
## Requires GOOGLE_CLIENT_ID in HTML template
func login_google() -> void:
	if not _is_web or not _init_complete:
		login_failed.emit("CheddaBoards not ready")
		return

	JavaScriptBridge.eval("chedda_login_google()", true)
	_log("Google login requested")
	_start_login_timeout()

## Log in with Apple
## Requires APPLE_SERVICE_ID and APPLE_REDIRECT_URI in HTML template
func login_apple() -> void:
	if not _is_web or not _init_complete:
		login_failed.emit("CheddaBoards not ready")
		return

	JavaScriptBridge.eval("chedda_login_apple()", true)
	_log("Apple login requested")
	_start_login_timeout()

## Log out the current user
func logout() -> void:
	if not _is_web or not _init_complete:
		return

	JavaScriptBridge.eval("chedda_logout()", true)
	_log("Logout requested")

## Check if user is currently authenticated
func is_authenticated() -> bool:
	if not _is_web or not _init_complete:
		return false

	var result: Variant = JavaScriptBridge.eval("chedda_is_auth()", true)
	return bool(result)

## Get the authentication type (google, apple, cheddaId, internetIdentity)
func get_auth_type() -> String:
	return _auth_type

# ============================================================
# PUBLIC API - PROFILE MANAGEMENT
# ============================================================

## Refresh profile data from server
## Respects cooldown to prevent spamming
func refresh_profile() -> void:
	if not _is_web or not _init_complete:
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

## Get the cached profile data (instant, no network call)
## Returns empty Dictionary if not logged in
func get_cached_profile() -> Dictionary:
	return _cached_profile

## Open the nickname change prompt
func change_nickname() -> void:
	if not _is_web or not _init_complete:
		return

	JavaScriptBridge.eval("chedda_change_nickname_prompt()", true)
	_log("Nickname change requested")

# ============================================================
# PUBLIC API - SCORES & LEADERBOARDS
# ============================================================

## Submit score and streak to leaderboard
## Emits score_submitted on success, score_error on failure
func submit_score(score: int, streak: int = 0) -> void:
	if not _is_web or not _init_complete:
		score_error.emit("CheddaBoards not ready")
		return

	if not is_authenticated():
		_log("Not authenticated, cannot submit score")
		score_error.emit("Not authenticated")
		return

	if _is_submitting_score:
		_log("Score submission already in progress")
		return

	_is_submitting_score = true

	var js_code: String = "chedda_submit_score(%d, %d)" % [score, streak]
	JavaScriptBridge.eval(js_code, true)
	_log("Score submission: %d points, %d streak" % [score, streak])

## Get leaderboard data
## Emits leaderboard_loaded with array of entries
func get_leaderboard(sort_by: String = "score", limit: int = 100) -> void:
	if not _is_web or not _init_complete:
		return

	var js_code: String = "chedda_get_leaderboard('%s', %d)" % [sort_by, limit]
	JavaScriptBridge.eval(js_code, true)
	_log("Leaderboard requested (sort: %s, limit: %d)" % [sort_by, limit])

## Get current player's rank on leaderboard
## Emits player_rank_loaded on success, rank_error on failure
func get_player_rank(sort_by: String = "score") -> void:
	if not _is_web or not _init_complete:
		return

	var js_code: String = "chedda_get_player_rank('%s')" % sort_by
	JavaScriptBridge.eval(js_code, true)
	_log("Player rank requested (sort: %s)" % sort_by)

# ============================================================
# PUBLIC API - ACHIEVEMENTS
# ============================================================

## Unlock a single achievement
func unlock_achievement(achievement_id: String, achievement_name: String, achievement_desc: String = "") -> void:
	if not _is_web or not _init_complete:
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

## Submit score with achievements in one call
func submit_score_with_achievements(score: int, streak: int, achievements: Array) -> void:
	if not _is_web or not _init_complete:
		score_error.emit("CheddaBoards not ready")
		return

	if not is_authenticated():
		_log("Not authenticated, cannot submit")
		score_error.emit("Not authenticated")
		return

	if _is_submitting_score:
		_log("Score submission already in progress")
		return

	_is_submitting_score = true

	# First unlock achievements individually (these are non-blocking)
	for ach in achievements:
		if typeof(ach) == TYPE_DICTIONARY:
			var ach_id: String = str(ach.get("id", ""))
			var ach_name: String = str(ach.get("name", ""))
			var ach_desc: String = str(ach.get("description", ""))
			if ach_id != "":
				unlock_achievement(ach_id, ach_name, ach_desc)
	
	# Then submit score using the bridge function (this queues response to Godot)
	_is_submitting_score = false  # Reset so submit_score can proceed
	submit_score(score, streak)
	_log("Score + %d achievements submitted" % achievements.size())

# ============================================================
# PUBLIC API - ANALYTICS
# ============================================================

## Track a custom event (for analytics)
func track_event(event_type: String, metadata: Dictionary = {}) -> void:
	if not _is_web or not _init_complete:
		return

	var meta_json: String = JSON.stringify(metadata)

	var js_code: String = """
		if (window.chedda && window.chedda.trackEvent) {
			window.chedda.trackEvent('%s', %s);
		}
	""" % [event_type, meta_json]

	JavaScriptBridge.eval(js_code, true)
	_log("Event tracked: %s" % event_type)

# ============================================================
# HELPER FUNCTIONS
# ============================================================

## Force check for pending events or auth status
## Useful after scene changes or if you suspect missed signals
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

## Get profile data directly from JavaScript cache
## Internal use - prefer get_cached_profile() or refresh_profile()
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
	print("║        CheddaBoards Debug Status v1.1.0      ║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Environment                                  ║")
	print("║  - Is Web:           %s" % str(_is_web).rpad(24) + "║")
	print("║  - Init Complete:    %s" % str(_init_complete).rpad(24) + "║")
	print("║  - Init Attempts:    %s" % str(_init_attempts).rpad(24) + "║")
	print("╠══════════════════════════════════════════════╣")
	print("║ Authentication                               ║")
	print("║  - Authenticated:    %s" % str(is_authenticated()).rpad(24) + "║")
	print("║  - Auth Type:        %s" % _auth_type.rpad(24) + "║")
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
