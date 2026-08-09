# Web Export

Exporting a CheddaBoards game for the web has a few platform-specific requirements. Get these right and the same code that runs on desktop/mobile runs in the browser — anonymous play, device code auth, leaderboards, and achievements all work.

> Most projects need **only the steps in "Web export setup" below.** Device Code Auth works on web out of the box with zero configuration. The [Legacy direct OAuth](#legacy-direct-oauth-v1x) section at the end is only for older v1.x projects that used the in-browser Google/Apple buttons and the JavaScript bridge.

---

## Web export setup

**1. Set the HTML shell (optional).** Project → Export → Add → Web. Under the **HTML** section:

```
Custom HTML Shell:  res://template.html
```

This is **optional** in v2 — it just gives you the branded loading screen. Auth, scores, and leaderboards all run from GDScript over HTTP, so they work with Godot's default shell too. If you *do* use the included `template.html`, export as `index.html` (it loads `index.js`).

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
| Account upgrade (anon → verified) | ✅ | None |

Device Code Auth is the recommended path on web exactly as on every other platform — see [Device Code Login](device-code-login.md). No OAuth credentials, no browser popups, no platform branching.

**Sessions persist on web too (SDK v2.2.3+):** the session is saved to `user://`, which the browser keeps in IndexedDB, so players sign in once per site. Two environments can't hold it: Safari blocks storage inside third-party iframes, and itch.io serves each new upload from a new path, orphaning the previous upload's storage — so itch players re-auth once per build you push. Details: [Troubleshooting](../TROUBLESHOOTING.md).

---

## The exit button on web

`get_tree().quit()` does nothing useful in a browser — it just freezes the canvas. The right move is to navigate somewhere, and *how* depends on whether your game is embedded in an iframe (itch.io serves web games inside one).

**Template (v2.1.7+): it's a setting, not code.** Select the `MainMenu` node and set **Web Exit Url** in the Inspector to your game's website or itch page:

- **Empty (the default):** all Exit buttons are hidden on web builds — no dead-end button
- **Set, running full-window:** Exit does a same-tab redirect to the URL
- **Set, running in an iframe (itch.io):** Exit opens the URL in a **new tab**, leaving the host page intact — a same-tab redirect would load your whole website inside the game embed. If a popup blocker eats the new tab, the button shows the URL instead

Native builds always show Exit and quit normally, whatever the setting.

**Drop-in SDK: roll the same logic yourself.** The iframe check matters — don't blind-redirect:

```gdscript
func _on_exit_pressed():
    if OS.has_feature("web"):
        var in_iframe = JavaScriptBridge.eval("window.self !== window.top", true)
        if in_iframe:
            # itch.io etc. - new tab keeps the host page intact
            JavaScriptBridge.eval("window.open('https://yourdomain.com', '_blank')", true)
        else:
            JavaScriptBridge.eval("window.location.href = 'https://yourdomain.com'", true)
        return
    get_tree().quit()
```

---

## template.html

In v2, `template.html` is **just** the loading screen plus the Godot engine bootstrap — no SDK, no OAuth scripts, no JavaScript bridge. Authentication and scores run from GDScript over the HTTP API, so the shell carries none of that.

If your `template.html` has a large `CONFIG` block, a `cheddaboards_v1` CDN `<script>`, or `window.chedda_*` bridge functions, you're on the **old v1.x shell** — replace it with the lean v2 one.

---

## Web setup checklist

- [ ] *(Optional)* Custom HTML Shell set to `res://template.html` for the branded loader
- [ ] Exported as `index.html`
- [ ] Served over HTTP (not `file://`)
- [ ] `web_exit_url` set on MainMenu (or deliberately left empty to hide Exit on web); drop-in projects use the iframe-aware redirect above
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
