# CheddaBoards Godot 4 Template

A complete, production-ready template for integrating [CheddaBoards](https://cheddaboards.com) into your Godot 4 web game.

**Zero servers. $0 for indie devs. 5-minute setup with the Setup Wizard.**

---

## 🎮 Features

### Authentication
- ✅ Google Sign-In
- ✅ Apple Sign-In  
- ✅ Internet Identity (passwordless)
- ✅ Session persistence across page reloads
- ✅ Automatic profile syncing

### Leaderboards
- ✅ Global leaderboard with rankings
- ✅ Sort by score or streak
- ✅ Player rank display
- ✅ Your entry highlighted

### Achievements
- ✅ 17 pre-configured achievements
- ✅ Backend-first architecture
- ✅ Automatic unlocking based on score/streak
- ✅ Popup notifications
- ✅ Offline support with local caching
- ✅ Multi-device sync

### Player Stats
- ✅ High score tracking
- ✅ Best streak tracking
- ✅ Games played count (playCount)
- ✅ Cross-game player profiles (social only)

### Technical
- ✅ Godot 4.x compatible
- ✅ HTML5 web export
- ✅ JavaScript ↔ GDScript bridge
- ✅ Signal-based architecture
- ✅ Comprehensive error handling
- ✅ Debug logging & shortcuts
- ✅ **Setup Wizard** for automated configuration

---

## 📋 Prerequisites

- **Godot 4.x** (tested on 4.3+)
- **CheddaBoards Account** - Free at [cheddaboards.com](https://cheddaboards.com)
- **Game ID** - Register your game on the dashboard
- **Web server** for testing (can't use `file://` protocol)

---

## 🚀 Quick Start (5 Minutes)

### 1. Register Your Game

1. Go to [cheddaboards.com](https://cheddaboards.com)
2. Click "Register Game"
3. Sign in with Internet Identity
4. Fill in: Game ID, Name, Description
5. **Save your Game ID!**

### 2. Download Template Files

From [GitHub](https://github.com/cheddatech/CheddaBoards-Godot):

Copy the `addons/cheddaboards/` folder to your project:
- `CheddaBoards.gd` - Core SDK integration
- `Achievements.gd` - Achievement system
- `SetupWizard.gd` - **Automated setup & configuration**
- `plugin.cfg` - Asset Library metadata
- `icon.png` - Plugin icon

Copy `template.html` to your project root.

### 3. Run the Setup Wizard ✨

In Godot: **File → Run** (or `Ctrl+Shift+X`)

Select `addons/cheddaboards/SetupWizard.gd` and run it. The wizard will:

| What It Checks | What It Does |
|----------------|--------------|
| Godot version | Verifies 4.x compatibility |
| Autoloads | **Auto-adds** CheddaBoards & Achievements |
| Required files | Lists any missing files |
| CheddaBoards.gd | Validates configuration |
| Project settings | Checks stretch mode, main scene |
| Export preset | Warns if Web export not configured |
| template.html | Validates Game ID |
| Game ID | **Opens interactive config popup** |

After running, you'll see a summary of any issues and a popup to configure your Game ID.

### 4. Set Export Template

In Godot: **Project → Export → Web**

Under "HTML" section:
- **Custom HTML Shell:** `res://template.html`

### 5. Export & Test

> ⚠️ **IMPORTANT:** Export your game as `index.html` - the template expects `index.js`!

```bash
# Export from Godot as index.html, then:
cd your-export-folder
python3 -m http.server 8000

# Open: http://localhost:8000
```

**Common error:** "Engine is not defined" = You exported with wrong filename. Must be `index.html`.

---

## 🧙 Setup Wizard Reference

### Running the Wizard

```
File → Run (Ctrl+Shift+X) → Select addons/cheddaboards/SetupWizard.gd
```

### What It Checks

```
╔══════════════════════════════════════════════════════════════╗
║         🧀 CheddaBoards Ultimate Setup Wizard v2.1          ║
╚══════════════════════════════════════════════════════════════╝

┌─ Godot Version
│  ✅ Godot 4.3.0 - Compatible

┌─ Autoloads
│  ✅ CheddaBoards → addons/cheddaboards/CheddaBoards.gd
│  🔧 Achievements → Added automatically    ← Auto-fixed!

┌─ Required Files
│  ✅ CheddaBoards.gd (Core SDK)
│  ✅ template.html (Web export template)
│  ...

┌─ Template.html (Game ID)
│  ⚠️  Using default Game ID: 'catch-the-cheese'
│      → This works for testing!

═══════════════════════════════════════════════════════════════
                        📊 SUMMARY
═══════════════════════════════════════════════════════════════

🔧 Auto-Fixes Applied (1):
   • Added Achievements autoload

✅ Setup complete with 1 warning(s) - project should work!
```

### Interactive Game ID Configuration

After checks complete, a popup appears:

```
┌────────────────────────────────────────┐
│  🧀 CheddaBoards - Set Game ID         │
├────────────────────────────────────────┤
│  Current: catch-the-cheese (default)   │
│                                        │
│  Enter new Game ID:                    │
│  ┌──────────────────────────────────┐  │
│  │ my-awesome-game                  │  │
│  └──────────────────────────────────┘  │
│                                        │
│  💡 Get your Game ID at                │
│     cheddaboards.com                   │
│                                        │
│         [Cancel]  [Save]               │
└────────────────────────────────────────┘
```

### Utility Functions

The wizard also provides functions you can call from other scripts:

```gdscript
# Get project status
var status = SetupWizard.get_project_status()
# Returns: {
#   has_cheddaboards_autoload: true,
#   has_achievements_autoload: true,
#   has_template_html: true,
#   game_id: "my-game",
#   using_default_game_id: false,
#   ...
# }

# Check if ready to export
if SetupWizard.is_ready_to_export():
    print("Good to go!")

# Fix autoloads programmatically
var fixed = SetupWizard.fix_autoloads()
print("Fixed: ", fixed)  # ["Achievements"]
```

---

## 📁 Project Structure

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd       # Core SDK (Autoload)
│       ├── Achievements.gd       # Achievement system (Autoload)
│       ├── SetupWizard.gd        # Setup & validation tool
│       ├── plugin.cfg            # Asset Library metadata
│       └── icon.png              # Plugin icon (256x256)
├── template.html                 # HTML export template (root!)
├── scenes/
│   ├── MainMenu.tscn/.gd         # Login & navigation
│   ├── Game.tscn/.gd             # Your game
│   ├── GameOver.tscn/.gd         # Score submission
│   ├── Leaderboard.tscn/.gd      # Rankings display
│   └── AchievementsView.tscn/.gd # Achievement list
├── project.godot
└── export/                       # Your export folder
    ├── index.html                # ⚠️ MUST be index.html!
    ├── index.js
    ├── index.wasm
    └── index.pck
```

---

## 🎯 Integration Guide

### Basic Usage

```gdscript
extends Node

func _ready():
    # Wait for SDK to be ready
    await CheddaBoards.wait_until_ready()
    
    # Connect signals
    CheddaBoards.login_success.connect(_on_login)
    CheddaBoards.score_submitted.connect(_on_score_saved)

func _on_login_button():
    CheddaBoards.login_google()  # or login_apple() or login_internet_identity()

func _on_login(nickname: String):
    print("Welcome, ", nickname)

func _on_game_over(score: int, streak: int):
    # Check achievements
    var is_first = not Achievements.is_unlocked("first_game")
    Achievements.check_game_over(score, streak, is_first)
    
    # Submit score + achievements
    Achievements.submit_with_score(score, streak)
```

### Authentication

```gdscript
# Login methods
CheddaBoards.login_google()
CheddaBoards.login_apple()
CheddaBoards.login_internet_identity()

# Check status
if CheddaBoards.is_authenticated():
    var name = CheddaBoards.get_nickname()
    var score = CheddaBoards.get_high_score()
    var streak = CheddaBoards.get_best_streak()

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
        print(entry)  # {nickname, score, streak, rank}

# Get player rank
CheddaBoards.player_rank_loaded.connect(_on_rank)
CheddaBoards.get_player_rank("score")
```

### Achievements

```gdscript
# Unlock single achievement
Achievements.unlock("first_game")

# Check score/streak achievements
Achievements.check_score(current_score)
Achievements.check_streak(current_streak)

# Check all at game over
Achievements.check_game_over(score, streak, is_first_game)

# Submit with achievements
Achievements.submit_with_score(score, streak)

# Query achievements
var unlocked = Achievements.get_unlocked_count()
var total = Achievements.get_total_count()
var percent = Achievements.get_unlocked_percentage()
```

---

## 🏆 Pre-configured Achievements

### Games Played (6)
| ID | Name | Description |
|----|------|-------------|
| `games_1` | First Slice | Complete your very first cheese run |
| `games_5` | Getting Hungry | Play 5 games — the cheese addiction begins |
| `games_10` | Cheese Curious | Play 10 games — developing a taste for chedda |
| `games_20` | Dairy Devotee | Play 20 games — officially hooked on cheese |
| `games_30` | Fromage Fanatic | Play 30 games — cheese runs through your veins |
| `games_50` | Cheese Legend | Play 50 games — a true master of the wheel |

### Score Milestones (6)
| ID | Name | Description |
|----|------|-------------|
| `score_1000` | Cheese Nibbler | Score 1,000 points in a single game |
| `score_2000` | Chedda Chaser | Score 2,000 points — warming up nicely |
| `score_3000` | Gouda Grabber | Score 3,000 points — now we're cooking |
| `score_5000` | Brie Boss | Score 5,000 points — serious cheese skills |
| `score_7500` | Parmesan Pro | Score 7,500 points — elite tier unlocked |
| `score_10000` | The Big Cheese | Score 10,000 points — absolute dairy dominance |

### Clutch Achievements (5)
*Score X points with ≤5 seconds remaining*

| ID | Name | Description |
|----|------|-------------|
| `clutch_500` | Close Call Chedda | Finish with 500+ points and ≤5 seconds left |
| `clutch_1000` | Last Bite | Finish with 1,000+ points and ≤5 seconds left |
| `clutch_2000` | Buzzer Beater Brie | Finish with 2,000+ points and ≤5 seconds left |
| `clutch_3000` | Photo Finish Fromage | Finish with 3,000+ points and ≤5 seconds left |
| `clutch_5000` | Miraculous Mozzarella | Finish with 5,000+ points and ≤5 seconds left |

**Customize in** `addons/cheddaboards/Achievements.gd` → `ACHIEVEMENTS` constant.

---

## 📡 Signals Reference

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

# Scores
signal score_submitted(score: int, streak: int)
signal score_error(reason: String)

# Leaderboards
signal leaderboard_loaded(entries: Array)
signal player_rank_loaded(rank: int, score: int, streak: int, total_players: int)
signal rank_error(reason: String)
```

### Achievements.gd

```gdscript
signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal progress_updated(achievement_id: String, current: int, total: int)
signal achievements_synced()
signal achievements_ready()
```

---

## 🔧 Configuration Options

### HTML Template (template.html)

```javascript
const CONFIG = {
  // REQUIRED
  GAME_ID: 'your-game-id',  // ← Set via Setup Wizard!
  CANISTER_ID: 'fdvph-sqaaa-aaaap-qqc4a-cai',
  
  // OPTIONAL: Google OAuth
  GOOGLE_CLIENT_ID: '',  // From console.cloud.google.com
  
  // OPTIONAL: Apple OAuth
  APPLE_SERVICE_ID: '',
  APPLE_REDIRECT_URI: ''  // https://yourdomain.com/auth/apple
};
```

**💡 Tip:** Use the Setup Wizard to configure Game ID instead of editing manually!

### CheddaBoards.gd Constants

```gdscript
const LOGIN_TIMEOUT_DURATION: float = 35.0
const POLL_INTERVAL: float = 0.1
const PROFILE_REFRESH_COOLDOWN: float = 2.0
```

---

## 🐛 Debugging

### Setup Wizard

Run the wizard anytime to check project health:
```
File → Run → addons/cheddaboards/SetupWizard.gd
```

### Keyboard Shortcuts

| Key | Action | Scene |
|-----|--------|-------|
| F8 | Force profile refresh | MainMenu |
| F9 | Dump debug info | MainMenu |
| Ctrl+Shift+C | Clear achievement cache | Game |
| Ctrl+Shift+D | Debug status | Game |

### Debug Methods

```gdscript
# Print full status
CheddaBoards.debug_status()
Achievements.debug_status()

# Enable verbose logging
CheddaBoards.debug_logging = true
Achievements.debug_logging = true
```

### Browser Console

Press F12 and check for `[CheddaBoards]` and `[Achievements]` logs.

---

## 🚢 Deployment

### Export Checklist

Run the Setup Wizard to verify all of these automatically!

- [ ] Game ID configured in template.html
- [ ] CheddaBoards in Autoload (exact name)
- [ ] Achievements in Autoload (exact name)
- [ ] Custom HTML Shell set to `res://template.html`
- [ ] **Export filename is `index.html`** ⚠️
- [ ] Tested locally with `python3 -m http.server 8000`
- [ ] All login methods working
- [ ] Score submission working
- [ ] Leaderboard displaying

### Hosting Options

CheddaBoards requires HTTPS for OAuth. Use:

- **Netlify** (recommended, free)
- **Vercel** (free)
- **itch.io** (free, game-focused)
- **GitHub Pages** (free)

### Deploy to Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
cd your-export-folder
netlify deploy --prod
```

---

## ❓ Troubleshooting

### "Engine is not defined"

- **You exported with the wrong filename!**
- Export MUST be named `index.html` (creates `index.js`, `index.wasm`, etc.)
- The template looks for `index.js` - any other name fails

### "CheddaBoards not ready"

- Run the Setup Wizard - it will auto-add the autoload
- Or manually add: `await CheddaBoards.wait_until_ready()` before using SDK

### "Game not registered" error

- Complete registration at cheddaboards.com
- Run the Setup Wizard to configure Game ID
- Check Game ID matches exactly (case-sensitive)

### "Login popup blocked"

- Login must be triggered by direct button click
- Allow popups for your domain in browser

### "Blank screen / CORS error"

- Use web server: `python3 -m http.server 8000`
- Don't open HTML file directly (file://)

### "localhost:4943 connection refused"

- This means the SDK is trying to connect to a local ICP replica
- The template.html already includes `host: 'https://icp-api.io'` to fix this
- If you see this error, make sure you have the latest template.html

### "Score not submitting"

- Check `CheddaBoards.is_authenticated()` is true
- Connect to `score_error` signal for error details
- Check browser console for errors

### "Achievements not syncing"

- Run Setup Wizard to verify Achievements autoload
- Check `Achievements.is_ready` is true
- Use `Achievements.debug_status()` to inspect state

---

## 📊 How It Works

### Architecture

```
┌─────────────────────┐
│     Your Game       │
│     (GDScript)      │
└──────────┬──────────┘
           │ Signals & Methods
┌──────────┴──────────┐
│  CheddaBoards.gd    │  ← Autoload
│  Achievements.gd    │  ← Autoload
└──────────┬──────────┘
           │ JavaScriptBridge
┌──────────┴──────────┐
│   HTML Template     │  ← Custom Export Shell
│   (SDK via CDN)     │
└──────────┬──────────┘
           │ HTTPS
┌──────────┴──────────┐
│    CheddaBoards     │  ← Backend (ICP)
│      Canister       │
└─────────────────────┘
```

### Data Flow

1. **Login** → OAuth popup → Profile from backend
2. **Play** → Track score/streak locally
3. **Game Over** → Check achievements → Submit to backend
4. **Leaderboard** → Fetch from backend → Display

### Offline Support

- Profile cached in localStorage
- Achievements cached locally
- Pending achievements queued
- Syncs when back online

---

## 🔗 Resources

- **Dashboard:** [cheddaboards.com](https://cheddaboards.com)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
- **Example Game:** [thecheesegame.online](https://thecheesegame.online)
- **Support:** info@cheddaboards.com

---

## 📄 Files Included

| File | Version | Description |
|------|---------|-------------|
| `addons/cheddaboards/CheddaBoards.gd` | v1.1.0 | Core SDK integration |
| `addons/cheddaboards/Achievements.gd` | v1.1.0 | Achievement system |
| `addons/cheddaboards/SetupWizard.gd` | v2.1.0 | **Automated setup & config** |
| `addons/cheddaboards/plugin.cfg` | v1.1.0 | Asset Library metadata |
| `addons/cheddaboards/icon.png` | - | Plugin icon (256x256) |
| `template.html` | v1.1.0 | HTML export template |

---

## 💡 Tips

- ⭐ Run the Setup Wizard first - it auto-fixes most issues!
- ⭐ **Always export as `index.html`** - other names break the template!
- ⭐ Always use `await CheddaBoards.wait_until_ready()` before SDK calls
- ⭐ Test with `python3 -m http.server 8000`, never `file://`
- ⭐ Check browser console (F12) for debug logs
- ⭐ Clear browser cache if you see stale data
- ⭐ Use debug shortcuts during development

---

## 📄 License

MIT License - Use freely in your games!

---

## 🤝 Contributing

Found a bug? Have an improvement?

1. Open an issue on GitHub
2. Submit a pull request
3. Email info@cheddaboards.com

---

**Ready to add leaderboards to your game?**

**Start at [cheddaboards.com](https://cheddaboards.com)** 🚀