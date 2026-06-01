# CheddaBoards Quick Start

**Add leaderboards to a game you've already built.** Works on web, desktop, and mobile.

> **SDK Version:** 2.2.0 | [Changelog](CHANGELOG.md)

---

## Two ways to start — pick the one that matches where you are

- **Starting fresh, or just trying CheddaBoards out?**
  This whole repo **is** a working Godot 4 template. Open it in Godot, run the Setup Wizard (`File → Run → addons/cheddaboards/SetupWizard.gd`), paste your Game ID + API key, and the included example game (CheddaClick) submits scores straight from the editor. To use your own game instead, set `game_scene_path` in `scenes/Game.tscn` and emit four signals — the wrapper handles HUD, game-over, and submission for you. **~3 minutes.** See the [README](../README.md).

- **Adding leaderboards to a game you already have?**
  Copy just the `addons/cheddaboards/` folder into your project and wire the calls yourself. That's what the steps below cover. **~10 minutes.**

---

## Before you start

- **Godot 4.x.** This guide uses `await`, which is Godot 4 syntax. On **Godot 3.6**, replace `await CheddaBoards.wait_until_ready()` with `yield(CheddaBoards, "sdk_ready")` — see [SETUP.md](SETUP.md).
- **A game that already has a score.** CheddaBoards ranks numbers, so you need a project that produces a score (and ideally a streak) and has a *game-over moment* to submit from. If you don't have that yet, build the game loop first — there's nothing to submit without it.
- **Basic GDScript:** connecting signals, `_ready()`, and `await`.

---

## Step 1: Register & Get API Key (~3 min)

1. Go to [cheddaboards.com/developers](https://cheddaboards.com/developers)
2. Sign in with Google or Apple
3. Click **"Register New Game"**
4. Copy your **Game ID** (e.g. `my-game`) and **API Key** (e.g. `cb_my-game_xxxxxxxxx`)

---

## Step 2: Add CheddaBoards.gd (~2 min)

Download from [GitHub](https://github.com/cheddatech/CheddaBoards-Godot) and copy the `addons/cheddaboards/` folder to your project:

```
YourGame/
└── addons/
    └── cheddaboards/
        ├── CheddaBoards.gd
        └── SetupWizard.gd
```

**Fastest path —** run the wizard, which registers the autoload for you:

```
File → Run → addons/cheddaboards/SetupWizard.gd
```

**Or do it manually —** Project → Project Settings → Autoload → Add:

```
Name: CheddaBoards
Path: res://addons/cheddaboards/CheddaBoards.gd
```

---

## Step 3: Wire It Up (~4 min)

Everything below goes in **one script** — wherever your game starts (e.g. `MainMenu.gd`). This is the whole integration: credentials, login, submitting a score, and reading the leaderboard.

```gdscript
extends Control  # or whatever your start scene is

func _ready():
    # --- Credentials: must come before any other CheddaBoards call ---
    CheddaBoards.set_api_key("cb_my-game_xxxxxxxxx")
    CheddaBoards.set_game_id("my-game")

    # Connect the leaderboard signal ONCE here (not inside a function,
    # or you'll re-connect it every time you open the board).
    CheddaBoards.leaderboard_loaded.connect(_on_leaderboard)

    # Wait for the SDK, then log in.
    # IMPORTANT: submit_score fails until login has completed.
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("PlayerName")


# Call this from YOUR game-over code, passing the final score and streak.
func _on_game_over(score: int, streak: int):
    CheddaBoards.submit_score(score, streak)


# Call this when you want to show the board (e.g. from a button press).
func show_leaderboard():
    CheddaBoards.get_leaderboard("score", 100)


# Fires when get_leaderboard() returns. Connected once, in _ready().
func _on_leaderboard(entries: Array):
    for e in entries:
        print("#%d %s - %d" % [e.rank, e.nickname, e.score])
```

That's it. The two things you wire into your own game: call `_on_game_over(score, streak)` when a run ends, and call `show_leaderboard()` from a button.

---

## Done!

**Total time: ~10 minutes** — roughly half setup (Steps 1–2), half code (Step 3).

You now have anonymous login, score submission, and global leaderboards on web, desktop, and mobile.

---

## Quick Reference

### Authentication

```gdscript
# Anonymous (works everywhere)
CheddaBoards.login_anonymous("PlayerName")

# Device Code Auth - Google/Apple/Internet Identity on any platform
CheddaBoards.login_with_device_code()

# Listen for the code, verification URL, and QR data to display to the player
CheddaBoards.device_code_received.connect(func(user_code: String, verification_url: String, qr_data_url: String):
    print("Go to %s and enter: %s" % [verification_url, user_code])
    # qr_data_url is a base64 PNG you can decode into a TextureRect — see
    # scripts/DeviceCodeLogin.gd for a reference implementation
)

# Login completes automatically via background polling
CheddaBoards.device_code_approved.connect(func(nickname: String):
    print("Welcome, %s!" % nickname)
)

# Check status
if CheddaBoards.is_authenticated():
    print("Logged in as: ", CheddaBoards.get_nickname())
```

### Profile

```gdscript
# v2.2.0+: profile_loaded emits play_count as 5th argument
CheddaBoards.profile_loaded.connect(func(nickname, score, streak, achievements, play_count):
    print("%s — score %d, streak %d, plays %d" % [nickname, score, streak, play_count])
)

CheddaBoards.refresh_profile()
```

### Scores

```gdscript
# Submit score with streak
CheddaBoards.submit_score(1000, 5)

# Signals
CheddaBoards.score_submitted.connect(_on_score_submitted)
CheddaBoards.score_error.connect(_on_score_error)
```

### Leaderboards

```gdscript
# Get top 100
CheddaBoards.get_leaderboard("score", 100)

# Get specific scoreboard
CheddaBoards.get_scoreboard("weekly-scoreboard", 50)

# Get player's rank
CheddaBoards.get_player_rank()
```

### Multiple Scoreboards

Run weekly competitions alongside all-time high scores:

```gdscript
# All-time high scores
CheddaBoards.get_scoreboard("all-time", 100)

# Weekly competition
CheddaBoards.get_scoreboard("weekly-scoreboard", 100)

# Daily challenge
CheddaBoards.get_scoreboard("daily-challenge", 100)
```

> Full guide: [guides/timed-leaderboards.md](guides/timed-leaderboards.md)

### Scoreboard Archives

```gdscript
# View last week's results
CheddaBoards.get_last_archived_scoreboard("weekly-scoreboard", 100)

CheddaBoards.archived_scoreboard_loaded.connect(_on_archive_loaded)

func _on_archive_loaded(archive_id: String, config: Dictionary, entries: Array):
    if entries.size() > 0:
        print("Last week's winner: %s" % entries[0].nickname)
```

### Nicknames

```gdscript
# Change to specific name
CheddaBoards.change_nickname("NewName")

# Listen for result
CheddaBoards.nickname_changed.connect(func(new_nickname: String):
    print("Now playing as: ", new_nickname)
)
CheddaBoards.nickname_error.connect(func(reason: String):
    print("Nickname change failed: ", reason)
)
```

### Quick Achievements (Optional)

```gdscript
func _on_game_over(score: int, streak: int):
    Achievements.increment_games_played()
    Achievements.check_game_over(score, 0, streak)
    Achievements.submit_with_score(score, streak)
```

> Full achievement sync requires login (Google/Apple/II). Anonymous users have achievements stored locally and synced once they upgrade their account.

---

## Signals Reference

The most common signals you'll connect to. The full list (34 signals across 10 categories) lives in the SDK source.

| Signal | Parameters | When |
|--------|------------|------|
| `sdk_ready` | — | SDK initialised and ready for calls |
| `login_success` | `nickname: String` | Login completed |
| `login_failed` | `reason: String` | Login error |
| `device_code_received` | `user_code, verification_url, qr_data_url` | Device code ready to display |
| `device_code_approved` | `nickname: String` | Player completed device code sign-in |
| `device_code_expired` | — | Device code timed out after 5 min |
| `profile_loaded` | `nickname, score, streak, achievements, play_count` | Profile loaded (v2.2.0+ adds `play_count`) |
| `score_submitted` | `score, streak` | Score saved |
| `score_error` | `reason: String` | Score submission failed |
| `leaderboard_loaded` | `entries: Array` | Leaderboard data |
| `scoreboard_loaded` | `id, config, entries` | Specific scoreboard data |
| `player_rank_loaded` | `rank, score, streak, total_players` | Rank data |
| `archived_scoreboard_loaded` | `id, config, entries` | Archive data |
| `nickname_changed` | `new_nickname: String` | Name updated |

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "API key not set" | Call `CheddaBoards.set_api_key(...)` in your `_ready()` (v2.2.0+ ships with empty defaults) |
| "Game ID not set" | Call `CheddaBoards.set_game_id(...)` in your `_ready()` |
| "Not authenticated" | Submit ran before login finished. `await wait_until_ready()` then `login_anonymous()` **before** any `submit_score()` |
| `await` won't parse / "Expected end of statement" | You're on Godot 3.6 — use `yield(CheddaBoards, "sdk_ready")` instead of `await` |
| 4-arg `_on_profile_loaded` errors | v2.2.0 added `play_count` as 5th arg — add a trailing `play_count: int` parameter |
| Leaderboard shows duplicates / fires twice | You connected `leaderboard_loaded` inside a function — connect it once in `_ready()` |
| Score not saving | Check `score_error` signal for the reason |
| Leaderboard empty | Verify `game_id` matches the one in your dashboard |
| "CheddaBoards not found" | Add to Autoloads or run Setup Wizard |
| Blank screen (web) | Use `python3 -m http.server`, not `file://` |
| "Engine not defined" (web) | Export must be named `index.html`, not `MyGame.html` |
| Clicks offset | Project Settings → Display → DPI → Allow Hidpi: On |

---

## More Documentation

| Doc | Description |
|-----|-------------|
| [SETUP.md](SETUP.md) | Detailed setup, web export & OAuth specifics |
| [guides/timed-leaderboards.md](guides/timed-leaderboards.md) | Weekly/daily competitions & archives |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common problems & fixes |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## Resources

- **Developer Console:** [cheddaboards.com/developers](https://cheddaboards.com/developers)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
- **Asset Library:** [godotengine.org/asset-library/asset/4574](https://godotengine.org/asset-library/asset/4574)
- **Support:** info@cheddaboards.com
