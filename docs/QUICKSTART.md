# ⚡ CheddaBoards Quick Start

**Add leaderboards to your game in minutes.**

---

## Choose Your Integration

| Path | Time | Best For |
|------|------|----------|
| **[API Only](#-api-quick-start)** | 3 min | Native builds, simple integration |
| **[Full Web SDK](#-web-sdk-quick-start)** | 5 min | Web builds with login UI, OAuth |

> 💡 **Not sure?** Start with API Only - it works everywhere and you can add web features later.

---

# 🚀 API Quick Start

**The simplest integration. Works on all platforms.**

### Step 1: Get API Key (2 min)

1. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
2. Sign in (Internet Identity, Google, or Apple)
3. Register your game
4. Click **"Generate API Key"**
5. Copy your key: `cb_your-game_xxxxxxxxx`

### Step 2: Add to Project (30 sec)

Download from [GitHub](https://github.com/cheddatech/CheddaBoards-Godot) and copy `CheddaBoards.gd` to your project.

Add as Autoload:
```
Project → Project Settings → Autoload → Add
Path: res://CheddaBoards.gd
Name: CheddaBoards
```

Set your API key in CheddaBoards.gd:
```gdscript
var api_key: String = "cb_your-game_xxxxxxxxx"
```

### Step 3: Use It (30 sec)

```gdscript
func _ready():
    await CheddaBoards.wait_until_ready()
    CheddaBoards.login_anonymous("PlayerName")

func _on_game_over(score, streak):
    CheddaBoards.submit_score(score, streak)

func _show_leaderboard():
    CheddaBoards.leaderboard_loaded.connect(_on_leaderboard)
    CheddaBoards.get_leaderboard("score", 100)

func _on_leaderboard(entries):
    for e in entries:
        print("#%d %s - %d" % [e.rank, e.nickname, e.score])
```

### ✅ Done!

**Total time: ~3 minutes**

You now have global leaderboards, score submission, and player nicknames.

> 📖 **Full API docs:** [API_QUICKSTART.md](API_QUICKSTART.md)

---

# 🌐 Web SDK Quick Start

**Full integration with login UI, Chedda ID, and optional Google/Apple OAuth.**

### Step 1: Register Game (2 min)

1. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
2. Sign in and register your game
3. Copy your **Game ID**
4. (Optional) Generate API key for anonymous play

### Step 2: Download Files (1 min)

From [GitHub](https://github.com/cheddatech/CheddaBoards-Godot), copy to your project:

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd
│       ├── Achievements.gd
│       └── SetupWizard.gd
└── template.html          ← Required for web!
```

### Step 3: Run Setup Wizard (30 sec)

```
File → Run (Ctrl+Shift+X) → Select SetupWizard.gd
```

The wizard will:
- ✅ Auto-add Autoloads
- ✅ Check required files
- ✅ Prompt for your Game ID

### Step 4: Configure Export (30 sec)

```
Project → Export → Web
Under HTML section:
  Custom HTML Shell: res://template.html
```

### Step 5: Export & Test (1 min)

1. Export as **`index.html`** (important!)
2. Run local server: `python3 -m http.server 8000`
3. Open `http://localhost:8000`
4. Test login and leaderboards!

### ✅ Done!

**Total time: ~5 minutes**

You now have:
- ✅ Chedda ID login (works out of box)
- ✅ Anonymous play
- ✅ Google/Apple login (requires your OAuth credentials)
- ✅ Achievements system
- ✅ Full leaderboard UI

---

## 🎮 Basic Usage

```gdscript
# Wait for SDK
await CheddaBoards.wait_until_ready()

# === LOGIN OPTIONS ===
CheddaBoards.login_anonymous("PlayerName")     # Works everywhere
CheddaBoards.login_internet_identity()         # Web only, works out of box
CheddaBoards.login_google()                    # Web only, needs your OAuth
CheddaBoards.login_apple()                     # Web only, needs your OAuth

# === SCORES ===
CheddaBoards.submit_score(1000, 5)  # score, streak

# === LEADERBOARD ===
CheddaBoards.leaderboard_loaded.connect(_on_leaderboard)
CheddaBoards.get_leaderboard("score", 100)

func _on_leaderboard(entries):
    for e in entries:
        print("#%d %s - %d" % [e.rank, e.nickname, e.score])

# === STATUS ===
if CheddaBoards.is_authenticated():
    print("Logged in as: ", CheddaBoards.get_nickname())
```

---

## 📊 Multiple Scoreboards (v1.3.0+)

Run weekly competitions alongside all-time high scores:

```gdscript
# Get specific scoreboard
CheddaBoards.get_scoreboard("weekly-scoreboard", 100)
CheddaBoards.get_scoreboard("all-time", 100)

# View last week's results
CheddaBoards.get_last_archived_scoreboard("weekly-scoreboard", 100)

CheddaBoards.archived_scoreboard_loaded.connect(_on_archive)

func _on_archive(archive_id, config, entries):
    if entries.size() > 0:
        print("Last week's winner: %s 👑" % entries[0].nickname)
```

> 📖 **Full guide:** [TIMED_SCOREBOARDS.md](TIMED_SCOREBOARDS.md)

---

## 🏆 Quick Achievements (Optional)

```gdscript
func _on_game_over(score, streak):
    Achievements.increment_games_played()
    Achievements.check_game_over(score, 0, streak)
    Achievements.submit_with_score(score, streak)
```

---

## 🐛 Debug Shortcuts

Press during development:

| Key | Action |
|-----|--------|
| F6 | Submit 5 random test scores |
| F7 | Submit 1 random test score |
| F8 | Force profile refresh |
| F9 | Debug status dump |

---

## ❓ Common Issues

| Issue | Solution |
|-------|----------|
| "API key not set" | Set `api_key` in CheddaBoards.gd |
| "CheddaBoards not found" | Add to Autoloads or run Setup Wizard |
| Blank screen (web) | Use `python3 -m http.server`, not file:// |
| "Engine not defined" (web) | Export must be named `index.html` |
| Clicks offset | Project Settings → Display → DPI → Allow Hidpi: On |

---

## 📚 More Documentation

| Doc | Description |
|-----|-------------|
| [API_QUICKSTART.md](API_QUICKSTART.md) | Full API reference |
| [TIMED_SCOREBOARDS.md](TIMED_SCOREBOARDS.md) | Weekly/daily competitions & archives |
| [SETUP.md](SETUP.md) | Detailed setup guide |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common problems & solutions |

---

## 🔗 Resources

- **Dashboard:** [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)
- **Example:** [cheddaclick.cheddagames.com](https://cheddaclick.cheddagames.com)

---

**Zero servers. Free tier forever. Any platform.** 🧀
