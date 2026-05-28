extends Node

## DisplayHelper — autoload: scale UI from 1080×1920 design base + safe-area insets.
const BASE_SIZE: Vector2 = Vector2(1080, 1920)


func get_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func get_scale() -> Vector2:
	return get_viewport_size() / BASE_SIZE


func sx(value: float) -> float:
	return value * get_scale().x


func sy(value: float) -> float:
	return value * get_scale().y


func scale_pos(pos: Vector2) -> Vector2:
	var s := get_scale()
	return Vector2(pos.x * s.x, pos.y * s.y)


func scale_size(size: Vector2) -> Vector2:
	var s := get_scale()
	return Vector2(size.x * s.x, size.y * s.y)


func center() -> Vector2:
	return get_viewport_size() * 0.5


func fill_control(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0
	control.offset_top = 0
	control.offset_right = 0
	control.offset_bottom = 0


func scale_font(base_size: int) -> int:
	return maxi(12, int(round(base_size * min(get_scale().x, get_scale().y))))


func safe_area_insets() -> Vector4:
	# Возвращает отступы safe area в пикселях viewport: (left, top, right, bottom)
	# На Android это уводит UI от выреза/селфи-камеры.
	var vp := get_viewport()
	if vp == null:
		return Vector4.ZERO
	var vp_rect: Rect2 = vp.get_visible_rect()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	# safe area в координатах экрана; приводим к viewport через clamp.
	var left := maxf(0.0, float(safe.position.x))
	var top := maxf(0.0, float(safe.position.y))
	var right := maxf(0.0, float(vp_rect.size.x - (safe.position.x + safe.size.x)))
	var bottom := maxf(0.0, float(vp_rect.size.y - (safe.position.y + safe.size.y)))
	# Если движок/устройство не отдаёт safe area — будет полный экран, инсет = 0.
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	return Vector4(left, top, right, bottom)


func apply_safe_area_top(control: Control, extra_px: float = 0.0) -> void:
	# Сдвигает UI вниз на top inset + extra.
	if control == null:
		return
	var insets := safe_area_insets()
	var top := insets.y + extra_px
	if top <= 0.0:
		return
	control.offset_top += top
	control.offset_bottom -= 0.0


func setup_design_root(control: Control) -> void:
	control.size = BASE_SIZE
	var s := get_scale()
	control.scale = s
	var pos := (get_viewport_size() - BASE_SIZE * s) * 0.5
	# Добавляем safe-area inset (в координатах viewport).
	var insets := safe_area_insets()
	pos.y += insets.y
	control.position = pos


func make_button_clickable(btn: BaseButton) -> void:
	if btn.size.length() < 1:
		btn.custom_minimum_size = Vector2(80, 80)
	for child in btn.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if btn is TextureButton:
		var empty := ImageTexture.new()
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0.01))
		empty.set_image(img)
		btn.texture_normal = empty
		btn.texture_pressed = empty
		btn.texture_hover = empty
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_SCALE
