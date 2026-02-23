# CheddaBoards Setup Guide

**Detailed setup instructions for all platforms.**

> **SDK Version:** 1.9.0 | [Changelog](CHANGELOG.md)

> Want the fast version? See [QUICKSTART.md](QUICKSTART.md)

---

## Prerequisites

- [ ] Godot 4.x installed (tested on 4.3+)
- [ ] CheddaBoards account ([cheddaboards.com](https://cheddaboards.com))
- [ ] Game registered on dashboard
- [ ] API Key generated

---

## Choose Your Setup

| Setup | Platforms | Auth Options | Complexity |
|-------|-----------|--------------|------------|
| **[API / Native](#api-only-setup)** | All | Anonymous, Device Code (Google/Apple) | Simple |
| **[Web SDK](SETUP_WEB.md)** | Web | Anonymous, Google, Apple, Device Code, Account Upgrade | Medium |

---

# API Only Setup

**Just CheddaBoards.gd. Works everywhere.**

### 1. Register & Get API Key

1. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
2. Sign in with Google or Apple
3. Click **"Register New Game"**
4. Fill in:
   - **Game ID:** `my-game` (lowercase, hyphens only)
   - **Name:** My Awesome Game
   - **Description:** Brief description
5. Click **"Register"**
6. Click **"Generate API Key"**
7. Copy the key: `cb_my-game_xxxxxxxxx`

### 2. Add CheddaBoards.gd

Download from [GitHub](https://github.com/cheddatech/CheddaBoards-Godot).

Copy `addons/cheddaboards/` folder to your project:

```
YourGame/
├── addons/
│   └── cheddaboards/
│       └── CheddaBoards.gd
├── scenes/
│   └── Game.tscn
└── project.godot
```

### 3. Configure Autoload

**Project → Project Settings → Autoload**

| Path | Name |
|------|------|
| `res://addons/cheddaboards/CheddaBoards.gd` | `CheddaBoards` |

### 4. Set API Key

Open `CheddaBoards.gd` and find (around line 35):

```gdscript
var api_key: String = ""
var game_id: String = ""
```

Change to:

```gdscript
var api_key: String = "cb_my-game_xxxxxxxxx"
var game_id: String = "my-game"
```

Or set at runtime:

```gdscript
func _ready():
    CheddaBoards.set_api_key("cb_my-game_xxxxxxxxx")
```

> **Tip:** Run the Setup Wizard (`File → Run → addons/cheddaboards/SetupWizard.gd`) to configure these automatically!

### 5. Use It

```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("Player1")

func _on_game_over(score: int, streak: int):
    CheddaBoards.submit_score(score, streak)
```

### API Setup Complete!

Export for any platform and you're done.

---

## Timed Scoreboards Setup

Run weekly, daily, or monthly competitions with automatic archiving.

### 1. Create Scoreboards in Dashboard

1. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
2. Select your game → **Scoreboards**
3. Click **Add Scoreboard**

**Example scoreboards:**

| ID | Name | Reset Period |
|----|------|--------------|
| `all-time` | All Time | Never |
| `weekly-scoreboard` | Weekly Challenge | Weekly |
| `daily-challenge` | Daily Challenge | Daily |

### 2. Configure Leaderboard UI

In `scripts/Leaderboard.gd`, set your scoreboard IDs:

```gdscript
const SCOREBOARD_ALL_TIME: String = "all-time"
const SCOREBOARD_WEEKLY: String = "weekly-scoreboard"
```

### 3. Use Multiple Scoreboards

```gdscript
# Get specific scoreboard
CheddaBoards.get_scoreboard("weekly-scoreboard", 100)

# View last week's results
CheddaBoards.get_last_archived_scoreboard("weekly-scoreboard", 100)

CheddaBoards.archived_scoreboard_loaded.connect(_on_archive)

func _on_archive(archive_id, config, entries):
    if entries.size() > 0:
        print("Last week's winner: %s" % entries[0].nickname)
```

> Full guide: [TIMED_LEADERBOARDS.md](TIMED_LEADERBOARDS.md)

---

## Authentication Deep Dive

### What Works

| Method | Native | Mobile | Web | Setup |
|--------|--------|--------|-----|-------|
| **Anonymous** | ✅ | ✅ | ✅ | Just API key |
| **Google (Device Code)** | ✅ | ✅ | ✅ | None — built in |
| **Apple (Device Code)** | ✅ | ✅ | ✅ | None — built in |
| **Google (Direct OAuth)** | — | — | ✅ | Your OAuth credentials |
| **Apple (Direct OAuth)** | — | — | ✅ | Your OAuth credentials |
| **Account Upgrade** | ✅ | ✅ | ✅ | None (anon → Google/Apple) |

### Device Code Auth (v1.9.0)

Device Code Auth lets players sign in with Google or Apple on **any platform** — no browser popups, no OAuth SDKs needed in your game.

**How it works:**
1. Game requests a device code from CheddaBoards
2. Game displays: "Go to cheddaboards.com/link and enter: CHEDDA-7K3M"
3. Player opens that URL on their phone and signs in with Google or Apple
4. Game automatically picks up the session via polling

```gdscript
# Start device code login
CheddaBoards.login_google_device_code("PlayerName")

# Show the code to the player
CheddaBoards.device_code_received.connect(func(url, code, expires_in):
    $CodeLabel.text = "Go to %s\nEnter code: %s" % [url, code]
)

# Login completes automatically
CheddaBoards.login_success.connect(func(nickname):
    print("Welcome, %s!" % nickname)
)

# Handle expiry
CheddaBoards.device_code_expired.connect(func():
    $CodeLabel.text = "Code expired — try again"
)
```

The DeviceCodeLogin scene (`scenes/DeviceCodeLogin.tscn`) provides a ready-made UI for this flow.

### Account Upgrade

Players can start anonymous and upgrade their account to Google or Apple later via Device Code Auth. This preserves all scores and achievements while enabling cross-device sync.

> For web-specific auth options (direct OAuth, Anonymous Dashboard upgrade), see [SETUP_WEB.md](SETUP_WEB.md).

---

## Achievements Setup

The Achievements.gd autoload handles unlocking and syncing.

> **Note:** Full achievement sync requires login (Google/Apple). Anonymous users have achievements stored locally.

### Define Your Achievements

Edit `autoloads/Achievements.gd`:

```gdscript
const ACHIEVEMENTS = {
    # Games played
    "games_1": {"name": "First Game", "desc": "Play your first game"},
    "games_10": {"name": "Dedicated", "desc": "Play 10 games"},
    
    # Score milestones  
    "score_1000": {"name": "Beginner", "desc": "Score 1,000 points"},
    "score_5000": {"name": "Skilled", "desc": "Score 5,000 points"},
    
    # Streaks
    "streak_10": {"name": "On Fire", "desc": "10 streak"},
    
    # Levels
    "level_2": {"name": "Level 2", "desc": "Reach Level 2"},
    "level_5": {"name": "Master", "desc": "Reach Level 5"},
}
```

### Use in Your Game

```gdscript
func _on_game_over(score: int, streak: int):
    # Track games played
    Achievements.increment_games_played()
    
    # Check score/streak achievements
    Achievements.check_game_over(score, 0, streak)
    
    # Submit score WITH achievements
    Achievements.submit_with_score(score, streak)

func _on_level_up(level: int):
    # Check level achievements
    Achievements.check_level(level)
```

---

## Anti-Cheat Setup

Configure limits from the dashboard — no code required. CheddaBoards enforces them automatically.

| Setting | Recommended | Description |
|---------|-------------|-------------|
| Max Score Per Submission | `200000` | Single game max |
| Max Streak Per Submission | `10` | Max combo/streak |
| Absolute Score Cap | `500000` | Lifetime max (or blank) |
| Absolute Streak Cap | `10` | Matches game code |

Base these on your game's mechanics. Start generous, then tighten based on real player data. See your game's Security tab on the dashboard.

---

## Project Structure

### API Only

```
YourGame/
├── addons/
│   └── cheddaboards/
│       └── CheddaBoards.gd  ← API key + game_id set
├── scenes/
│   └── Game.tscn
└── project.godot
```

### Full Template

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd       ← Autoload
│       ├── SetupWizard.gd
│       ├── cheddaboards_logo.png
│       └── icon.png
├── autoloads/
│   ├── Achievements.gd           ← Autoload
│   └── MobileUI.gd               ← Autoload
├── scenes/
│   ├── Game.tscn
│   ├── MainMenu.tscn
│   ├── Leaderboard.tscn
│   ├── AchievementsView.tscn
│   ├── AchievementNotification.tscn
│   └── DeviceCodeLogin.tscn
├── scripts/
│   ├── Game.gd
│   ├── MainMenu.gd
│   ├── Leaderboard.gd
│   ├── AchievementsView.gd
│   ├── AchievementNotification.gd
│   └── DeviceCodeLogin.gd
├── example_game/
│   ├── CheddaClickGame.tscn
│   ├── CheddaClickGame.gd
│   └── cheese.png
├── template.html
└── project.godot
```

> For the web-specific project structure, see [SETUP_WEB.md](SETUP_WEB.md).

---

## Setup Checklist

### API Only
- [ ] Game registered on dashboard
- [ ] API key generated and copied
- [ ] `addons/cheddaboards/` folder added to project
- [ ] CheddaBoards in Autoloads
- [ ] API key and game_id set in CheddaBoards.gd

### Timed Scoreboards (Optional)
- [ ] Scoreboards created in dashboard
- [ ] Scoreboard IDs set in Leaderboard.gd
- [ ] Leaderboard.tscn updated with period buttons

### Anti-Cheat (Optional)
- [ ] Score limits set in dashboard
- [ ] Limits match your game mechanics

---

## More Documentation

| Doc | Description |
|-----|-------------|
| [SETUP_WEB.md](SETUP_WEB.md) | Web SDK setup guide |
| [QUICKSTART.md](QUICKSTART.md) | Fast setup guide |
| [API_QUICKSTART.md](API_QUICKSTART.md) | Full API reference |
| [TIMED_LEADERBOARDS.md](TIMED_LEADERBOARDS.md) | Weekly/daily competitions |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common problems & solutions |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## Resources

- **Dashboard:** [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
- **Example:** [cheddaclick.cheddagames.com](https://cheddaclick.cheddagames.com)

---

**Need help?** info@cheddaboards.com
