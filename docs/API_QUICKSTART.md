# 🚀 CheddaBoards API Quick Start

**Add leaderboards to your Godot game in 3 minutes.**

**Works on Windows, Mac, Linux, Mobile, and Web.**

---

## The Simplest Path

```
1. Register game → Get API key (2 min)
2. Add CheddaBoards.gd to project (30 sec)
3. Call the functions (30 sec)
```

That's it. No servers, no OAuth, no complexity.

---

## Step 1: Get Your API Key

```
🌐 Go to: cheddaboards.com/dashboard
   ↓
🔐 Sign in (Internet Identity, Google, or Apple)
   ↓
📝 Register your game:
   • Game ID: my-awesome-game
   • Name: My Awesome Game
   ↓
🔑 Click "Generate API Key"
   ↓
📋 Copy your key: cb_my-awesome-game_xxxxxxxxx
```

**Time: 2 minutes**

---

## Step 2: Add to Your Project

**Download:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)

Copy ONE file to your project:

```
YourGame/
├── autoloads/
│   └── CheddaBoards.gd    ← Just this file!
└── project.godot
```

Add as Autoload:
```
Project → Project Settings → Autoload → Add
Path: res://autoloads/CheddaBoards.gd
Name: CheddaBoards
```

Set your API key in CheddaBoards.gd (around line 35):
```gdscript
var api_key: String = "cb_my-awesome-game_xxxxxxxxx"
```

**Time: 30 seconds**

---

## Step 3: Use It

```gdscript
extends Node

func _ready():
    # Wait for SDK to initialize
    await CheddaBoards.wait_until_ready()
    
    # Login anonymously with a nickname
    CheddaBoards.login_anonymous("PlayerName")

func _on_game_over(score: int, streak: int):
    # Submit the score
    CheddaBoards.submit_score(score, streak)

func _show_leaderboard():
    # Get top 100 scores
    CheddaBoards.leaderboard_loaded.connect(_on_leaderboard)
    CheddaBoards.get_leaderboard("score", 100)

func _on_leaderboard(entries: Array):
    for entry in entries:
        print("#%d %s - %d pts" % [entry.rank, entry.nickname, entry.score])
```

**Time: 30 seconds**

---

## ✅ Done!

You now have:
- ✅ Global leaderboards
- ✅ Score submission with anti-cheat
- ✅ Player nicknames
- ✅ Streak tracking

**Total time: ~3 minutes**

---

## 📖 API Reference

### Authentication

```gdscript
# Anonymous login (recommended for native)
CheddaBoards.login_anonymous("PlayerNickname")

# Check status
if CheddaBoards.is_authenticated():
    print("Ready to submit scores!")

# Get current nickname
var name = CheddaBoards.get_nickname()

# Change nickname
CheddaBoards.change_nickname_to("NewName")

# Logout
CheddaBoards.logout()
```

### Scores

```gdscript
# Submit score
CheddaBoards.submit_score(1500, 10)  # score, streak

# Listen for result
CheddaBoards.score_submitted.connect(func(s, st):
    print("Score saved: %d, streak: %d" % [s, st])
)

CheddaBoards.score_error.connect(func(reason):
    print("Error: ", reason)
)
```

### Leaderboards

```gdscript
# Get leaderboard
CheddaBoards.get_leaderboard("score", 100)  # sort_by, limit
# sort_by: "score" or "streak"

CheddaBoards.leaderboard_loaded.connect(func(entries):
    for e in entries:
        print("#%d %s - %d" % [e.rank, e.nickname, e.score])
)

# Get player's rank
CheddaBoards.get_player_rank("score")

CheddaBoards.player_rank_loaded.connect(func(rank, score, streak, total):
    print("You are #%d of %d players!" % [rank, total])
)
```

### Achievements

```gdscript
# Unlock an achievement
CheddaBoards.unlock_achievement("first_win")

# Get player's achievements
CheddaBoards.get_achievements()

CheddaBoards.achievements_loaded.connect(func(achievements):
    for a in achievements:
        print("Unlocked: ", a)
)
```

---

## 🔧 Configuration Options

```gdscript
# In CheddaBoards.gd or at runtime:

# Required for API mode
var api_key: String = "cb_your_key_here"

# Optional: Your game ID (auto-extracted from API key)
var game_id: String = "your-game-id"

# Debug logging
var debug_logging: bool = false  # Set true to see all requests
```

---

## 📡 All Signals

```gdscript
# SDK Status
signal sdk_ready()

# Auth
signal login_success(nickname: String)
signal login_failed(reason: String)
signal logout_success()

# Scores
signal score_submitted(score: int, streak: int)
signal score_error(reason: String)

# Leaderboards
signal leaderboard_loaded(entries: Array)
signal player_rank_loaded(rank: int, score: int, streak: int, total: int)

# Achievements
signal achievement_unlocked(achievement_id: String)
signal achievements_loaded(achievements: Array)

# Errors
signal request_failed(endpoint: String, error: String)
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| "API key not set" | Set `api_key` in CheddaBoards.gd |
| "Not authenticated" | Call `login_anonymous()` first |
| Score not saving | Check `is_authenticated()` is true |
| Request failed | Check internet connection, verify API key |

### Debug Mode

```gdscript
# Enable verbose logging
CheddaBoards.debug_logging = true

# Print full status
CheddaBoards.debug_status()
```

---

## 🎯 Common Patterns

### Game Over Screen

```gdscript
func _on_game_over():
    var score = GameManager.score
    var streak = GameManager.best_streak
    
    if CheddaBoards.is_authenticated():
        CheddaBoards.submit_score(score, streak)
        
        # Show "Saving..." then update when done
        CheddaBoards.score_submitted.connect(func(s, st):
            show_message("Score saved!")
        , CONNECT_ONE_SHOT)
```

### Main Menu with Leaderboard

```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("Player")
    _load_leaderboard()

func _load_leaderboard():
    CheddaBoards.leaderboard_loaded.connect(_display_leaderboard, CONNECT_ONE_SHOT)
    CheddaBoards.get_leaderboard("score", 10)

func _display_leaderboard(entries):
    for i in entries.size():
        var e = entries[i]
        $LeaderboardList.add_item("#%d %s - %d" % [e.rank, e.nickname, e.score])
```

### Let Player Set Nickname

```gdscript
func _on_nickname_submitted(new_name: String):
    CheddaBoards.change_nickname_to(new_name)
    
    CheddaBoards.nickname_changed.connect(func(name):
        $NicknameLabel.text = name
    , CONNECT_ONE_SHOT)
```

---

## 🔗 Resources

- **Dashboard:** [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
- **Full Docs:** See README.md for web builds, achievements system, OAuth setup

---

## 💡 Tips

- ⭐ Anonymous login works on ALL platforms
- ⭐ API key is required for native builds
- ⭐ Scores only save if higher than previous best
- ⭐ Use `debug_logging = true` to troubleshoot

---

**Zero servers. Free tier forever. Ship your game!** 🧀
