# Build Your Own Game on the Template

The template ships running **CheddaClick**, the example game. This guide swaps it for *your* game. You don't touch the wrapper, the MainMenu, or the Leaderboard — you provide a game scene that emits a signal or two, then point the wrapper at it.

> Just need the short version? It's [Step 2 of the README](../../README.md#2-add-your-game). This page is the full walkthrough.
>
> Brand new to Godot? Start with [Getting Started](getting-started.md) — it covers install, the Setup Wizard, and a one-button test before you get here.

---

## How the template fits together

```
scenes/Game.tscn  (the "wrapper" — scripts/Game.gd)
   ├── loads your game scene as a child
   ├── draws the HUD (only the panels your game feeds — score/combo, timer, two stat slots)
   ├── shows the game-over screen
   └── talks to CheddaBoards (login, submit, achievements, play session)

example_game/CheddaClickGame.tscn   ← the game it loads by default
```

The wrapper is the host. It loads **one** game scene as a child and listens for its signals. Replacing CheddaClick means giving it a different child scene to load.

Your half of the deal is one required signal:

- **`game_over(final_score: int, stats: Dictionary)`** — emit it when a run ends. That's the only thing the wrapper *needs*.

Everything else (live HUD updates, Play Again, pause) is optional.

---

## Step 1 — Create your game scene

Make a new scene for your game. The root node can be **any type** — `Node2D`, `Control`, `Node` — whatever your game needs. Build your gameplay in it as normal.

Save it somewhere outside `example_game/`, e.g. `res://your_game/YourGame.tscn`.

> Tip: open `example_game/CheddaClickGame.tscn` and its script first — it's a complete, working reference for everything below.

---

## Step 2 — Emit `game_over` (required)

Declare the signal and emit it the moment a run ends, with a stats dictionary:

```gdscript
signal game_over(final_score: int, stats: Dictionary)

func _end_run():
    game_over.emit(score, {
        "hits": hits,          # all keys optional — include a key to show its
        "misses": misses,      # game-over field; omit it and the field is hidden
        "max_combo": max_combo,
        "level": level,
        "accuracy": accuracy,  # 0–100
    })
```

When this fires, the wrapper shows the game-over screen, submits the score, checks achievements, and closes the anti-cheat session. You don't call `submit_score` yourself.

### Where each value goes

This is the part that trips people up: the dict *looks* like it all gets saved, but the leaderboard entry is only ever **two numbers — score and streak.** Here's what the wrapper does with everything you emit:

| Value | Where it goes |
|-------|---------------|
| `final_score` (1st arg) | **Saved** to the leaderboard as the player's **score** |
| `max_combo` | **Saved** to the leaderboard as the player's **streak** — *and* checked for combo achievements |
| `hits` | Fed into the game-over achievement check; **not saved** |
| `level` | Shown on the game-over screen (`Level: N`); **not saved** |
| `accuracy` | Shown on the game-over screen (`Accuracy: N%`); **not saved** |
| `misses` | Drives the live HUD during play (via `stats_changed`); the stock wrapper doesn't read it at game-over |
| any other key | **Ignored** — the wrapper only reads the five above |

So `level`, `accuracy`, `hits`, and `misses` are there for the game-over screen and achievement logic — they never reach the server. (Unlocked achievements and your play count *do* sync, but separately; they aren't part of the leaderboard row.) For the full picture of what is and isn't persisted, see [What CheddaBoards Stores](data-model.md).

> **The game-over screen shows only the fields you send (wrapper v1.1.0+).** Omit `accuracy` and the Accuracy line doesn't appear at all — it no longer falls back to `0%`. Same for `level` and `max_combo`. So a game that tracks none of them gets a clean game-over screen (title, final score, buttons) instead of rows of zeros.

Two takeaways:

- **"Streak" is whatever you put in `max_combo`.** If your game's streak isn't a combo — days-in-a-row, kills-in-a-row, anything — put that number in `max_combo` and it ranks as the streak. (Or use the [Drop-in path](../quickstart-dropin.md) and call `submit_score(score, your_streak)` directly.)
- **You can add custom keys, but they do nothing.** The stock wrapper ignores anything beyond the five keys, and the score API has no free-form field, so a custom stat won't be saved unless you map it onto score/streak or extend the wrapper and your backend yourself.

---

## Step 3 — Feed the built-in HUD (optional)

If you're using the template's HUD, add any of these three. Each panel appears **only if your scene declares its signal**, so include the ones you want and the rest stay hidden — no empty placeholders left over:

```gdscript
signal score_changed(score: int, combo: int)                # live score + combo
signal stats_changed(hits: int, misses: int, level: int)    # two stat slots
signal time_changed(time_remaining: float, max_time: float) # countdown timer

# …emit as values change during play:
score_changed.emit(score, combo)
stats_changed.emit(hits, misses, level)
time_changed.emit(time_left, round_length)
```

What the wrapper does with them:

| Signal | HUD result |
|--------|-----------|
| `score_changed` | Updates **Score** and **Combo**, colours the combo by tier, **and** runs live score/combo achievement checks |
| `stats_changed` | Fills the two stat slots — labelled **Level** and **Misses** |
| `time_changed` | Updates the **timer** (turns yellow ≤30s, red ≤10s) |

The game-over screen shows **Level**, **Accuracy**, and **Max Combo** — but only for the keys you include in your `game_over` stats dict. Send all three and all three show; send only `level` and that's the only one that appears.

> The two stat slots are hard-labelled "Level" and "Misses" by the wrapper. If your game's concepts don't map onto those, either pass your nearest equivalent or skip `stats_changed` entirely — the panel then doesn't render at all, rather than sitting there empty.
>
> Skipping `score_changed` doesn't lose you achievements; score/combo achievements just get checked once at game-over instead of live.

---

## Step 4 — Point the wrapper at your scene

Two ways:

- **Inspector (recommended):** open `scenes/Game.tscn`, select the **Game** node, and set **Game Scene Path** to `res://your_game/YourGame.tscn`.
- **In code:** change the default on the wrapper script:

```gdscript
@export var game_scene_path: String = "res://your_game/YourGame.tscn"
```

Run the project. The wrapper now loads your game instead of CheddaClick.

> **If you've moved MainMenu or Leaderboard:** the game-over **Main Menu** and **Leaderboard** buttons default to `res://scenes/MainMenu.tscn` and `res://scenes/Leaderboard.tscn`. If your project keeps them elsewhere, set the **Main Menu Scene** and **Leaderboard Scene** export vars on the **Game** node to match — otherwise those buttons fail silently. Stock template layout works as-is.

---

## Step 5 — Tune the game-over titles (optional)

The wrapper picks a game-over title from score thresholds. Both are export vars on the **Game** node, so you can tune them in the Inspector to match your game's scoring range:

```gdscript
@export var title_thresholds: Array[int] = [10000, 5000, 2500, 1000]
@export var game_over_titles: Dictionary = {
    "amazing": "AMAZING!",
    "excellent": "Excellent!",
    "great": "Great Game!",
    "good": "Good Effort!",
    "default": "Game Over",
}
```

A score ≥ the first threshold gets "amazing", and so on down; anything below the last gets "default".

---

## Step 6 — Play Again & pause (optional)

By default "Play Again" reloads the whole scene. If your game can reset itself in place, add a `restart()` method and the wrapper calls that instead (faster, no reload):

```gdscript
func restart():
    # reset your state back to the start of a run
    pass

func pause():    # optional
    pass
func unpause():  # optional
    pass
```

---

## Step 7 — Remove CheddaClick (optional)

Once your game runs cleanly through the wrapper, you can delete `example_game/` and make sure `game_scene_path` no longer points into it. Plenty of people keep it around as a reference — your call.

---

## Complete minimal example

A full, compilable game scene that satisfies the contract end to end. Drop it on a `Node2D`, wire your real gameplay into `register_hit` / `register_miss`, and point the wrapper at it.

```gdscript
extends Node2D
## Minimal game that works with the CheddaBoards template.
## Replace the body with your real gameplay — keep the signals.

# Required
signal game_over(final_score: int, stats: Dictionary)

# Optional — only if you use the built-in HUD
signal score_changed(score: int, combo: int)
signal stats_changed(hits: int, misses: int, level: int)
signal time_changed(time_remaining: float, max_time: float)

var score := 0
var combo := 1
var max_combo := 1
var hits := 0
var misses := 0
var level := 1
var time_left := 60.0
const ROUND_LENGTH := 60.0

func _ready():
    time_left = ROUND_LENGTH
    time_changed.emit(time_left, ROUND_LENGTH)
    score_changed.emit(score, combo)
    stats_changed.emit(hits, misses, level)

func _process(delta):
    time_left -= delta
    time_changed.emit(time_left, ROUND_LENGTH)
    if time_left <= 0.0:
        _end_run()

# Call from your gameplay when the player scores
func register_hit(points: int):
    hits += 1
    combo += 1
    max_combo = max(max_combo, combo)
    score += points * combo
    score_changed.emit(score, combo)
    stats_changed.emit(hits, misses, level)

# Call when the player misses
func register_miss():
    misses += 1
    combo = 1
    score_changed.emit(score, combo)
    stats_changed.emit(hits, misses, level)

func _end_run():
    set_process(false)
    var accuracy := 0
    if hits + misses > 0:
        accuracy = int(round(100.0 * hits / float(hits + misses)))
    game_over.emit(score, {
        "hits": hits,
        "misses": misses,
        "max_combo": max_combo,
        "level": level,
        "accuracy": accuracy,
    })

# Optional — wrapper calls this on "Play Again" instead of reloading
func restart():
    score = 0
    combo = 1
    max_combo = 1
    hits = 0
    misses = 0
    level = 1
    time_left = ROUND_LENGTH
    set_process(true)
    score_changed.emit(score, combo)
    stats_changed.emit(hits, misses, level)
    time_changed.emit(time_left, ROUND_LENGTH)
```

---

## How CheddaClick does it

`example_game/CheddaClickGame.gd` is the working reference — open it alongside this guide. It implements the exact contract above; here's the map so you can diff your own game against it.

**Scene shape.** The root is a `Control` with two children the script expects: `$GameArea` (a Control the cheese spawns into, whose empty-space clicks count as misses) and `$SpawnTimer` (a `Timer`). If you build something similar, mirror those node names or change the `@onready` paths to match yours.

**Signals** are declared at the top, one-for-one with the contract, and emitted where you'd expect:

| Signal | Emitted from |
|--------|--------------|
| `time_changed` | every frame in `_process`, and whenever an off-target click drains the clock |
| `score_changed` | on every hit, and when the combo resets |
| `stats_changed` | on hits, misses, and level-ups |
| `game_over` | once, from `_end_game()` when the timer hits zero |

**Play Again.** `restart()` simply calls `_start_game()`, so the wrapper resets the run in place rather than reloading the scene.

**The stats it submits**, from `_end_game()`:

```gdscript
game_over.emit(current_score, {
    "hits": total_hits,
    "misses": total_misses,
    "max_combo": max_combo,        # highest combo *multiplier* reached (1–10)
    "level": max_level_reached,    # peak level, not the level at the final moment
    "accuracy": accuracy,          # hits / (hits + misses) × 100, as an int
})
```

Two choices worth copying: it reports `max_level_reached` rather than the current level (so slipping back a level right before time runs out doesn't rob the player of their best), and `accuracy` is a clean integer percentage. Note too that its `max_combo` is the combo *multiplier*, capped at 10 — which is exactly why the recommended **Max Streak Per Submission** in [Anti-cheat](anti-cheat.md) is also `10`, since that's the value submitted as the streak.

**Achievements.** CheddaClick checks its own **level** achievements directly — `Achievements.check_level(...)` inside `_level_up()`. The wrapper handles score, combo, and games-played at game-over. So if your game has levels, that's the split: emit `stats_changed` for the HUD, and call `check_level(...)` yourself as the player climbs.

---

## Checklist

- [ ] Game built as its own scene (any root node type)
- [ ] Emits `game_over(final_score, stats)` when a run ends
- [ ] (Optional) emits `score_changed` / `stats_changed` / `time_changed` for the HUD
- [ ] (Optional) has a `restart()` method for Play Again
- [ ] `game_scene_path` points at your scene
- [ ] (Optional) `title_thresholds` tuned to your scoring
- [ ] Ran it — score reaches the leaderboard

---

**See also:** [README Quick Start](../../README.md#quick-start) · [Achievements](achievements.md) · [Anti-cheat](anti-cheat.md) · [Signals Reference](signals-reference.md)
