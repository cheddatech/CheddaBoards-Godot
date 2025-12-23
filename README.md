# CheddaBoards Godot 4 Template

A complete game template with leaderboards, achievements, and authentication built in.

**Download → Add your game → Export. That's it.**

Zero servers. $0 for indie devs. Web, Windows, Mac, Linux, Mobile.

---

## What's Included

| Scene | Description |
|-------|-------------|
| MainMenu | Login screen with auth options and player profile display |
| Game | Example game scene (replace with yours!) |
| Leaderboard | Full leaderboard UI with rankings |
| AchievementsView | Achievement list with progress |
| AchievementNotification | Popup system for unlocks |
| CheddaBoards SDK | Core backend integration |
| Achievements System | Backend-synced achievements |

---

## Features

### Platform Support

- **Web exports** - JavaScript bridge for full ICP authentication
- **Native exports** - HTTP API for Windows, Mac, Linux, Mobile
- **Anonymous play** - No account required, instant play with device ID
- **Cross-platform** - Same codebase works everywhere

### Authentication

| Method | Web | Native | Setup Required |
|--------|-----|--------|----------------|
| Chedda ID / Internet Identity | ✅ | — | None |
| Anonymous / Device ID | ✅ | ✅ | None |
| Google Sign-In | ✅ | — | OAuth credentials |
| Apple Sign-In | ✅ | — | OAuth credentials |

Session persistence works across page reloads.

### Leaderboards

- Global leaderboard with rankings
- Sort by score or streak
- Player rank display
- Custom nicknames for anonymous players
- Your entry highlighted

### Achievements

- Configurable achievement definitions
- Backend-first architecture
- Automatic unlocking based on score/streak/games played
- Popup notifications
- Offline support with local caching
- Multi-device sync

### Player Stats

- High score tracking
- Best streak tracking
- Games played count
- Cross-game player profiles

---

## Prerequisites

- **Godot 4.x** (tested on 4.3+)
- **CheddaBoards Account** - Free at [cheddaboards.com](https://cheddaboards.com)
- **Game ID** - Register your game on the dashboard
- **API Key** - For native/anonymous builds (get from dashboard)

---

## Quick Start

### How It Works

1. Download the template from Asset Library or GitHub
2. Open in Godot 4.x
3. Run Setup Wizard → Enter your Game ID & API key
4. Replace `Game.tscn` with your actual game
5. Export → Players get leaderboards & achievements!

### Web Setup (5 Minutes)

1. Register your game at [cheddaboards.com](https://cheddaboards.com)
2. Copy files to your project:
   - `addons/cheddaboards/` folder
   - `template.html` to project root
3. Run Setup Wizard: `File → Run → SetupWizard.gd`
4. Configure export: `Project → Export → Web → Custom HTML Shell: res://template.html`
5. Export as `index.html` and test with local server

### Native Export (Windows/Mac/Linux/Mobile)

1. Register your game at [cheddaboards.com](https://cheddaboards.com)
2. Get your API Key from the dashboard
3. Copy files to your project:
   - `addons/cheddaboards/` folder
4. Add Autoloads in Project Settings:
   - `CheddaBoards` → `addons/cheddaboards/CheddaBoards.gd`
   - `Achievements` → `addons/cheddaboards/Achievements.gd`
5. Set API key in `CheddaBoards.gd` or at runtime:

```gdscript
CheddaBoards.set_api_key("cb_your_api_key_here")
```

---

## Platform Modes

The SDK automatically detects the platform and uses the appropriate backend:

| Platform | Mode | Authentication Options |
|----------|------|------------------------|
| Web | JavaScript Bridge | Chedda ID, Anonymous, Google/Apple* |
| Windows/Mac/Linux | HTTP API | Anonymous |
| Mobile | HTTP API | Anonymous |

*Requires your own OAuth credentials

```gdscript
# The SDK handles this automatically!
# Same code works on all platforms:

func _ready():
    await CheddaBoards.wait_until_ready()
    
    # This works on web AND native:
    CheddaBoards.login_anonymous("PlayerName")
    CheddaBoards.submit_score(1000, 5)
```

### Anonymous Play (Recommended for Native)

Anonymous play uses device IDs - no account creation required:

```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    
    # Login with device ID + custom nickname
    CheddaBoards.login_anonymous("CheeseMaster")
    
    # Or setup without emitting signals (for pre-config)
    CheddaBoards.setup_anonymous_player("", "CheeseMaster")

func _on_game_over(score: int, streak: int):
    # Works exactly like authenticated play
    CheddaBoards.submit_score(score, streak)
```

**Benefits of Anonymous Play:**

- Instant play - no login popups
- Works on ALL platforms (web + native)
- Players can set custom nicknames
- Scores appear on leaderboards
- Achievements still work
- Device ID persists across sessions

---

## Integration Guide

### Basic Setup

```gdscript
extends Node

func _ready():
    # Wait for SDK
    await CheddaBoards.wait_until_ready()
    
    # Connect signals
    CheddaBoards.login_success.connect(_on_login)
    CheddaBoards.score_submitted.connect(_on_score_saved)
    CheddaBoards.score_error.connect(_on_score_error)

func _start_game():
    # For anonymous play (works everywhere)
    CheddaBoards.login_anonymous("PlayerName")

func _on_login(nickname: String):
    print("Welcome, ", nickname)

func _on_game_over(score: int, streak: int):
    # Submit score (with achievements if using Achievements.gd)
    if Achievements:
        Achievements.increment_games_played()
        Achievements.check_game_over(score, 0, streak)
        Achievements.submit_with_score(score, streak)
    else:
        CheddaBoards.submit_score(score, streak)

func _on_score_saved(score: int, streak: int):
    print("Score saved: ", score)

func _on_score_error(reason: String):
    print("Error: ", reason)
```

### Authentication Options

```gdscript
# Anonymous (Web + Native) - Works out of box
CheddaBoards.login_anonymous("CustomNickname")

# Chedda ID (Web only) - Works out of box
CheddaBoards.login_internet_identity("Nickname")

# Google/Apple (Web only) - Requires your OAuth credentials
# Set GOOGLE_CLIENT_ID or APPLE_SERVICE_ID in template.html first
CheddaBoards.login_google()
CheddaBoards.login_apple()

# Check status
if CheddaBoards.is_authenticated():
    print("Logged in as: ", CheddaBoards.get_nickname())

if CheddaBoards.is_anonymous():
    print("Playing anonymously")

if CheddaBoards.has_account():
    print("Has real account (Google/Apple/Chedda ID)")

# Logout
CheddaBoards.logout()
```

### Scores & Leaderboards

```gdscript
# Submit score
CheddaBoards.submit_score(1000, 25)  # score, streak

# Get leaderboard
CheddaBoards.leaderboard_loaded.connect(_on_leaderboard)
CheddaBoards.get_leaderboard("score", 100)  # sort_by, limit

func _on_leaderboard(entries: Array):
    for entry in entries:
        print("%d. %s - %d pts" % [entry.rank, entry.nickname, entry.score])

# Get player rank
CheddaBoards.player_rank_loaded.connect(_on_rank)
CheddaBoards.get_player_rank("score")

func _on_rank(rank: int, score: int, streak: int, total: int):
    print("You are #%d of %d players!" % [rank, total])
```

### Nickname Management

```gdscript
# Get current nickname
var name = CheddaBoards.get_nickname()

# Set nickname (anonymous players)
CheddaBoards.set_nickname("NewName")

# Change nickname via API (persists to backend)
CheddaBoards.change_nickname_to("NewName")
CheddaBoards.nickname_changed.connect(func(n): print("Now known as: ", n))
CheddaBoards.nickname_error.connect(func(e): print("Error: ", e))

# Web only - opens popup
CheddaBoards.change_nickname()
```

### Achievements

```gdscript
# Check if Achievements autoload exists
var has_achievements = get_node_or_null("/root/Achievements") != null

# Unlock single achievement
Achievements.unlock("first_game")

# Check achievements during gameplay
Achievements.check_score(current_score)
Achievements.check_combo(max_combo)
Achievements.check_clicks(total_clicks)

# At game over - check all + increment games
Achievements.increment_games_played()
Achievements.check_game_over(score, clicks, max_combo)

# Submit score WITH achievements attached
Achievements.submit_with_score(score, streak)

# Query status
var unlocked = Achievements.get_unlocked_count()
var total = Achievements.get_total_count()
var percent = Achievements.get_unlocked_percentage()
print("%d/%d (%.0f%%)" % [unlocked, total, percent])
```

---

## Configuration

### API Key (Native/Anonymous)

Set in `CheddaBoards.gd`:

```gdscript
var api_key: String = "cb_your_api_key_here"
```

Or at runtime:

```gdscript
func _ready():
    CheddaBoards.set_api_key("cb_your_api_key_here")
```

### HTML Template (Web)

In `template.html`:

```javascript
const CONFIG = {
    GAME_ID: 'your-game-id',  // From dashboard
    CANISTER_ID: 'fdvph-sqaaa-aaaap-qqc4a-cai',
    
    // Optional: Social login
    GOOGLE_CLIENT_ID: '',
    APPLE_SERVICE_ID: '',
    APPLE_REDIRECT_URI: ''
};
```

### Project Settings

For high-DPI display support:

- `Display → Window → DPI → Allow Hidpi`: On
- `Display → Window → Stretch → Mode`: canvas_items
- `Display → Window → Stretch → Aspect`: keep

---

## Signals Reference

### CheddaBoards.gd

```gdscript
# Initialization
signal sdk_ready()
signal init_error(reason: String)

# Authentication
signal login_success(nickname: String)
signal login_failed(reason: String)
signal login_timeout()
signal logout_success()

# Profile
signal profile_loaded(nickname: String, score: int, streak: int, achievements: Array)
signal no_profile()
signal nickname_changed(new_nickname: String)
signal nickname_error(reason: String)

# Scores
signal score_submitted(score: int, streak: int)
signal score_error(reason: String)

# Leaderboards
signal leaderboard_loaded(entries: Array)
signal player_rank_loaded(rank: int, score: int, streak: int, total_players: int)
signal rank_error(reason: String)

# Achievements
signal achievement_unlocked(achievement_id: String)
signal achievements_loaded(achievements: Array)

# HTTP API
signal request_failed(endpoint: String, error: String)
```

### Achievements.gd

```gdscript
signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal progress_updated(achievement_id: String, current: int, total: int)
signal achievements_synced()
signal achievements_ready()
```

---

## Example Achievement Definitions

Customize in `Achievements.gd`:

```gdscript
const ACHIEVEMENTS = {
    # Games Played
    "games_1": {"name": "First Game", "description": "Play your first game"},
    "games_10": {"name": "Getting Started", "description": "Play 10 games"},
    "games_50": {"name": "Dedicated", "description": "Play 50 games"},
    
    # Score Milestones
    "score_1000": {"name": "Beginner", "description": "Score 1,000 points"},
    "score_5000": {"name": "Skilled", "description": "Score 5,000 points"},
    "score_10000": {"name": "Expert", "description": "Score 10,000 points"},
    
    # Combo/Streak
    "combo_10": {"name": "Combo Starter", "description": "Reach 10x combo"},
    "combo_50": {"name": "Combo Master", "description": "Reach 50x combo"},
}
```

---

## Debugging

### Debug Methods

```gdscript
# Print full status
CheddaBoards.debug_status()
Achievements.debug_status()

# Enable verbose logging
CheddaBoards.debug_logging = true
Achievements.debug_logging = true
```

### Keyboard Shortcuts

Add to your game for quick debugging:

```gdscript
func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F9:
            CheddaBoards.debug_status()
        if event.keycode == KEY_F10:
            Achievements.debug_status()
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "API key not set" | Set `api_key` in CheddaBoards.gd or call `set_api_key()` |
| "CheddaBoards not ready" | Use `await CheddaBoards.wait_until_ready()` |
| Score not submitting | Check `is_authenticated()` and connect to `score_error` |
| Click offset on high-DPI | Enable "Allow Hidpi" in Project Settings |
| Web: "Engine not defined" | Export must be named `index.html` |
| Web: Blank screen | Use local server, not `file://` |

---

## Deployment

### Web Export Checklist

- [ ] Game ID configured in `template.html`
- [ ] Custom HTML Shell set to `res://template.html`
- [ ] Export filename is `index.html`
- [ ] Test with `python3 -m http.server 8000`
- [ ] Deploy to HTTPS host (Netlify, Vercel, itch.io)

### Native Export Checklist

- [ ] API Key set in `CheddaBoards.gd`
- [ ] CheddaBoards + Achievements in Autoloads
- [ ] High-DPI settings configured
- [ ] Test anonymous login flow

### Exit Button (Web vs Native)

```gdscript
func _on_exit_pressed():
    if OS.get_name() == "Web":
        JavaScriptBridge.eval("window.location.href = 'https://yourdomain.com'")
    else:
        get_tree().quit()
```

---

## Template Structure

```
CheddaBoards-Godot/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd       # Core SDK (Autoload)
│       ├── Achievements.gd       # Achievement system (Autoload)
│       ├── SetupWizard.gd        # Setup & validation tool
│       └── icon.png
├── scenes/
│   ├── MainMenu.tscn/.gd         # Login & profile UI
│   ├── Game.tscn/.gd             # ← REPLACE WITH YOUR GAME
│   ├── Leaderboard.tscn/.gd      # Leaderboard display
│   ├── AchievementsView.tscn/.gd # Achievement list
│   └── AchievementNotification.* # Unlock popups
├── assets/                       # Sprites, fonts, etc.
├── template.html                 # Web export template
├── project.godot                 # Pre-configured project
└── README.md
```

---

## Resources

- **Dashboard**: [cheddaboards.com](https://cheddaboards.com)
- **GitHub**: [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
- **Support**: info@cheddaboards.com

---

## Version History

| Version | Changes |
|---------|---------|
| v1.2.1 | Native HTTP API support, anonymous login, API key auth |
| v1.1.0 | Achievement system, Setup Wizard |
| v1.0.0 | Initial release - Web only |

---

## License

MIT License - Use freely in your games!

---

**Ready to add leaderboards to your game?**

Start at [cheddaboards.com](https://cheddaboards.com) 🚀
