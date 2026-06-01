# API Quickstart (REST)

Use CheddaBoards from **any** engine or language by calling the HTTP API directly — no Godot, no SDK. This is the same API the Godot SDK uses under the hood.

> The endpoints and request bodies below were taken from the v2.2.0 SDK. Response field names are described where confirmed; check live responses for the exact shape of any field your code depends on.

---

## Base URL

```
https://api.cheddaboards.com
```

---

## Authentication

Every request sends JSON and identifies the game. How you identify the *player* depends on whether they're anonymous or signed in.

| Header | Value | When |
|--------|-------|------|
| `Content-Type` | `application/json` | Always |
| `X-Game-ID` | your Game ID (e.g. `my-game`) | Always |
| `X-API-Key` | your API key (`cb_my-game_xxxxxxxxx`) | Anonymous / API-key requests |
| `X-Session-Token` | the player's `sessionId` | After Device Code sign-in |

`X-Session-Token` and `X-API-Key` are mutually exclusive — if you have a session token, send that instead of the API key. (Exception: `play-sessions/*` always use the API key.)

### Players & anonymous identity

There's no "anonymous login" call. An anonymous player is just a **persistent ID you generate and store client-side** — the SDK uses the form `dev_<unixtime>_<random>` (e.g. `dev_1730000000_1a2b3c4d`). Send it as `playerId`; the first score submission creates the profile on the backend.

---

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

Add `"playSessionToken": "<token>"` to the body if you're using anti-cheat play sessions (see §4).

## 2. Read the leaderboard

```bash
curl "https://api.cheddaboards.com/leaderboard?sort=score&limit=100" \
  -H "X-API-Key: cb_my-game_xxxxxxxxx" \
  -H "X-Game-ID: my-game"
```

`sort` accepts `score` or `streak`. Entries come back with rank, nickname, score, and streak.

## 3. Sign in with Google / Apple / Internet Identity (Device Code)

A two-step polling flow (RFC 8628). The player authorises on their phone; you poll until approved.

**Request a code:**

```bash
curl -X POST https://api.cheddaboards.com/auth/device/code \
  -H "Content-Type: application/json" \
  -H "X-Game-ID: my-game" \
  -d '{"gameId": "my-game"}'
```

Returns a user code, a verification URL (`cheddaboards.com/link`), the `device_code`, and a QR data URL. Show the user code + QR to the player.

**Poll for approval:**

```bash
curl -X POST https://api.cheddaboards.com/auth/device/token \
  -H "Content-Type: application/json" \
  -H "X-Game-ID: my-game" \
  -d '{"device_code": "<device_code>"}'
```

- **`428`** → `authorization_pending`, keep polling (the SDK polls every 5s).
- **`200`** with `{ "ok": true, "data": { "sessionId": "...", "nickname": "...", "email": "...", "gameProfile": {...} } }` → approved.

Use the returned `sessionId` as your `X-Session-Token` on subsequent requests, and stop sending `X-API-Key`.

## 4. Anti-cheat play sessions (optional)

Wrap a run in a server-tracked session so the backend can validate the score against elapsed time.

```bash
# Start — returns a session token
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

Pass the same `playSessionToken` in your `POST /scores` body, and configure limits from your dashboard's Security tab — see [Anti-cheat](guides/anti-cheat.md).

---

## Endpoint reference

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/scores` | Submit a score (`playerId`, `gameId`, `score`, `streak`, `nickname`, `playSessionToken?`) |
| `GET`  | `/leaderboard?sort={score\|streak}&limit={n}` | Global leaderboard |
| `GET`  | `/players/{playerId}/rank?sort={score\|streak}` | A player's rank |
| `GET`  | `/players/{playerId}/profile` | Anonymous player profile |
| `GET`  | `/auth/profile` | Signed-in player profile (uses `X-Session-Token`) |
| `PUT`  | `/profile/nickname` | Change nickname (`{ nickname }`) |
| `GET`  | `/games/{gameId}/scoreboards` | List timed scoreboards |
| `GET`  | `/games/{gameId}/scoreboards/{scoreboardId}?limit={n}` | A timed scoreboard's entries |
| `POST` | `/auth/device/code` | Start Device Code auth (`{ gameId }`) |
| `POST` | `/auth/device/token` | Poll for approval (`{ device_code }`) |
| `POST` | `/migrate-account` | Upgrade an anonymous account to a verified one |
| `POST` | `/play-sessions/start` | Begin an anti-cheat session (`{ gameId, playerId }`) |
| `POST` | `/play-sessions/end` | End a session (`{ playSessionToken }`) |
| `GET`/`POST` | `/achievements` | List / sync achievements |
| `GET`  | `/game`, `/game/stats` | Game metadata & stats |
| `GET`  | `/health` | Service health check |

> Timed-scoreboard **archives** have their own endpoints under `/games/{gameId}/scoreboards/...` — see [Timed Leaderboards](guides/timed-leaderboards.md).

---

## Notes

- All bodies are JSON; all responses are JSON.
- A `404` on a scoreboard lookup is normal — it just means that scoreboard isn't configured for the game.
- Rate limiting and score validation are enforced server-side; a rejected score comes back as an error you should surface to the player.

---

**See also:** [Drop-in (Godot) Quickstart](quickstart-dropin.md) · [Authentication](guides/authentication.md) · [Anti-cheat](guides/anti-cheat.md) · [docs index](README.md)
