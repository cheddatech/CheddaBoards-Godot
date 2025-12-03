# Setup Guide

Get started with the CheddaBoards Godot 4 Template in 5 minutes using the **Setup Wizard**.

---

## 📋 Prerequisites Checklist

Before you begin, make sure you have:

- [ ] **Godot 4.x installed** (download from https://godotengine.org)
- [ ] **CheddaBoards account** (free at https://cheddaboards.com)
- [ ] **Game registered** on CheddaBoards Developer Dashboard
- [ ] **Game ID** copied from your registered game

---

## 🚀 Step-by-Step Setup

### Step 1: Register Your Game

1. Go to **https://cheddaboards.com**
2. Click **"Register Game"**
3. Sign in with **Internet Identity**
4. Fill in the form:
   - **Game ID:** `my-awesome-game` (lowercase, hyphens only)
   - **Game Name:** `My Awesome Game`
   - **Description:** Brief description
5. Click **"✨ Register Game"**
6. **Copy your Game ID** - you'll need it in Step 3!

✅ **Game registered**

---

### Step 2: Download Template Files

From **GitHub:** https://github.com/cheddatech/CheddaBoards-Godot

Download or clone the repository and copy files to your project:

**Place the addon folder and template in your project:**

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd      ← Core SDK
│       ├── Achievements.gd      ← Achievement system
│       ├── SetupWizard.gd       ← Automated setup tool ✨
│       ├── plugin.cfg           ← Plugin metadata
│       └── icon.png             ← Plugin icon
├── template.html                ← Put in project root
└── project.godot
```

✅ **Files downloaded**

---

### Step 3: Run the Setup Wizard ✨

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

═══════════════════════════════════════════════════════════════
                    🎮 GAME ID CONFIGURATION
═══════════════════════════════════════════════════════════════

   Current Game ID: 'catch-the-cheese'
   Status: ⚠️  Default (OK for testing)
```

4. A **popup dialog** will appear:

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

5. Enter your **Game ID from Step 1**
6. Click **Save**

✅ **Project configured automatically!**

---

### Step 4: Set Export Template

1. In Godot: **Project → Export**
2. Click **Add...** → Select **Web**
3. If prompted to download export templates:
   - Click **Download and Install**
   - Wait for download
   - Close and reopen Export dialog
4. Under the **HTML** section:
   - **Custom HTML Shell:** `res://template.html`
5. Close the Export dialog

✅ **Export template configured**

---

### Step 5: Export to Web

1. **Project → Export**
2. Select **Web** preset
3. Click **Export Project**
4. Choose a folder (e.g., `build/`)
5. **⚠️ IMPORTANT: Name it `index.html`** 
   - This creates: `index.html`, `index.js`, `index.wasm`, `index.pck`
   - The template expects `index.js` - other names will cause errors!
6. Click **Save**

✅ **Project exported**

---

### Step 6: Run on Web Server

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

**Option C: VS Code**

Install "Live Server" extension and click "Go Live"

Then open: **http://localhost:8000**

✅ **Running on web server**

---

### Step 7: Test Everything

1. **Open** http://localhost:8000 in browser
2. **Click** "Sign in with Google" (or Internet Identity)
3. **Complete** authentication
4. **See:** Main menu with your profile and stats
5. **Click** "Play"
6. **Play the game** and earn points
7. **See:** Achievement notifications pop up! 🏆
8. **Wait** for game over
9. **See:** "Score saved!" message
10. **Click** "Leaderboard"
11. **See:** Your score and rank
12. **Click** "Achievements"
13. **See:** Your unlocked achievements

✅ **Everything working!**

---

## 🧙 What the Setup Wizard Does

| Check | Auto-Fix? | Details |
|-------|-----------|---------|
| Godot Version | ❌ | Verifies you're on Godot 4.x |
| CheddaBoards Autoload | ✅ | Adds to Project Settings if missing |
| Achievements Autoload | ✅ | Adds to Project Settings if missing |
| Required Files | ❌ | Lists what's missing |
| CheddaBoards.gd Config | ❌ | Validates signals/functions exist |
| Project Settings | ❌ | Checks stretch mode, main scene |
| Export Preset | ❌ | Warns if Web export not configured |
| template.html | ❌ | Validates file exists |
| Game ID | ✅ | Interactive popup to configure |

**Run the wizard anytime** to check your project health!

---

## 🎯 What You Should Have Working

After setup:

- ✅ Authentication (Google, Apple, Internet Identity)
- ✅ Profile display (nickname, high score, best streak, games played)
- ✅ Score submission
- ✅ Achievement unlocking & notifications
- ✅ Leaderboard with rankings
- ✅ Achievement view
- ✅ Session persistence (stay logged in on refresh)

---

## 🔧 Troubleshooting

### "Engine is not defined" error

**Cause:** Export files not named `index.*`

**Fix:** Re-export and save as `index.html` (not `MyGame.html`)

---

### "CheddaBoards not ready" error

**Cause:** SDK not initialized yet

**Fix:** Run the Setup Wizard first! It auto-adds the autoload.

Or add this to your script:
```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    # Now safe to use CheddaBoards
```

---

### "Game not registered" error

**Cause:** Game ID doesn't match

**Fix:**
1. Run the Setup Wizard
2. Enter the correct Game ID in the popup
3. Game IDs are case-sensitive!

---

### Login popup blocked

**Cause:** Browser blocking popups

**Fix:**
- Allow popups for localhost in browser settings
- Make sure login is triggered by direct button click
- Try a different browser

---

### Blank screen / CORS error

**Cause:** Opening HTML file directly (file://)

**Fix:** Use a web server:
```bash
python3 -m http.server 8000
```
Then open http://localhost:8000

---

### Achievements not showing

**Cause:** Achievements autoload not configured

**Fix:** Run the Setup Wizard - it auto-adds the autoload!

---

### "Cannot find CheddaBoards"

**Cause:** Autoload missing or misnamed

**Fix:** Run the Setup Wizard - it auto-adds autoloads with correct names!

---

### Score not submitting

**Cause:** Not authenticated

**Fix:**
1. Check `CheddaBoards.is_authenticated()` returns true
2. Connect to `score_error` signal to see error messages
3. Check browser console (F12) for errors

---

### Setup Wizard shows errors

**Cause:** Missing files or misconfiguration

**Fix:** 
1. Read the error messages in the summary
2. Download any missing files from GitHub
3. Run the wizard again

---

### "localhost:4943" connection errors

**Cause:** SDK trying to connect to local ICP replica

**Fix:** Add `host` option in template.html:
```javascript
chedda = await window.CheddaBoards.init(CONFIG.CANISTER_ID, {
  gameId: CONFIG.GAME_ID,
  host: 'https://icp-api.io'  // Force mainnet
});
```

---

## 📁 Final Project Structure

After setup, your project should look like:

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd      ← Core SDK (Autoload ✓)
│       ├── Achievements.gd      ← Achievement system (Autoload ✓)
│       ├── SetupWizard.gd       ← Setup tool
│       ├── plugin.cfg
│       └── icon.png
├── template.html                ← Web template (Game ID ✓)
├── scenes/
│   ├── MainMenu.tscn/.gd
│   ├── Game.tscn/.gd
│   ├── Leaderboard.tscn/.gd
│   └── AchievementsView.tscn/.gd
├── export_presets.cfg           ← Created when you add Web export
└── project.godot                ← Autoloads added by wizard
```

---

## 🎨 Next Steps

Now that it's working:

1. **Replace Game.tscn** with your actual game
2. **Customize achievements** in `Achievements.gd`
3. **Style the UI** to match your game's theme
4. **Deploy** to Netlify, Vercel, or itch.io

---

## 📚 More Help

- **Full Documentation:** See README.md
- **Quick Reference:** See QUICKSTART.md
- **Example Game:** https://thecheesegame.online
- **Support:** info@cheddaboards.com

---

## ✅ Setup Complete!

You now have a fully functional CheddaBoards integration!

**Time to build your game!** 🎮🧀
