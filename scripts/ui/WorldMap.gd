extends Control

## World map: seven islands, unlock chain, crystal finale; navigation hub after the main menu.

signal world_selected(world_id: int)
signal back_pressed

const TOTAL_WORLDS = 7
const TOTAL_SHARDS = TOTAL_WORLDS
const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const StickerAlbumScript := preload("res://scripts/ui/StickerAlbum.gd")
const ISLAND_TEX: Array[Texture2D] = [
	preload("res://assets/graphics/ui/wow/worlds/island_forest.png"),
	preload("res://assets/graphics/ui/wow/worlds/island_ice.png"),
	preload("res://assets/graphics/ui/wow/worlds/island_clouds.png"),
	preload("res://assets/graphics/ui/wow/worlds/island_sea.png"),
	preload("res://assets/graphics/ui/wow/worlds/island_desert.png"),
	preload("res://assets/graphics/ui/wow/worlds/island_grove.png"),
	preload("res://assets/graphics/ui/wow/worlds/island_dreams.png"),
]

const WORLD_SHORT_NAMES: Array[String] = [
	"Лес", "Лёд", "Облака", "Море", "Пустыня", "Роща", "Сны"
]
const WORLD_COLORS: Array[Color] = [
	Color("#2ecc71"), Color("#74b9ff"), Color("#fd79a8"),
	Color("#00cec9"), Color("#fdcb6e"), Color("#a29bfe"), Color("#e17055")
]
const MAP_TITLE_TEX := "res://assets/graphics/ui/minigames/worldmap/map_title.png"
const MAP_HINT_DEFAULT_TEX := "res://assets/graphics/ui/minigames/worldmap/hint_default.png"
const MAP_HINT_OPENING_TEX := "res://assets/graphics/ui/minigames/worldmap/hint_opening.png"
const MAP_HINT_LOCKED_TEX := "res://assets/graphics/ui/minigames/worldmap/hint_locked.png"
const MAP_BACK_TEX := "res://assets/graphics/ui/minigames/worldmap/back_menu.png"
const MAP_ALBUM_TEX := "res://assets/graphics/ui/minigames/worldmap/album_button.png"
const MAP_CRYSTAL_LABEL_TEX := "res://assets/graphics/ui/minigames/worldmap/crystal_label.png"
const MAP_SHARDS_LABEL_TEX := "res://assets/graphics/ui/minigames/worldmap/shards_label.png"
const MAP_WORLD_NAME_TEX := [
	"res://assets/graphics/ui/minigames/worldmap/world_name_0.png",
	"res://assets/graphics/ui/minigames/worldmap/world_name_1.png",
	"res://assets/graphics/ui/minigames/worldmap/world_name_2.png",
	"res://assets/graphics/ui/minigames/worldmap/world_name_3.png",
	"res://assets/graphics/ui/minigames/worldmap/world_name_4.png",
	"res://assets/graphics/ui/minigames/worldmap/world_name_5.png",
	"res://assets/graphics/ui/minigames/worldmap/world_name_6.png",
]
const MAP_BADGE_OPEN_TEX := "res://assets/graphics/ui/minigames/worldmap/badge_open.png"
const MAP_BADGE_DONE_TEX := "res://assets/graphics/ui/minigames/worldmap/badge_done.png"
const MAP_BADGE_LOCK_TEX := "res://assets/graphics/ui/minigames/worldmap/badge_lock.png"
const DIGIT_TEXTURES := [
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
const DIGIT_SLASH_TEX := "res://assets/graphics/ui/minigames/digits/slash.png"

enum WorldState { LOCKED, AVAILABLE, COMPLETED }

@onready var background = $Background
@onready var connection_lines = $ConnectionLines
@onready var crystal_icon = $CrystalContainer/CrystalIcon
@onready var shard_counter = $ShardCounter
@onready var _hint_label: Label = $MapHint
@onready var _title_label: Label = $MapTitle

var world_buttons: Array[Button] = []
var world_states: Dictionary = {}
var shards_collected: int = 0
var shake_tween: Tween
var _crystal_tween: Tween = null
var _title_art: TextureRect = null
var _hint_art: TextureRect = null
var _shard_label_art: TextureRect = null
var _crystal_digits: Control = null
var _shard_digits: Control = null
var _safe_top: float = 0.0
var _safe_left: float = 0.0
var _safe_right: float = 0.0
var _safe_bottom: float = 0.0
const ISLAND_LAYOUT_GAP_Y := 56.0
const ISLAND_SIDE_MARGIN := 72.0
const ISLAND_HINT_RESERVE_Y := 200.0


func _ready() -> void:
	_setup_root_layout()
	_replace_static_labels()
	_collect_world_buttons()
	_relayout_top_ui()
	_style_world_buttons()
	_style_static_ui()
	_load_game_state()
	_update_world_display()
	_update_shard_counter()
	_update_crystal_glow()
	_connect_signals()
	call_deferred("_show_first_visit_hint")
	call_deferred("_check_crystal_finale")


func _replace_static_labels() -> void:
	if _title_label:
		_title_label.visible = false
		_title_art = MiniGameArt.make_picture("MapTitleArt", MAP_TITLE_TEX, Vector2(620, 112), Vector2(230, 92), 20)
		add_child(_title_art)
	if _hint_label:
		_hint_label.visible = false
		_hint_art = MiniGameArt.make_picture("MapHintArt", MAP_HINT_DEFAULT_TEX, Vector2(760, 104), Vector2(160, 1548), 20)
		add_child(_hint_art)
	if crystal_icon:
		crystal_icon.visible = false
		var crystal_parent := crystal_icon.get_parent()
		crystal_parent.add_child(MiniGameArt.make_picture("CrystalLabelArt", MAP_CRYSTAL_LABEL_TEX, Vector2(240, 80), Vector2(-120, -24), 15))
		_crystal_digits = Control.new()
		_crystal_digits.name = "CrystalDigits"
		_crystal_digits.position = Vector2(-74, 44)
		_crystal_digits.size = Vector2(148, 60)
		_crystal_digits.z_index = 15
		crystal_parent.add_child(_crystal_digits)
	if shard_counter:
		shard_counter.visible = false
	var back_btn: Button = $BackButton
	back_btn.text = ""
	MiniGameArt.replace_picture(back_btn, "BackArt", MAP_BACK_TEX, back_btn.size)
	var album_btn: Button = $AlbumButton
	album_btn.text = ""
	MiniGameArt.replace_picture(album_btn, "AlbumArt", MAP_ALBUM_TEX, album_btn.size)


func _render_digits(container: Control, text: String) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
	var x := 0.0
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		var tex_path: String = DIGIT_SLASH_TEX if ch == "/" else String(DIGIT_TEXTURES[int(ch)])
		var width := 24.0 if ch == "/" else 34.0
		var digit := MiniGameArt.make_picture("Digit_" + str(i), tex_path, Vector2(width, 52), Vector2(x, 0), 0)
		container.add_child(digit)
		x += width - (4.0 if ch == "/" else 2.0)


func _set_hint_texture(texture_path: String, size: Vector2) -> void:
	if _hint_art == null:
		return
	_hint_art.texture = MiniGameArt.resolve_texture(texture_path)
	_hint_art.size = size
	var map_w := size.x if size.x > 1.0 else DisplayHelper.get_viewport_size().x
	var map_h := size.y if size.y > 1.0 else DisplayHelper.get_viewport_size().y
	_layout_hint(map_w, map_h)


func _setup_root_layout() -> void:
	DisplayHelper.fill_control(self)
	var insets := DisplayHelper.safe_area_insets()
	_safe_left = insets.x
	_safe_top = insets.y
	_safe_right = insets.z
	_safe_bottom = insets.w
	if background:
		DisplayHelper.fill_control(background)
		# WOW фон приглушаем, чтобы острова и текст читались.
		background.modulate = Color(0.22, 0.25, 0.35, 1.0)
	var decor = get_node_or_null("MapDecor")
	if decor:
		DisplayHelper.fill_control(decor)
	if connection_lines:
		connection_lines.z_index = 1

	# Safe-area: опускаем верхние кнопки ниже выреза/камеры.
	# Позиции выставляем в _relayout_top_ui().


func _relayout_top_ui() -> void:
	var map_w := size.x if size.x > 1.0 else DisplayHelper.get_viewport_size().x
	var map_h := size.y if size.y > 1.0 else DisplayHelper.get_viewport_size().y
	var margin := DisplayHelper.sx(24.0)
	# Заголовок под верхними кнопками и safe-area
	var header_y := _safe_top + DisplayHelper.sy(118.0)
	var title_h := _title_art.size.y if _title_art else DisplayHelper.sy(112.0)

	# Back / Album buttons
	var back_btn := get_node_or_null("BackButton") as Control
	if back_btn:
		back_btn.position = Vector2(margin + _safe_left, margin + _safe_top)

	var album_btn := get_node_or_null("AlbumButton") as Control
	if album_btn:
		album_btn.position = Vector2(map_w - margin - album_btn.size.x - _safe_right, margin + _safe_top)

	if _title_art:
		_title_art.position = Vector2((map_w - _title_art.size.x) * 0.5, header_y)

	_hide_center_crystal()

	var header_bottom := header_y + title_h + DisplayHelper.sy(28.0)
	_layout_world_islands(header_bottom)
	_layout_hint(map_w, map_h)


func _hide_center_crystal() -> void:
	var crystal_parent := get_node_or_null("CrystalContainer") as Control
	if crystal_parent:
		crystal_parent.visible = false
		crystal_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _layout_world_islands(header_bottom: float) -> void:
	if world_buttons.is_empty():
		return

	var map_w := size.x if size.x > 1.0 else DisplayHelper.BASE_SIZE.x
	var map_h := size.y if size.y > 1.0 else DisplayHelper.BASE_SIZE.y
	var island_sz := world_buttons[0].size
	if island_sz.length_squared() < 1.0:
		island_sz = Vector2(200, 200)

	var gap_y := DisplayHelper.sy(ISLAND_LAYOUT_GAP_Y)
	var left_x := DisplayHelper.sx(ISLAND_SIDE_MARGIN)
	var right_x := map_w - DisplayHelper.sx(ISLAND_SIDE_MARGIN) - island_sz.x
	var center_x := (map_w - island_sz.x) * 0.5
	var top_y := header_bottom + DisplayHelper.sy(12.0)
	var bottom_limit := map_h - DisplayHelper.sy(ISLAND_HINT_RESERVE_Y) - _safe_bottom

	# Зигзаг: центр → лево/право → лево/право → центр → центр (без наложений)
	var layout: Array[Vector2] = []
	layout.resize(TOTAL_WORLDS)
	var y := top_y
	layout[0] = Vector2(center_x, y)
	y += island_sz.y + gap_y
	layout[1] = Vector2(left_x, y)
	layout[3] = Vector2(right_x, y)
	y += island_sz.y + gap_y
	layout[2] = Vector2(left_x, y)
	layout[5] = Vector2(right_x, y)
	y += island_sz.y + gap_y
	layout[4] = Vector2(center_x, y)
	y += island_sz.y + gap_y
	layout[6] = Vector2(center_x, y)

	var content_bottom := layout[6].y + island_sz.y
	if content_bottom > bottom_limit and content_bottom > top_y:
		var scale := (bottom_limit - top_y) / (content_bottom - top_y)
		for i in range(TOTAL_WORLDS):
			layout[i].y = top_y + (layout[i].y - top_y) * scale

	for i in range(world_buttons.size()):
		world_buttons[i].position = layout[i]

	_update_connection_lines()


func _island_center(idx: int) -> Vector2:
	var btn: Button = world_buttons[idx]
	return btn.position + btn.size * 0.5


func _update_connection_lines() -> void:
	if connection_lines == null or world_buttons.size() < TOTAL_WORLDS:
		return
	var links: Dictionary = {
		"Line1_2": [0, 1],
		"Line2_3": [1, 2],
		"Line2_4": [1, 3],
		"Line3_5": [2, 4],
		"Line4_6": [3, 5],
		"Line4_7": [3, 6],
		"Line6_7": [5, 6],
	}
	for line_name in links.keys():
		var line := connection_lines.get_node_or_null(line_name) as Line2D
		if line == null:
			continue
		var ab: Array = links[line_name]
		line.points = PackedVector2Array([
			_island_center(ab[0]),
			_island_center(ab[1]),
		])


func _layout_hint(map_w: float, map_h: float) -> void:
	if _hint_art == null:
		return
	var bottom_gap := DisplayHelper.sy(56.0) + _safe_bottom
	_hint_art.position = Vector2(
		(map_w - _hint_art.size.x) * 0.5,
		map_h - _hint_art.size.y - bottom_gap
	)


func _collect_world_buttons() -> void:
	world_buttons.clear()
	for i in range(TOTAL_WORLDS):
		var btn: Button = get_node("World" + str(i + 1))
		btn.z_index = 15
		world_buttons.append(btn)


func _style_world_buttons() -> void:
	for i in range(world_buttons.size()):
		var btn: Button = world_buttons[i]
		btn.text = ""
		btn.add_theme_font_size_override("font_size", DisplayHelper.scale_font(34))
		btn.icon = ISLAND_TEX[i]
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		_attach_world_badges(btn, i)
		_apply_island_style(btn, WORLD_COLORS[i])


func _attach_world_badges(btn: Button, idx: int) -> void:
	for node_name in ["NameArt", "StateArt"]:
		var old_node := btn.get_node_or_null(node_name)
		if old_node:
			old_node.queue_free()
	var name_art := MiniGameArt.make_picture("NameArt", MAP_WORLD_NAME_TEX[idx], Vector2(170, 70), Vector2((btn.size.x - 170.0) * 0.5, btn.size.y - 34), 1)
	btn.add_child(name_art)


func _apply_island_style(btn: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.0)
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(4)
	style.set_corner_radius_all(28)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.25)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := style.duplicate()
	disabled.bg_color = color.darkened(0.35)
	btn.add_theme_stylebox_override("disabled", disabled)


func _style_static_ui() -> void:
	_hide_center_crystal()

	if shard_counter:
		shard_counter.z_index = 20

	var back_btn: Button = $BackButton
	back_btn.z_index = 20
	var empty_style := StyleBoxEmpty.new()
	back_btn.add_theme_stylebox_override("normal", empty_style)
	back_btn.add_theme_stylebox_override("hover", empty_style)
	back_btn.add_theme_stylebox_override("pressed", empty_style)
	back_btn.add_theme_stylebox_override("focus", empty_style)

	var album_btn: Button = $AlbumButton
	album_btn.z_index = 20
	album_btn.add_theme_stylebox_override("normal", empty_style)
	album_btn.add_theme_stylebox_override("hover", empty_style)
	album_btn.add_theme_stylebox_override("pressed", empty_style)
	album_btn.add_theme_stylebox_override("focus", empty_style)


func _connect_signals() -> void:
	$BackButton.pressed.connect(_on_back_pressed)
	$AlbumButton.pressed.connect(_on_album_pressed)
	for i in range(world_buttons.size()):
		world_buttons[i].pressed.connect(_on_world_pressed.bind(i + 1))


func _show_first_visit_hint() -> void:
	if _hint_art == null:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(_hint_art, "modulate:a", 0.45, 0.8)
	tw.tween_property(_hint_art, "modulate:a", 1.0, 0.8)


func _on_album_pressed() -> void:
	JuiceManager.button_pop($AlbumButton)
	StickerAlbumScript.open_over(self)


func _update_crystal_glow() -> void:
	var count: int = _get_collected_shards()
	var ratio: float = float(count) / float(TOTAL_SHARDS)
	_render_digits(_crystal_digits, str(count) + "/" + str(TOTAL_SHARDS))
	if _crystal_digits:
		_crystal_digits.scale = Vector2.ONE * (1.0 + ratio * 0.08)

	if _crystal_tween and _crystal_tween.is_valid():
		_crystal_tween.kill()
	if _crystal_digits:
		_crystal_tween = create_tween().set_loops()
		_crystal_tween.tween_property(_crystal_digits, "modulate", Color(0.9, 1.0, 1.0), 0.9)
		_crystal_tween.tween_property(_crystal_digits, "modulate", Color(0.7, 0.85, 1.0), 0.9)


func _load_game_state() -> void:
	shards_collected = GameState.get_shard_count()
	world_states.clear()
	for key in GameState.world_states.keys():
		var world_id: int = int(key)
		var state_name: String = str(GameState.world_states[key])
		match state_name:
			"open":
				world_states[world_id + 1] = WorldState.AVAILABLE
			"completed":
				world_states[world_id + 1] = WorldState.COMPLETED
			_:
				world_states[world_id + 1] = WorldState.LOCKED

	for i in range(2, TOTAL_WORLDS + 1):
		if world_states.get(i - 1, WorldState.LOCKED) == WorldState.COMPLETED:
			if world_states.get(i, WorldState.LOCKED) == WorldState.LOCKED:
				world_states[i] = WorldState.AVAILABLE

	if not world_states.has(1):
		world_states[1] = WorldState.AVAILABLE


func _update_world_display() -> void:
	for i in range(world_buttons.size()):
		var btn: Button = world_buttons[i]
		var world_id: int = i + 1
		var state = world_states.get(world_id, WorldState.LOCKED)
		var base_name: String = WORLD_SHORT_NAMES[i]

		match state:
			WorldState.COMPLETED:
				btn.modulate = Color(0.85, 1.0, 0.85)
				btn.disabled = false
				_set_button_state_art(btn, MAP_BADGE_DONE_TEX, Vector2(140, 52))
			WorldState.AVAILABLE:
				btn.modulate = Color(1, 1, 1)
				btn.disabled = false
				_set_button_state_art(btn, MAP_BADGE_OPEN_TEX, Vector2(120, 52))
				_add_highlight_animation(btn)
			WorldState.LOCKED:
				btn.modulate = Color(0.55, 0.55, 0.6)
				btn.disabled = false
				_set_button_state_art(btn, MAP_BADGE_LOCK_TEX, Vector2(130, 52))


func _set_button_state_art(btn: Button, texture_path: String, size: Vector2) -> void:
	var old := btn.get_node_or_null("StateArt")
	if old:
		old.queue_free()
	var art := MiniGameArt.make_picture("StateArt", texture_path, size, Vector2((btn.size.x - size.x) * 0.5, 6), 1)
	btn.add_child(art)


func _add_highlight_animation(btn: Button) -> void:
	if btn.has_meta("highlight_tween"):
		return
	btn.set_meta("highlight_tween", true)
	var tw := create_tween().set_loops()
	tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.85)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.85)


func _update_shard_counter() -> void:
	if _shard_digits == null:
		return
	var collected := _get_collected_shards()
	_render_digits(_shard_digits, str(collected) + "/" + str(TOTAL_SHARDS))


func _get_collected_shards() -> int:
	return GameState.get_shard_count()


func _on_back_pressed() -> void:
	JuiceManager.button_pop($BackButton)
	emit_signal("back_pressed")
	SceneManager.goto_menu()


func _on_world_pressed(world_id: int) -> void:
	var state = world_states.get(world_id, WorldState.LOCKED)
	match state:
		WorldState.COMPLETED, WorldState.AVAILABLE:
			var btn: Button = world_buttons[world_id - 1]
			JuiceManager.button_pop(btn)
			_set_hint_texture(MAP_HINT_OPENING_TEX, Vector2(520, 104))
			emit_signal("world_selected", world_id)
			SceneManager.goto_world(world_id - 1)
		WorldState.LOCKED:
			_show_locked_feedback(world_buttons[world_id - 1])
			_set_hint_texture(MAP_HINT_LOCKED_TEX, Vector2(780, 104))


func _show_locked_feedback(btn: Button) -> void:
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	var original_pos: Vector2 = btn.position
	shake_tween = create_tween()
	for _i in range(3):
		shake_tween.tween_property(btn, "position", original_pos + Vector2(-8, 0), 0.04)
		shake_tween.tween_property(btn, "position", original_pos + Vector2(8, 0), 0.04)
	shake_tween.tween_property(btn, "position", original_pos, 0.04)


func refresh() -> void:
	_load_game_state()
	_update_world_display()
	_update_shard_counter()
	_update_crystal_glow()


## ── Финал: кристалл восстановлен ───────────────────────────────────

func _check_crystal_finale() -> void:
	if not GameState.is_crystal_complete():
		return
	if GameState.crystal_finale_shown:
		return
	GameState.crystal_finale_shown = true
	SaveManager.save_game(GameState.current_save_slot)
	_play_crystal_finale()


func _play_crystal_finale() -> void:
	var center := DisplayHelper.center()

	var overlay := ColorRect.new()
	overlay.name = "CrystalFinaleOverlay"
	overlay.color = Color(0.04, 0.02, 0.12, 0.0)
	DisplayHelper.fill_control(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 400
	add_child(overlay)

	var title := MiniGameArt.make_text_art(
		"FinaleTitleArt", "Кристалл Дружбы\nвосстановлён!",
		Vector2(900, 260), Vector2((DisplayHelper.get_viewport_size().x - 900) * 0.5, center.y - 320),
		{
			"font_size": 64,
			"font_color": Color(1, 0.95, 0.6),
			"outline_color": Color(0.1, 0.05, 0.25, 1),
			"outline_size": 6,
			"autowrap": TextServer.AUTOWRAP_WORD_SMART,
			"halign": HORIZONTAL_ALIGNMENT_CENTER
		}
	)
	title.z_index = 401
	title.modulate.a = 0.0
	add_child(title)

	var crystal := MiniGameArt.make_text_art(
		"FinaleCrystalArt", "💎",
		Vector2(240, 240), Vector2(center.x - 120, center.y - 40),
		{"font_size": 180}
	)
	crystal.z_index = 401
	crystal.modulate.a = 0.0
	crystal.pivot_offset = crystal.size * 0.5
	add_child(crystal)

	var ok_btn := Button.new()
	ok_btn.name = "FinaleOkButton"
	ok_btn.size = Vector2(320, 110)
	ok_btn.position = Vector2(center.x - 160, center.y + 260)
	ok_btn.z_index = 401
	var ok_style := StyleBoxFlat.new()
	ok_style.bg_color = Color(0.3, 0.75, 0.95, 0.97)
	ok_style.set_corner_radius_all(28)
	ok_btn.add_theme_stylebox_override("normal", ok_style)
	DisplayHelper.make_button_clickable(ok_btn)
	ok_btn.add_child(
		MiniGameArt.make_text_art(
			"FinaleOkArt", "Ура!",
			ok_btn.size, Vector2.ZERO,
			{"font_size": 40, "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.1, 0.2, 0.3, 1), "outline_size": 3}
		)
	)
	ok_btn.modulate.a = 0.0
	add_child(ok_btn)

	var finale_nodes := [overlay, title, crystal, ok_btn]
	ok_btn.pressed.connect(func():
		AudioManager.play_sfx("transition")
		for n in finale_nodes:
			if is_instance_valid(n):
				n.queue_free()
	)

	AudioManager.play_sfx("shard")
	JuiceManager.screen_flash(Color(0.7, 0.9, 1.0), 0.6, 0.6)
	JuiceManager.confetti_at(center, self, 64)
	JuiceManager.sparkle_burst(center, self)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(overlay, "color:a", 0.78, 0.4)
	tween.tween_property(title, "modulate:a", 1.0, 0.5).set_delay(0.15)
	tween.tween_property(crystal, "modulate:a", 1.0, 0.5).set_delay(0.2)
	tween.tween_property(ok_btn, "modulate:a", 1.0, 0.4).set_delay(0.5)

	var pulse := create_tween().set_loops()
	pulse.tween_property(crystal, "scale", Vector2(1.12, 1.12), 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(crystal, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
