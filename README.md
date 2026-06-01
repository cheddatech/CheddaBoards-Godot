<p align="center">
  <img src="addons/cheddaboards/cheddaboards_logo.png" alt="CheddaBoards" width="160"/>
</p>

# CheddaBoards — Godot 4 Template

**A complete game template with leaderboards, achievements, and cross-platform auth built in.**
**Download → Add your game → Export. That's it.**

> **SDK 2.2.0** · Godot 4.x · Windows / Mac / Linux / Mobile / Web · MIT · Free tier · [Changelog](docs/CHANGELOG.md)

<p align="center">
  <img src="screenshots/screenshot1.png" alt="In-game" width="45%"/>
  <img src="screenshots/screenshot_leaderboard_alltime.png" alt="Leaderboard" width="45%"/>
</p>

Built on the [Internet Computer](https://internetcomputer.org) — no per-player fees, no surprise bills. Battle-tested in production by the studio's own arcade games.

---

## Choose your path

This repo is a full **template** — most people should just start with the [Quick Start](#quick-start) below. If that's not you, the [`docs/`](docs/README.md) folder has the other routes:

| You have… | Best route | Time |
|-----------|------------|------|
| A fresh project, or you want the full UI out of the box | **Template** — keep reading, start at [Quick Start](#quick-start) | ~3 min |
| A game you've already built | **[Drop-in SDK](docs/quickstart-dropin.md)** — just the SDK, your own UI | ~10 min |
| A non-Godot engine, or you want raw control | **[REST API](docs/quickstart-api.md)** | varies |

> 📚 Full documentation index: **[docs/README.md](docs/README.md)**

---

## Quick Look

Five lines from a fresh project to a working leaderboard:

```gdscript
func _ready():
    CheddaBoards.set_api_key("cb_your-api-key")
    CheddaBoards.set_game_id("your-game-id")
    CheddaBoards.login_anonymous("PlayerName")

func _on_game_over(score: int, streak: int):
    CheddaBoards.submit_score(score, streak)
```

Drop in the MainMenu and Leaderboard scenes and you've got a full UI too — profile, rank, achievements, and anti-cheat all work with no further setup.

---

## What's included

| Component | Description |
|-----------|-------------|
| **Game Wrapper** | Drop-in wrapper handles HUD, game over, score submission, achievements |
| **Example Game** | CheddaClick — a clicker game with levels & combos |
| **MainMenu** | Four-panel auth flow with anonymous dashboard |
| **Leaderboard** | Full UI with time periods & archives |
| **Achievements** | Backend-synced, with popup notifications & offline cache |
| **CheddaBoards SDK** | Core backend integration (also usable standalone) |

**Status:** Native, Mobile, and Web are all ✅ stable. Every platform supports Google/Apple sign-in via Device Code Auth — no OAuth SDKs in your game. → [Device Code Login](docs/guides/device-code-login.md)

---

## Quick Start

**1. Setup** — Download from the [Asset Library](https://godotengine.org/asset-library/asset/4574) or GitHub, open in Godot 4.x, then run the Setup Wizard:

```
File → Run → addons/cheddaboards/SetupWizard.gd
```

Enter your Game ID & API key from [cheddaboards.com](https://cheddaboards.com). The wizard also registers the autoloads (`CheddaBoards`, `Achievements`, `MobileUI`).

**2. Add your game** — Create your game scene, add the four required signals, emit them as things happen, and set `game_scene_path` in `scenes/Game.tscn`:

```gdscript
extends Control

# The Game wrapper listens to these — emit them and it handles the rest
signal score_changed(score: int, combo: int)
signal stats_changed(hits: int, misses: int, level: int)
signal time_changed(time_remaining: float, max_time: float)
signal game_over(final_score: int, stats: Dictionary)

func _on_game_ended():
    game_over.emit(current_score, {
        "hits": total_hits, "max_combo": max_combo, "level": current_level
    })
```

```gdscript
# In scenes/Game.tscn
@export var game_scene_path: String = "res://example_game/CheddaClickGame.tscn"
```

**3. Export** — players get leaderboards, achievements, and anti-cheat.

> 📖 Detailed setup, web export & OAuth specifics: **[SETUP.md](docs/SETUP.md)**

---

## Features at a glance

| Feature | Learn more |
|---------|------------|
| Cross-platform auth — anonymous, Google/Apple via device code, account linking | [Authentication](docs/guides/authentication.md) · [Device Code Login](docs/guides/device-code-login.md) |
| Global leaderboards (sort by score or streak, player rank highlighted) | [Drop-in Quickstart](docs/quickstart-dropin.md) |
| Timed scoreboards — weekly / daily / monthly, auto-reset & archive | [Timed Leaderboards](docs/guides/timed-leaderboards.md) |
| Achievements — auto-unlock, offline cache, deferred sync, popups | [Achievements](docs/guides/achievements.md) |
| Anti-cheat — server-side sessions, score validation, configurable caps | [Anti-cheat](docs/guides/anti-cheat.md) |
| 34 typed signals across the SDK | [Signals Reference](docs/guides/signals-reference.md) |

---

## Project structure

```
CheddaBoards-Godot/
├── addons/cheddaboards/      # Core SDK + Setup Wizard (autoload)
├── autoloads/                # Achievements, MobileUI (autoloads)
├── scenes/                   # Game wrapper, MainMenu, Leaderboard, Achievements, DeviceCodeLogin
├── scripts/                  # Logic for the scenes above
├── example_game/             # CheddaClick — the example game
├── assets/fonts/
├── screenshots/
├── docs/                     # Full documentation (see docs/README.md)
│   ├── README.md             # Docs index / router
│   ├── quickstart-dropin.md
│   ├── quickstart-api.md
│   ├── SETUP.md
│   ├── CHANGELOG.md
│   ├── TROUBLESHOOTING.md
│   └── guides/
│       ├── authentication.md
│       ├── device-code-login.md
│       ├── achievements.md
│       ├── anti-cheat.md
│       ├── signals-reference.md
│       └── timed-leaderboards.md
├── template.html             # Web export template
├── project.godot
└── README.md
```

---

## Prerequisites

- **Godot 4.x** (tested on 4.3+)
- A free **CheddaBoards account** — [cheddaboards.com](https://cheddaboards.com) — for your Game ID & API key

> **Heads up (v2.2.0):** `profile_loaded` now emits `play_count` as a 5th argument — a breaking change for 4-arg handlers. Full migration notes in the [Changelog](docs/CHANGELOG.md).

---

## Roadmap

- [ ] Godot 3.6 SDK release
- [ ] Unity SDK (in progress)
- [ ] Expanded analytics dashboard

---

## Support

- **Bugs & feature requests:** [GitHub Issues](https://github.com/cheddatech/CheddaBoards-Godot/issues)
- **Player & developer info:** [cheddaboards.com](https://cheddaboards.com)
- **Studio:** [cheddatech.com](https://cheddatech.com)
- **Support development:** [Buy me a coffee](https://buymeacoffee.com/CheddaTech) — no VC, no investors, built by a solo founder for indie devs

MIT License — use freely in your games.
