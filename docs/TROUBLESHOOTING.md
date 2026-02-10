# 🔧 CheddaBoards Troubleshooting

**Find your problem, get the fix.**

---

## 🚨 Quick Fixes

**90% of problems are solved by:**

| Problem Type | Fix |
|--------------|-----|
| API/Native issues | Check API key is set correctly |
| Web issues | Use web server (not file://), export as `index.html` |
| Both | Run Setup Wizard, check Autoloads |

---

## 🧙 First: Run the Setup Wizard

Before debugging manually, run the wizard:

```
File → Run (Ctrl+Shift+X) → Select SetupWizard.gd
```

It auto-fixes:
- ✅ Missing Autoloads
- ✅ Wrong Game ID
- ✅ Export settings

---

## Find Your Issue

| What's broken? | Jump to |
|----------------|---------|
| API key errors | [API Key Issues](#-api-key-issues) |
| Login not working | [Login Issues](#-login-issues) |
| Scores not saving | [Score Issues](#-score-issues) |
| Leaderboard empty | [Leaderboard Issues](#-leaderboard-issues) |
| Web blank screen | [Web Issues](#-web-issues) |
| Clicks offset | [Display Issues](#-display-issues) |
| Achievements | [Achievement Issues](#-achievement-issues) |

---

# 🔑 API Key Issues

### "API key not set"

**Cause:** Native builds require an API key.

**Fix:**
1. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
2. Open your game → Generate API Key
3. Copy the key (looks like `cb_your-game_xxxxxxxxx`)
4. Set in CheddaBoards.gd:

```gdscript
var api_key: String = "cb_your-game_xxxxxxxxx"
```

### "Invalid API key"

**Cause:** Key doesn't match game or was revoked.

**Fix:**
1. Go to dashboard
2. Check the key matches your game
3. Generate a new key if needed

### "Request failed"

**Checklist:**
- [ ] API key is correct
- [ ] Internet connection works
- [ ] Game is registered and active

**Debug:**
```gdscript
CheddaBoards.debug_logging = true
CheddaBoards.request_failed.connect(func(endpoint, error):
    print("Failed: %s - %s" % [endpoint, error])
)
```

---

# 🔐 Login Issues

### Which login works where?

| Method | Web | Native |
|--------|-----|--------|
| Anonymous | ✅ | ✅ |
| Chedda ID | ✅ | ❌ |
| Google | ✅ | ❌ |
| Apple | ✅ | ❌ |
| Account Upgrade (Anon → Google/Apple) | ✅ | ❌ |

### "Not authenticated"

**Cause:** Trying to submit score without logging in.

**Fix:**
```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("Player")  # Do this first!

func _on_game_over(score, streak):
    if CheddaBoards.is_authenticated():
        CheddaBoards.submit_score(score, streak)
    else:
        print("Not logged in!")
```

### Login button does nothing (Web)

**Checklist:**
- [ ] Using http://localhost, not file://
- [ ] Popups allowed in browser
- [ ] Game ID set in template.html

### Popup blocked

1. Look for blocked popup icon in address bar
2. Click → Allow popups for this site
3. Try again

### Google/Apple login not working

**Checklist:**
- [ ] Using http:// or https://, not file://
- [ ] Popups allowed in browser
- [ ] Game ID set in template.html
- [ ] Using latest template.html with OAuth support

---

# 💾 Score Issues

### Score not saving

**Checklist:**
- [ ] `is_authenticated()` returns true
- [ ] API key is set (native)
- [ ] No errors in console

**Debug:**
```gdscript
CheddaBoards.score_error.connect(func(reason):
    print("Score error: ", reason)
)

CheddaBoards.score_submitted.connect(func(score, streak):
    print("Saved: %d, %d" % [score, streak])
)
```

### Score saves but doesn't appear on leaderboard

**Causes:**
1. Score isn't higher than previous best
2. Network delay - wait 5 seconds
3. Wrong Game ID

**Fix:** Submit a higher score, refresh leaderboard.

### "Score rejected" or anti-cheat error

**Cause:** Score exceeds game's anti-cheat limits.

**Fix:** Check your game's rules on the dashboard. Default limits:
- Max score per round: 5,000
- Max streak delta: 200
- Absolute score cap: 100,000

---

# 📊 Leaderboard Issues

### Leaderboard is empty

**Causes:**
1. No scores submitted yet
2. Wrong Game ID
3. Network error

**Fix:**
1. Submit a test score first
2. Run Setup Wizard to verify Game ID
3. Check console for errors

### Wrong data showing

**Cause:** Wrong Game ID - each game has its own leaderboard.

**Fix:** Verify Game ID in template.html or CheddaBoards.gd matches dashboard.

---

# 🌐 Web Issues

### Blank screen / nothing loads

**Cause:** Opening HTML file directly (file://)

**Fix:** Use a web server:
```bash
cd your-export-folder
python3 -m http.server 8000
# Open http://localhost:8000
```

### "Engine is not defined"

**Cause:** Export not named `index.html`

**Fix:** Re-export and save as `index.html` (not MyGame.html)

### "CheddaBoards is not defined"

**Cause:** Custom HTML Shell not set.

**Fix:**
1. Project → Export → Web
2. HTML section → Custom HTML Shell: `res://template.html`
3. Re-export

### CORS error

**Cause:** Using file:// instead of http://

**Fix:** Use local web server (see blank screen fix above)

---

# 🖥️ Display Issues

### Clicks offset / wrong position

**Cause:** High-DPI display scaling (125%, 150%)

**Fix:**
1. Project → Project Settings
2. Display → Window → DPI
3. **Allow Hidpi:** `On`

### UI too small/large

**Fix:**
1. Display → Window → Stretch
2. **Mode:** `canvas_items`
3. **Aspect:** `keep`

---

# 🏆 Achievement Issues

### Achievements not unlocking

**Checklist:**
- [ ] Achievements.gd in Autoloads
- [ ] Player is authenticated
- [ ] Calling the check methods

**Fix:**
```gdscript
Achievements.check_score(score)
Achievements.increment_games_played()
```

### Achievements not saving

**Cause:** Not syncing to backend.

**Fix:** Use `submit_with_score()`:
```gdscript
Achievements.submit_with_score(score, streak)
```

---

# 🐛 Debug Tools

### Enable Logging

```gdscript
CheddaBoards.debug_logging = true
Achievements.debug_logging = true
```

### Print Status

```gdscript
CheddaBoards.debug_status()
Achievements.debug_status()
```

### Add Debug Keys

```gdscript
func _input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_F9: CheddaBoards.debug_status()
            KEY_F10: Achievements.debug_status()
```

### Browser Console (Web)

1. Press F12
2. Console tab
3. Look for `[CheddaBoards]` messages

---

# ✅ Pre-Flight Checklist

### API/Native Build

- [ ] API key set in CheddaBoards.gd
- [ ] CheddaBoards in Autoloads
- [ ] Using `login_anonymous()` before submitting
- [ ] Allow Hidpi enabled (for high-DPI)

### Web Build

- [ ] Game ID set in template.html
- [ ] Custom HTML Shell: `res://template.html`
- [ ] Exported as `index.html`
- [ ] Testing with web server (not file://)

---

# 🆘 Still Stuck?

### Include This Info

1. **Platform:** Web or Native?
2. **Godot version:** e.g., 4.3.1
3. **Error message:** Screenshot or copy
4. **Output of:** `CheddaBoards.debug_status()`

### Get Help

- **Email:** info@cheddaboards.com
- **GitHub:** [Issues](https://github.com/cheddatech/CheddaBoards-Godot/issues)

---

**Most problems = API key (native) or web server (web). Check those first!** 🧀
