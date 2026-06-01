# Anti-cheat

Built-in, server-side protection — no code required in your game. You configure limits from your dashboard and CheddaBoards enforces them automatically on every submission.

| Protection | How it works |
|------------|--------------|
| **Play Sessions** | The server tracks real play time — scores without a valid session are rejected |
| **Score Validation** | The backend calculates the max possible score for the elapsed time and rejects anything above it |
| **Rate Limiting** | Blocks rapid-fire submissions from bots or scripts |
| **Score Caps** | Set a max score/streak per submission, plus absolute lifetime caps |

---

## Configuring limits

Set your limits from your game's **Security** tab on the dashboard, based on your game's mechanics — for example, a max of 200,000 points per round and a max streak of 10. Start loose, then tighten as you see real player data.

There are no default caps; validation is per-game and entirely dashboard-driven, so a fast scoring game and a slow puzzle game can have completely different rules without any code changes.

---

## Play session signals

Most enforcement is invisible to your code, but you can react to session state if you need to:

```gdscript
signal play_session_started(token: String)
signal play_session_error(reason: String)
```

If a score is rejected as invalid, you'll get the reason via `score_error` — see [Troubleshooting](../TROUBLESHOOTING.md).

---

**See also:** [Signals Reference](signals-reference.md) · [Troubleshooting](../TROUBLESHOOTING.md) · [docs index](../README.md)
