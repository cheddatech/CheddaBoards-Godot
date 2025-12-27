# Changelog

All notable changes to CheddaBoards Godot 4 SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.2] - 2025-12-27

### Fixed

- Default nickname now generates unique "Player_abc123" instead of generic "Player" to prevent duplicate leaderboard entries

---

## [1.2.1] - 2025-12-18

### Native Platform Support & HTTP API

**CheddaBoards now works on ALL platforms!** Windows, Mac, Linux, Mobile, and Web - same codebase, same API.

### Added

#### Native HTTP API Mode
- **Full REST API support**: Native builds use HTTP API instead of JavaScript bridge
- **Platform auto-detection**: SDK automatically uses correct mode (Web = JS bridge, Native = HTTP)
- **API key authentication**: Secure API key for native/anonymous builds
- **Request queuing**: Multiple requests handled gracefully, no more race conditions

#### New CheddaBoards.gd Functions
- `set_api_key(key)` - Set API key for HTTP authentication
- `get_player_id()` - Get sanitized device/player ID
- `set_player_id(id)` - Set custom player ID
- `setup_anonymous_player(id, nickname)` - Configure anonymous player without signals
- `get_player_profile(player_id)` - Fetch player profile via HTTP
- `health_check()` - Verify API connection
- `get_game_info()` - Get game metadata
- `get_game_stats()` - Get game statistics

#### API Endpoints Supported
- `POST /scores` - Submit score
- `GET /leaderboard` - Get leaderboard
- `GET /players/{id}/profile` - Get player profile
- `GET /players/{id}/rank` - Get player rank
- `PUT /players/{id}/nickname` - Change nickname
- `POST /achievements` - Unlock achievement
- `GET /players/{id}/achievements` - Get achievements
- `GET /health` - Health check

#### New Signals
- `request_failed(endpoint, error)` - HTTP request failure notification

### Changed

#### Hybrid Architecture
- **Web exports**: Continue using JavaScript bridge for full ICP authentication
- **Native exports**: Use HTTP API with API key authentication
- **Anonymous play**: Works on BOTH web and native via HTTP API
- Same GDScript code works on all platforms - SDK handles the difference

#### CheddaBoards.gd Improvements
- `is_authenticated()` - Now checks API key for native builds
- `submit_score()` - Routes to HTTP or JS based on platform
- `get_leaderboard()` - Works on native via HTTP API
- `login_anonymous()` - Uses HTTP API on all platforms for consistency
- Player ID sanitization (alphanumeric, underscore, hyphen only, max 100 chars)

#### Documentation
- README completely rewritten for multi-platform support
- Added Native Export section
- Added Platform Modes comparison table
- Added API Key configuration guide
- High-DPI display fix documented

### Fixed

#### High-DPI Display Support
- Click/input offset on scaled displays (125%, 150%, etc.)
- Add to Project Settings: Display → Window → DPI → Allow Hidpi: On

#### HTTP Request Handling
- Request queue prevents "HTTP busy" errors
- Proper error propagation to correct signals
- Timeout handling for failed requests

#### Player ID Issues
- OS.get_unique_id() sanitization (removes invalid characters)
- Fallback ID generation if device ID unavailable
- Ensures ID starts with letter (API requirement)

### Technical Details

**API Base URL**: `https://api.cheddaboards.com`
**API Key Format**: `cb_yourgame_xxxxxxxxx`
**Player ID Format**: 1-100 characters, alphanumeric + underscore + hyphen

### Migration from v1.2.0

1. **Update CheddaBoards.gd** - Replace with new version

2. **Set API Key** (for native builds):
   ```gdscript
   # In CheddaBoards.gd
   var api_key: String = "cb_your_api_key_here"
   
   # Or at runtime
   CheddaBoards.set_api_key("cb_your_api_key_here")
   ```

3. **High-DPI fix** (if experiencing click offset):
   - Project Settings → Display → Window → DPI → Allow Hidpi: On

4. **No changes needed** for web-only games - fully backward compatible

---

## [1.2.0] - 2025-12-15

### Anonymous Play & Device ID Support

Play and save scores without requiring login! Perfect for casual players who want to jump straight into the game.

### Added

#### Anonymous Play System
- **Device ID authentication**: Unique device identifier generated and stored in localStorage
- **Play without login**: Users can click "PLAY NOW" and scores still save
- **Auto-anonymous login**: MainMenu automatically creates anonymous session on direct play
- **Local score storage**: Fallback for anonymous users if backend unavailable
- **Seamless upgrade path**: Anonymous users can later login to sync to real account

#### New CheddaBoards.gd Functions
- `login_anonymous()` - Create anonymous session with device ID
- `is_anonymous()` - Check if using device/anonymous authentication
- `get_device_id()` - Get the unique device identifier

#### Template Configuration
- `CONFIG.ALLOW_ANONYMOUS_PLAY` - Enable/disable anonymous play (default: true)
- `chedda_login_anonymous()` - JavaScript bridge for anonymous login
- `chedda_get_device_id()` - Get device ID from JavaScript

### Changed

#### Authentication Flow
- `is_authenticated()` now returns `true` for anonymous/device users
- `chedda_is_auth()` checks both SDK auth and device ID
- Score submission works for both authenticated and anonymous users
- Leaderboard viewing no longer requires authentication

#### MainMenu.gd
- "PLAY NOW" button now auto-calls `login_anonymous()` before starting game
- Anonymous users get temporary nickname like "Player_abc123"

#### Game.gd
- Simplified game over logic - always tries to submit if SDK ready
- Handles both authenticated and anonymous score submission
- Better logging for auth type during submission

#### template.html
- Added device ID generation using crypto API
- Anonymous profile creation and caching
- Score submission fallback for anonymous users
- Achievement storage for anonymous users (local only)

### Fixed

- Double authentication check blocking anonymous score submission
- Score submission failing silently when not logged in
- Leaderboard requiring auth just to view

### Technical Details

**Device ID Format**: `dev_` + 32 hex characters (128-bit random)
**Storage Key**: `cheddaboards_device_{GAME_ID}`
**Anonymous Profile**: Stored in localStorage, persists across sessions

### Important Notes

- Anonymous scores are stored locally as fallback
- To sync anonymous progress to account: login after playing
- Device ID persists even after logout (for future anonymous play)
- Anonymous users appear on leaderboard with auto-generated nicknames

---

## [1.1.0] - 2025-12-03

### Setup Wizard & Asset Library Release

New automated setup wizard and restructured for Godot Asset Library compatibility!

### Added

#### Setup Wizard (SetupWizard.gd v2.1)
- **One-command setup**: `File > Run > addons/cheddaboards/SetupWizard.gd`
- **Auto-fix autoloads**: Automatically adds CheddaBoards & Achievements if missing
- **Interactive Game ID popup**: Configure your Game ID without editing files
- **Comprehensive validation**: Checks Godot version, files, settings, export config
- **Summary report**: Clear overview of issues, warnings, and auto-fixes applied
- **Utility functions** for other scripts:
  - `get_project_status()` - Get full project health check
  - `is_ready_to_export()` - Quick export readiness check
  - `fix_autoloads()` - Programmatically fix missing autoloads

#### Asset Library Support
- `plugin.cfg` for Godot Asset Library submission
- Proper `addons/cheddaboards/` folder structure
- `icon.png` (256x256) for plugin branding
- MIT LICENSE file

#### Quality of Life
- Game ID validation (alphanumeric, hyphens, underscores only)
- Default Game ID detection with clear warnings
- Export preset verification
- Project settings checks (stretch mode, main scene)

### Changed

#### File Structure (Asset Library Compatible)
```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd      <- Core SDK
│       ├── Achievements.gd      <- Achievement system
│       ├── SetupWizard.gd       <- NEW! Automated setup
│       ├── plugin.cfg           <- NEW! Asset Library metadata
│       └── icon.png             <- NEW! Plugin icon
├── template.html                <- Web export template (root)
├── docs/
│   ├── QUICKSTART.md
│   ├── SETUP.md
│   ├── TROUBLESHOOTING.md
│   └── CHANGELOG.md
├── README.md
├── LICENSE
├── .gitignore
└── project.godot
```

#### Template Updates
- Renamed to `template.html` (from `cheddaboards-template.html`)
- Added `host: 'https://icp-api.io'` to force mainnet connection
- Fixed localhost detection issue for local testing

#### Documentation Overhaul
- **QUICKSTART.md**: Reduced from 10 minutes to 5 minutes with wizard
- **README.md**: Added full "Setup Wizard Reference" section
- **SETUP.md**: Step 3 now "Run the Setup Wizard" with visual guides
- **TROUBLESHOOTING.md**: "Run the wizard first!" as primary solution
- All docs emphasize exporting as `index.html` (required!)

### Fixed
- SDK leaderboard parsing for single-entry edge case
- Localhost detection now properly connects to mainnet
- Consistent file naming across all documentation
- Clearer error messages for common setup issues

### Important Notes
- **Export as `index.html`**: Template expects `index.js` - other names cause errors!
- **Use web server**: `python3 -m http.server 8000` (never open file:// directly)

---

## [1.0.0] - 2025-11-02

### Initial Release

First public release of the CheddaBoards Godot 4 Template.

### Added

#### Core Features
- Complete CheddaBoards SDK integration (CheddaBoards.gd autoload)
- Achievement system with backend-first architecture (Achievements.gd autoload)
- Authentication with Google, Apple, and Internet Identity (passwordless)
- Global leaderboards with score/streak sorting
- Achievement view with progress tracking
- Animated notification popups for achievement unlocks
- Persistent player profiles across devices

#### Setup Tools
- One-click setup wizard (CheddaBoardsSetup.gd)
- Visual config plugin for easy Game ID configuration
- Automatic verification of project setup
- In-editor configuration dock
- Testing shortcut: Press Ctrl+Shift+C to clear cached achievements for easy testing

#### Scenes & UI
- MainMenu scene with authentication
- Game scene with test button (replace with your game)
- GameOver panel with score submission
- Leaderboard display with player rankings
- AchievementsView with all achievements
- AchievementNotification popup system

#### Documentation
- Comprehensive README with integration examples
- QUICKSTART guide (5-minute setup)
- Detailed SETUP guide with troubleshooting
- Complete TROUBLESHOOTING flowchart

#### Developer Experience
- Pre-configured autoloads
- 9 example achievements (customizable)
- Working test button for quick verification
- Clear code comments and structure
- Copy-paste integration examples

### Technical Details

- **Godot Version**: 4.0+ compatible
- **Export**: HTML5/Web
- **License**: MIT
- **Cost**: 100% free forever
- **Backend**: CheddaBoards (serverless, zero maintenance)

### Known Limitations

- HTML5 export only (Unity support coming to CheddaBoards)
- Requires web server for testing (no file:// protocol)
- HTTPS required for OAuth in production

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| **v1.2.2** | 2025-12-27 | Unique default nicknames fix |
| **v1.2.1** | 2025-12-18 | Native platform support, HTTP REST API, API key auth |
| **v1.2.0** | 2025-12-15 | Anonymous play with device ID, play without login |
| **v1.1.0** | 2025-12-03 | Setup Wizard v2.1, Asset Library structure, mainnet fix |
| **v1.0.0** | 2025-11-02 | Initial public release |

---

## Upgrade Guide

### From v1.2.1 to v1.2.2

1. **Update CheddaBoards.gd** - Replace with new version
2. No other changes required - existing "Player" names will now show as unique IDs

### From v1.2.0 to v1.2.1

1. **Update CheddaBoards.gd** - Replace with new version (adds HTTP API support)

2. **For Native builds, set API key**:
   ```gdscript
   # Option A: In CheddaBoards.gd directly
   var api_key: String = "cb_your_api_key_here"
   
   # Option B: At runtime
   func _ready():
       CheddaBoards.set_api_key("cb_your_api_key_here")
   ```

3. **Fix high-DPI click offset** (if affected):
   - Project Settings → Display → Window → DPI → Allow Hidpi: `On`

4. **Web builds**: No changes required - fully backward compatible

5. **Exit button for web** (optional):
   ```gdscript
   func _on_exit_pressed():
       if OS.get_name() == "Web":
           JavaScriptBridge.eval("window.location.href = 'https://yourdomain.com'")
       else:
           get_tree().quit()
   ```

### From v1.1.0 to v1.2.0

1. **Update these files:**
   - `addons/cheddaboards/CheddaBoards.gd` (new anonymous functions)
   - `template.html` (device ID support)
   - Your `MainMenu.gd` (if using direct play button)

2. **Optional: Enable/disable anonymous play** in template.html:
   ```javascript
   CONFIG.ALLOW_ANONYMOUS_PLAY: true,  // or false to require login
   ```

3. **Update MainMenu direct play** to auto-login anonymously:
   ```gdscript
   func _on_direct_play_button_pressed():
       if not CheddaBoards.is_authenticated():
           CheddaBoards.login_anonymous()
       get_tree().change_scene_to_file("res://scenes/game.tscn")
   ```

4. **No changes needed** to:
   - Achievements.gd (works as-is)
   - GameOver.gd (works as-is)

### From v1.0.0 to v1.1.0

1. **Restructure to addons/ folder:**
   ```
   mkdir -p addons/cheddaboards
   mv CheddaBoards.gd addons/cheddaboards/
   mv Achievements.gd addons/cheddaboards/
   ```

2. **Download new files:**
   - `addons/cheddaboards/SetupWizard.gd` (new!)
   - `addons/cheddaboards/plugin.cfg` (new!)
   - `addons/cheddaboards/icon.png` (new!)
   - Updated `template.html` (renamed, with mainnet fix)

3. **Update autoload paths** in Project Settings > Autoload:
   ```
   CheddaBoards: res://addons/cheddaboards/CheddaBoards.gd
   Achievements: res://addons/cheddaboards/Achievements.gd
   ```

4. **Run the wizard:**
   ```
   File > Run > addons/cheddaboards/SetupWizard.gd
   ```

5. **Update export settings:**
   - Change Custom HTML Shell to `res://template.html`
   - Always export as `index.html`

### From Nothing to v1.2.2

1. Download/clone from GitHub
2. Copy `addons/cheddaboards/` folder to your project
3. Copy `template.html` to your project root (web only)
4. Run `File > Run > addons/cheddaboards/SetupWizard.gd`
5. Enter your Game ID in the popup
6. **For native**: Set API key in CheddaBoards.gd
7. **For web**: Export as `index.html` and test!
8. Users can play immediately on any platform!

---

## Roadmap

### Planned Features
- [ ] Unity SDK
- [ ] Unreal Plugin
- [ ] Full REST API documentation (OpenAPI/Swagger)
- [ ] Self-hosting option
- [ ] Analytics dashboard
- [ ] Tournament/competition mode
- [ ] Friend leaderboards
- [ ] Video tutorials

---

## Support

- **Documentation**: See README.md
- **GitHub**: https://github.com/cheddatech/CheddaBoards-Godot
- **CheddaBoards**: https://cheddaboards.com
- **Example Games**: 
  - https://thecheesegame.online (Web)
  - https://cheddaclick.cheddagames.com (Web + Native)
- **Contact**: info@cheddaboards.com

---

## Contributing

Found a bug? Have a feature request? 
- Open an issue on GitHub
- Submit a pull request
- Join the community discussion

---

**Thank you for using CheddaBoards!** 🧀

*Zero servers. $0 for indie devs. Any platform.*
