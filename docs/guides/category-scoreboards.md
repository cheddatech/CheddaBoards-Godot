# Category & Targeted Scoreboards

**Run per-level, per-mode, or per-category leaderboards under a single game.**

---

## Overview

A CheddaBoards scoreboard has two independent dials:

| Dial | Options | Controls |
|------|---------|----------|
| **Write mode** | Fan-out · Targeted | *Which* board a score lands on |
| **Reset cadence** | Never · Daily · Weekly · Monthly · Every N days | *When* the board resets — see [Timed Scoreboards](timed-leaderboards.md) |

This guide is about the first dial. The two are orthogonal: a targeted board can still reset weekly, and a fan-out board can be all-time.

| Mode | Receives | Use case |
|------|----------|----------|
| **Fan-out** (default) | *Every* plain score submit | One overall leaderboard per game |
| **Targeted** | *Only* scores addressed to it by ID | `level-01 … level-28`, `boss-rush`, `time-trial`, `runs`, difficulty tiers |

A plain submit fans out to every non-targeted board on the game. A **targeted** board is invisible to that fan-out — it only ever receives scores you send to it explicitly, by its ID. That's what lets you run a separate leaderboard per level (or per mode/category) without registering a separate game for each one.

---

## When to use targeted boards

- **Per-level boards** — a leaderboard for every level in your game.
- **Per-mode boards** — Easy / Normal / Hard, or Solo / Co-op.
- **Category boards** — fastest time, longest run, most coins, kept separate from your main score board.

If you just want one leaderboard for the whole game (plus optional weekly/daily resets), you don't need targeted boards at all — stick with fan-out.

---

## Setup in Dashboard

1. Go to [cheddaboards.com/developers](https://cheddaboards.com/developers)
2. Select your game → **Scoreboards**
3. In **Create New Scoreboard**, configure:

| Field | Example | Description |
|-------|---------|-------------|
| Scoreboard ID | `level-14` | Unique identifier (lowercase, hyphens) |
| Display Name | `Level 14` | Display name |
| **Board Type** | **Targeted** | Set this to **Targeted** — this is what makes it a category board |
| Reset Period | `All Time` | Targeted boards can use any cadence (incl. every-N-days) |
| Sort By | `Score (High to Low)` | Ranking method |

The **Board Type** selector is the whole trick: leave it on *Fan-out* and the board behaves like a normal one; set it to *Targeted* and it drops out of the fan-out and waits for scores sent to its ID.

> A targeted board ranks scores exactly like any other board (keep-highest per player, sorted by score or streak). "Targeted" only changes *which submits reach it*, not how it ranks them.

---

## Submitting to a targeted board

### Godot (SDK)

> **SDK status:** the `submit_score_to_board()` helper is part of the targeted-scoreboards update. If your SDK predates it, use the REST call below — it works against the same backend.

```gdscript
# Send this run's score to ONE board, by ID.
CheddaBoards.submit_score_to_board("level-14", score, streak)
```

This writes to `level-14` only. It does **not** fan out to your all-time/weekly/daily boards, and it does **not** change the player's overall profile total. If you also want the run counted toward the player's global stats, send a normal `submit_score(score, streak)` as well.

You can address several boards in one run — e.g. a per-level board plus a shared `runs` board:

```gdscript
CheddaBoards.submit_score_to_board("level-14", score, streak)
CheddaBoards.submit_score_to_board("runs", score, streak)
```

The submission throttle is keyed per board, so these back-to-back calls won't trip the 2-second rate gate.

### REST (any engine)

The targeted submit is a normal `POST /scores` with a `scoreboardId` field added:

```bash
curl -X POST https://api.cheddaboards.com/scores \
  -H "Content-Type: application/json" \
  -H "X-API-Key: cb_my-game_xxxxxxxxx" \
  -H "X-Game-ID: my-game" \
  -d '{
    "playerId": "dev_1730000000_1a2b3c4d",
    "score": 1000,
    "streak": 5,
    "nickname": "PlayerName",
    "scoreboardId": "level-14"
  }'
```

On success the response confirms the board: `"Submitted to level-14 - Score: 1000, Streak: 0"`.

If the game has time validation enabled, include a `playSessionToken` exactly as you would for a normal submit — targeted submits go through the same anti-cheat gate. See [Anti-cheat](guides/anti-cheat.md) and the [API Quickstart](quickstart-api.md).

---

## Reading a targeted board

Reading is no different from any other board — same call, same signal:

```gdscript
CheddaBoards.get_scoreboard("level-14", 100)

CheddaBoards.scoreboard_loaded.connect(_on_scoreboard_loaded)

func _on_scoreboard_loaded(scoreboard_id: String, config: Dictionary, entries: Array):
    for entry in entries:
        print("#%d %s: %d pts" % [entry.rank, entry.nickname, entry.score])
```

REST:

```bash
curl "https://api.cheddaboards.com/games/my-game/scoreboards/level-14?limit=100" \
  -H "X-API-Key: cb_my-game_xxxxxxxxx" \
  -H "X-Game-ID: my-game"
```

---

## How a targeted submit behaves

- **One board only.** It writes to the board you named and nothing else — no fan-out.
- **No aggregate update.** It does not touch the player's profile total or global stats. Targeted boards are standalone rankings.
- **Same anti-cheat.** Play-session / time-validation and rate-limit rules are identical to a plain submit.
- **Per-board throttle.** The 2-second submit gate is keyed per (player, game, board), so chaining several board submits in one run is fine.
- **Must be targeted.** The board has to exist *and* be marked Targeted. Submitting a `scoreboardId` that points at a fan-out board (or one that doesn't exist) returns an error rather than silently writing the wrong place.

---

## Combining with reset cadence

Targeted and timed are independent, so you can mix them. A few patterns:

- **All-time per-level boards** — `level-01 … level-28`, each Targeted + All Time. Career bests per level.
- **Weekly category board** — a `time-trial` board, Targeted + Weekly, for a rotating weekly challenge that archives each week.
- **Every-N-days event** — a `sprint` board, Targeted + Custom interval (e.g. every 3 days).

When a targeted board has a reset cadence, it archives on reset just like any timed board — see [Timed Scoreboards & Archives](timed-leaderboards.md).

---

## HTTP API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/scores` (with `scoreboardId`) | POST | Submit to one targeted board |
| `/games/:gameId/scoreboards/:id` | GET | Read a board's entries (targeted or fan-out) |
| `/games/:gameId/scoreboards` | GET | List the game's boards (both kinds) |

---

## Best Practices

### 1. Keep IDs predictable

Use a consistent scheme like `level-01`, `level-02` (zero-padded) so you can build board IDs programmatically from the current level.

### 2. Decide whether targeted runs also count globally

A targeted submit does *not* update the player's overall total. If your per-level scores should also feed the main leaderboard, send both a `submit_score_to_board(...)` and a normal `submit_score(...)`.

### 3. Don't over-create boards

Each targeted board is a separate leaderboard to maintain. Per-level for a 28-level game is fine; per-level for 500 procedurally generated levels probably isn't.

### 4. Pre-create boards in the dashboard

A targeted submit fails if the board doesn't exist yet. Create your level/category boards up front rather than expecting them to auto-create.

---

## Links

- **Dashboard:** [cheddaboards.com/developers](https://cheddaboards.com/developers)
- **Timed boards & archives:** [Timed Scoreboards](timed-leaderboards.md)
- **REST API:** [API Quickstart](quickstart-api.md)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)

---

**Need help?** info@cheddaboards.com
