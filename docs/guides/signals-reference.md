# Signals Reference

Every signal CheddaBoards emits, grouped by category. All are typed for Godot 4.x.

> Connect the ones you need in `_ready()`. The [Drop-in Quickstart](../quickstart-dropin.md) shows the common ones in context; this page is the complete list.

---

## CheddaBoards.gd

The SDK exposes 34 signals, grouped into the categories below.

### Initialization

```gdscript
signal sdk_ready()
signal init_error(reason: String)
```

### Authentication

```gdscript
signal login_success(nickname: String)
signal login_failed(reason: String)
signal logout_success()
signal auth_error(reason: String)
```

### Profile

```gdscript
# v2.2.0: play_count added as 5th arg.
# 4-arg handlers from older versions must add a trailing play_count: int.
signal profile_loaded(nickname: String, score: int, streak: int, achievements: Array, play_count: int)
signal no_profile()
signal nickname_changed(new_nickname: String)
signal nickname_error(reason: String)
```

### Scores & Legacy Leaderboard

```gdscript
signal score_submitted(score: int, streak: int)
signal score_error(reason: String)
signal leaderboard_loaded(entries: Array)
signal player_rank_loaded(rank: int, score: int, streak: int, total_players: int)
signal rank_error(reason: String)
```

### Scoreboards (Time-based)

```gdscript
signal scoreboards_loaded(scoreboards: Array)
signal scoreboard_loaded(scoreboard_id: String, config: Dictionary, entries: Array)
signal scoreboard_rank_loaded(scoreboard_id: String, rank: int, score: int, streak: int, total: int)
signal scoreboard_error(reason: String)
```

### Scoreboard Archives

```gdscript
signal archives_list_loaded(scoreboard_id: String, archives: Array)
signal archived_scoreboard_loaded(archive_id: String, config: Dictionary, entries: Array)
signal archive_stats_loaded(total_archives: int, by_scoreboard: Array)
signal archive_error(reason: String)
```

### Achievements

```gdscript
signal achievement_unlocked(achievement_id: String)
signal achievements_loaded(achievements: Array)
```

### Play Sessions (Anti-Cheat)

```gdscript
signal play_session_started(token: String)
signal play_session_error(reason: String)
```

### Account Upgrade (Anonymous → Verified)

```gdscript
signal account_upgraded(profile: Dictionary, migration: Dictionary)
signal account_upgrade_failed(reason: String)
```

### Device Code Auth

```gdscript
# qr_data_url is a base64 PNG of a QR encoding the full verification URL
# with the code pre-filled. Decode and apply to a TextureRect for scanning.
signal device_code_received(user_code: String, verification_url: String, qr_data_url: String)
signal device_code_approved(nickname: String)
signal device_code_expired()
signal device_code_error(reason: String)
```

### HTTP (catch-all)

```gdscript
signal request_failed(endpoint: String, error: String)
```

---

## Achievements.gd

```gdscript
signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal achievements_ready()
```

---

## Your Game (Template wrapper)

If you use the Template's `Game.gd` wrapper, your own game scene emits these — the wrapper listens and handles submission, the game-over screen, and achievements. **Only `game_over` is required;** the other three are optional and only feed the built-in HUD.

```gdscript
signal game_over(final_score: int, stats: Dictionary)         # REQUIRED — wrapper can't submit without it
signal score_changed(score: int, combo: int)                  # optional — live score/combo HUD + mid-game achievement pops
signal stats_changed(hits: int, misses: int, level: int)      # optional — level/misses HUD
signal time_changed(time_remaining: float, max_time: float)   # optional — countdown timer HUD
```

→ Full breakdown of the contract and what each value does: [Build Your Own Game](your-own-game.md).

---

**See also:** [Authentication](authentication.md) · [Achievements](achievements.md) · [Anti-cheat](anti-cheat.md) · [docs index](../README.md)
