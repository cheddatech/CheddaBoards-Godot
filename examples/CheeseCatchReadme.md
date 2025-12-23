# 🧀 Cheese Catch

A minimal example game demonstrating **API-only** CheddaBoards integration.

No MainMenu template, no extra scenes - just one script that handles everything.

## Features Demonstrated

- Anonymous login with custom nickname
- Score submission
- Leaderboard display
- Name entry (web prompt + native UI)

## Setup

1. Copy `CheeseCatch.gd` and `CheeseCatch.tscn` to your project
2. Ensure `CheddaBoards` is in your Autoloads
3. Set your API key in `CheddaBoards.gd`
4. Run!

## How It Works

### Initialization

```gdscript
func _ready():
    randomize()
    _build_ui()
    
    await CheddaBoards.wait_until_ready()
    
    CheddaBoards.login_success.connect(_on_login_success)
    CheddaBoards.score_submitted.connect(_on_score_submitted)
    CheddaBoards.leaderboard_loaded.connect(_on_leaderboard_loaded)
    
    _prompt_for_name()
```

### Login with Nickname

```gdscript
func _login_with_name(nickname: String):
    CheddaBoards.change_nickname_to(nickname)  # Sync to backend
    CheddaBoards.login_anonymous(nickname)      # Login
```

### Submit Score

```gdscript
func _submit_score():
    CheddaBoards.submit_score(score, best_streak)
```

### Get Leaderboard

```gdscript
func _on_leaderboard_pressed():
    CheddaBoards.get_leaderboard("score", 10)

func _on_leaderboard_loaded(entries: Array):
    for entry in entries:
        print("#%d %s - %d pts" % [entry.rank, entry.nickname, entry.score])
```

## Game Rules

- Click falling 🧀 to catch them
- +10 points base, +2 per streak level
- Miss 3 cheese = game over
- Speed increases over time

## Files

| File | Description |
|------|-------------|
| `CheeseCatch.gd` | Complete game logic + CheddaBoards integration |
| `CheeseCatch.tscn` | Minimal scene (just root Control node) |

## API Methods Used

| Method | Purpose |
|--------|---------|
| `await CheddaBoards.wait_until_ready()` | Wait for SDK |
| `CheddaBoards.login_anonymous(nickname)` | Anonymous login |
| `CheddaBoards.change_nickname_to(name)` | Sync nickname to backend |
| `CheddaBoards.submit_score(score, streak)` | Submit score |
| `CheddaBoards.get_leaderboard(sort, limit)` | Fetch leaderboard |

## Signals Used

| Signal | Purpose |
|--------|---------|
| `login_success(nickname)` | Login completed |
| `score_submitted(score, streak)` | Score saved |
| `score_error(reason)` | Score failed |
| `leaderboard_loaded(entries)` | Leaderboard ready |

## Notes

- UI is built programmatically - no scene editor required
- Web uses browser `prompt()` for name entry (better mobile support)
- Native uses in-game panel with LineEdit
- All code in one file for easy reference

---

Part of [CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
