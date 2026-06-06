# Anti-cheat

Built-in, server-side protection. You set the limits from your dashboard and CheddaBoards enforces them on every submission — score **caps and validation** need no game code at all. **Play sessions** (which let the server validate a score against real elapsed play time) are handled automatically on the Template, and are a few calls on the Drop-in / REST paths.

| Protection | How it works |
|------------|--------------|
| **Play Sessions** | The server tracks real play time — a score submitted without a valid session can't be time-validated and may be rejected |
| **Score Validation** | The backend calculates the max possible score for the elapsed time and rejects anything above it |
| **Rate Limiting** | Blocks rapid-fire submissions from bots or scripts |
| **Score Caps** | Set a max score/streak per submission, plus absolute lifetime caps |

---

## Configuring limits

Set your limits from your game's **Security** tab on the dashboard, based on your game's mechanics — for example, a max of 200,000 points per round and a max streak of 10. Start loose, then tighten as you see real player data.

There are no default caps; validation is per-game and entirely dashboard-driven, so a fast scoring game and a slow puzzle game can have completely different rules without any code changes.

---

## Play sessions in code

On the **Template**, the wrapper opens a session when a run starts and clears it after the score submits — nothing for you to do. On the **Drop-in** or **REST** paths you handle it yourself:

```gdscript
CheddaBoards.start_play_session()          # when the run begins
# … play …
CheddaBoards.submit_score(score, streak)   # the active session token is attached automatically
CheddaBoards.clear_play_session()          # after submit, on success or error
```

Full lifecycle: [Drop-in Quickstart](../quickstart-dropin.md) · [API Quickstart](../quickstart-api.md).

## Play session signals

Most enforcement is invisible to your code, but you can react to session state if you need to:

```gdscript
signal play_session_started(token: String)
signal play_session_error(reason: String)
```

If a score is rejected as invalid, you'll get the reason via `score_error` — see [Troubleshooting](../TROUBLESHOOTING.md).

---

**See also:** [Signals Reference](signals-reference.md) · [Troubleshooting](../TROUBLESHOOTING.md) · [docs index](../README.md)
