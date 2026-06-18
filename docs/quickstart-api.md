# API Quickstart (REST)

Use CheddaBoards from any engine or language by calling the HTTP API directly — no Godot, no SDK. This is the same API the Godot SDK uses under the hood.

The endpoints and request bodies below were taken from the v2.2.1 SDK. Response field names are described where confirmed; check live responses for the exact shape of any field your code depends on.

## Base URL

```
https://api.cheddaboards.com
```

## Authentication

Every request sends JSON and identifies the game. How you identify the player depends on whether they're anonymous or signed in.

| Header | Value | When |
| --- | --- | --- |
| `Content-Type` | `application/json` | Always |
| `X-Game-ID` | your Game ID (e.g. `my-game`) | Always |
| `X-API-Key` | your API key (`cb_my-game_xxxxxxxxx`) | Anonymous / API-key requests |
| `X-Session-Token` | the player's `sessionId` | After Device Code sign-in |

`X-Session-Token` and `X-API-Key` are mutually exclusive — if you have a session token, send that instead of the API key. (Exception: `play-sessions/*` always use the API key.)

## Players & anonymous identity

There's no "anonymous login" call. An anonymous player is just a persistent ID you generate and store client-side — the SDK uses the form `dev_<unixtime>_<random>` (e.g. `dev_1730000000_1a2b3c4d`). Send it as `playerId`; the first score submission creates the profile on the backend.

## 1. Submit a score

```bash
curl -X POST https://api.cheddaboards.com/scores \
  -H "Content-Type: application/json" \
  -H "X-API-Key: cb_my-game_xxxxxxxxx" \
  -H "X-Game-ID: my-game" \
  -d '{
    "playerId": "dev_1730000000_1a2b3c4d",
    "gameId": "my-game",
    "score": 1000,
    "streak": 5,
    "nickname": "PlayerName"
  }'
```

A submit with no `scoreboardId` (above) **fans out**: the score is recorded against the player's profile and applied to every one of the game's standard time-based boards (all-time, weekly, daily, etc.).

If you started a play session for the run (see §4 — recommended), include its token in the body as `"playSessionToken": "<token>"` so the backend can time-validate the score. If the game has time validation enabled, the session token is **required**, not optional.

A passed `nickname` is only applied if it's 2–20 characters and not already taken by another player; otherwise the player keeps their existing or default (`Player_<n>`) nickname.

### Submitting to one specific board (category / targeted scoreboards)

Targeted scoreboards let you run per-level or per-category leaderboards — `level-01 … level-28`, `boss-rush`, `time-trial`, `runs`, and so on — under a single game, without registering a separate game for each.

There are two kinds of board:

- **Fan-out boards** (the default) receive *every* plain submit, as in §1.
- **Targeted boards** receive *only* scores explicitly addressed to them by ID. A plain submit never touches them.

To send a score to one targeted board, add `scoreboardId` to the body:

```bash
curl -X POST https://api.cheddaboards.com/scores \
  -H "Content-Type: application/json" \
  -H "X-API-Key: cb_my-game_xxxxxxxxx" \
  -H "X-Game-ID: my-game" \
  -d '{
    "playerId": "dev_1730000000_1a2b3c4d",
    "gameId": "my-game",
    "score": 1000,
    "streak": 5,
    "nickname": "PlayerName",
    "scoreboardId": "level-14"
  }'
```

On success the response confirms the board it landed on, e.g. `"Submitted to level-14 - Score: 1000, Streak: 0"`.

How a targeted submit differs from a plain one:

- It writes to **exactly that one board** and nowhere else — no fan-out to your time-based boards.
- It does **not** update the player's aggregate profile / global stats. Targeted boards are standalone rankings; if you also want the score reflected in the player's overall totals, send a separate plain submit.
- The same play-session / time-validation and rate-limit rules apply as for a plain submit.
- You can chain several targeted submits for one run (e.g. a `runs` board plus the relevant `level-14` board) — the throttle is keyed per board so back-to-back board writes won't trip the 2-second gate.

The target board must already exist **and be marked as targeted**. Create one in the **Developer Console → Scoreboards** tab: set a Scoreboard ID, choose **Board Type → Targeted**, and create it. Submitting a `scoreboardId` that points at a fan-out board (or a board that doesn't exist) returns an error rather than silently writing the wrong place.

Reading a targeted board is no different from any other — see §2 below and the scoreboard read endpoint:

```bash
curl "https://api.cheddaboards.com/games/my-game/scoreboards/level-14?limit=100" \
  -H "X-API-Key: cb_my-game_xxxxxxxxx" \
  -H "X-Game-ID: my-game"
```

## 2. Read the leaderboard

```bash
curl "https://api.cheddaboards.com/leaderboard?sort=score&limit=100" \
  -H "X-API-Key: cb_my-game_xxxxxxxxx" \
  -H "X-Game-ID: my-game"
```

`sort` accepts `score` or `streak`. Entries come back with `rank`, `nickname`, `score`, and `streak`.

This reads the game's global (fan-out) leaderboard. For a specific board — timed *or* targeted — use `GET /games/{gameId}/scoreboards/{scoreboardId}`.

## 3. Sign in with Google / Apple (Device Code)

A two-step polling flow (RFC 8628). The player authorises on their phone; you poll until approved.

Request a code:

```bash
curl -X POST https://api.cheddaboards.com/auth/device/code \
  -H "Content-Type: application/json" \
  -H "X-Game-ID: my-game" \
  -d '{"gameId": "my-game"}'
```

Returns a user code, a verification URL (`cheddaboards.com/link`), the `device_code`, and a QR data URL. Show the user code + QR to the player.

Poll for approval:

```bash
curl -X POST https://api.cheddaboards.com/auth/device/token \
  -H "Content-Type: application/json" \
  -H "X-Game-ID: my-game" \
  -d '{"device_code": "<device_code>"}'
```

- `428` → `authorization_pending`, keep polling (the SDK polls every 5s).
- `200` with `{ "ok": true, "data": { "sessionId": "...", "nickname": "...", "email": "...", "gameProfile": {...} } }` → approved.

Use the returned `sessionId` as your `X-Session-Token` on subsequent requests, and stop sending `X-API-Key`.

## 4. Anti-cheat play sessions (recommended)

Wrap each run in a server-tracked session so the backend can validate the score against elapsed time. The Godot SDK does this automatically; on the raw REST path you do it yourself. If you've set anti-cheat caps on your dashboard — or enabled time validation for the game — do this: scores submitted without a valid session token skip time validation and may be rejected. Targeted submits go through the same gate.

The lifecycle is: **start** when the run begins → pass the token in your `POST /scores` body → **end** after submitting.

```bash
# Start — returns a session token (in data.ok)
curl -X POST https://api.cheddaboards.com/play-sessions/start \
  -H "Content-Type: application/json" \
  -H "X-API-Key: cb_my-game_xxxxxxxxx" \
  -H "X-Game-ID: my-game" \
  -d '{"gameId": "my-game", "playerId": "dev_1730000000_1a2b3c4d"}'

# End
curl -X POST https://api.cheddaboards.com/play-sessions/end \
  -H "Content-Type: application/json" \
  -H "X-API-Key: cb_my-game_xxxxxxxxx" \
  -H "X-Game-ID: my-game" \
  -d '{"playSessionToken": "<token>"}'
```

Pass the same `playSessionToken` in your `POST /scores` body (plain *or* targeted), and configure limits from your dashboard's Security tab — see Anti-cheat. Sessions are capped per player, so end them when the run finishes (or use a fresh `playerId` when testing) to avoid a "too many active sessions" error.

## Endpoint reference

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `POST` | `/scores` | Submit a score (`playerId`, `gameId`, `score`, `streak`, `nickname`, `playSessionToken?`, `scoreboardId?`). With `scoreboardId`, writes to that one targeted board instead of fanning out. |
| `GET` | `/leaderboard?sort={score\|streak}&limit={n}` | Global leaderboard |
| `GET` | `/players/{playerId}/rank?sort={score\|streak}` | A player's rank |
| `GET` | `/players/{playerId}/profile` | Anonymous player profile |
| `GET` | `/auth/profile` | Signed-in player profile (uses `X-Session-Token`) |
| `PUT` | `/profile/nickname` | Change nickname (`{ nickname }`) |
| `GET` | `/games/{gameId}/scoreboards` | List the game's scoreboards (timed and targeted) |
| `GET` | `/games/{gameId}/scoreboards/{scoreboardId}?limit={n}` | A single scoreboard's entries (timed or targeted) |
| `POST` | `/auth/device/code` | Start Device Code auth (`{ gameId }`) |
| `POST` | `/auth/device/token` | Poll for approval (`{ device_code }`) |
| `POST` | `/migrate-account` | Upgrade an anonymous account to a verified one |
| `POST` | `/play-sessions/start` | Begin an anti-cheat session (`{ gameId, playerId }`) |
| `POST` | `/play-sessions/end` | End a session (`{ playSessionToken }`) |
| `GET`/`POST` | `/achievements` | List / sync achievements |
| `GET` | `/game`, `/game/stats` | Game metadata & stats |
| `GET` | `/health` | Service health check |

Timed-scoreboard archives have their own endpoints under `/games/{gameId}/scoreboards/...` — see Timed Leaderboards.

## Notes

- All bodies are JSON; all responses are JSON.
- A `404` on a scoreboard lookup is normal — it just means that scoreboard isn't configured for the game.
- Rate limiting and score validation are enforced server-side; a rejected score comes back as an error you should surface to the player.
- Targeted boards are created in the Developer Console (Board Type → Targeted). A submit to a `scoreboardId` that isn't a targeted board returns an error.

See also: Drop-in (Godot) Quickstart · Authentication · Anti-cheat · docs index
