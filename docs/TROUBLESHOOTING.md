# CheddaBoards Troubleshooting

Find your problem, get the fix.

---

## Start here

**90% of problems** are one of these:

| Symptom | First thing to try |
|---------|--------------------|
| API / Native issues | Check your API key is set in `_ready()` |
| Web issues | Serve over HTTP (not `file://`), export as `index.html` |
| Anything in the Template | Run the **Setup Wizard**, confirm your Autoloads |
| Need to see what's going on | Press **F9** in-game (wrapper status) or **F10** (achievements status) |

**Run the Setup Wizard first.** `File → Run → addons/cheddaboards/SetupWizard.gd`. It registers the autoloads and writes your credentials (paste just your API key — it reads the Game ID from it).

**Use the built-in debug hotkeys.** The Template wrapper prints a full status dump on **F9**, and the achievements state on **F10**. Start there before adding any debug code of your own.

---

## Find your issue

| What's broken? | Jump to |
|----------------|---------|
| API key errors | [API key issues](#api-key-issues) |
| Login not working | [Login issues](#login-issues) |
| Scores not saving | [Score issues](#score-issues) |
| Leaderboard empty or stale | [Leaderboard issues](#leaderboard-issues) |
| Game-over screen won't show | [Template issues](#template-issues) |
| My game won't load / still CheddaClick | [Template issues](#template-issues) |
| Signals not connecting | [Template issues](#template-issues) |
| Restart / Play Again broken | [Template issues](#template-issues) |
| HUD not updating | [Template issues](#template-issues) |
| Achievements not firing | [Achievement issues](#achievement-issues) |
| Web blank screen | [Web issues](#web-issues) |
| Clicks offset | [Display issues](#display-issues) |

---

## API key issues

### "API key not set"

**Cause:** SDK v2.2.0+ ships with empty credential defaults — it doesn't know which game it's talking to until you tell it.

**Fix:** set credentials in `_ready()` before any other CheddaBoards call:

```gdscript
func _ready():
    CheddaBoards.set_api_key("cb_your-game_xxxxxxxxx")
    CheddaBoards.set_game_id("your-game-id")
```

(In the Template, the Setup Wizard writes these into `MainMenu.gd` for you.)

### "Invalid API key"

The key doesn't match the game, or it was revoked. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard), confirm the key matches your game, and generate a new one if needed.

### "Request failed"

Check: the API key is correct, you have a working connection, and the game is registered and active. To see the reason:

```gdscript
CheddaBoards.request_failed.connect(func(endpoint, error):
    print("Failed: %s — %s" % [endpoint, error])
)
```

---

## Login issues

### Which login works where?

| Method | Native | Mobile | Web |
|--------|--------|--------|-----|
| Anonymous | ✅ | ✅ | ✅ |
| Google (Device Code) | ✅ | ✅ | ✅ |
| Apple (Device Code) | ✅ | ✅ | ✅ |
| Account Upgrade (anon → verified) | ✅ | ✅ | ✅ |

> Legacy direct OAuth (in-browser Google/Apple buttons in `template.html`) was removed in v2.0.0. See [Web Export](guides/web-export.md) if you're maintaining a v1.x project that still uses it.

### "Not authenticated"

**Cause:** submitting a score before login finished.

**Fix:** wait for the SDK, log in, *then* submit.

```gdscript
func _ready():
    CheddaBoards.set_api_key("cb_your-game_xxxxxxxxx")
    CheddaBoards.set_game_id("your-game-id")
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("Player")   # do this first

func _on_game_over(score, streak):
    if CheddaBoards.is_authenticated():
        CheddaBoards.submit_score(score, streak)
    else:
        print("Not logged in!")
```

### Device code not appearing

Check you're connected to `device_code_received`, your connection works, and the API key is set:

```gdscript
CheddaBoards.device_code_received.connect(func(user_code, verification_url, qr_data_url):
    print("Code: %s at %s" % [user_code, verification_url])
)
CheddaBoards.device_code_expired.connect(func(): print("Device code expired"))
CheddaBoards.login_failed.connect(func(reason): print("Login failed: ", reason))
```

### Device code expired before sign-in

Codes expire after 5 minutes. Call `login_with_device_code()` again for a fresh one.

### Login button does nothing (Web)

Check you're on `http://localhost` (not `file://`) and that pop-ups are allowed.

---

## Score issues

### Score not saving

Check `is_authenticated()` is true, your API key is set (native), and watch for an error:

```gdscript
CheddaBoards.score_error.connect(func(reason): print("Score error: ", reason))
CheddaBoards.score_submitted.connect(func(score, streak): print("Saved: %d / %d" % [score, streak]))
```

### "Offline - Score not saved" (Template)

**Cause:** the wrapper found you weren't authenticated at game-over. The Template logs in at the **MainMenu** — if you ran the `Game` scene on its own (F6), you skipped login.

**Fix:** run the whole project (**F5**) and log in at the menu first.

### "Score rejected" / anti-cheat error

The score exceeds your game's limits, or it submitted without a valid play session. Check the **Security** tab on your dashboard, and make sure a play session is open for the run — see [Anti-cheat](guides/anti-cheat.md).

---

## Leaderboard issues

### Leaderboard empty

No scores yet, wrong Game ID, or a network error. Submit a test score, run the Setup Wizard to confirm the Game ID, and check the console.

### Leaderboard not updating after I submit

The board stores **only each player's personal best**, so a new score doesn't always change the board:

- **You didn't beat your best.** A lower score never replaces a higher one — your row only moves when you set a new high. (See [What CheddaBoards stores](guides/data-model.md).)
- **You're viewing a different board than you submitted to.** A score submitted to all-time won't show on the weekly board, and vice-versa.
- **You didn't re-fetch.** The list doesn't live-update — call `get_leaderboard()` / `get_scoreboard()` again after submitting to pull fresh data.
- **The signal is connected inside a function.** Connecting `leaderboard_loaded` somewhere that runs repeatedly stacks handlers and shows stale/duplicate data. Connect it once in `_ready()`.
- **Propagation delay.** Give it a couple of seconds and refresh.

### Wrong data showing

Wrong Game ID — each game has its own boards. Confirm the Game ID in `CheddaBoards.gd` / your `_ready()` matches the dashboard.

---

## Template issues

These cover the Template's `Game.gd` wrapper specifically. → [Build Your Own Game](guides/your-own-game.md)

### Game-over screen never appears

**Most common cause:** your game scene never emits `game_over`, or doesn't declare it. If the signal is missing, the wrapper logs:

```
[GameWrapper] Game missing 'game_over' signal
```

Fix checklist:

- Your game scene declares `signal game_over(final_score: int, stats: Dictionary)` — exact name and signature.
- You actually call `game_over.emit(final_score, { ... })` when the run ends.
- The game scene loaded at all — look for `[GameWrapper] Game loaded: res://...` in the Output. If you instead see `No game_scene_path set!` or `Failed to load game scene`, fix the path (next section).

### My game won't load / it still runs CheddaClick

`game_scene_path` still points at the example. Select the **Game** node in `scenes/Game.tscn` and set **Game Scene Path** to your scene (e.g. `res://your_game/YourGame.tscn`), or change the `@export` default in the wrapper.

### Signals not connecting

The wrapper connects your game's signals by name, and **only if your scene actually declares them**:

- **`game_over`** is required — if it's missing you get the warning above and nothing submits.
- **`score_changed` / `stats_changed` / `time_changed`** are optional and connected only when present. A **typo in the signal name** means it's silently skipped — no error, the HUD just never updates. Check the spelling against the contract.
- **Handler signature must match** the signal's argument count and types, or Godot throws a connection error.
- **Connect once.** Connecting a signal inside a function that runs more than once stacks the connection and the handler fires multiple times — connect in `_ready()`.
- **`profile_loaded` gained a 5th argument** (`play_count`) in v2.2.0. A 4-argument handler errors — add a trailing `play_count: int`.

### HUD not updating

The built-in HUD is driven by the optional signals: **Score/Combo** from `score_changed`, the two stat slots (**Level/Misses**) from `stats_changed`, and the **timer** from `time_changed`. If a value isn't moving, you're either not emitting that signal or it's misnamed (see above).

### Restart / Play Again not working

"Play Again" behaves one of two ways (wrapper, `_on_play_again_pressed`):

- **If your game has a `restart()` method**, the wrapper resets *its own* counters, starts a fresh play session, and calls `game_instance.restart()`.
- **If it doesn't**, the wrapper reloads the whole scene.

So:

- **Old state carries over after Play Again** → your `restart()` exists but isn't resetting *your* variables. The wrapper can't reach inside your game; make `restart()` return your game to a clean start.
- **Method named something else** (`reset()`, `restart_game()`) → the wrapper won't find it and falls back to a full scene reload. Works, but slower and re-runs `_ready()`. Name it exactly `restart()` and take no arguments.
- **Nothing happens** → an error thrown inside your `restart()`. Check the Output panel.

---

## Achievement issues

### Achievements not firing at all

**First check the init log.** When the game loads, the wrapper prints:

```
[GameWrapper] Achievements: enabled
```

If it says **disabled**, the `Achievements` autoload isn't registered — and the wrapper skips *every* achievement check silently. Run the Setup Wizard, or add it under **Project Settings → Autoload**.

### Specific achievements not unlocking

- **Score & combo** achievements fire live from `score_changed` (the wrapper calls `check_score` / `check_combo` as values change) and again at game-over (`check_game_over`). If you don't emit `score_changed`, they're only evaluated at game-over.
- **Level achievements are your job.** The wrapper does *not* check them — call `Achievements.check_level(level)` yourself when the player levels up.
- **IDs must match.** The achievement IDs you check against must match the keys in the `ACHIEVEMENTS` dict in `autoloads/Achievements.gd`.

### Achievements unlock but don't save to my account

Anonymous players' achievements are stored **locally** and only sync to the backend once they sign in with Google/Apple. So "unlocked but not on my account" for an anonymous player is expected — it syncs on upgrade. To sync as part of score submission, use `Achievements.submit_with_score(score, streak)`. → [Achievements](guides/achievements.md)

---

## Web issues

### Blank screen / nothing loads

**Cause:** opening the HTML file directly (`file://`). **Fix:** use a web server.

```bash
cd your-export-folder
python3 -m http.server 8000
# open http://localhost:8000
```

### "Engine is not defined"

Export wasn't named `index.html`. Re-export and save it as **`index.html`** (not `MyGame.html`).

### "CheddaBoards is not defined"

Custom HTML Shell not set. **Project → Export → Web → HTML → Custom HTML Shell:** `res://template.html`, then re-export.

### CORS error

You're on `file://`. Use a local web server (see blank-screen fix). Full guide: [Web Export](guides/web-export.md).

---

## Display issues

### Clicks offset / wrong position

High-DPI scaling (125%, 150%). **Project Settings → Display → Window → DPI → Allow Hidpi: On.**

### UI too small / large

**Display → Window → Stretch** → Mode: `canvas_items`, Aspect: `keep`.

---

## Debug tools

**In-game hotkeys (Template):**

- **F9** — full wrapper status: score, combo, game-over state, whether the game scene loaded, SDK ready, authenticated, play session, achievements.
- **F10** — achievements status (`Achievements.debug_status()`).

**Watch the error signals.** Every failure path has a signal carrying the reason:

```gdscript
CheddaBoards.score_error.connect(func(r): print("score: ", r))
CheddaBoards.login_failed.connect(func(r): print("login: ", r))
CheddaBoards.request_failed.connect(func(endpoint, e): print("http: %s — %s" % [endpoint, e]))
CheddaBoards.device_code_error.connect(func(r): print("device code: ", r))
CheddaBoards.scoreboard_error.connect(func(r): print("scoreboard: ", r))
CheddaBoards.play_session_error.connect(func(r): print("session: ", r))
```

**Read the console.** The wrapper and SDK print `[GameWrapper]` and `[CheddaBoards]` lines throughout. On **web**, open the browser console (F12) and look for the same.

---

## Pre-flight checklist

**API / Native build**
- [ ] `set_api_key()` and `set_game_id()` called in `_ready()`
- [ ] `CheddaBoards` (and `Achievements`, `MobileUI`) in Autoloads
- [ ] `login_anonymous()` or `login_with_device_code()` before submitting
- [ ] Allow Hidpi enabled (for high-DPI displays)

**Template build**
- [ ] Game scene emits `game_over(final_score, stats)`
- [ ] `game_scene_path` points at your scene
- [ ] `restart()` (if present) fully resets your game state
- [ ] Init log shows `Achievements: enabled` (if you use them)

**Web build**
- [ ] Custom HTML Shell: `res://template.html`
- [ ] Exported as `index.html`
- [ ] Tested with a web server (not `file://`)

---

## Still stuck?

Include this when you ask for help:

- Platform: Web or Native?
- Godot version (e.g. 4.6.x)
- The error message (screenshot or copy)
- The F9 status dump from in-game

**Email:** info@cheddaboards.com · **GitHub:** [Issues](https://github.com/cheddatech/CheddaBoards-Godot/issues)
