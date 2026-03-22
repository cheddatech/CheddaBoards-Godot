# DeviceCodePopup.gd v1.1.0
# Reusable popup for device code sign-in flow.
# Displays a scannable QR code pointing to the verification URL with the
# code pre-filled. Falls back to showing the raw code for manual entry.
#
# USAGE (from any script):
#   var popup = preload("res://scenes/DeviceCodePopup.tscn").instantiate()
#   add_child(popup)
#   popup.start_sign_in()
#
# Or even simpler - just call it as a one-liner:
#   DeviceCodePopup.show_sign_in(self)
#
# The popup connects to CheddaBoards signals automatically.
# When approved, it emits `signed_in(nickname)` and removes itself.
# When cancelled/expired, it emits `cancelled` and removes itself.
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
@onready var fallback_label = $Panel/MarginContainer/VBox/FallbackLabel
@onready var code_label = $Panel/MarginContainer/VBox/CodeLabel
@onready var status_label = $Panel/MarginContainer/VBox/StatusLabel
@onready var timer_label = $Panel/MarginContainer/VBox/TimerLabel
@onready var cancel_button = $Panel/MarginContainer/VBox/CancelButton

var _expires_at: float = 0.0
var _is_active: bool = false

func _ready():
	cancel_button.pressed.connect(_on_cancel_pressed)

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
	var popup = load("res://scenes/DeviceCodePopup.tscn").instantiate()
	parent.add_child(popup)
	popup.start_sign_in()
	return popup

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_device_code_received(user_code: String, _verification_url: String, qr_data_url: String):
	_is_active = true
	_expires_at = Time.get_unix_time_from_system() + 300  # 5 minutes

	# Build QR texture from base64 data URL
	var qr_ok = _set_qr_from_data_url(qr_data_url)

	# Always show the raw code as fallback
	code_label.text = user_code

	instruction_label.text = "Scan to sign in instantly:"
	instruction_label.visible = true
	qr_texture.visible = qr_ok
	fallback_label.visible = true
	code_label.visible = true
	status_label.text = "Waiting for you to sign in..."
	status_label.visible = true
	timer_label.visible = true
	cancel_button.text = "Cancel"
	cancel_button.disabled = false

func _on_device_code_approved(nickname: String):
	_is_active = false

	title_label.text = "Signed In!"
	instruction_label.visible = false
	qr_texture.visible = false
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
	status_label.text = "Code expired. Try again."
	status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3, 1))
	timer_label.visible = false
	cancel_button.text = "Close"
	cancel_button.disabled = false

	cancelled.emit()

func _on_device_code_error(reason: String):
	_is_active = false

	qr_texture.visible = false
	status_label.text = "Error: %s" % reason
	status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3, 1))
	timer_label.visible = false
	cancel_button.text = "Close"
	cancel_button.disabled = false

func _on_cancel_pressed():
	if _is_active:
		CheddaBoards.cancel_device_code()
	_is_active = false
	cancelled.emit()
	_cleanup()

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

func _show_requesting_state():
	title_label.text = "Sign In"
	instruction_label.visible = false
	qr_texture.visible = false
	fallback_label.visible = false
	code_label.text = "Requesting code..."
	code_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
	code_label.visible = true
	status_label.text = ""
	status_label.remove_theme_color_override("font_color")
	status_label.visible = false
	timer_label.visible = false
	cancel_button.text = "Cancel"
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
