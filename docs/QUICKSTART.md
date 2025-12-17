# ⚡ CheddaBoards Quick Start

**Get leaderboards in your Godot 4 game in 5 minutes!**

**Works on Web, Windows, Mac, Linux, and Mobile!**

---

## Choose Your Path

| Platform | Time | Auth Options |
|----------|------|--------------|
| **Web** | 5 min | Chedda ID ✅, Anonymous ✅, Google/Apple (own credentials) |
| **Native** (Win/Mac/Linux/Mobile) | 3 min | Anonymous ✅ |

> ✅ = Works out of the box, no extra setup

---

# 🌐 Web Quick Start

## Step 1️⃣: Register Your Game

```
🌐 Go to: cheddaboards.com
   ↓
🔐 Click "Register Game"
   ↓
🆔 Sign in with Internet Identity
   ↓
📝 Fill in:
   • Game ID: my-awesome-game
   • Game Name: My Awesome Game
   • Description: A cool game
   ↓
✨ Click "Register Game"
   ↓
📋 SAVE YOUR GAME ID!
   ↓
🔑 (Optional) Click "Generate API Key" for anonymous play
```

**Time: 2 minutes**

---

## Step 2️⃣: Download Files

```
🌐 Go to: github.com/cheddatech/CheddaBoards-Godot
   ↓
📥 Download or clone the repo
   ↓
📂 Copy addons/cheddaboards/ folder to your project:

   YourGame/
   ├── addons/
   │   └── cheddaboards/
   │       ├── CheddaBoards.gd
   │       ├── Achievements.gd
   │       ├── SetupWizard.gd
   │       ├── plugin.cfg
   │       └── icon.png
   └── template.html          ← Also copy this to root!
```

**Time: 1 minute**

---

## Step 3️⃣: Run the Setup Wizard ✨

```
🎮 In Godot:
   File → Run (or Ctrl+Shift+X)
   ↓
🔍 Select: addons/cheddaboards/SetupWizard.gd
   ↓
🧙 The wizard will:
   ✅ Check your Godot version
   ✅ Auto-add missing Autoloads
   ✅ Verify all required files
   ✅ Check export settings
   ✅ Open Game ID configuration popup
   ↓
📝 Enter your Game ID from Step 1
   ↓
💾 Click "Save"
```

**Time: 30 seconds**

---

## Step 4️⃣: Set Export Template

```
🎮 In Godot:
   Project → Export
   ↓
➕ Add "Web" preset (if not exists)
   ↓
🔧 Under "HTML" section:
   Custom HTML Shell: res://template.html
   ↓
💾 Close
```

**Time: 30 seconds**

---

## Step 5️⃣: Export & Test

```
📦 Project → Export → Web
   ↓
💾 Click "Export Project"
   ↓
📂 ⚠️ Save as **index.html** ⚠️
   (This creates index.js, index.wasm, index.pck)
   ↓
💻 Open terminal in that folder:
   python3 -m http.server 8000
   ↓
🌐 Open browser:
   http://localhost:8000
   ↓
🎮 Test login & leaderboards!
```

**⚠️ IMPORTANT:** Must be named `index.html` - the template expects `index.js`!

**Time: 2 minutes**

---

# 🖥️ Native Quick Start (Windows/Mac/Linux/Mobile)

## Step 1️⃣: Register Game & Generate API Key

```
🌐 Go to: cheddaboards.com
   ↓
🔐 Click "Register Game"
   ↓
🆔 Sign in with Internet Identity
   ↓
📝 Fill in:
   • Game ID: my-awesome-game
   • Game Name: My Awesome Game
   • Description: A cool game
   ↓
✨ Click "Register Game"
   ↓
🎮 Go to your Game Dashboard
   ↓
🔑 Click "Generate API Key"
   ↓
📋 Copy your API KEY (looks like: cb_yourgame_xxxxxxxxx)
```

**Time: 2 minutes**

---

## Step 2️⃣: Add Files & Set API Key

```
📥 Download from GitHub
   ↓
📂 Copy addons/cheddaboards/ to your project
   ↓
🔧 Open addons/cheddaboards/CheddaBoards.gd
   ↓
📝 Find this line (around line 35):
   var api_key: String = ""
   ↓
✏️ Change to:
   var api_key: String = "cb_your_api_key_here"
   ↓
💾 Save
```

**Time: 1 minute**

---

## Step 3️⃣: Add Autoloads

```
🎮 In Godot:
   Project → Project Settings → Autoload
   ↓
➕ Add:
   Path: res://addons/cheddaboards/CheddaBoards.gd
   Name: CheddaBoards
   ↓
➕ Add:
   Path: res://addons/cheddaboards/Achievements.gd
   Name: Achievements
   ↓
💾 Close
```

Or run the Setup Wizard: `File → Run → SetupWizard.gd`

**Time: 30 seconds**

---

## Step 4️⃣: Use Anonymous Login

```gdscript
# In your game code:
func _ready():
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("PlayerName")

func _on_game_over(score, streak):
    CheddaBoards.submit_score(score, streak)
```

**That's it! Export and run!**

**Time: 30 seconds**

---

# 🎉 Total Time: 3-5 minutes!

---

## ✅ Verify It Works

### Web:
1. **Click "Chedda ID"** → Login popup opens (works out of box!)
2. **Play a game** → Score increments
3. **Game over** → "Score submitted!" message
4. **View Leaderboard** → Your score appears

### Native:
1. **Run game** → Auto-logs in anonymously
2. **Play a game** → Score increments
3. **Game over** → "Score saved!" message
4. **View Leaderboard** → Your score appears

> 💡 **Note:** Chedda ID (Internet Identity) works immediately. Google/Apple login require you to set up your own OAuth credentials in template.html.

---

## 🎮 Basic Usage

```gdscript
# Wait for SDK
await CheddaBoards.wait_until_ready()

# === ANONYMOUS LOGIN (Works everywhere!) ===
CheddaBoards.login_anonymous("PlayerName")

# === CHEDDA ID (Works out of box!) ===
CheddaBoards.login_internet_identity()

# === GOOGLE/APPLE (Requires your own OAuth credentials) ===
CheddaBoards.login_google()   # Set GOOGLE_CLIENT_ID in template.html
CheddaBoards.login_apple()    # Set APPLE_SERVICE_ID in template.html

# === SUBMIT SCORE ===
CheddaBoards.submit_score(1000, 5)  # score, streak

# === GET LEADERBOARD ===
CheddaBoards.leaderboard_loaded.connect(_on_leaderboard)
CheddaBoards.get_leaderboard("score", 100)

func _on_leaderboard(entries):
    for entry in entries:
        print("%d. %s - %d" % [entry.rank, entry.nickname, entry.score])

# === CHECK STATUS ===
if CheddaBoards.is_authenticated():
    print("Logged in as: ", CheddaBoards.get_nickname())

if CheddaBoards.is_anonymous():
    print("Playing anonymously")
```

---

## 🏆 Quick Achievements Setup

```gdscript
# At game over:
func _on_game_over(score, streak):
    # Increment games played
    Achievements.increment_games_played()
    
    # Check achievements
    Achievements.check_game_over(score, 0, streak)
    
    # Submit score WITH achievements
    Achievements.submit_with_score(score, streak)
```

---

## ❓ Common Issues

| Issue | Solution |
|-------|----------|
| "CheddaBoards not found" | Run Setup Wizard or add Autoload manually |
| "API key not set" | Set `api_key` in CheddaBoards.gd (native only) |
| "Game not registered" | Complete registration at cheddaboards.com |
| Login popup blocked | Allow popups in browser (web only) |
| Blank screen / CORS | Use `python3 -m http.server` not file:// |
| "Engine not defined" | Export must be named `index.html` |
| Click offset on high-DPI | Project Settings → Display → Window → DPI → Allow Hidpi: On |
| Score not submitting | Check `is_authenticated()` and browser console |

---

## 🔧 High-DPI Fix

If clicks are offset on scaled displays (125%, 150%):

```
Project Settings → Display → Window → DPI → Allow Hidpi: On
```

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

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd    ← Core SDK (Autoload)
│       ├── Achievements.gd    ← Achievements (Autoload)
│       ├── SetupWizard.gd     ← Run via File → Run
│       └── icon.png
├── template.html              ← Web only
├── MainMenu.tscn
├── Game.tscn
└── project.godot
```

---

## 🚀 Next Steps

1. ✅ **Working?** → Customize for your game
2. 📖 **Need details?** → Read the full README.md
3. 🏆 **Add achievements?** → See Achievements.gd
4. 🎨 **Style it?** → Edit CSS in template.html (web)
5. 🌐 **Deploy web?** → Netlify, Vercel, or itch.io
6. 🖥️ **Deploy native?** → Steam, itch.io, or direct download

---

## 💡 Pro Tips

- ⭐ Run the Setup Wizard anytime to check project health
- ⭐ Anonymous login works on ALL platforms
- ⭐ Web: Always export as `index.html`
- ⭐ Web: Always test with local server, never file://
- ⭐ Check console/output for `[CheddaBoards]` debug logs
- ⭐ Enable `debug_logging = true` for verbose output

---

## 🔗 Resources

- **Dashboard:** https://cheddaboards.com
- **GitHub:** https://github.com/cheddatech/CheddaBoards-Godot
- **Example Games:**
  - https://cheddagames.com
- **Support:** info@cheddaboards.com

---

**Zero servers. $0 for indie devs. Any platform.** 🧀
