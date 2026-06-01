<p align="center">
  <img src="../addons/cheddaboards/cheddaboards_logo.png" alt="CheddaBoards" width="160"/>
</p>

# CheddaBoards Documentation

**Leaderboards, achievements, and cross-platform auth for Godot 4 — as a drop-in SDK or a full template.**

> **SDK Version:** 2.2.0 · Godot 4.x · Windows / Mac / Linux / Mobile / Web · [Changelog](CHANGELOG.md)

---

## Choose your path

Three ways in. Pick the row that matches where you are.

| You have… | Use | What you actually do | Time |
|-----------|-----|----------------------|------|
| A fresh project, or you want a full UI out of the box | **Template** | Open the repo in Godot, run the Setup Wizard, drop in your game scene | **~3 min** |
| A game you've already built, and just want leaderboards | **Drop-in SDK** | Copy `addons/cheddaboards/` into your project, wire a few calls | **~10 min** |
| A non-Godot engine, or you want raw control | **REST API** | Call the HTTP endpoints directly | varies |

➡️ **[Template Quickstart](../README.md)**  ·  **[Drop-in Quickstart](quickstart-dropin.md)**  ·  **[API Quickstart](quickstart-api.md)**

> **Template vs Drop-in, in one line:** the **Template** gives your game a wrapper plus ready-made MainMenu / Leaderboard / Achievements scenes — your game just *emits signals* and the wrapper handles submission. The **Drop-in** is only the SDK: you call `submit_score()` yourself and build your own UI. Start with the Template for speed; reach for the Drop-in when you need full control over your own screens.

---

## What you get

| Feature | The short version | Learn more |
|---------|-------------------|------------|
| **Global leaderboards** | Submit a score + streak, read the top 100, highlight the player's own rank | Quickstarts |
| **Timed scoreboards** | Weekly / daily / monthly boards that reset and archive automatically | [Guide](guides/timed-leaderboards.md) |
| **Achievements** | Auto-unlock on score/streak/level, offline cache, deferred sync, popups | [Guide](guides/achievements.md) |
| **Device Code Auth** | Google / Apple sign-in on *any* platform via QR + code — no OAuth SDKs | [Guide](guides/device-code-login.md) |
| **Account linking** | Anonymous players upgrade to Google / Apple later, keeping all progress | [Guide](guides/authentication.md) |
| **Anti-cheat** | Server-side sessions, score validation, rate limiting, configurable caps | [Guide](guides/anti-cheat.md) |

Anonymous play works everywhere with zero setup — no account required to start submitting scores.

---

## Requirements

- **Godot 4.x** (tested on 4.3+)
- A free **CheddaBoards account** — [cheddaboards.com](https://cheddaboards.com)
- A **Game ID** and **API Key** from the developer dashboard

> Building for **Godot 3.6**? See the notes in the [Drop-in Quickstart](quickstart-dropin.md) — the syntax differs (`yield` instead of `await`).

---

## All documentation

| Doc | What's in it |
|-----|--------------|
| [Template Quickstart](../README.md) | Clone, configure, swap in your game |
| [Drop-in Quickstart](quickstart-dropin.md) | Add the SDK to an existing game |
| [API Quickstart](quickstart-api.md) | Raw REST integration |
| [Setup & Platforms](SETUP.md) | Detailed setup, autoloads, achievements, anti-cheat |
| [Web Export](guides/web-export.md) | Browser export: HTML shell, index.html, local serving |
| [Timed Leaderboards](guides/timed-leaderboards.md) | Weekly/daily/monthly competitions & archives |
| [Authentication](guides/authentication.md) | Device code auth, QR, account linking |
| [Device Code Login](guides/device-code-login.md) | Build the social sign-in screen (QR rendering, signals) |
| [Achievements](guides/achievements.md) | Definitions, sync, notifications |
| [Anti-cheat](guides/anti-cheat.md) | Sessions, validation, dashboard config |
| [Signals Reference](guides/signals-reference.md) | All 34 signals, grouped by category |
| [Troubleshooting](TROUBLESHOOTING.md) | Common problems & fixes |
| [Changelog](CHANGELOG.md) | Version history & migration notes |

---

## Support

- **Bugs & feature requests:** [GitHub Issues](https://github.com/cheddatech/CheddaBoards-Godot/issues)
- **Player & developer info:** [cheddaboards.com](https://cheddaboards.com)
- **Studio:** [cheddatech.com](https://cheddatech.com)
- **Support development:** [Buy me a coffee](https://buymeacoffee.com/CheddaTech) — no VC, no investors

MIT License — use freely in your games.
