# DeviceCodeLogin.gd v1.4.0
# Ships with the CheddaBoards addon (addons/cheddaboards/ui/). Reusable
# popup for the device code sign-in flow. Reskin it via theme overrides
# on the scene, or copy it into your project and edit freely.
# Displays a scannable QR code pointing to the verification URL with the
# code pre-filled, plus a clickable LinkButton fallback for desktop / no-camera
# scenarios. Also shows the raw code for manual entry as a last resort.
#
# USAGE (from any script):
#   var popup = preload("res://addons/cheddaboards/ui/DeviceCodeLogin.tscn").instantiate()
#   add_child(popup)
#   popup.signed_in.connect(func(nick): print("signed in as ", nick))
#   popup.start_sign_in()
#
# Or as a one-liner:
#   preload("res://addons/cheddaboards/ui/DeviceCodeLogin.gd").show_sign_in(self)
#
# The popup connects to CheddaBoards signals automatically.
# When approved, it emits `signed_in(nickname)` and removes itself.
# When closed/expired, it emits `cancelled` and removes itself.
#
# v1.4.0: Closing the popup no longer cancels the sign-in. The button is a
#          "Close": it hides the popup and leaves the SDK polling, so a
#          player who dismisses the QR before their phone finishes still
#          gets signed in (login_success fires from the SDK; connect that
#          in the parent, not here). Previously Close called
#          CheddaBoards.cancel_device_code(), which meant an approval
#          made after closing landed on the link page as "success" while
#          the game stayed logged out. Polling stops by itself on approval
#          or expiry, so nothing leaks. The countdown now reads the real
#          remaining time from the SDK (a code restored after a page
#          reload has less than 5 minutes left). Requires SDK >= 2.3.0.
# v1.3.0: Mobile sizing. The scene's fixed 360x480 panel and 200x200 QR
#          are desktop dimensions - unscannable-small on phones. On
#          mobile the panel now sizes to ~92% of viewport height
#          (width follows the original 3:4 aspect) and the QR grows to
#          ~45% of screen height. The QR TextureRect also switches to
#          NEAREST filtering: linear blurs the black/white modules when
#          scaled, which hurts scanning as much as small size does.
#          Fonts scale with the viewport. Desktop layout untouched.
# v1.2.0: Clickable LinkButton opens the verification URL (with code pre-filled)
#          in the system browser via OS.shell_open(). Falls back gracefully if
#          the SDK didn't supply a URL.
# v1.1.0: QR code rendering from base64 data URL.
#
# REQUIRES: CheddaBoards.device_code_received to emit:
#   (user_code: String, verification_url: String, qr_data_url: String)
#   where qr_data_url is a base64 PNG data URL, e.g.:
#   "data:image/png;base64,iVBORw0KGgo..."

extends CanvasLayer

signal signed_in(nickname: String)
signal cancelled()

@onready var overlay = $Overlay
@onready var panel = $Panel
@onready var title_label = $Panel/MarginContainer/VBox/TitleLabel
@onready var instruction_label = $Panel/MarginContainer/VBox/InstructionLabel
@onready var qr_texture = $Panel/MarginContainer/VBox/QRCode
@onready var link_button = $Panel/MarginContainer/VBox/LinkButton
@onready var fallback_label = $Panel/MarginContainer/VBox/FallbackLabel
@onready var code_label = $Panel/MarginContainer/VBox/CodeLabel
@onready var status_label = $Panel/MarginContainer/VBox/StatusLabel
@onready var timer_label = $Panel/MarginContainer/VBox/TimerLabel
@onready var cancel_button = $Panel/MarginContainer/VBox/CancelButton

var _expires_at: float = 0.0
var _is_active: bool = false
var _verification_url: String = ""

func _ready():
	cancel_button.pressed.connect(_on_cancel_pressed)
	link_button.pressed.connect(_on_link_pressed)
	
	# Crisp QR modules at any size - linear filtering blurs them
	qr_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	_fit_mobile()

	CheddaBoards.device_code_received.connect(_on_device_code_received)
	CheddaBoards.device_code_approved.connect(_on_device_code_approved)
	CheddaBoards.device_code_expired.connect(_on_device_code_expired)
	CheddaBoards.device_code_error.connect(_on_device_code_error)

	_show_requesting_state()

func _process(_delta):
	if not _is_active or _expires_at <= 0.0:
		return

	var remaining = _expires_at - Time.get_unix_time_from_system()
	if remaining <= 0:
		timer_label.text = "Expired"
		return

	var mins = int(remaining) / 60
	var secs = int(remaining) % 60
	timer_label.text = "Expires in %d:%02d" % [mins, secs]

	if remaining <= 60:
		timer_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3, 1))

## Start the device code sign-in flow. Call this after adding to tree.
func start_sign_in():
	_show_requesting_state()
	CheddaBoards.login_with_device_code()

## Static helper: instantiate, add to parent, and start flow in one call.
static func show_sign_in(parent: Node) -> Node:
	var popup = load("res://addons/cheddaboards/ui/DeviceCodeLogin.tscn").instantiate()
	parent.add_child(popup)
	popup.start_sign_in()
	return popup

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_device_code_received(user_code: String, verification_url: String, qr_data_url: String):
	_is_active = true
	var secs = 300
	if CheddaBoards.has_method("get_device_code_seconds_remaining"):
		secs = CheddaBoards.get_device_code_seconds_remaining()
		if secs <= 0:
			secs = 300
	_expires_at = Time.get_unix_time_from_system() + secs
	_verification_url = verification_url

	# Build QR texture from base64 data URL
	var qr_ok = _set_qr_from_data_url(qr_data_url)

	# Always show the raw code as fallback
	code_label.text = user_code

	instruction_label.text = "Scan to sign in instantly:"
	instruction_label.visible = true
	qr_texture.visible = qr_ok
	# Show clickable link only if SDK gave us a URL — graceful fallback otherwise
	link_button.visible = not _verification_url.is_empty()
	fallback_label.visible = true
	code_label.visible = true
	status_label.text = "Waiting for you to sign in...\nYou can close this, sign-in finishes in the background."
	status_label.visible = true
	timer_label.visible = true
	cancel_button.text = "Close"
	cancel_button.disabled = false

func _on_device_code_approved(nickname: String):
	_is_active = false

	title_label.text = "Signed In!"
	instruction_label.visible = false
	qr_texture.visible = false
	link_button.visible = false
	fallback_label.visible = false
	code_label.text = "Welcome, %s!" % nickname
	code_label.add_theme_color_override("font_color", Color(0.3, 1, 0.4, 1))
	status_label.visible = false
	timer_label.visible = false
	cancel_button.visible = false

	signed_in.emit(nickname)
	await get_tree().create_timer(1.5).timeout
	_cleanup()

func _on_device_code_expired():
	_is_active = false

	qr_texture.visible = false
	link_button.visible = false
	status_label.text = "Code expired. Try again."
	status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3, 1))
	timer_label.visible = false
	cancel_button.text = "Close"
	cancel_button.disabled = false

	cancelled.emit()

func _on_device_code_error(reason: String):
	_is_active = false

	qr_texture.visible = false
	link_button.visible = false
	status_label.text = "Error: %s" % reason
	status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3, 1))
	timer_label.visible = false
	cancel_button.text = "Close"
	cancel_button.disabled = false

func _on_cancel_pressed():
	# Close, not cancel: the SDK keeps polling the same code. If the
	# player approves it after this, the SDK emits device_code_approved and
	# login_success on its own. To hard-abandon a sign-in (e.g. a "use a
	# different account" button) call CheddaBoards.cancel_device_code()
	# from the parent instead.
	_is_active = false
	cancelled.emit()
	_cleanup()

func _on_link_pressed():
	# Open the verification URL (with code pre-filled) in the system browser.
	# On web exports OS.shell_open routes through JavaScript window.open;
	# on desktop/mobile it hands off to the OS handler.
	if _verification_url.is_empty():
		push_warning("DeviceCodePopup: link pressed but no verification URL set")
		return
	OS.shell_open(_verification_url)

# ============================================================
# INTERNAL
# ============================================================

## Decode a base64 PNG data URL and apply it to the QR TextureRect.
## Returns true on success, false if decoding fails.
func _set_qr_from_data_url(data_url: String) -> bool:
	# Strip the "data:image/png;base64," prefix
	var comma = data_url.find(",")
	if comma == -1:
		push_warning("DeviceCodePopup: invalid QR data URL (no comma found)")
		return false

	var b64 = data_url.substr(comma + 1)
	var raw: PackedByteArray = Marshalls.base64_to_raw(b64)
	if raw.is_empty():
		push_warning("DeviceCodePopup: base64 decode produced empty buffer")
		return false

	var img = Image.new()
	var err = img.load_png_from_buffer(raw)
	if err != OK:
		push_warning("DeviceCodePopup: failed to load PNG from buffer (error %d)" % err)
		return false

	qr_texture.texture = ImageTexture.create_from_image(img)
	return true

func _fit_mobile():
	"""Scale the popup to the phone. The scene ships desktop-sized
	(360x480 panel, 200x200 QR); on mobile everything derives from the
	viewport instead - the QR is the hero at ~45% of screen height."""
	var mobile_ui = get_node_or_null("/root/MobileUI")
	if not mobile_ui or not mobile_ui.is_mobile:
		return
	var vp: Vector2 = panel.get_viewport_rect().size
	var H: float = vp.y
	
	# Panel: centred, ~92% of height, width follows the 3:4 design aspect
	var ph: float = H * 0.92
	var pw: float = clamp(ph * 0.75, 300.0, vp.x * 0.9)
	panel.offset_left = -pw / 2.0
	panel.offset_right = pw / 2.0
	panel.offset_top = -ph / 2.0
	panel.offset_bottom = ph / 2.0
	
	# QR is the hero
	var qr_side := int(H * 0.45)
	qr_texture.custom_minimum_size = Vector2(qr_side, qr_side)
	
	# Type scales with the screen
	title_label.add_theme_font_size_override("font_size", max(18, int(H * 0.045)))
	instruction_label.add_theme_font_size_override("font_size", max(12, int(H * 0.026)))
	code_label.add_theme_font_size_override("font_size", max(20, int(H * 0.05)))
	status_label.add_theme_font_size_override("font_size", max(12, int(H * 0.024)))
	timer_label.add_theme_font_size_override("font_size", max(11, int(H * 0.022)))
	fallback_label.add_theme_font_size_override("font_size", max(11, int(H * 0.022)))
	link_button.add_theme_font_size_override("font_size", max(13, int(H * 0.028)))
	cancel_button.add_theme_font_size_override("font_size", max(14, int(H * 0.03)))
	cancel_button.custom_minimum_size.y = max(44, int(H * 0.09))

func _show_requesting_state():
	title_label.text = "Sign In"
	instruction_label.visible = false
	qr_texture.visible = false
	link_button.visible = false
	fallback_label.visible = false
	code_label.text = "Requesting code..."
	code_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	code_label.visible = true
	status_label.text = ""
	status_label.remove_theme_color_override("font_color")
	status_label.visible = false
	timer_label.visible = false
	cancel_button.text = "Close"
	cancel_button.disabled = false
	cancel_button.visible = true

func _cleanup():
	if CheddaBoards.device_code_received.is_connected(_on_device_code_received):
		CheddaBoards.device_code_received.disconnect(_on_device_code_received)
	if CheddaBoards.device_code_approved.is_connected(_on_device_code_approved):
		CheddaBoards.device_code_approved.disconnect(_on_device_code_approved)
	if CheddaBoards.device_code_expired.is_connected(_on_device_code_expired):
		CheddaBoards.device_code_expired.disconnect(_on_device_code_expired)
	if CheddaBoards.device_code_error.is_connected(_on_device_code_error):
		CheddaBoards.device_code_error.disconnect(_on_device_code_error)

	queue_free()
