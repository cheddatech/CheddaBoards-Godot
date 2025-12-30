# Timed Scoreboards & Archives

**Run weekly competitions, daily challenges, and view past winners.**

---

## Overview

CheddaBoards supports time-based scoreboards that automatically reset and archive results:

| Type | Resets | Archives Kept | Use Case |
|------|--------|---------------|----------|
| **All-Time** | Never | None | Career high scores |
| **Weekly** | Every Monday | 52 (1 year) | Weekly competitions |
| **Daily** | Every midnight | 52 | Daily challenges |
| **Monthly** | 1st of month | 52 | Monthly tournaments |

---

## Setup in Dashboard

1. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
2. Select your game → **Scoreboards**
3. Click **Add Scoreboard**
4. Configure:

| Field | Example | Description |
|-------|---------|-------------|
| ID | `weekly-scoreboard` | Unique identifier |
| Name | `Weekly Challenge` | Display name |
| Reset Period | `Weekly` | When to archive & reset |
| Sort By | `Score (High to Low)` | Ranking method |

---

## Basic Usage

### Submit to Multiple Scoreboards

Scores automatically go to the default scoreboard. For multiple:

```gdscript
# Submit to specific scoreboard
CheddaBoards.submit_score_to_scoreboard("weekly-scoreboard", score, streak)

# Or submit once, backend routes to all applicable scoreboards
CheddaBoards.submit_score(score, streak)
```

### Get Current Standings

```gdscript
# Weekly leaderboard
CheddaBoards.get_scoreboard("weekly-scoreboard", 100)

# All-time leaderboard  
CheddaBoards.get_scoreboard("all-time", 100)

# Handle response
CheddaBoards.scoreboard_loaded.connect(_on_scoreboard_loaded)

func _on_scoreboard_loaded(scoreboard_id: String, config: Dictionary, entries: Array):
    print("Loaded %s with %d entries" % [scoreboard_id, entries.size()])
    for entry in entries:
        print("#%d %s: %d pts" % [entry.rank, entry.nickname, entry.score])
```

---

## Viewing Archives

When a timed scoreboard resets, the previous period is archived.

### Get Last Period's Results

```gdscript
# Last week's winners
CheddaBoards.get_last_archived_scoreboard("weekly-scoreboard", 100)

# Handle response
CheddaBoards.archived_scoreboard_loaded.connect(_on_archive_loaded)

func _on_archive_loaded(archive_id: String, config: Dictionary, entries: Array):
    var winner = entries[0] if entries.size() > 0 else null
    if winner:
        print("Last week's champion: %s with %d pts!" % [winner.nickname, winner.score])
    
    # Config contains period info
    print("Period: %s to %s" % [config.periodStart, config.periodEnd])
```

### Convenience Functions

```gdscript
# Quick access to common archives
CheddaBoards.get_last_week_scoreboard()      # Weekly → last week
CheddaBoards.get_last_month_scoreboard()     # Monthly → last month  
CheddaBoards.get_yesterday_scoreboard()      # Daily → yesterday
```

### List All Archives

```gdscript
# Get list of all archived periods
CheddaBoards.get_scoreboard_archives("weekly-scoreboard")

CheddaBoards.archives_list_loaded.connect(_on_archives_list)

func _on_archives_list(scoreboard_id: String, archives: Array):
    print("Found %d archived weeks" % archives.size())
    for archive in archives:
        print("- %s: %s to %s" % [archive.id, archive.periodStart, archive.periodEnd])
```

### Get Specific Archive

```gdscript
# Archive ID format: "gameId:scoreboardId:timestamp"
CheddaBoards.get_archived_scoreboard("my-game:weekly-scoreboard:1703980800000000000", 100)
```

---

## Leaderboard UI

The included `Leaderboard.tscn` supports both time periods and archives:

### Scene Structure

```
Leaderboard
├── TimeContainer          # All Time / Weekly toggle
│   ├── AllTimeButton
│   └── WeeklyButton
├── PeriodContainer        # Current / Last Period toggle
│   ├── CurrentButton
│   └── LastPeriodButton   # Shows "Last Week", "Yesterday", etc.
└── LeaderboardList
```

### Configuration

In `Leaderboard.gd`, set your scoreboard IDs:

```gdscript
const SCOREBOARD_ALL_TIME: String = "all-time"      # Your all-time ID
const SCOREBOARD_WEEKLY: String = "weekly-scoreboard"  # Your weekly ID
```

### Features

- **Time toggle**: Switch between All Time and Weekly views
- **Archive toggle**: View current or last period (auto-hides for All Time)
- **Winner highlight**: Gold background + 👑 for #1 in archives
- **Date display**: Shows period dates when viewing archives

---

## Archive Display Examples

### Show Last Week's Winner

```gdscript
func _show_last_weeks_winner():
    CheddaBoards.archived_scoreboard_loaded.connect(_on_winner_loaded)
    CheddaBoards.get_last_archived_scoreboard("weekly-scoreboard", 1)

func _on_winner_loaded(archive_id: String, config: Dictionary, entries: Array):
    if entries.size() > 0:
        var winner = entries[0]
        winner_label.text = "Last Week's Champion: %s 👑" % winner.nickname
        winner_score.text = "%d pts" % winner.score
```

### Hall of Fame (Multiple Archives)

```gdscript
func _load_hall_of_fame():
    CheddaBoards.archives_list_loaded.connect(_on_archives_for_hall)
    CheddaBoards.get_scoreboard_archives("weekly-scoreboard")

func _on_archives_for_hall(scoreboard_id: String, archives: Array):
    # Load winner from each archive
    for archive in archives.slice(0, 10):  # Last 10 weeks
        CheddaBoards.get_archived_scoreboard(archive.id, 1)
```

---

## Signals Reference

| Signal | Parameters | Description |
|--------|------------|-------------|
| `scoreboard_loaded` | id, config, entries | Current scoreboard data |
| `archives_list_loaded` | scoreboard_id, archives | List of available archives |
| `archived_scoreboard_loaded` | archive_id, config, entries | Archive leaderboard data |
| `archive_stats_loaded` | total, by_scoreboard | Archive statistics |
| `archive_error` | reason | Archive operation failed |

---

## Config Dictionary

When loading scoreboards/archives, the `config` dictionary contains:

```gdscript
{
    "name": "Weekly Challenge",       # Display name
    "scoreboardId": "weekly-scoreboard",
    "resetPeriod": "weekly",          # daily, weekly, monthly, never
    "sortBy": "score",                # score or streak
    "sortDirection": "desc",          # desc (high first) or asc
    "periodStart": 1703548800000000000,  # Nanosecond timestamp
    "periodEnd": 1704153600000000000,
}
```

### Format Timestamps

```gdscript
func _format_timestamp(timestamp_ns: int) -> String:
    if timestamp_ns == 0:
        return ""
    var timestamp_s = timestamp_ns / 1_000_000_000
    var datetime = Time.get_datetime_dict_from_unix_time(timestamp_s)
    return "%d/%d/%d" % [datetime.day, datetime.month, datetime.year]
```

---

## Best Practices

### 1. Always Have an All-Time Board

Players want to see their career bests, not just weekly scores.

### 2. Show Both Current and Archive

Let players see "This Week" and "Last Week" easily.

### 3. Celebrate Winners

Highlight past champions with special UI (gold, crown emoji, etc.)

### 4. Handle Empty Archives

New scoreboards won't have archives yet:

```gdscript
func _on_archive_loaded(archive_id, config, entries):
    if entries.is_empty():
        status_label.text = "No archived data yet"
        return
    # ... display entries
```

### 5. Cache Archive Data

Archives don't change - cache them locally:

```gdscript
var archive_cache: Dictionary = {}

func _on_archive_loaded(archive_id, config, entries):
    archive_cache[archive_id] = {"config": config, "entries": entries}
```

---

## HTTP API Endpoints

For custom integrations:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/games/:gameId/scoreboards/:id/archives` | GET | List archives |
| `/games/:gameId/scoreboards/:id/archives/latest` | GET | Most recent archive |
| `/archives/:archiveId` | GET | Specific archive |
| `/games/:gameId/archives/stats` | GET | Archive statistics |

### Example Request

```bash
curl "https://api.cheddaboards.com/games/my-game/scoreboards/weekly/archives/latest?limit=10" \
  -H "X-API-Key: cb_your_api_key"
```

---

## Technical Details

| Setting | Value |
|---------|-------|
| Max archives per scoreboard | 52 |
| Archive retention | ~1 year |
| Archive ID format | `gameId:scoreboardId:timestamp` |
| Timestamp format | Nanoseconds (ICP standard) |

---

## Migration from v1.2.x

If upgrading from an older version:

1. **Update CheddaBoards.gd** to v1.3.0+
2. **Update Leaderboard.gd** to v1.4.0+
3. **Update Leaderboard.tscn** with new button containers
4. **Set scoreboard IDs** in Leaderboard.gd constants

Existing scores and scoreboards are unaffected.

---

## Links

- **Dashboard:** [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
- **API Quickstart:** [API_QUICKSTART.md](API_QUICKSTART.md)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)

---

**Weekly competitions. Automatic archives. Zero maintenance.** 🧀
