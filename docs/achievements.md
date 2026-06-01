# Achievements

Backend-synced achievements that also work offline and for anonymous players.

- Configurable achievement definitions
- **Score-first submission** — the score submits immediately, achievements sync silently afterwards
- **Deferred sync** — failed achievements re-queue automatically
- **Session tracking** — track combos, levels, and special actions per run
- Automatic unlocking based on score / streak / games played
- **Level achievements** — unlock for reaching game levels
- Popup notifications with batch support
- Offline support with local caching
- Works for anonymous players (local storage), syncing once they upgrade

---

## Quick usage

Call these from your game-over handler, alongside your score submission:

```gdscript
func _on_game_over(score: int, streak: int):
    Achievements.increment_games_played()
    Achievements.check_game_over(score, 0, streak)
    Achievements.submit_with_score(score, streak)
```

`check_game_over` evaluates the run against your achievement definitions; `submit_with_score` piggybacks the achievement sync onto the score submission so there's only one round trip.

> **Sync requires login for the backend copy.** Full achievement sync needs a verified account (Google/Apple/Internet Identity). Anonymous players have achievements stored locally and synced automatically once they upgrade — see [Authentication → Account linking](authentication.md#account-linking-anonymous--verified).

---

## Signals

The SDK and the `Achievements` autoload both emit unlock signals:

```gdscript
# CheddaBoards.gd
signal achievement_unlocked(achievement_id: String)
signal achievements_loaded(achievements: Array)

# Achievements.gd
signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal achievements_ready()
```

Connect `Achievements.achievement_unlocked` to drive your popup notifications.

---

**See also:** [Authentication](authentication.md) · [Signals Reference](signals-reference.md) · [docs index](../README.md)
