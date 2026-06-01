# Authentication

CheddaBoards supports three levels of identity, all cross-platform: **anonymous play**, **Device Code Auth** (Google / Apple / Internet Identity on any platform), and **account upgrade** (turn an anonymous player into a verified one without losing progress).

| Method | Native | Mobile | Web | Status |
|--------|--------|--------|-----|--------|
| Anonymous / Device ID | ✅ | ✅ | ✅ | **Working** |
| Google Sign-In (Device Code) | ✅ | ✅ | ✅ | **Working** |
| Apple Sign-In (Device Code) | ✅ | ✅ | ✅ | **Working** |
| Internet Identity (Device Code) | ✅ | ✅ | ✅ | **Working** |
| Account Upgrade (Anon → Google / Apple / II) | ✅ | ✅ | ✅ | **Working** |

No OAuth SDKs, no browser popups, no platform-specific branching — every platform uses the same flow.

---

## Anonymous play

Works everywhere with zero setup. No account required to start submitting scores.

```gdscript
CheddaBoards.login_anonymous("PlayerName")
```

Anonymous players keep an empty `_nickname` until they set one, so your UI can show "Guest" instead of an auto-generated placeholder. Achievements are stored locally and sync once the player upgrades to a verified account.

---

## Device Code Auth (Google / Apple / Internet Identity)

The game shows a QR code, a URL, and a short code. The player signs in on their phone browser, and the game picks up the session automatically via background polling.

```
┌──────────────┐                    ┌──────────────────────┐
│  Your Game   │                    │  Player's Phone      │
│              │                    │                      │
│  "Scan QR or │                    │  cheddaboards.com/   │
│   go to      │                    │  link                │
│   cheddaboards                    │                      │
│   .com/link" │                    │  Enter: CHEDDA-7K3M  │
│              │                    │  [Google] [Apple]    │
│  "Enter code:│                    │                      │
│   CHEDDA-7K3M"│    polls every 5s │  ✅ Signed in!       │
│  ✅ Logged in!│◄──────────────────│                      │
└──────────────┘                    └──────────────────────┘
```

```gdscript
# In your game — no OAuth SDKs needed
CheddaBoards.login_with_device_code()

# Listen for the code/URL/QR to display
CheddaBoards.device_code_received.connect(func(user_code, verification_url, qr_data_url):
    show_label("Go to %s and enter: %s" % [verification_url, user_code])
    # qr_data_url is a base64 PNG you can decode into a TextureRect
    # (see scripts/DeviceCodeLogin.gd for a reference implementation)
)

# Login completes automatically via polling
CheddaBoards.device_code_approved.connect(func(nickname):
    print("Welcome, %s!" % nickname)
)
```

When the player finishes signing in on their phone and returns to the game, focus-regain triggers an immediate poll, so the popup closes within ~100ms instead of waiting for the next scheduled cycle. Device codes expire after 5 minutes (`device_code_expired`).

### QR codes (v2.1.0+)

`device_code_received` emits a `qr_data_url` — a base64 PNG encoding the full verification URL with the code pre-filled. The player scans once and taps a single button instead of typing the 6-digit code. Falls back to the raw code if the API returns null.

---

## Account linking (Anonymous → Verified)

- Anonymous players can upgrade to Google / Apple / Internet Identity via the same device code flow.
- All scores, achievements, and progress are preserved through migration.
- Available from both the in-game **Sign In** button and the **Anonymous Dashboard**.

```gdscript
CheddaBoards.account_upgraded.connect(func(profile, migration):
    print("Upgraded — progress preserved")
)
CheddaBoards.account_upgrade_failed.connect(func(reason):
    push_warning("Upgrade failed: %s" % reason)
)
```

---

## Four-panel MainMenu flow (Template)

The Template's MainMenu handles the whole identity lifecycle for you:

| Panel | When shown | Features |
|-------|------------|----------|
| **Login Panel** | First-time players | PLAY NOW, Leaderboard, login buttons |
| **Name Entry** | Before first game | Custom nickname input |
| **Anonymous Dashboard** | Returning anonymous players | Stats, achievements, **upgrade to a verified provider** |
| **Main Panel** | Logged-in users | Full profile with all features |

If you're on the Drop-in path, you build your own equivalents and drive them with the signals below.

---

## Signals

```gdscript
signal login_success(nickname: String)
signal login_failed(reason: String)
signal logout_success()
signal auth_error(reason: String)

signal device_code_received(user_code: String, verification_url: String, qr_data_url: String)
signal device_code_approved(nickname: String)
signal device_code_expired()
signal device_code_error(reason: String)

signal account_upgraded(profile: Dictionary, migration: Dictionary)
signal account_upgrade_failed(reason: String)
```

---

**See also:** [Signals Reference](signals-reference.md) · [Achievements](achievements.md) · [docs index](../README.md)
