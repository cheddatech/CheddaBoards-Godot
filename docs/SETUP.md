# Setup Guide

Get started with the CheddaBoards Godot 4 SDK in 5 minutes.

**Works on Web, Windows, Mac, Linux, and Mobile!**

---

## 📋 Prerequisites Checklist

Before you begin, make sure you have:

- [ ] **Godot 4.x installed** (download from https://godotengine.org)
- [ ] **CheddaBoards account** (free at https://cheddaboards.com)
- [ ] **Game registered** on CheddaBoards Developer Dashboard
- [ ] **Game ID** copied from your registered game
- [ ] **API Key** generated (for native/anonymous play)

---

## Choose Your Platform

| Platform | Setup Time | Auth Options |
|----------|------------|--------------|
| **Web** | 5 min | Chedda ID ✅, Anonymous ✅, Google/Apple ⚙️ |
| **Native** | 3 min | Anonymous ✅ |

> ✅ = Works out of box | ⚙️ = Requires your own OAuth credentials

---

# 🌐 Web Setup

## Step 1: Register Your Game & Generate API Key

1. Go to **https://cheddaboards.com**
2. Click **"Register Game"**
3. Sign in with **Internet Identity**
4. Fill in the form:
   - **Game ID:** `my-awesome-game` (lowercase, hyphens only)
   - **Game Name:** `My Awesome Game`
   - **Description:** Brief description
5. Click **"✨ Register Game"**
6. **Copy your Game ID**
7. Go to your **Game Dashboard**
8. Click **"Generate API Key"**
9. **Copy your API Key** (looks like `cb_yourgame_xxxxxxxxx`)

✅ **Game registered & API key generated**

---

## Step 2: Download Template Files

From **GitHub:** https://github.com/cheddatech/CheddaBoards-Godot

Download or clone the repository and copy files to your project:

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd      ← Core SDK
│       ├── Achievements.gd      ← Achievement system
│       ├── SetupWizard.gd       ← Automated setup tool ✨
│       ├── plugin.cfg           ← Plugin metadata
│       └── icon.png             ← Plugin icon
├── template.html                ← Put in project root (web only)
└── project.godot
```

✅ **Files downloaded**

---

## Step 3: Run the Setup Wizard ✨

This is where the magic happens! The wizard automates most of the setup.

1. In Godot: **File → Run** (or `Ctrl+Shift+X`)
2. Navigate to `addons/cheddaboards/SetupWizard.gd`
3. Click **Open**

The wizard will run and display:

```
╔══════════════════════════════════════════════════════════════╗
║         🧀 CheddaBoards Ultimate Setup Wizard v2.1          ║
╚══════════════════════════════════════════════════════════════╝

┌─ Godot Version
│  ✅ Godot 4.5.0 - Compatible

┌─ Autoloads
│  🔧 CheddaBoards → Added automatically
│  🔧 Achievements → Added automatically

┌─ Required Files
│  ✅ CheddaBoards.gd (Core SDK)
│  ✅ Achievements.gd (Achievements system)
│  ✅ template.html (Web export template)

┌─ Template.html (Game ID)
│  ⚠️  Using default Game ID: 'catch-the-cheese'
```

4. A **popup dialog** will appear - enter your **Game ID from Step 1**
5. Click **Save**

✅ **Project configured automatically!**

---

## Step 4: Set Export Template

1. In Godot: **Project → Export**
2. Click **Add...** → Select **Web**
3. If prompted to download export templates, click **Download and Install**
4. Under the **HTML** section:
   - **Custom HTML Shell:** `res://template.html`
5. Close the Export dialog

✅ **Export template configured**

---

## Step 5: Export to Web

1. **Project → Export**
2. Select **Web** preset
3. Click **Export Project**
4. **⚠️ IMPORTANT: Name it `index.html`**
   - This creates: `index.html`, `index.js`, `index.wasm`, `index.pck`
   - The template expects `index.js` - other names will cause errors!
5. Click **Save**

✅ **Project exported**

---

## Step 6: Run on Web Server

**⚠️ Important:** You MUST use a web server. Don't open the HTML file directly!

**Option A: Python3 (Recommended)**

```bash
cd your-export-folder
python3 -m http.server 8000
```

**Option B: Node.js**

```bash
cd your-export-folder
npx http-server -p 8000
```

Then open: **http://localhost:8000**

✅ **Running on web server**

---

## Step 7: Test Everything

1. **Open** http://localhost:8000 in browser
2. **Click** "Chedda ID" (or "Play Now" for anonymous)
3. **Complete** authentication
4. **Play the game** and earn points
5. **See:** Achievement notifications pop up! 🏆
6. **Wait** for game over
7. **See:** "Score saved!" message
8. **Click** "Leaderboard"
9. **See:** Your score and rank

✅ **Everything working!**

---

# 🖥️ Native Setup (Windows/Mac/Linux/Mobile)

## Step 1: Register Your Game & Generate API Key

1. Go to **https://cheddaboards.com**
2. Click **"Register Game"**
3. Sign in with **Internet Identity**
4. Fill in the form and click **"✨ Register Game"**
5. Go to your **Game Dashboard**
6. Click **"Generate API Key"**
7. **Copy your API Key** (looks like `cb_yourgame_xxxxxxxxx`)

✅ **Game registered & API key generated**

---

## Step 2: Download SDK Files

From **GitHub:** https://github.com/cheddatech/CheddaBoards-Godot

Copy the addon folder to your project:

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd      ← Core SDK
│       ├── Achievements.gd      ← Achievement system
│       └── ...
└── project.godot
```

> Note: You don't need `template.html` for native builds

✅ **Files downloaded**

---

## Step 3: Set API Key

Open `addons/cheddaboards/CheddaBoards.gd` and find this line (around line 35):

```gdscript
var api_key: String = ""
```

Change it to:

```gdscript
var api_key: String = "cb_your_api_key_here"
```

Or set it at runtime:

```gdscript
func _ready():
    CheddaBoards.set_api_key("cb_your_api_key_here")
```

✅ **API key configured**

---

## Step 4: Add Autoloads

Run the **Setup Wizard**: File → Run → `SetupWizard.gd`

Or manually add autoloads:

1. **Project → Project Settings → Autoload**
2. Add:
   - Path: `res://addons/cheddaboards/CheddaBoards.gd` | Name: `CheddaBoards`
   - Path: `res://addons/cheddaboards/Achievements.gd` | Name: `Achievements`

✅ **Autoloads configured**

---

## Step 5: Use Anonymous Login

Add this to your game code:

```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("PlayerName")

func _on_game_over(score: int, streak: int):
    CheddaBoards.submit_score(score, streak)
```

✅ **Ready to export!**

---

## Step 6: Fix High-DPI Displays (Important!)

If clicks are offset on scaled displays (125%, 150%):

1. **Project → Project Settings → Display → Window**
2. **DPI → Allow Hidpi:** `On`

✅ **High-DPI fixed**

---

# 🧙 What the Setup Wizard Does

| Check | Auto-Fix? | Details |
|-------|-----------|---------|
| Godot Version | ❌ | Verifies you're on Godot 4.x |
| CheddaBoards Autoload | ✅ | Adds to Project Settings if missing |
| Achievements Autoload | ✅ | Adds to Project Settings if missing |
| Required Files | ❌ | Lists what's missing |
| Export Preset | ❌ | Warns if Web export not configured |
| template.html | ❌ | Validates file exists |
| Game ID | ✅ | Interactive popup to configure |

**Run the wizard anytime** to check your project health!

---

# 🔐 Authentication Options

## What Works Out of the Box

| Method | Web | Native | Setup Required |
|--------|-----|--------|----------------|
| **Anonymous** | ✅ | ✅ | Just API key |
| **Chedda ID** | ✅ | ❌ | None |
| **Google** | ✅ | ❌ | Your OAuth credentials |
| **Apple** | ✅ | ❌ | Your OAuth credentials |

## Setting Up Google/Apple Login (Optional)

If you want Google or Apple login, you need to set up your own OAuth credentials:

### Google OAuth

1. Go to https://console.cloud.google.com
2. Create a new project
3. Enable Google Sign-In API
4. Create OAuth 2.0 credentials
5. Add your domain to authorized origins
6. Copy the Client ID to `template.html`:

```javascript
const CONFIG = {
    // ...
    GOOGLE_CLIENT_ID: 'your-client-id.apps.googleusercontent.com',
};
```

### Apple Sign-In

1. Go to https://developer.apple.com
2. Register an App ID with Sign In with Apple
3. Create a Services ID
4. Configure your domain and redirect URI
5. Add to `template.html`:

```javascript
const CONFIG = {
    // ...
    APPLE_SERVICE_ID: 'com.yourdomain.yourapp',
    APPLE_REDIRECT_URI: 'https://yourdomain.com/auth/apple'
};
```

---

# 🔧 Troubleshooting

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Engine is not defined" | Wrong export filename | Re-export as `index.html` |
| "CheddaBoards not ready" | SDK not initialized | Use `await CheddaBoards.wait_until_ready()` |
| "API key not set" | Missing API key | Set `api_key` in CheddaBoards.gd |
| "Game not registered" | Wrong Game ID | Check Game ID matches exactly |
| Login popup blocked | Browser settings | Allow popups for localhost |
| Blank screen / CORS | Opening file directly | Use `python3 -m http.server` |
| Click offset | High-DPI display | Enable "Allow Hidpi" in Project Settings |
| Score not submitting | Not authenticated | Check `is_authenticated()` returns true |

## Debug Mode

Enable verbose logging:

```gdscript
CheddaBoards.debug_logging = true
Achievements.debug_logging = true
```

Check console for `[CheddaBoards]` and `[Achievements]` messages.

## Keyboard Shortcuts (Add to Your Game)

```gdscript
func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F9:
            CheddaBoards.debug_status()
        if event.keycode == KEY_F10:
            Achievements.debug_status()
```

---

# 🚪 Exit Button (Web vs Native)

Handle exit differently per platform:

```gdscript
func _on_exit_pressed():
    if OS.get_name() == "Web":
        JavaScriptBridge.eval("window.location.href = 'https://yourdomain.com'")
    else:
        get_tree().quit()
```

---

# 📁 Final Project Structure

## Web Project

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd      ← Autoload ✓
│       ├── Achievements.gd      ← Autoload ✓
│       └── SetupWizard.gd
├── template.html                ← Game ID configured ✓
├── scenes/
│   ├── MainMenu.tscn
│   ├── Game.tscn
│   └── Leaderboard.tscn
└── project.godot
```

## Native Project

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd      ← Autoload ✓, API key set ✓
│       ├── Achievements.gd      ← Autoload ✓
│       └── SetupWizard.gd
├── scenes/
│   ├── MainMenu.tscn
│   ├── Game.tscn
│   └── Leaderboard.tscn
└── project.godot
```

---

# 🎨 Next Steps

Now that it's working:

1. **Replace Game.tscn** with your actual game
2. **Customize achievements** in `Achievements.gd`
3. **Style the UI** to match your game's theme
4. **Deploy:**
   - Web: Netlify, Vercel, itch.io
   - Native: Steam, itch.io, direct download

---

# 📚 More Help

- **Quick Start:** See QUICKSTART.md
- **Full Documentation:** See README.md
- **Example Games:**
  - https://thecheesegame.online (Web)
  - https://cheddaclick.cheddagames.com (Web + Native)
- **Support:** info@cheddaboards.com

---

# ✅ Setup Complete!

You now have a fully functional CheddaBoards integration!

**Time to build your game!** 🎮🧀
