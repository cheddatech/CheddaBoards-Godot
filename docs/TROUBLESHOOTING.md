# 🔧 CheddaBoards Troubleshooting Guide

**Having issues? Run the Setup Wizard first, then find your problem below!**

---

## 🧙 First: Run the Setup Wizard

**Before anything else, run the wizard!** It auto-fixes most common issues.

```
File → Run (Ctrl+Shift+X) → Select SetupWizard.gd
```

The wizard will:
- ✅ Auto-add missing Autoloads
- ✅ Check all required files
- ✅ Validate your Game ID
- ✅ Show exactly what's wrong

**Still having problems after running the wizard?** Find your issue below 👇

---

## 🚨 Quick Diagnosis

**What's not working?**

| Problem | Jump to |
|---------|---------|
| Template won't open | [Project Problems](#-project-problems) |
| Export fails | [Export Problems](#-export-problems) |
| Blank screen in browser | [Browser Problems](#-browser-problems) |
| Login not working | [Login Problems](#-login-problems) |
| Scores not saving | [Score Problems](#-score-problems) |
| Achievements broken | [Achievement Problems](#-achievement-problems) |
| Leaderboard empty | [Leaderboard Problems](#-leaderboard-problems) |

---

## 📂 Project Problems

### Problem: Template won't open in Godot

**Are you using Godot 4.x?**
```
Godot 3.x → ❌ Won't work! Download Godot 4+
Godot 4.x → ✅ Should work
```

**Solution:**
1. Download Godot 4.x from godotengine.org
2. Open Godot → Import → Browse to `project.godot`
3. Click "Import & Edit"

---

### Problem: "Autoload not found" error

**Solution:** Run the Setup Wizard! It auto-adds missing autoloads.

```
File → Run → SetupWizard.gd
```

**Manual fix (if needed):**
1. **Project → Project Settings → Autoload**
2. Click **+** to add:

| Path | Name |
|------|------|
| `res://CheddaBoards.gd` | `CheddaBoards` |
| `res://Achievements.gd` | `Achievements` |

3. Make sure both are **enabled** (checkbox)
4. Names must be **exact** (case-sensitive)!

---

### Problem: "CheddaBoards not ready" errors

**Cause:** Using CheddaBoards before SDK is loaded

**First:** Run the Setup Wizard to verify autoloads are configured.

**Then** add this to your script:
```gdscript
func _ready():
    # Wait for SDK to initialize
    await CheddaBoards.wait_until_ready()
    
    # Now safe to use
    if CheddaBoards.is_authenticated():
        print("Logged in!")
```

---

## 📦 Export Problems

### Problem: No "Web" export option

**Solution:**
1. **Project → Export**
2. Click **Add...** → Select **Web**
3. If prompted for templates → **Download and Install**
4. Wait for download to complete
5. Close and reopen Export dialog

---

### Problem: Export fails

**Check the error:**

| Error | Solution |
|-------|----------|
| "Export template not found" | Editor → Manage Export Templates → Download |
| "Can't write to folder" | Choose a different export folder |
| "Custom HTML Shell not found" | Check path: `res://template.html` |

---

### Problem: Forgot to set Custom HTML Shell

**This is critical!** Without it, CheddaBoards won't work.

**Solution:**
1. **Project → Export → Web**
2. Scroll to **HTML** section
3. Set **Custom HTML Shell:** `res://template.html`
4. Re-export

💡 **Tip:** The Setup Wizard warns you if this isn't configured!

---

## 🌐 Browser Problems

### Problem: Blank page / nothing loads

**How are you opening it?**

```
file:///path/to/index.html → ❌ WON'T WORK!
http://localhost:8000     → ✅ Correct way
```

**Solution:**
```bash
# Navigate to your export folder
cd path/to/exported/game

# Start a web server
python -m http.server 8000

# Open in browser
# http://localhost:8000
```

**Alternative servers:**
```bash
# Node.js
npx http-server -p 8000

# PHP
php -S localhost:8000
```

---

### Problem: CORS error in console

**Cause:** Opening HTML file directly (file://)

**Solution:** Use a web server (see above)

---

### Problem: "CheddaBoards is not defined"

**Cause:** HTML template not configured correctly

**Solution:**
1. Check you set **Custom HTML Shell** in export settings
2. Verify `template.html` exists in project root
3. Re-export the project

---

### Problem: Game loads but shows JavaScript errors

**Solution:**
1. Press **F12** to open browser console
2. Look for red errors
3. Common fixes:
   - Re-export from Godot
   - Clear browser cache
   - Try different browser

---

## 🔐 Login Problems

### Problem: Login button does nothing

**Checklist:**
```
[ ] Using web server (not file://)
[ ] Popups allowed in browser
[ ] Game ID configured (run Setup Wizard!)
```

**Solution:**
1. Must use `http://` or `https://` (not `file://`)
2. Allow popups for localhost in browser settings
3. Try a different browser

---

### Problem: Popup blocked

**Solution:**
1. Look for popup blocked icon in browser address bar
2. Click it → Allow popups for this site
3. Try login again

---

### Problem: "Game not registered" error

**Cause:** Game ID doesn't match

**Solution:** Run the Setup Wizard and use the Game ID popup!

```
File → Run → SetupWizard.gd → Enter correct Game ID → Save
```

**Manual fix:**
1. Go to **cheddaboards.com**
2. Check your registered game's ID
3. Open `template.html`
4. Make sure `GAME_ID` matches **exactly** (case-sensitive)

```javascript
const CONFIG = {
  GAME_ID: 'your-exact-game-id',  // ← Must match dashboard
  ...
};
```

---

### Problem: Login succeeds but profile doesn't show

**Solution:**
1. Press **F12** → Check console for errors
2. Look for `[CheddaBoards] profile_loaded` message
3. If no message, try:
   - Clear browser cache
   - Logout and login again
   - Run Setup Wizard to check Game ID

---

## 💾 Score Problems

### Problem: "Not authenticated" error

**Cause:** Trying to submit score without logging in

**Solution:**
```gdscript
# Always check authentication before submitting
if CheddaBoards.is_authenticated():
    CheddaBoards.submit_score(score, streak)
else:
    print("Please login first!")
```

---

### Problem: Score submits but doesn't appear on leaderboard

**Possible causes:**

1. **Same score as before** - Leaderboard shows high scores only
2. **Network delay** - Wait 5-10 seconds, then refresh
3. **Wrong Game ID** - Run Setup Wizard to check!

**Solution:**
1. Submit a HIGHER score than your previous high
2. Wait a few seconds
3. Click Refresh on leaderboard
4. Check browser console for errors

---

### Problem: "Score submission failed" error

**Solution:**
1. Connect to error signal to see details:
```gdscript
CheddaBoards.score_error.connect(_on_score_error)

func _on_score_error(reason: String):
    print("Score failed: ", reason)
```
2. Check browser console for more details
3. Verify you're authenticated

---

## 🏆 Achievement Problems

### Problem: Achievements not unlocking

**First:** Run the Setup Wizard to verify Achievements autoload exists!

**Checklist:**
```
[ ] Achievements.gd in Autoload (wizard auto-adds this!)
[ ] Logged in (authenticated)
[ ] Achievement conditions met (score >= threshold)
```

**Solution:**
1. Check you're logged in first
2. Verify conditions in `Achievements.gd`:
```gdscript
# score_100 unlocks at score >= 100
# streak_5 unlocks at streak >= 5
```
3. Check console for `[Achievements] 🏆 Unlocked:` messages

---

### Problem: Achievement notification not showing

**Cause:** AchievementNotification node missing from scene

**Solution:**
1. Add `AchievementNotification` scene to your Game scene
2. Connect the signal:
```gdscript
Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
```

---

### Problem: Achievements not saving / syncing

**Solution:**
1. Must be logged in to save achievements
2. Use `Achievements.submit_with_score()` to sync:
```gdscript
# This submits score AND pending achievements
Achievements.submit_with_score(score, streak)
```

---

### Problem: Achievements reset on refresh

**Cause:** Not synced to backend

**Solution:**
1. Always submit score at game over (syncs achievements)
2. Check you're authenticated
3. Use `Achievements.debug_status()` to inspect state

---

## 📊 Leaderboard Problems

### Problem: Leaderboard is empty

**Possible causes:**

1. **No scores submitted yet** - Submit a test score first
2. **Wrong Game ID** - Run Setup Wizard to check!
3. **Network error** - Check browser console

**Solution:**
1. Play a game and submit a score
2. Run Setup Wizard → verify Game ID
3. Press F12 → Look for `[Leaderboard]` messages

---

### Problem: Only seeing my own score

**This is normal!** If you're the only player, you'll be alone on the leaderboard.

---

### Problem: Leaderboard shows wrong data

**Cause:** Wrong Game ID

**Solution:**
1. Run the Setup Wizard
2. Check the Game ID matches your game on cheddaboards.com
3. Each game has its own separate leaderboard

---

## 🔄 Cache Problems

### Problem: Changes not appearing

**Nuclear option - clear everything:**

1. Close browser completely
2. Clear cache and cookies for localhost
3. In Godot: Re-export the project
4. Restart web server
5. Open browser → Hard refresh (**Ctrl + Shift + R**)

---

### Problem: Old profile data showing

**Solution:**
```gdscript
# Force profile refresh
CheddaBoards.refresh_profile()
```

Or clear localStorage in browser:
1. Press F12
2. Go to Application tab
3. Clear Local Storage for localhost

---

## 🐛 Debug Tools

### Setup Wizard

Run anytime to check project health:
```
File → Run → SetupWizard.gd
```

### Keyboard Shortcuts

| Key | Action | Scene |
|-----|--------|-------|
| **F8** | Force profile refresh | MainMenu |
| **F9** | Dump debug info | MainMenu |
| **Ctrl+Shift+C** | Clear achievement cache | Game |
| **Ctrl+Shift+D** | Print debug status | Game |

### Debug Methods

```gdscript
# Print full CheddaBoards status
CheddaBoards.debug_status()

# Print achievement status
Achievements.debug_status()

# Enable verbose logging
CheddaBoards.debug_logging = true
Achievements.debug_logging = true
```

### Browser Console

1. Press **F12**
2. Go to **Console** tab
3. Look for:
   - `[CheddaBoards]` messages
   - `[Achievements]` messages
   - Red error messages

---

## ✅ Pre-Flight Checklist

**Step 1: Run the Setup Wizard!**
```
File → Run → SetupWizard.gd
```

**Step 2: Verify the wizard shows:**
- [ ] ✅ Godot 4.x detected
- [ ] ✅ CheddaBoards autoload present
- [ ] ✅ Achievements autoload present
- [ ] ✅ template.html found
- [ ] ✅ Game ID configured (not default)

**Step 3: Manual checks:**
- [ ] **Custom HTML Shell** set in export settings
- [ ] Using **web server** (not file://)
- [ ] **Logged in** before testing features
- [ ] Browser console shows **no red errors**

---

## 🆘 Still Stuck?

### When asking for help, include:

1. **Setup Wizard output** (copy from console)
2. **Godot version** (e.g., 4.3.1)
3. **Browser** (e.g., Chrome 120)
4. **Console errors** (screenshot)
5. **What you've tried**
6. **Output of** `CheddaBoards.debug_status()`

### Where to get help:

- **Email:** info@cheddaboards.com
- **GitHub Issues:** github.com/cheddatech/CheddaBoards-SDK
- **Example Game:** thecheesegame.online (see it working)

---

## 💡 90% of Problems Are Fixed By:

1. 🧙 **Running the Setup Wizard first!**
2. ✅ Using Godot 4.x (not 3.x)
3. ✅ Using a web server (file:// doesn't work!)
4. ✅ Correct Game ID (wizard popup makes this easy)
5. ✅ Custom HTML Shell set in export
6. ✅ Being logged in before testing

**Run the wizard, fix these basics, and you're golden!** 🎯

---

**You got this!** 💪🧀
