extends RefCounted
class_name MiniGameArt

## Shared UI factory: textured buttons, digit rows, gradient mini-game backgrounds.

static var _texture_cache: Dictionary = {}
static var _cyrillic_font: Font = null


static func get_cyrillic_font() -> Font:
	if _cyrillic_font == null:
		_cyrillic_font = load("res://assets/fonts/ArialBold.ttf") as Font
	return _cyrillic_font

static func resolve_texture(texture_source: Variant) -> Texture2D:
	if texture_source is Texture2D:
		return texture_source as Texture2D
	var path := String(texture_source)
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var loaded: Texture2D = null
	loaded = load(path) as Texture2D
	if loaded == null:
		var ext := path.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "webp"]:
			var image := Image.load_from_file(path)
			if image != null and not image.is_empty():
				loaded = ImageTexture.create_from_image(image)
	if loaded != null:
		_texture_cache[path] = loaded
	return loaded


static func clear_texture_cache() -> void:
	_texture_cache.clear()


const DIGIT_TEXTURES: Array[String] = [
	"res://assets/graphics/ui/minigames/digits/0.png",
	"res://assets/graphics/ui/minigames/digits/1.png",
	"res://assets/graphics/ui/minigames/digits/2.png",
	"res://assets/graphics/ui/minigames/digits/3.png",
	"res://assets/graphics/ui/minigames/digits/4.png",
	"res://assets/graphics/ui/minigames/digits/5.png",
	"res://assets/graphics/ui/minigames/digits/6.png",
	"res://assets/graphics/ui/minigames/digits/7.png",
	"res://assets/graphics/ui/minigames/digits/8.png",
	"res://assets/graphics/ui/minigames/digits/9.png",
]
const DIGIT_SLASH_TEX: String = "res://assets/graphics/ui/minigames/digits/slash.png"


static func render_digit_row_default(
	container: Control,
	text: String,
	digit_size: Vector2 = Vector2(44, 58),
	advance: float = 38.0
) -> void:
	render_digit_row(container, text, DIGIT_TEXTURES, digit_size, advance)


static func render_fraction_digits(container: Control, numerator: int, denominator: int) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var x := 0.0
	for ch in str(numerator):
		container.add_child(make_picture("N_" + ch, DIGIT_TEXTURES[int(ch)], Vector2(34, 52), Vector2(x, 0), 0))
		x += 30.0
	container.add_child(make_picture("Slash", DIGIT_SLASH_TEX, Vector2(24, 52), Vector2(x, 0), 0))
	x += 22.0
	for ch in str(denominator):
		container.add_child(make_picture("D_" + ch, DIGIT_TEXTURES[int(ch)], Vector2(34, 52), Vector2(x, 0), 0))
		x += 30.0


## Общий фон мини-игр: градиент + мерцание. Добавляет ноды в host и опускает их назад.
static func build_minigame_background(
	host: Control,
	color_top: Color,
	color_bottom: Color,
	twinkle_color: Color = Color(1, 0.95, 0.7, 0.22),
	density: float = 9.5
) -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	DisplayHelper.fill_control(bg)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/shaders/gradient.gdshader")
	mat.set_shader_parameter("color_top", color_top)
	mat.set_shader_parameter("color_bottom", color_bottom)
	bg.material = mat
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)
	host.move_child(bg, 0)

	var twinkle := ColorRect.new()
	twinkle.name = "Twinkle"
	DisplayHelper.fill_control(twinkle)
	twinkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw_mat := ShaderMaterial.new()
	tw_mat.shader = load("res://scripts/shaders/twinkle.gdshader")
	tw_mat.set_shader_parameter("twinkle_color", twinkle_color)
	tw_mat.set_shader_parameter("density", density)
	twinkle.material = tw_mat
	host.add_child(twinkle)
	host.move_child(twinkle, 1)


## Рендер строки цифр (и слэша) из текстур в container.
static func render_digit_row(
	container: Control,
	text: String,
	digit_textures: Array,
	digit_size: Vector2 = Vector2(44, 58),
	advance: float = 38.0
) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var x := 0.0
	for i in range(text.length()):
		var idx := int(text.substr(i, 1))
		if idx < 0 or idx >= digit_textures.size():
			continue
		var digit := make_picture("Digit_" + str(i), digit_textures[idx], digit_size, Vector2(x, 0), 0)
		container.add_child(digit)
		x += advance


static func make_picture(name: String, texture_source: Variant, size: Vector2, position: Vector2, z_index: int = 0) -> TextureRect:
	var pic := TextureRect.new()
	pic.name = name
	pic.texture = resolve_texture(texture_source)
	pic.size = size
	pic.position = position
	pic.z_index = z_index
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


static func make_clear_button_style(button: BaseButton) -> void:
	if button is Button:
		var btn := button as Button
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(1, 1, 1, 0)
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1, 1, 1, 0)
		var pressed := StyleBoxFlat.new()
		pressed.bg_color = Color(1, 1, 1, 0)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)


static func make_picture_button(name: String, texture_source: Variant, size: Vector2, position: Vector2, z_index: int = 0) -> Button:
	var btn := Button.new()
	btn.name = name
	btn.size = size
	btn.position = position
	btn.z_index = z_index
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	make_clear_button_style(btn)
	var art := make_picture("Art", texture_source, size, Vector2.ZERO)
	btn.add_child(art)
	return btn


static func replace_picture(parent: Control, child_name: String, texture_source: Variant, size: Vector2) -> void:
	var current := parent.get_node_or_null(child_name)
	if current:
		current.queue_free()
	var picture := make_picture(child_name, texture_source, size, Vector2.ZERO)
	parent.add_child(picture)


static func make_text_art(name: String, text: String, size: Vector2, position: Vector2, options: Dictionary = {}) -> Control:
	var holder := Control.new()
	holder.name = name
	holder.position = position
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.name = "Viewport"
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.size = Vector2i(size)
	holder.add_child(viewport)

	var label := Label.new()
	label.name = "Label"
	label.text = text
	label.position = Vector2.ZERO
	label.size = size
	label.horizontal_alignment = options.get("halign", HORIZONTAL_ALIGNMENT_CENTER)
	label.vertical_alignment = options.get("valign", VERTICAL_ALIGNMENT_CENTER)
	label.autowrap_mode = options.get("autowrap", TextServer.AUTOWRAP_WORD_SMART)
	label.clip_text = options.get("clip_text", true)
	var cyrillic_font := get_cyrillic_font()
	if cyrillic_font != null:
		label.add_theme_font_override("font", cyrillic_font)
	label.add_theme_font_size_override("font_size", int(options.get("font_size", 32)))
	label.add_theme_color_override("font_color", options.get("font_color", Color(1, 1, 1, 1)))
	if options.has("outline_color"):
		label.add_theme_color_override("font_outline_color", options["outline_color"])
	if options.has("outline_size"):
		label.add_theme_constant_override("outline_size", int(options["outline_size"]))
	viewport.add_child(label)

	var texture := TextureRect.new()
	texture.name = "Texture"
	texture.texture = viewport.get_texture()
	texture.size = size
	texture.position = Vector2.ZERO
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(texture)
	return holder


static func set_text_art(holder: Control, text: String) -> void:
	if holder == null:
		return
	var viewport := holder.get_node_or_null("Viewport") as SubViewport
	var label := holder.get_node_or_null("Viewport/Label") as Label
	var texture := holder.get_node_or_null("Texture") as TextureRect
	if label:
		label.text = text
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if texture and viewport:
		texture.texture = viewport.get_texture()
