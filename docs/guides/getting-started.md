# Getting Started — New to Godot? Start Here

This is the zero-experience path. By the end you'll have the template running, your own tiny game swapped in, and a **real score on a live leaderboard**. No prior Godot or backend experience needed. About 20 minutes.

> Already comfortable in Godot? Skip to the [README Quick Start](../../README.md#quick-start) — it's the 3-step version.

---

## What you'll need

- **Godot 4.6 or newer** — free from [godotengine.org](https://godotengine.org). It's a single download: unzip it and run the app, there's no installer.
- **A free CheddaBoards account** — [cheddaboards.com](https://cheddaboards.com), for a Game ID and API key.
- **The template** — download from the [Asset Library](https://godotengine.org/asset-library/asset/4574) or [GitHub](https://github.com/cheddatech/CheddaBoards-Godot).

---

## A 60-second vocabulary

You'll see these words throughout. Plain-English versions:

- **Project** — your game. A folder Godot opens.
- **Scene** — a reusable piece of your game: a screen, a whole minigame, or a single object. The template is built from several scenes.
- **Node** — a building block inside a scene: a button, an image, a timer.
- **Autoload** — a script Godot keeps loaded *all the time*, reachable from anywhere by name. That's why any script can just write `CheddaBoards.something`.
- **Signal** — a little "this just happened" message a node sends out. Other code can listen for it. The template listens for your game's `game_over` signal.
- **Inspector** — the panel (usually right-hand side) showing the settings of whatever node you've clicked on.
- **Running** — **F5** plays the *whole project* (starts at the main menu). **F6** plays *only the scene you're editing*. This difference matters later.

---

## 1. Open the template and run it (your first win)

Before changing anything, let's confirm it all works.

1. Download the template and unzip it.
2. Open Godot. Click **Import**, find the template's `project.godot` file, and open it.
3. Press **F5** (or the ▶ button, top-right).
4. You should land on the **CheddaBoards main menu**. Start a game as an anonymous guest (just enter a name), and the example game — **CheddaClick** — loads. Click some cheese.

If that worked, your Godot install is fine and the template is intact. That's the whole thing running before you've touched a line of code.

---

## 2. Run the Setup Wizard (connect your account)

Right now scores have nowhere of *yours* to go. The wizard fixes that.

1. **Get your API key:** sign in at [cheddaboards.com](https://cheddaboards.com), register a game, and copy your **API key** (e.g. `cb_my-game_xxxxxxxxx`). Your Game ID (`my-game`) is baked right into it, so that's all you need.
2. In Godot: **File → Run**, then choose `addons/cheddaboards/SetupWizard.gd`.
3. Paste your **API key** when prompted — the wizard reads the Game ID from it automatically.

**What the wizard does for you:**
- Registers three **autoloads** — `CheddaBoards`, `Achievements`, `MobileUI` — so they're callable from anywhere.
- Writes your API key — and the Game ID it reads from that key — into `MainMenu.gd`, so login works.

**Did it work?** Open **Project → Project Settings → Autoload**. You should see `CheddaBoards`, `Achievements`, and `MobileUI` in the list. If they're there, you're connected.

---

## 3. The one rule: emit `game_over`

Your game lives in its own scene. The template's **wrapper** loads that scene and waits for a single signal — `game_over`. When your game emits it, the wrapper shows the game-over screen and saves the score. **That is the entire integration.**

A signal is just a named message. You declare it once at the top of a script, then "emit" it when the moment arrives:

```gdscript
signal game_over(final_score: int, stats: Dictionary)

# …later, when a run ends:
game_over.emit(final_score, {})
```

The `{}` is a dictionary of optional extra stats (hits, level, accuracy…). We'll leave it empty for now and fill it in once the basics work.

---

## 4. Prove it with a one-button "game"

Let's build the smallest possible thing that scores 500 and ends — just to watch a score travel all the way from a click to the leaderboard.

1. **New scene:** **Scene → New Scene → User Interface**. This gives you a `Control` root node. Save it as `your_game/TestGame.tscn`.
2. **Add a button:** with the root node selected, click the **+** (Add Child Node), search for **Button**, and add it. It'll be named `Button`.
3. **Attach a script:** select the **root** node, click the *attach script* icon, and create `TestGame.gd`. Paste this in:

```gdscript
extends Control

# The one signal the template needs.
signal game_over(final_score: int, stats: Dictionary)

func _ready():
    $Button.pressed.connect(_on_button_pressed)

func _on_button_pressed():
    # Pretend the player just finished a run worth 500 points.
    game_over.emit(500, {})
```

4. **Point the wrapper at it:** open `scenes/Game.tscn`, select the **Game** node, and in the **Inspector** set **Game Scene Path** to `res://your_game/TestGame.tscn`.
5. **Run it:** press **F5**, log in at the menu, and when your test game loads, click the button.

**Did it work?** You should see, in order:

- The **game-over screen** appears showing **Final Score: 500**.
- It says **"Saving score…"**, then **"Score saved!"** in green.
- Open the **Output** panel (bottom of the editor) and you'll see lines like:
  ```
  [GameWrapper] Game loaded: res://your_game/TestGame.tscn
  [GameWrapper] ✓ Score submitted: 500 points
  ```
- Open the **Leaderboard** from the menu — your name and **500** are on it.

If all of that happened, the full pipeline works: **your game → wrapper → CheddaBoards → leaderboard.** Everything from here is just building a real game in place of that button.

> ⚠️ **The login trap.** Run with **F5** (the whole project), *not* **F6** (this scene alone). Login happens at the main menu — if you launch the `Game` scene by itself, you're never logged in, and instead of a saved score you'll see **"Offline - Score not saved"**.

---

## 5. Now build your real game

Swap the button for actual gameplay, and start filling in the stats dictionary (`hits`, `misses`, `max_combo`, `level`, `accuracy`) so the HUD and game-over screen have something to show.

The full walkthrough — the optional live-HUD signals, tuning the game-over titles, Play Again, and a complete example game — is in **[Build Your Own Game](your-own-game.md)**. And `example_game/CheddaClickGame.gd` is a finished game wired up exactly this way — open it as a reference.

---

## Troubleshooting

| What you see | Why | Fix |
|--------------|-----|-----|
| Still see **CheddaClick**, not my game | `game_scene_path` still points at the example | Select the **Game** node in `scenes/Game.tscn`, set **Game Scene Path** to your scene |
| **"Offline - Score not saved"** | Not logged in — you ran the Game scene on its own | Run the whole project with **F5** and log in at the menu first |
| Game-over screen **never appears** | Your game never emits `game_over` | Call `game_over.emit(...)` when the run ends. Check the Output panel for `[GameWrapper] Game missing 'game_over' signal` |
| Errors mentioning **CheddaBoards** / "not found" | Autoloads aren't registered | Re-run the Setup Wizard, or add them under **Project Settings → Autoload** |
| **"API key not set"** | Credentials missing | Re-run the wizard, or set them in `MainMenu.gd`'s `_ready()` |
| Score **saved but not on the board** | Your Game ID doesn't match your dashboard | Check the Game ID you entered matches the one at cheddaboards.com |
| **Blank screen** in a web build | The file was opened directly | Serve it: `python3 -m http.server`, then open the `localhost` URL — not `file://` |

---

## Where next

- **[Build Your Own Game](your-own-game.md)** — real gameplay plus the live-HUD signals.
- **[SETUP.md](../SETUP.md)** — platforms, web export, achievements, anti-cheat.
- **[Troubleshooting](../TROUBLESHOOTING.md)** — the full list.
