# Device Code Login

sign players in with Google or Apple on **any** platform — desktop, mobile, web, even consoles — with no bundled OAuth SDK and no in-game browser popup. The player authorises on their phone; your game polls and picks up the session automatically.

This is the hands-on companion to [Authentication](authentication.md), which covers the wider auth picture (anonymous play, account linking). Here we build the **login screen** itself.

- On the **Template**, the screen is already built — skip to [Fastest path](#fastest-path).
- On the **Drop-in** path, [Build your own](#build-your-own-screen) shows the pattern.

---

## How it works (30 seconds)

1. You call `login_with_device_code()`.
2. The SDK emits `device_code_received` with a short code, a verification URL, and a QR image.
3. You show those to the player. They scan the QR (or open the link) on their phone and sign in with Google or Apple.
4. The SDK polls in the background and emits `device_code_approved(nickname)` when they're done — or `device_code_expired` after 5 minutes.

The full sequence diagram is in [Authentication → Device Code Auth](authentication.md#device-code-auth-google--apple).

---

## Fastest path

The Template ships a reusable popup scene + script that wires every signal and cleans itself up. Instantiate it and start the flow:

```gdscript
var popup = preload("res://scenes/DeviceCodeLogin.tscn").instantiate()
add_child(popup)
popup.start_sign_in()

popup.signed_in.connect(func(nickname): print("Welcome, %s!" % nickname))
popup.cancelled.connect(func(): print("Sign-in dismissed"))
```

It emits `signed_in(nickname)` on success and `cancelled()` if dismissed or expired, then frees itself. (The script also exposes a `show_sign_in(parent)` static helper for a true one-liner — see the note at the end of this guide.)

---

## The signal lifecycle

Whether you use the prebuilt popup or roll your own, these four CheddaBoards signals drive the entire flow:

| Signal | Fires when | Your UI should… |
|--------|------------|-----------------|
| `device_code_received(user_code, verification_url, qr_data_url)` | The code is ready | Show the QR + raw code + link, start the countdown |
| `device_code_approved(nickname)` | Player finished on their phone | Show success, then continue into the game |
| `device_code_expired()` | The 5-minute window elapsed | Offer "try again" |
| `device_code_error(reason)` | Something went wrong | Show the reason, offer retry |

Connect them in `_ready()`, and disconnect on teardown so a second attempt starts clean.

---

## Build your own screen

A minimal version, distilled from the reference implementation:

```gdscript
extends CanvasLayer

func _ready():
    CheddaBoards.device_code_received.connect(_on_received)
    CheddaBoards.device_code_approved.connect(_on_approved)
    CheddaBoards.device_code_expired.connect(_on_expired)
    CheddaBoards.device_code_error.connect(_on_error)
    CheddaBoards.login_with_device_code()

func _on_received(user_code: String, verification_url: String, qr_data_url: String):
    $CodeLabel.text = user_code                 # raw code (always show as fallback)
    _set_qr_from_data_url(qr_data_url)          # the QR image — see below
    $Status.text = "Waiting for you to sign in..."

func _on_approved(nickname: String):
    print("Signed in as %s" % nickname)
    queue_free()

func _on_expired():
    $Status.text = "Code expired — try again."

func _on_error(reason: String):
    $Status.text = "Error: %s" % reason
```

---

## Rendering the QR code

This is the part that trips everyone up. `device_code_received` hands you `qr_data_url` as a base64 PNG **data URL** — a string like `data:image/png;base64,iVBORw0KGgo...`. Godot can't apply that to a `TextureRect` directly. You have to strip the prefix, base64-decode it, load it as a PNG, and wrap it in a texture:

```gdscript
## Decode a base64 PNG data URL onto a TextureRect. Returns true on success.
func _set_qr_from_data_url(data_url: String) -> bool:
    # Strip the "data:image/png;base64," prefix
    var comma = data_url.find(",")
    if comma == -1:
        push_warning("Invalid QR data URL (no comma found)")
        return false

    var b64 = data_url.substr(comma + 1)
    var raw: PackedByteArray = Marshalls.base64_to_raw(b64)
    if raw.is_empty():
        return false

    var img = Image.new()
    if img.load_png_from_buffer(raw) != OK:
        return false

    $QRCode.texture = ImageTexture.create_from_image(img)
    return true
```

> **Always show the raw `user_code` as well.** `qr_data_url` can come back null (the SDK falls back to the raw code), and plenty of players don't have a second device with a camera handy.

---

## The expiry countdown

The code is valid for 5 minutes. Record the deadline when the code arrives and tick it down in `_process`:

```gdscript
var _expires_at := 0.0

func _on_received(_user_code, _url, _qr):
    _expires_at = Time.get_unix_time_from_system() + 300  # 5 minutes

func _process(_delta):
    if _expires_at <= 0.0:
        return
    var remaining = _expires_at - Time.get_unix_time_from_system()
    if remaining <= 0:
        $TimerLabel.text = "Expired"
        return
    $TimerLabel.text = "Expires in %d:%02d" % [int(remaining) / 60, int(remaining) % 60]
```

---

## Opening the link (desktop / no camera)

For players who can't scan, make the verification URL clickable. `OS.shell_open` works everywhere — on web it routes through the browser's `window.open`, on desktop/mobile it hands off to the OS handler:

```gdscript
func _on_link_pressed():
    if _verification_url.is_empty():
        return
    OS.shell_open(_verification_url)
```

The verification URL already has the code pre-filled, so the player just taps a provider button on the page.

---

## Cleaning up

When the flow ends — approved, expired, or cancelled — disconnect the signals and free the node. If you tear down while still waiting, tell the SDK to stop polling:

```gdscript
func _close():
    if _still_waiting:
        CheddaBoards.cancel_device_code()
    # disconnect device_code_* signals here
    queue_free()
```

---

## Note on the one-liner helper

The reference script exposes a static `show_sign_in(parent)` that instantiates, adds, and starts the flow in a single call. To use it as `DeviceCodeLogin.show_sign_in(self)`, the script needs a `class_name` and the popup scene must sit at the path the helper loads (`res://scenes/DeviceCodeLogin.tscn`). If you've renamed either, update both to match. The explicit `preload(...).instantiate()` form above always works regardless.

---

**See also:** [Authentication](authentication.md) · [Signals Reference](signals-reference.md) · [Drop-in Quickstart](../quickstart-dropin.md) · [docs index](../README.md)
