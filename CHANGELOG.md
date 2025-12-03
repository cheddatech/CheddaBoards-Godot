# Changelog

All notable changes to CheddaBoards Godot 4 Template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2025-12-03

### 🧙 Setup Wizard & Asset Library Release

New automated setup wizard and restructured for Godot Asset Library compatibility!

### Added

#### Setup Wizard (SetupWizard.gd v2.1)
- **One-command setup**: `File → Run → addons/cheddaboards/SetupWizard.gd`
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
│       ├── CheddaBoards.gd      ← Core SDK
│       ├── Achievements.gd      ← Achievement system
│       ├── SetupWizard.gd       ← NEW! Automated setup
│       ├── plugin.cfg           ← NEW! Asset Library metadata
│       └── icon.png             ← NEW! Plugin icon
├── template.html                ← Web export template (root)
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

### 🎉 Initial Release

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

## [Unreleased]

### Planned Features
- Desktop export support (when CheddaBoards adds native SDKs)
- Additional example achievements
- More customization options
- Video tutorial link
- Community templates

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| **v1.1.0** | 2025-12-03 | Setup Wizard v2.1, Asset Library structure, mainnet fix |
| **v1.0.0** | 2025-11-02 | Initial public release |

---

## Upgrade Guide

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

3. **Update autoload paths** in Project Settings → Autoload:
   ```
   CheddaBoards: res://addons/cheddaboards/CheddaBoards.gd
   Achievements: res://addons/cheddaboards/Achievements.gd
   ```

4. **Run the wizard:**
   ```
   File → Run → addons/cheddaboards/SetupWizard.gd
   ```

5. **Update export settings:**
   - Change Custom HTML Shell to `res://template.html`
   - Always export as `index.html`

### From Nothing to v1.1.0
1. Download/clone from GitHub
2. Copy `addons/cheddaboards/` folder to your project
3. Copy `template.html` to your project root
4. Run `File → Run → addons/cheddaboards/SetupWizard.gd`
5. Enter your Game ID in the popup
6. Export as `index.html` and test!

---

## Support

- **Documentation**: See README.md
- **GitHub**: https://github.com/cheddatech/CheddaBoards-Godot
- **CheddaBoards**: https://cheddaboards.com
- **Example Game**: https://thecheesegame.online
- **Contact**: info@cheddaboards.com

---

## Contributing

Found a bug? Have a feature request? 
- Open an issue on GitHub
- Submit a pull request
- Join the community discussion

---

**Thank you for using CheddaBoards!** 🧀🎮