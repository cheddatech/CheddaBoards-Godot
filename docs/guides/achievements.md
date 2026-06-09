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

> ⚠ **The shipped achievements are CheddaClick's example set — replace them before you ship.** Making them your own means changing **two** things, not one: the definitions (below) *and* the unlock conditions in `check_score` / `check_combo` / `check_level` / `check_game_over`, which fire on CheddaClick's concepts (score, combo, hits, level, time-remaining). If your game has no combos or levels, rewrite those checks to call `_unlock("your_id")` on whatever your game actually tracks. The unlock/save/sync engine around them is generic — leave it alone.

---

## Defining your achievements

Achievements are declared in `autoloads/Achievements.gd` as a dictionary keyed by ID:

```gdscript
var achievements = {
    # Games played
    "games_1":     {"name": "First Game", "desc": "Play your first game"},
    "games_10":    {"name": "Dedicated",  "desc": "Play 10 games"},

    # Score milestones
    "score_1000":  {"name": "Beginner",   "desc": "Score 1,000 points"},
    "score_5000":  {"name": "Skilled",    "desc": "Score 5,000 points"},

    # Combos (max_combo is submitted as the player's streak)
    "combo_10":    {"name": "On Fire",    "desc": "Reach a x10 combo"},

    # Levels
    "level_2":     {"name": "Level 2",    "desc": "Reach Level 2"},
    "level_5":     {"name": "Master",     "desc": "Reach Level 5"},
}
```

> The dictionary above shows the structure with generic examples. The shipped `Achievements.gd` carries CheddaClick's actual set — cheese / combo / level achievements — which is the example you replace.

## Quick usage

Call these from your game-over handler, alongside your score submission:

```gdscript
func _on_game_over(score: int, streak: int):
    Achievements.increment_games_played()
    Achievements.check_game_over(score, 0, streak)   # evaluates score, combo & hits achievements
    Achievements.submit_with_score(score, streak)

func _on_level_up(level: int):
    Achievements.check_level(level)                  # checks level achievements
```

`check_game_over` evaluates the run against your achievement definitions; `submit_with_score` piggybacks the achievement sync onto the score submission so there's only one round trip.

> **Sync requires login for the backend copy.** Full achievement sync needs a verified account (Google/Apple). Anonymous players have achievements stored locally and synced automatically once they upgrade — see [Authentication → Account linking](authentication.md#account-linking-anonymous--verified).

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
