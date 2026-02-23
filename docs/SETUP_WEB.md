# CheddaBoards Web Setup Guide

**Full web integration with login UI, achievements, OAuth, and account upgrade.**

> **SDK Version:** 1.9.0 | [Changelog](CHANGELOG.md)

> Looking for the native/API setup? See [SETUP.md](SETUP.md)

---

## Prerequisites

- [ ] Godot 4.x installed (tested on 4.3+)
- [ ] CheddaBoards account ([cheddaboards.com](https://cheddaboards.com))
- [ ] Game registered on dashboard
- [ ] API Key generated
- [ ] Full template downloaded from [GitHub](https://github.com/cheddatech/CheddaBoards-Godot)

---

## Web SDK Setup

### 1. Register Game

1. Go to [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
2. Sign in with Google or Apple
3. Click **"Register New Game"**
4. Fill in:
   - **Game ID:** `my-game` (lowercase, hyphens only)
   - **Name:** My Awesome Game
   - **Description:** Brief description
5. Click **"Register"**
6. Click **"Generate API Key"**
7. Copy the key: `cb_my-game_xxxxxxxxx`

You'll need:
- **Game ID** (for template.html and CheddaBoards.gd)
- **API Key** (for anonymous play)

### 2. Download Files

From [GitHub](https://github.com/cheddatech/CheddaBoards-Godot), copy the full template to your project.

### 3. Run Setup Wizard

**File → Run** (or Ctrl+Shift+X) → Select `SetupWizard.gd`

The wizard will:
- Auto-add CheddaBoards, Achievements, and MobileUI to Autoloads
- Check all required files exist
- Prompt you to enter your Game ID (syncs to both files)
- Prompt you to enter your API Key
- Configure Google/Apple OAuth credentials
- Validate your export settings

### 4. Configure Web Export

**Project → Export → Add → Web**

Under **HTML** section:
- **Custom HTML Shell:** `res://template.html`

> This is required! Without it, authentication won't work on web.

### 5. Export & Test

1. **Project → Export → Web**
2. Click **Export Project**
3. **Save as `index.html`** (not MyGame.html!)
4. Open terminal in export folder:
   ```bash
   python3 -m http.server 8000
   ```
5. Open `http://localhost:8000`
6. Test login and leaderboards!

---

## Web Authentication

Web builds support all authentication methods — anonymous, device code, direct OAuth, and account upgrade.

| Method | Status | Setup |
|--------|--------|-------|
| **Anonymous** | ✅ Working | Just API key |
| **Google (Device Code)** | ✅ Working | None — built in |
| **Apple (Device Code)** | ✅ Working | None — built in |
| **Google (Direct OAuth)** | ✅ Working | Your OAuth credentials |
| **Apple (Direct OAuth)** | ✅ Working | Your OAuth credentials |
| **Account Upgrade** | ✅ Working | None (anon → Google/Apple) |

### Direct OAuth Setup (Optional)

Device Code Auth works out of the box with no setup. Direct OAuth buttons give web players a more streamlined experience but require your own credentials.

#### Google OAuth

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create project → Enable Google Sign-In API
3. Create OAuth 2.0 credentials
4. Add your domain to authorized origins
5. Run Setup Wizard and enter your Client ID, or manually add to `template.html`:

```javascript
GOOGLE_CLIENT_ID: 'xxxxx.apps.googleusercontent.com',
```

#### Apple Sign-In

1. Go to [developer.apple.com](https://developer.apple.com)
2. Register App ID with Sign In with Apple
3. Create Services ID
4. Configure domain and redirect URI
5. Run Setup Wizard and enter your credentials, or manually add to `template.html`:

```javascript
APPLE_SERVICE_ID: 'com.yourdomain.yourapp',
APPLE_REDIRECT_URI: 'https://yourdomain.com/auth/apple'
```

### Account Upgrade

Anonymous web players can link their account to Google or Apple from the Anonymous Dashboard. This preserves all scores and achievements while enabling cross-device sync.

---

## Web-Specific Configuration

### Custom HTML Template

The `template.html` file is your web export shell. It handles:
- Google and Apple Sign-In button integration
- JavaScript bridge between the browser and Godot
- Loading screen and preloader
- OAuth redirect handling

The Setup Wizard configures `template.html` automatically. To edit manually, look for the CONFIG section near the top of the file.

### Exit Button (Web)

On web, `get_tree().quit()` doesn't work. Redirect instead:

```gdscript
func _on_exit_pressed():
    if OS.get_name() == "Web":
        JavaScriptBridge.eval("window.location.href = 'https://yourdomain.com'")
    else:
        get_tree().quit()
```

### Web Export Filename

Always export as `index.html`. Other filenames can cause issues with relative paths and authentication redirects.

### Local Testing

Web builds won't work from `file://` URLs. Always use a local server:

```bash
# Python
python3 -m http.server 8000

# Node
npx serve .
```

Then open `http://localhost:8000`.

---

## Web Project Structure

```
YourGame/
├── addons/
│   └── cheddaboards/
│       ├── CheddaBoards.gd       ← Autoload
│       ├── SetupWizard.gd
│       ├── cheddaboards_logo.png
│       └── icon.png
├── autoloads/
│   ├── Achievements.gd           ← Autoload
│   └── MobileUI.gd               ← Autoload
├── scenes/
│   ├── Game.tscn
│   ├── MainMenu.tscn
│   ├── Leaderboard.tscn
│   ├── AchievementsView.tscn
│   ├── AchievementNotification.tscn
│   └── DeviceCodeLogin.tscn
├── scripts/
│   ├── Game.gd
│   ├── MainMenu.gd
│   ├── Leaderboard.gd
│   ├── AchievementsView.gd
│   ├── AchievementNotification.gd
│   └── DeviceCodeLogin.gd
├── example_game/
│   ├── CheddaClickGame.tscn
│   ├── CheddaClickGame.gd
│   └── cheese.png
├── template.html                 ← Required for web export
└── project.godot
```

---

## Web Setup Checklist

- [ ] Game registered on dashboard
- [ ] All files copied to project
- [ ] Setup Wizard run successfully
- [ ] Game ID set in both template.html and CheddaBoards.gd
- [ ] Custom HTML Shell set to `res://template.html` in export settings
- [ ] Exported as `index.html`
- [ ] Tested with local web server (not `file://`)
- [ ] (Optional) Google OAuth credentials configured
- [ ] (Optional) Apple Sign-In credentials configured

---

## More Documentation

| Doc | Description |
|-----|-------------|
| [SETUP.md](SETUP.md) | Native/API setup guide |
| [QUICKSTART.md](QUICKSTART.md) | Fast setup guide |
| [API_QUICKSTART.md](API_QUICKSTART.md) | Full API reference |
| [TIMED_LEADERBOARDS.md](TIMED_LEADERBOARDS.md) | Weekly/daily competitions |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common problems & solutions |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## Resources

- **Dashboard:** [cheddaboards.com/dashboard](https://cheddaboards.com/dashboard)
- **GitHub:** [github.com/cheddatech/CheddaBoards-Godot](https://github.com/cheddatech/CheddaBoards-Godot)

---

**Need help?** info@cheddaboards.com
