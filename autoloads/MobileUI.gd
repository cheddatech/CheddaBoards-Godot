# MobileUI.gd
# Autoload singleton for mobile-responsive UI scaling
# Add to Project > Project Settings > Autoload as "MobileUI"

extends Node

signal scale_changed(new_scale: float)

# Base design resolution (what you designed the UI for)
const BASE_WIDTH: float = 1280.0
const BASE_HEIGHT: float = 720.0
const BASE_DPI: float = 96.0

# Minimum touch target size (Apple HIG recommends 44pt)
const MIN_TOUCH_SIZE: float = 44.0

# Cached values
var ui_scale: float = 1.0
var font_scale: float = 1.0
var is_mobile: bool = false
var is_tablet: bool = false
var is_landscape: bool = true
var screen_size: Vector2 = Vector2(1280, 720)
var safe_area: Rect2 = Rect2()

# DPI-based scaling
var dpi_scale: float = 1.0

func _ready() -> void:
	_detect_platform()
	_calculate_scales()
	
	# Recalculate on window resize
	get_tree().root.size_changed.connect(_on_window_resized)
	
	print("[MobileUI] Platform: %s | Scale: %.2f | Font: %.2f | DPI: %.0f" % [
		"Mobile" if is_mobile else "Desktop",
		ui_scale,
		font_scale,
		dpi_scale * BASE_DPI
	])

func _detect_platform() -> void:
	if OS.get_name() == "Web":
		# Check user agent for mobile
		var is_mobile_browser = JavaScriptBridge.eval("""
			/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
		""", true)
		is_mobile = bool(is_mobile_browser)
		
		# Check for tablet (larger mobile screens)
		var is_tablet_check = JavaScriptBridge.eval("""
			/iPad|Android(?!.*Mobile)/i.test(navigator.userAgent)
		""", true)
		is_tablet = bool(is_tablet_check)
	else:
		is_mobile = OS.get_name() in ["Android", "iOS"]
		is_tablet = false  # Could check screen size
	
	# Also check if touch is available
	if DisplayServer.is_touchscreen_available():
		is_mobile = true

func _calculate_scales() -> void:
	screen_size = get_viewport().get_visible_rect().size
	is_landscape = screen_size.x > screen_size.y
	
	# Get safe area (notch, home indicator, etc.)
	safe_area = DisplayServer.get_display_safe_area()
	if safe_area.size == Vector2.ZERO:
		safe_area = Rect2(Vector2.ZERO, screen_size)
	
	# Calculate DPI scale
	var screen_dpi = DisplayServer.screen_get_dpi()
	if screen_dpi <= 0:
		screen_dpi = 96  # Default fallback
	dpi_scale = screen_dpi / BASE_DPI
	
	# Calculate base UI scale from screen size
	var width_scale = screen_size.x / BASE_WIDTH
	var height_scale = screen_size.y / BASE_HEIGHT
	var base_scale = min(width_scale, height_scale)
	
	# Mobile gets additional scaling boost
	if is_mobile:
		# Scale up more aggressively on mobile
		ui_scale = base_scale * 1.4
		font_scale = base_scale * 1.6  # Text needs to be even bigger
		
		# Extra boost for phones (not tablets)
		if not is_tablet:
			ui_scale *= 1.2
			font_scale *= 1.3
		
		# Portrait mode needs bigger UI
		if not is_landscape:
			ui_scale *= 1.1
			font_scale *= 1.1
	else:
		# Desktop scaling
		ui_scale = base_scale
		font_scale = base_scale
	
	# Clamp to reasonable ranges
	ui_scale = clamp(ui_scale, 0.5, 3.0)
	font_scale = clamp(font_scale, 0.5, 4.0)

func _on_window_resized() -> void:
	_calculate_scales()
	scale_changed.emit(ui_scale)

# ============================================================
# PUBLIC API - USE THESE IN YOUR SCRIPTS
# ============================================================

func get_font_size(base_size: int) -> int:
	"""Get scaled font size. Use for add_theme_font_size_override()"""
	return int(base_size * font_scale)

func get_size(base_size: float) -> float:
	"""Get scaled size for UI elements"""
	return base_size * ui_scale

func get_vector(base_vector: Vector2) -> Vector2:
	"""Get scaled Vector2 for positions/sizes"""
	return base_vector * ui_scale

func get_touch_size(base_size: float) -> float:
	"""Get size that's at least MIN_TOUCH_SIZE on mobile"""
	var scaled = base_size * ui_scale
	if is_mobile:
		return max(scaled, MIN_TOUCH_SIZE * dpi_scale)
	return scaled

func get_margin(base_margin: float) -> float:
	"""Get scaled margin/padding"""
	return base_margin * ui_scale

func get_safe_margin_top() -> float:
	"""Get top margin to avoid notch/status bar"""
	if safe_area.position.y > 0:
		return safe_area.position.y + get_margin(10)
	return get_margin(10)

func get_safe_margin_bottom() -> float:
	"""Get bottom margin to avoid home indicator"""
	var bottom_inset = screen_size.y - (safe_area.position.y + safe_area.size.y)
	if bottom_inset > 0:
		return bottom_inset + get_margin(10)
	return get_margin(10)

# ============================================================
# UI HELPER FUNCTIONS
# ============================================================

func scale_label(label: Label, base_font_size: int, bold: bool = false) -> void:
	"""Apply mobile-friendly scaling to a Label"""
	if not label:
		return
	label.add_theme_font_size_override("font_size", get_font_size(base_font_size))

func scale_button(button: Button, base_font_size: int = 18, min_height: float = 44) -> void:
	"""Apply mobile-friendly scaling to a Button"""
	if not button:
		return
	button.add_theme_font_size_override("font_size", get_font_size(base_font_size))
	button.custom_minimum_size.y = get_touch_size(min_height)

func scale_container_margins(container: MarginContainer, base_margin: float = 20) -> void:
	"""Apply scaled margins to a MarginContainer"""
	if not container:
		return
	var m = int(get_margin(base_margin))
	container.add_theme_constant_override("margin_left", m)
	container.add_theme_constant_override("margin_right", m)
	container.add_theme_constant_override("margin_top", m)
	container.add_theme_constant_override("margin_bottom", m)

func apply_safe_area_margins(control: Control) -> void:
	"""Apply safe area margins to a Control (for notch/home indicator)"""
	if not control:
		return
	control.offset_top = get_safe_margin_top()
	control.offset_bottom = -get_safe_margin_bottom()

# ============================================================
# PRESET CONFIGURATIONS
# ============================================================

func get_hud_font_size() -> int:
	"""Standard HUD text (score, distance, etc.)"""
	return get_font_size(22 if is_mobile else 18)

func get_title_font_size() -> int:
	"""Large titles"""
	return get_font_size(36 if is_mobile else 28)

func get_subtitle_font_size() -> int:
	"""Subtitles and secondary info"""
	return get_font_size(18 if is_mobile else 14)

func get_button_font_size() -> int:
	"""Button text"""
	return get_font_size(22 if is_mobile else 18)

func get_combo_font_size() -> int:
	"""Combo counter (needs to be very visible)"""
	return get_font_size(28 if is_mobile else 22)

func get_popup_font_size() -> int:
	"""Achievement/power-up popups"""
	return get_font_size(24 if is_mobile else 20)

# ============================================================
# DEBUG
# ============================================================

func debug_info() -> String:
	return """
MobileUI Debug:
  Platform: %s
  Is Mobile: %s
  Is Tablet: %s
  Is Landscape: %s
  Screen Size: %s
  UI Scale: %.2f
  Font Scale: %.2f
  DPI Scale: %.2f
  Safe Area: %s
""" % [
		OS.get_name(),
		str(is_mobile),
		str(is_tablet),
		str(is_landscape),
		str(screen_size),
		ui_scale,
		font_scale,
		dpi_scale,
		str(safe_area)
	]
