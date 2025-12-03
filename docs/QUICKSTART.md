# ⚡ CheddaBoards Quick Start

**Get leaderboards in your Godot 4 web game in 5 minutes!**

---

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

## 🎉 Total Time: ~5 minutes!

---

## ✅ Verify It Works:

1. **Click "Sign in with Google"** → Login popup opens
2. **Play a game** → Score increments
3. **Game over** → "Score submitted!" message
4. **View Leaderboard** → Your score appears
5. **Check profile** → Shows your stats

---

## 🧙 What the Setup Wizard Does

The wizard automatically:

| Check | Auto-Fix |
|-------|----------|
| Godot 4.x version | ❌ (manual upgrade needed) |
| CheddaBoards autoload | ✅ Adds if missing |
| Achievements autoload | ✅ Adds if missing |
| Required files exist | ❌ (tells you what's missing) |
| template.html present | ❌ (tells you to download) |
| Game ID configured | ✅ Opens config popup |
| Export preset exists | ⚠️ Warns if missing |

**Run it anytime** to check your project status!

---

## ❓ Common Issues

### "CheddaBoards not found"
→ Run the Setup Wizard - it will auto-add the autoload

### "Game not registered" error
→ Did you complete Step 1? Run wizard to verify Game ID

### "Login popup blocked"
→ Allow popups for localhost in your browser

### "Blank screen / CORS error"
→ Use `python3 -m http.server`, don't open HTML directly

### "Engine is not defined" error
→ You didn't export as `index.html` - rename files to index.*

### "Score not submitting"
→ Check browser console (F12) for errors

---

## 📁 Your Project Structure

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd    ← Core SDK (auto-added to Autoload)
│       ├── Achievements.gd    ← Achievement system (auto-added)
│       ├── SetupWizard.gd     ← Run via File → Run
│       ├── plugin.cfg
│       └── icon.png
├── template.html              ← Web export template
├── MainMenu.tscn
├── Game.tscn
├── Leaderboard.tscn
└── project.godot
```

---

## 🎮 Basic Usage in Your Code

```gdscript
# Wait for SDK
await CheddaBoards.wait_until_ready()

# Login
CheddaBoards.login_google()

# Submit score
CheddaBoards.submit_score(1000, 5)  # score, streak

# Get leaderboard
CheddaBoards.get_leaderboard("score", 100)

# Check if logged in
if CheddaBoards.is_authenticated():
    print("Logged in as: ", CheddaBoards.get_nickname())
```

---

## 🚀 Next Steps

1. ✅ **Working?** → Customize for your game
2. 📖 **Need details?** → Read the full SETUP.md
3. 🏆 **Add achievements?** → See Achievements.gd
4. 🎨 **Style it?** → Edit the CSS in template.html
5. 🌐 **Deploy?** → Upload to Netlify, Vercel, or itch.io

---

## 💡 Pro Tips

- ⭐ Run the Setup Wizard anytime to check project health
- ⭐ Always export as `index.html`
- ⭐ Always test with a local server, never file://
- ⭐ Check browser console (F12) for debug logs
- ⭐ Clear browser cache if you see stale data
- ⭐ The canister ID is the same for everyone: `fdvph-sqaaa-aaaap-qqc4a-cai`

---

## 🔗 Resources

- **Developer Dashboard:** https://cheddaboards.com
- **GitHub:** https://github.com/cheddatech/CheddaBoards-Godot
- **Example Game:** https://thecheesegame.online

---

**Questions?** → info@cheddaboards.com

**Ready to add leaderboards to your game? Start at https://cheddaboards.com** 🚀
