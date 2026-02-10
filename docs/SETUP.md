# 🔧 CheddaBoards Setup Guide

**Detailed setup instructions for all platforms.**

> **SDK Version:** 1.7.0 | [Changelog](CHANGELOG.md)

> 💡 **Want the fast version?** See [QUICKSTART.md](QUICKSTART.md)

---

## 📋 Prerequisites

- [ ] Godot 4.x installed
- [ ] CheddaBoards account ([cheddaboards.com](https://cheddaboards.com))
- [ ] Game registered on dashboard
- [ ] API Key generated (for API/native builds)

---

## Choose Your Setup

| Setup | Platforms | Auth Options | Complexity |
|-------|-----------|--------------|------------|
| **[API Only](#api-only-setup)** | All | Anonymous | Simple |
| **[Web SDK](#web-sdk-setup)** | Web | Chedda ID, Anonymous, Google*, Apple* | Medium |

> \* Requires your own OAuth credentials

---

# API Only Setup

**Just CheddaBoards.gd. Works everywhere.**

### 1. Register & Get API Key

1. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
2. Sign in with Internet Identity, Google, or Apple
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

> 💡 **Tip:** Run the Setup Wizard (`File → Run → addons/cheddaboards/SetupWizard.gd`) to configure these automatically!

### 5. Use It

```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("Player1")

func _on_game_over(score: int, streak: int):
    CheddaBoards.submit_score(score, streak)
```

### ✅ API Setup Complete!

Export for any platform and you're done.

---

# Web SDK Setup

**Full integration with login UI, achievements, and optional OAuth.**

### 1. Register Game

Same as API setup - register at [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard).

You'll need:
- **Game ID** (for template.html and CheddaBoards.gd)
- **API Key** (optional, for anonymous play)

### 2. Download Files

From [GitHub](https://github.com/cheddatech/CheddaBoards-Godot), copy:

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd      ← Core SDK
│       ├── Achievements.gd      ← Achievement system
│       ├── SetupWizard.gd       ← Setup tool (v2.4)
│       └── plugin.cfg
├── template.html                ← Web export template
└── project.godot
```

### 3. Run Setup Wizard

**File → Run** (or Ctrl+Shift+X) → Select `SetupWizard.gd`

The wizard will:
- ✅ Auto-add CheddaBoards and Achievements to Autoloads
- ✅ Check all required files exist
- ✅ Prompt you to enter your Game ID (syncs to both files)
- ✅ Prompt you to enter your API Key
- ✅ Configure Google/Apple OAuth credentials (v2.4+)
- ✅ Validate your export settings

### 4. Configure Web Export

**Project → Export → Add → Web**

Under **HTML** section:
- **Custom HTML Shell:** `res://template.html`

> ⚠️ This is required! Without it, authentication won't work.

### 5. Export & Test

1. **Project → Export → Web**
2. Click **Export Project**
3. **⚠️ Save as `index.html`** (not MyGame.html!)
4. Open terminal in export folder:
   ```bash
   python3 -m http.server 8000
   ```
5. Open `http://localhost:8000`
6. Test login and leaderboards!

### ✅ Web SDK Setup Complete!

---

## 📊 Timed Scoreboards Setup (v1.3.0+)

Run weekly/daily competitions with automatic archiving.

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

In `Leaderboard.gd`, set your scoreboard IDs:

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
        print("Last week's winner: %s 👑" % entries[0].nickname)
```

> 📖 **Full guide:** [TIMED_SCOREBOARDS.md](TIMED_SCOREBOARDS.md)

---

## 🔐 Authentication Deep Dive

### What Works Out of Box

| Method | Web | Native | Setup |
|--------|-----|--------|-------|
| **Anonymous** | ✅ | ✅ | Just API key |
| **Chedda ID** | ✅ | ❌ | None |
| **Google** | ✅ | ❌ | None (built-in) |
| **Apple** | ✅ | ❌ | None (built-in) |
| **Account Upgrade** | ✅ | ❌ | None (anon → Google/Apple) |

### Google & Apple Sign-In

Google and Apple Sign-In are now built into CheddaBoards and work out of the box on web builds. No OAuth credential setup required — the SDK handles authentication through the CheddaBoards backend.

Players can either sign in directly with Google/Apple, or start anonymous and upgrade their account later from the Anonymous Dashboard.

---

## 🏆 Achievements Setup (Web SDK)

The Achievements.gd autoload handles unlocking and syncing.

> ⚠️ **Note:** Full achievement sync requires login (Google/Apple/Chedda ID). Anonymous users have achievements stored locally.

### Define Your Achievements

Edit `Achievements.gd`:

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
    
    # Levels (v1.3.0+)
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
    # Check level achievements (v1.3.0+)
    Achievements.check_level(level)
```

---

## 🛡️ Anti-Cheat Setup (Optional)

In the dashboard, set limits to prevent cheating:

| Setting | Recommended | Description |
|---------|-------------|-------------|
| Max Score Per Submission | `200000` | Single game max |
| Max Streak Per Submission | `10` | Max combo/streak |
| Absolute Score Cap | `500000` | Lifetime max (or blank) |
| Absolute Streak Cap | `10` | Matches game code |

Base these on your game's mechanics. Start generous, then tighten based on real data.

---

## 🐛 Debug Shortcuts

Press during development:

| Key | Action |
|-----|--------|
| F6 | Submit 5 random test scores |
| F7 | Submit 1 random test score |
| F8 | Force profile refresh |
| F9 | Debug status dump |
| F10 | Achievement debug (if available) |

These are built into MainMenu.gd and Game.gd.

---

## 🖥️ High-DPI Display Fix

If clicks are offset on scaled displays (125%, 150%):

**Project → Project Settings → Display → Window → DPI**
- **Allow Hidpi:** `On`

**Display → Window → Stretch**
- **Mode:** `canvas_items`
- **Aspect:** `keep`

---

## 🚪 Exit Button (Web vs Native)

```gdscript
func _on_exit_pressed():
    if OS.get_name() == "Web":
        JavaScriptBridge.eval("window.location.href = 'https://yourdomain.com'")
    else:
        get_tree().quit()
```

---

## 📁 Project Structure

### API Only

```
YourGame/
├── addons/
│   └── cheddaboards/
│       └── CheddaBoards.gd  ← API key + game_id set ✓
├── scenes/
│   └── Game.tscn
└── project.godot
```

### Web SDK (Full)

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd  ← Autoload ✓
│       ├── Achievements.gd  ← Autoload ✓
│       └── SetupWizard.gd   ← v2.4
├── template.html            ← Game ID set ✓
├── scenes/
│   ├── MainMenu.tscn
│   ├── Game.tscn
│   ├── Leaderboard.tscn
│   └── AchievementsView.tscn
└── project.godot
```

---

## ✅ Setup Checklist

### API Only
- [ ] Game registered on dashboard
- [ ] API key generated and copied
- [ ] `addons/cheddaboards/` folder added to project
- [ ] CheddaBoards in Autoloads
- [ ] API key and game_id set in CheddaBoards.gd

### Web SDK
- [ ] Game registered on dashboard
- [ ] All files copied to project
- [ ] Setup Wizard run successfully
- [ ] Game ID set in both template.html and CheddaBoards.gd
- [ ] Custom HTML Shell set in export settings
- [ ] Tested with local web server

### Timed Scoreboards (Optional)
- [ ] Scoreboards created in dashboard
- [ ] Scoreboard IDs set in Leaderboard.gd
- [ ] Leaderboard.tscn updated with period buttons

### Anti-Cheat (Optional)
- [ ] Score limits set in dashboard
- [ ] Limits match your game mechanics

---

## 📚 More Documentation

| Doc | Description |
|-----|-------------|
| [QUICKSTART.md](QUICKSTART.md) | Fast setup guide |
| [API_QUICKSTART.md](API_QUICKSTART.md) | Full API reference |
| [TIMED_SCOREBOARDS.md](TIMED_SCOREBOARDS.md) | Weekly/daily competitions |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common problems & solutions |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## 🔗 Resources

- **Dashboard:** [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
- **Example:** [cheddagames.com/cheddaclick](https://cheddaclick.cheddagames.com)

---

**Need help?** info@cheddaboards.com
