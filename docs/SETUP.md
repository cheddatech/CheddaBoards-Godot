# 🔧 CheddaBoards Setup Guide

**Detailed setup instructions for all platforms.**

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

Copy `addons/cheddaboards/CheddaBoards.gd` to your project:

```
YourGame/
├── autoloads/
│   └── CheddaBoards.gd
├── scenes/
│   └── Game.tscn
└── project.godot
```

### 3. Configure Autoload

**Project → Project Settings → Autoload**

| Path | Name |
|------|------|
| `res://autoloads/CheddaBoards.gd` | `CheddaBoards` |

### 4. Set API Key

Open `CheddaBoards.gd` and find (around line 35):

```gdscript
var api_key: String = ""
```

Change to:

```gdscript
var api_key: String = "cb_my-game_xxxxxxxxx"
```

Or set at runtime:

```gdscript
func _ready():
    CheddaBoards.set_api_key("cb_my-game_xxxxxxxxx")
```

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
- **Game ID** (for template.html)
- **API Key** (optional, for anonymous play)

### 2. Download Files

From [GitHub](https://github.com/cheddatech/CheddaBoards-Godot), copy:

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd      ← Core SDK
│       ├── Achievements.gd      ← Achievement system
│       ├── SetupWizard.gd       ← Setup tool
│       └── plugin.cfg
├── template.html                ← Web export template
└── project.godot
```

### 3. Run Setup Wizard

**File → Run** (or Ctrl+Shift+X) → Select `SetupWizard.gd`

The wizard will:
- ✅ Auto-add CheddaBoards and Achievements to Autoloads
- ✅ Check all required files exist
- ✅ Prompt you to enter your Game ID
- ✅ Validate your export settings

### 4. Configure Web Export

**Project → Export → Add → Web**

Under **HTML** section:
- **Custom HTML Shell:** `res://template.html`

> ⚠️ This is required! Without it, authentication won't work.

### 5. Configure template.html

Open `template.html` and find the CONFIG section:

```javascript
const CONFIG = {
    GAME_ID: 'your-game-id',              // ← Your game ID
    CANISTER_ID: 'fdvph-sqaaa-aaaap-qqc4a-cai',
    
    // Optional: For Google/Apple login
    GOOGLE_CLIENT_ID: '',
    APPLE_SERVICE_ID: '',
    APPLE_REDIRECT_URI: ''
};
```

Set your **GAME_ID** to match what you registered.

### 6. Export & Test

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

## 🔐 Authentication Deep Dive

### What Works Out of Box

| Method | Web | Native | Setup |
|--------|-----|--------|-------|
| **Anonymous** | ✅ | ✅ | Just API key |
| **Chedda ID** | ✅ | ❌ | None |
| **Google** | ✅ | ❌ | Your OAuth credentials |
| **Apple** | ✅ | ❌ | Your OAuth credentials |

### Setting Up Google OAuth (Optional)

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create project → Enable Google Sign-In API
3. Create OAuth 2.0 credentials
4. Add your domain to authorized origins
5. Copy Client ID to `template.html`:

```javascript
GOOGLE_CLIENT_ID: 'xxxxx.apps.googleusercontent.com',
```

### Setting Up Apple Sign-In (Optional)

1. Go to [developer.apple.com](https://developer.apple.com)
2. Register App ID with Sign In with Apple
3. Create Services ID
4. Configure domain and redirect URI
5. Add to `template.html`:

```javascript
APPLE_SERVICE_ID: 'com.yourdomain.yourapp',
APPLE_REDIRECT_URI: 'https://yourdomain.com/auth/apple'
```

---

## 🏆 Achievements Setup (Web SDK)

The Achievements.gd autoload handles unlocking and syncing.

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
```

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
├── autoloads/
│   └── CheddaBoards.gd      ← API key set ✓
├── scenes/
│   └── Game.tscn
└── project.godot
```

### Web SDK

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd  ← Autoload ✓
│       ├── Achievements.gd  ← Autoload ✓
│       └── SetupWizard.gd
├── template.html            ← Game ID set ✓
├── scenes/
│   └── Game.tscn
└── project.godot
```

---

## ✅ Setup Checklist

### API Only
- [ ] Game registered on dashboard
- [ ] API key generated and copied
- [ ] CheddaBoards.gd added to project
- [ ] CheddaBoards in Autoloads
- [ ] API key set in CheddaBoards.gd

### Web SDK
- [ ] Game registered on dashboard
- [ ] All files copied to project
- [ ] Setup Wizard run successfully
- [ ] Game ID set in template.html
- [ ] Custom HTML Shell set in export settings
- [ ] Tested with local web server

---

## 🔗 Resources

- **Dashboard:** [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
- **Troubleshooting:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

**Need help?** info@cheddaboards.com
