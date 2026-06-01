# Web Export

Exporting a CheddaBoards game for the web has a few platform-specific requirements. Get these right and the same code that runs on desktop/mobile runs in the browser — anonymous play, device code auth, leaderboards, and achievements all work.

> Most projects need **only the steps in "Web export setup" below.** Device Code Auth works on web out of the box with zero configuration. The [Legacy direct OAuth](#legacy-direct-oauth-v1x) section at the end is only for older v1.x projects that used the in-browser Google/Apple buttons and the JavaScript bridge.

---

## Web export setup

**1. Set the HTML shell.** Project → Export → Add → Web. Under the **HTML** section:

```
Custom HTML Shell:  res://template.html
```

This is required — without it, authentication won't work on web.

**2. Export as `index.html`.** Project → Export → Web → Export Project, and save it as **`index.html`** — not `MyGame.html`. Other filenames break relative paths and auth redirects, and produce the "Engine not defined" error.

**3. Serve over HTTP, not `file://`.** Web builds won't run from a local file path. Use any static server:

```bash
python3 -m http.server 8000     # Python
npx serve .                     # Node
```

Then open `http://localhost:8000`.

That's the whole web checklist. Everything below is optional or legacy.

---

## Web authentication

Web builds support every auth method the rest of the SDK does:

| Method | Status | Setup |
|--------|--------|-------|
| Anonymous | ✅ | Just the API key |
| Google (Device Code) | ✅ | None — built in |
| Apple (Device Code) | ✅ | None — built in |
| Internet Identity (Device Code) | ✅ | None — built in |
| Account upgrade (anon → verified) | ✅ | None |

Device Code Auth is the recommended path on web exactly as on every other platform — see [Device Code Login](device-code-login.md). No OAuth credentials, no browser popups, no platform branching.

---

## The exit button on web

`get_tree().quit()` does nothing in a browser. Redirect instead:

```gdscript
func _on_exit_pressed():
    if OS.get_name() == "Web":
        JavaScriptBridge.eval("window.location.href = 'https://yourdomain.com'")
    else:
        get_tree().quit()
```

---

## template.html

`template.html` is your web export shell. It handles the loading screen/preloader and, for legacy projects, the OAuth button integration and JS bridge. The Setup Wizard configures it automatically; to edit by hand, look for the `CONFIG` block near the top of the file.

---

## Web setup checklist

- [ ] Custom HTML Shell set to `res://template.html`
- [ ] Exported as `index.html`
- [ ] Served over HTTP (not `file://`)
- [ ] Exit button redirects instead of `quit()` on web
- [ ] Login + leaderboards tested in the browser

---

## Legacy: direct OAuth (v1.x)

> **You almost certainly don't need this.** As of SDK v2.0.0 every platform uses HTTP + Device Code Auth, and the JavaScript bridge was removed. Direct in-browser Google/Apple buttons are retained only for older builds still on the v1.x bridge. New projects should use device code auth throughout.

If you're maintaining a v1.x project, direct OAuth requires your own provider credentials, entered via the Setup Wizard or by hand in `template.html`:

```javascript
GOOGLE_CLIENT_ID: 'xxxxx.apps.googleusercontent.com',
APPLE_SERVICE_ID: 'com.yourdomain.yourapp',
APPLE_REDIRECT_URI: 'https://yourdomain.com/auth/apple'
```

- **Google:** create an OAuth 2.0 client at [console.cloud.google.com](https://console.cloud.google.com) and add your domain to authorized origins.
- **Apple:** register a Services ID with Sign In with Apple at [developer.apple.com](https://developer.apple.com) and configure the redirect URI.

---

**See also:** [Setup & Platforms](../SETUP.md) · [Device Code Login](device-code-login.md) · [Troubleshooting](../TROUBLESHOOTING.md) · [docs index](../README.md)
