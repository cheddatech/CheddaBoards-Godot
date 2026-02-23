# CheddaBoards API Quickstart

**Get leaderboards in your game in 3 minutes.** Works on all platforms.

---

## Step 1: Get Your Game ID (1 min)

1. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
2. Create a game → Copy your **Game ID**
3. Copy your **API Key**

---

## Step 2: Add CheddaBoards.gd (30 sec)

```
YourGame/
└── addons/
    └── cheddaboards/
        └── CheddaBoards.gd
```

**Project → Project Settings → Autoload → Add:**
```
Name: CheddaBoards
Path: res://addons/cheddaboards/CheddaBoards.gd
```

---

## Step 3: Configure (30 sec)

Open `CheddaBoards.gd` and set:

```gdscript
var game_id: String = "your-game-id"
var api_key: String = "cb_your_api_key"
```

---

## Step 4: Use It (1 min)

```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("PlayerName")

func _on_game_over(score, streak):
    CheddaBoards.submit_score(score, streak)

func _show_leaderboard():
    CheddaBoards.leaderboard_loaded.connect(_on_leaderboard)
    CheddaBoards.get_leaderboard()

func _on_leaderboard(entries):
    for e in entries:
        print("#%d %s: %d pts" % [e.rank, e.nickname, e.score])
```

---

## That's It!

**Total time: ~3 minutes**

You now have score submission and global leaderboards on Web, Windows, Mac, Linux, and Mobile.

---

## Quick Reference

### Authentication

```gdscript
# Anonymous (works everywhere)
CheddaBoards.login_anonymous("PlayerName")

# Device Code Auth - Google/Apple on any platform (v1.9.0)
CheddaBoards.login_google_device_code("PlayerName")
CheddaBoards.login_apple_device_code("PlayerName")

# Listen for device code to display to player
CheddaBoards.device_code_received.connect(func(url, code, expires_in):
    print("Go to %s and enter: %s" % [url, code])
)

# Check status
if CheddaBoards.is_authenticated():
    print("Logged in as: ", CheddaBoards.get_nickname())
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

```gdscript
# All-time high scores
CheddaBoards.get_scoreboard("all-time", 100)

# Weekly competition
CheddaBoards.get_scoreboard("weekly", 100)

# Daily challenge
CheddaBoards.get_scoreboard("daily", 100)
```

### Scoreboard Archives

```gdscript
# View last week's results
CheddaBoards.get_last_archived_scoreboard("weekly", 100)

# Signals
CheddaBoards.archived_scoreboard_loaded.connect(_on_archive_loaded)

func _on_archive_loaded(archive_id, config, entries):
    print("Winner: %s" % entries[0].nickname)
```

### Nicknames

```gdscript
# Change nickname (shows prompt on web)
CheddaBoards.change_nickname()

# Change to specific name
CheddaBoards.change_nickname("NewName")
```

---

## Signals Reference

| Signal | Parameters | When |
|--------|------------|------|
| `sdk_ready` | - | SDK initialized |
| `login_success` | nickname | Login completed |
| `login_failed` | reason | Login error |
| `device_code_received` | url, code, expires_in | Device code ready to display |
| `device_code_expired` | - | Device code timed out |
| `score_submitted` | score, streak | Score saved |
| `score_error` | reason | Score failed |
| `leaderboard_loaded` | entries | Leaderboard data |
| `scoreboard_loaded` | id, config, entries | Scoreboard data |
| `player_rank_loaded` | rank, score, streak, total | Rank data |
| `archived_scoreboard_loaded` | id, config, entries | Archive data |
| `nickname_changed` | new_nickname | Name updated |

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "API key not set" | Set `api_key` in CheddaBoards.gd |
| "Not authenticated" | Call `login_anonymous()` first |
| Score not saving | Check `score_error` signal |
| Leaderboard empty | Verify `game_id` is correct |

---

## Web Export

For web builds with full OAuth support, see [SETUP_WEB.md](SETUP_WEB.md).

---

## Next Steps

- [TIMED_LEADERBOARDS.md](TIMED_LEADERBOARDS.md) — Weekly/daily competitions with archives
- [SETUP.md](SETUP.md) — Detailed setup guide
- [SETUP_WEB.md](SETUP_WEB.md) — Web SDK setup guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Common problems & fixes

---

## Links

- **Dashboard:** [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
