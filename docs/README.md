<p align="center">
  <img src="../addons/cheddaboards/cheddaboards_logo.png" alt="CheddaBoards" width="160"/>
</p>

# CheddaBoards Documentation

**Leaderboards, achievements, and cross-platform sign-in for Godot 4 — as a drop-in SDK or a full template.**

> **SDK 2.2.1** · Godot 4.6+ · Windows / Mac / Linux / Mobile / Web · MIT · [Changelog](CHANGELOG.md)

---

## Choose your path

Three ways in. The difference is really *how much UI we hand you* versus *how much you wire yourself*. Pick the row that matches where you are.

| You have… | Use | What you do | What you write | Time |
|-----------|-----|-------------|----------------|------|
| A fresh project, or you want a full UI out of the box | **Template** | Open the repo, run the Setup Wizard, point it at your game scene | Emit **one signal** — `game_over` | **~3 min** |
| A game you've already built, with your own menus and screens | **Drop-in SDK** | Copy `addons/cheddaboards/` in, call the SDK yourself | A handful of calls: login, submit, leaderboard (+ optional play sessions for anti-cheat) | **~10 min** |
| A non-Godot engine, or you want raw control | **REST API** | Call the HTTP endpoints directly | Your own HTTP requests | varies |

➡️ **[Template Quickstart](../README.md)**  ·  **[Drop-in Quickstart](quickstart-dropin.md)**  ·  **[API Quickstart](quickstart-api.md)**

### Template vs Drop-in — the real difference

**Template** wraps your game in a ready-made shell: a `GameWrapper` plus finished MainMenu / Leaderboard / Achievements screens. Your game scene only has to **emit `game_over(final_score, stats)`** when a run ends — the wrapper then shows the game-over screen, submits the score, runs the anti-cheat play session, and fires achievements for you. That's **one required signal.** If you also use the built-in HUD, you can *optionally* emit three more to feed it live (score/combo, stats, timer) — but they're not required to get scores on the board.

**Drop-in** is just the SDK — no wrapper, no screens. You call `submit_score()` yourself, build your own UI, and (for anti-cheat) start and clear play sessions yourself. More wiring, total control.

> Rule of thumb: start with the **Template** for speed; reach for the **Drop-in** when you need your own screens.

---

## What you get

| Feature | The short version | Learn more |
|---------|-------------------|------------|
| **Global leaderboards** | Submit a score + streak, read the top 100, highlight the player's own rank | Quickstarts |
| **Timed scoreboards** | Weekly / daily / monthly / custom-interval boards that reset and archive automatically | [Guide](guides/timed-leaderboards.md) |
| **Category scoreboards** | Per-level / per-mode targeted boards under one game — submit to one board by ID | [Guide](guides/category-scoreboards.md) |
| **Achievements** | Auto-unlock on score/streak/level, offline cache, deferred sync, popups | [Guide](guides/achievements.md) |
| **Device Code Auth** | Google / Apple sign-in on *any* platform via QR + code — no OAuth SDKs | [Guide](guides/device-code-login.md) |
| **Account linking** | Anonymous players upgrade to Google / Apple later, keeping all progress | [Guide](guides/authentication.md) |
| **Anti-cheat** | Server-side play sessions, score validation, rate limiting, configurable caps | [Guide](guides/anti-cheat.md) |

Anonymous play works everywhere with zero setup — no account required to start submitting scores.

---

## Requirements

- **Godot 4.6 or newer**
- A free **CheddaBoards account** — [cheddaboards.com](https://cheddaboards.com)
- A **Game ID** and **API Key** from the developer dashboard

> Building for **Godot 3.6**? See the notes in the [Drop-in Quickstart](quickstart-dropin.md) — the syntax differs (`yield` instead of `await`).

---

## All documentation

| Doc | What's in it |
|-----|--------------|
| [Getting Started](guides/getting-started.md) | New to Godot? Zero-experience walkthrough to your first score |
| [Template Quickstart](../README.md) | Open the repo, configure, swap in your own game scene |
| [Build Your Own Game](guides/your-own-game.md) | Full walkthrough: replace CheddaClick with your game (incl. example) |
| [Drop-in Quickstart](quickstart-dropin.md) | Add the SDK to an existing game (incl. play sessions) |
| [API Quickstart](quickstart-api.md) | Raw REST integration from any engine |
| [Setup & Platforms](SETUP.md) | Detailed setup, autoloads, achievements, anti-cheat |
| [Web Export](guides/web-export.md) | Browser export: HTML shell, index.html, local serving |
| [Timed Leaderboards](guides/timed-leaderboards.md) | Weekly / daily / monthly / custom-interval competitions & archives |
| [Category Scoreboards](guides/category-scoreboards.md) | Per-level / per-mode targeted leaderboards under one game |
| [Authentication](guides/authentication.md) | Device code auth, QR, account linking |
| [Device Code Login](guides/device-code-login.md) | Build the social sign-in screen (QR rendering, signals) |
| [Achievements](guides/achievements.md) | Definitions, sync, notifications |
| [Anti-cheat](guides/anti-cheat.md) | Play sessions, validation, dashboard config |
| [Signals Reference](guides/signals-reference.md) | Every SDK signal, grouped by category |
| [What CheddaBoards Stores](guides/data-model.md) | The data model — score, streak, profile, achievements (and what isn't stored) |
| [Troubleshooting](TROUBLESHOOTING.md) | Common problems & fixes |
| [Changelog](CHANGELOG.md) | Version history & migration notes |

---

## Support

- **Bugs & feature requests:** [GitHub Issues](https://github.com/cheddatech/CheddaBoards-Godot/issues)
- **Player & developer info:** [cheddaboards.com](https://cheddaboards.com)
- **Studio:** [cheddatech.com](https://cheddatech.com)
- **Support development:** [Buy me a coffee](https://buymeacoffee.com/CheddaTech) — no VC, no investors

MIT License — use freely in your games.
