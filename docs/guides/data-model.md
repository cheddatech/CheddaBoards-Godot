# What CheddaBoards Stores

The short version: for each player, CheddaBoards keeps a **personal best** (high score and high streak) on each board, a small **profile**, and the **achievements** they've unlocked. Your per-run details — hits, level, accuracy — stay on the device. Here's the whole picture.

---

## The leaderboard entry

One row per player, per board. Reading a board gives you:

| Field | What it is |
|-------|------------|
| `rank` | The player's position on that board |
| `nickname` | The player's public display name |
| `score` | The player's **highest** score on that board |
| `streak` | The player's **highest** streak on that board |

A few things worth knowing:

- **It's a personal best, not a history.** Submitting a lower score never replaces a higher one — only the best survives. There's one row per player, not one per run.
- **Score and streak are independent maxima.** Your best score and your best streak don't have to come from the same run; each is kept as its own high-water mark.
- **Bests are per board.** Your all-time best and your weekly best are tracked separately, so the same player can sit at different scores on different boards.

---

## The player profile

One profile per player, per game. It holds:

| Field | Notes |
|-------|-------|
| `nickname` | Public display name — the only identity other players ever see |
| `score` / `streak` | The player's bests (as above) |
| `play_count` | How many games they've finished |
| `achievements` | The set of achievement IDs they've unlocked |
| user ID | **Private.** Anonymous players get a generated `dev_…` ID; signed-in players are identified by their Google/Apple account (which may be an email address). It's used to identify and link the account and is **never shown to anyone** — only the nickname is public. |

---

## Achievements

Achievements are stored as **unlocked / not-unlocked flags, keyed by ID** — not as free-form data. They sync to the player's profile. Anonymous players keep them locally until they sign in, at which point they sync up. Use them for milestones and badges, not as a place to stash per-run stats.

---

## Scoreboards & archives

You can run as many boards as you like — an all-time board plus timed ones (daily / weekly / monthly) that reset on a schedule. Each board tracks its own per-player bests.

When a timed board resets, its final standings are **archived** — a snapshot you can read back later (e.g. to show "last week's winners"). Resetting a board doesn't throw the results away; the archive keeps them.

---

## Identity & account linking

- **Anonymous:** a `dev_<timestamp>_<random>` ID your game generates and stores on the device. The profile is created on the first score submission.
- **Signed in:** Google or Apple, via device code. The account is identified by a private user ID (possibly an email), never shown publicly.
- **Linking:** an anonymous player can upgrade to a Google/Apple account and keep all their progress. Scores, streaks, achievements, and play count carry over, merged as **per-field maxima** — so linking can only ever keep or raise a best, never lower one.

---

## Play sessions

A play session is a **short-lived server-side token** created for the duration of a single run, used to validate the score against elapsed time (anti-cheat). It isn't long-term player data — it exists only around a run and is cleared once the score is submitted.

---

## What CheddaBoards does *not* store

- **The rest of your `game_over` stats.** `hits`, `misses`, `level`, and `accuracy` are used by the wrapper for the game-over screen and achievement checks, then discarded. They never reach the server. → [Where each value goes](your-own-game.md#where-each-value-goes)
- **Arbitrary per-entry metadata.** A score row is score + streak — there's no free-form field to attach extra data to an entry today. To rank a custom value, map it onto score or streak.
- **Anything you don't send.** The data model is exactly what's listed on this page.

---

**See also:** [Build Your Own Game](your-own-game.md) · [Timed Leaderboards](timed-leaderboards.md) · [Authentication](authentication.md) · [Anti-cheat](anti-cheat.md)
