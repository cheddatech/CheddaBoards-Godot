# 🔧 CheddaBoards Troubleshooting Guide

**Having issues? Find your platform, then your problem below!**

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

**What platform are you on?**

| Platform | Common Issues |
|----------|---------------|
| Web | [Browser Problems](#-browser-problems), [Login Problems](#-login-problems) |
| Native (Win/Mac/Linux) | [API Key Problems](#-api-key-problems), [High-DPI Problems](#-high-dpi-problems) |
| Both | [Project Problems](#-project-problems), [Score Problems](#-score-problems) |

**What's not working?**

| Problem | Jump to |
|---------|---------|
| Template won't open | [Project Problems](#-project-problems) |
| API key errors (native) | [API Key Problems](#-api-key-problems) |
| Clicks offset / wrong position | [High-DPI Problems](#-high-dpi-problems) |
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
| `res://addons/cheddaboards/CheddaBoards.gd` | `CheddaBoards` |
| `res://addons/cheddaboards/Achievements.gd` | `Achievements` |

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

## 🔑 API Key Problems

### Problem: "API key not set" error

**Cause:** Native builds require an API key

**Solution:**
1. Go to **cheddaboards.com**
2. Go to your **Game Dashboard**
3. Click **"Generate API Key"**
4. Copy the key (looks like `cb_yourgame_xxxxxxxxx`)
5. Open `addons/cheddaboards/CheddaBoards.gd`
6. Find this line (around line 35):
   ```gdscript
   var api_key: String = ""
   ```
7. Change to:
   ```gdscript
   var api_key: String = "cb_your_api_key_here"
   ```

**Or set at runtime:**
```gdscript
func _ready():
    CheddaBoards.set_api_key("cb_your_api_key_here")
```

---

### Problem: "Request failed" errors on native

**Checklist:**
```
[ ] API key is set correctly
[ ] API key matches the game on dashboard
[ ] Internet connection is working
```

**Debug:**
```gdscript
# Enable logging to see what's happening
CheddaBoards.debug_logging = true

# Check the request_failed signal
CheddaBoards.request_failed.connect(func(endpoint, error):
    print("Request to %s failed: %s" % [endpoint, error])
)
```

---

## 🖱️ High-DPI Problems

### Problem: Clicks are offset / wrong position

**Symptom:** You click on a button but it doesn't register, or you have to click below/above the actual button.

**Cause:** Display scaling (125%, 150%, etc.) on Windows/Mac

**Solution:**
1. **Project → Project Settings**
2. **Display → Window → DPI**
3. Set **Allow Hidpi:** `On`

**Alternative:** Add to your main script:
```gdscript
func _ready():
    get_window().content_scale_factor = DisplayServer.screen_get_scale()
```

---

### Problem: UI looks tiny or huge on different displays

**Solution:**
1. **Project → Project Settings**
2. **Display → Window → Stretch**
3. Set **Mode:** `canvas_items`
4. Set **Aspect:** `keep`

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

### Problem: Forgot to set Custom HTML Shell (Web)

**This is critical for web builds!** Without it, CheddaBoards won't work.

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
python3 -m http.server 8000

# Open in browser
# http://localhost:8000
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

### Problem: "Engine is not defined" error

**Cause:** Export files not named `index.*`

**Solution:** Re-export and save as `index.html` (not `MyGame.html`)

The template expects `index.js` - other names will cause errors!

---

## 🔐 Login Problems

### Problem: Which login methods work?

| Method | Web | Native | Setup Required |
|--------|-----|--------|----------------|
| **Anonymous** | ✅ | ✅ | Just API key |
| **Chedda ID** | ✅ | ❌ | None - works out of box! |
| **Google** | ✅ | ❌ | Your own OAuth credentials |
| **Apple** | ✅ | ❌ | Your own OAuth credentials |

---

### Problem: Login button does nothing (Web)

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

### Problem: Google/Apple login not working

**Cause:** These require your own OAuth credentials

**Solution:** 
- Use **Chedda ID** or **Anonymous** login instead (work out of box!)
- Or set up your own OAuth credentials in `template.html`:

```javascript
const CONFIG = {
    // ...
    GOOGLE_CLIENT_ID: 'your-client-id.apps.googleusercontent.com',
    APPLE_SERVICE_ID: 'com.yourdomain.yourapp',
};
```

See SETUP.md for full OAuth setup instructions.

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

---

### Problem: Anonymous login not working (Native)

**Checklist:**
```
[ ] API key is set in CheddaBoards.gd
[ ] Using CheddaBoards.login_anonymous("PlayerName")
[ ] Waiting for SDK ready first
```

**Correct code:**
```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("PlayerName")
```

---

## 💾 Score Problems

### Problem: "Not authenticated" error

**Cause:** Trying to submit score without logging in

**Solution:**
```gdscript
# For native - use anonymous login
await CheddaBoards.wait_until_ready()
CheddaBoards.login_anonymous("PlayerName")

# Then submit
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
4. Check console for errors

---

### Problem: "Score submission failed" error

**Solution:**
```gdscript
# Connect to error signal to see details
CheddaBoards.score_error.connect(_on_score_error)

func _on_score_error(reason: String):
    print("Score failed: ", reason)
```

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
```gdscript
# Make sure you're calling the check methods
Achievements.check_score(current_score)
Achievements.check_combo(max_combo)
Achievements.increment_games_played()
```

---

### Problem: Achievement notification not showing

**Cause:** AchievementNotification node missing from scene

**Solution:**
1. Add `AchievementNotification` scene to your Game scene
2. Make sure the node is **visible** in the Inspector
3. Connect the signal if needed:
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

## 📊 Leaderboard Problems

### Problem: Leaderboard is empty

**Possible causes:**

1. **No scores submitted yet** - Submit a test score first
2. **Wrong Game ID / API key** - Run Setup Wizard to check!
3. **Network error** - Check console for errors

**Solution:**
1. Play a game and submit a score
2. Run Setup Wizard → verify Game ID
3. Check console for `[CheddaBoards]` messages

---

### Problem: Leaderboard shows wrong data

**Cause:** Wrong Game ID

**Solution:**
1. Run the Setup Wizard
2. Check the Game ID matches your game on cheddaboards.com
3. Each game has its own separate leaderboard

---

## 🚪 Exit Button Problems

### Problem: Exit button doesn't work on web

**Cause:** `get_tree().quit()` doesn't work in browsers

**Solution:**
```gdscript
func _on_exit_pressed():
    if OS.get_name() == "Web":
        JavaScriptBridge.eval("window.location.href = 'https://yourdomain.com'")
    else:
        get_tree().quit()
```

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

---

## 🐛 Debug Tools

### Setup Wizard

Run anytime to check project health:
```
File → Run → SetupWizard.gd
```

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

### Keyboard Shortcuts (Add to Your Game)

```gdscript
func _input(event):
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F9:
            CheddaBoards.debug_status()
        if event.keycode == KEY_F10:
            Achievements.debug_status()
```

### Browser Console (Web)

1. Press **F12**
2. Go to **Console** tab
3. Look for:
   - `[CheddaBoards]` messages
   - `[Achievements]` messages
   - Red error messages

---

## ✅ Pre-Flight Checklist

### Web Builds

- [ ] Setup Wizard shows all green
- [ ] Game ID configured (not default)
- [ ] **Custom HTML Shell** set to `res://template.html`
- [ ] Exported as `index.html`
- [ ] Using **web server** (not file://)
- [ ] Browser console shows **no red errors**

### Native Builds

- [ ] Setup Wizard shows all green
- [ ] **API key** set in CheddaBoards.gd
- [ ] Using `login_anonymous()` for auth
- [ ] **Allow Hidpi** enabled (for high-DPI displays)

---

## 🆘 Still Stuck?

### When asking for help, include:

1. **Platform:** Web or Native (Win/Mac/Linux)?
2. **Setup Wizard output** (copy from console)
3. **Godot version** (e.g., 4.3.1)
4. **Error messages** (screenshot or copy)
5. **Output of** `CheddaBoards.debug_status()`

### Where to get help:

- **Email:** info@cheddaboards.com
- **GitHub Issues:** github.com/cheddatech/CheddaBoards-Godot
- **Example Games:** 
  - thecheesegame.online (Web)
  - cheddaclick.cheddagames.com (Web + Native)

---

## 💡 90% of Problems Are Fixed By:

### Web
1. 🧙 **Running the Setup Wizard**
2. ✅ Using a web server (file:// doesn't work!)
3. ✅ Correct Game ID
4. ✅ Custom HTML Shell set in export
5. ✅ Exported as `index.html`

### Native
1. 🧙 **Running the Setup Wizard**
2. ✅ API key set in CheddaBoards.gd
3. ✅ Using `login_anonymous()`
4. ✅ Allow Hidpi enabled for high-DPI displays

**Run the wizard, fix these basics, and you're golden!** 🎯

---

**You got this!** 💪🧀
