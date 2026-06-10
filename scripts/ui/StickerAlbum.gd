extends Control
class_name StickerAlbum

## Full-screen sticker grid; opened from menu or world map overlay.

signal album_closed

const STICKER_GRID_COLS := 4
const STICKER_ALBUM_SCENE := preload("res://scenes/ui/StickerAlbum.tscn")
const CLOSE_BUTTON_TEX := "res://assets/graphics/ui/minigames/common/back_button.png"
const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")
const ALBUM_Z_INDEX := 500
const PANEL_DESIGN_SIZE := Vector2(900, 1200)

@onready var _overlay: ColorRect = null
@onready var _panel: Panel = null
@onready var _grid: GridContainer = null
@onready var _close_btn: Button = null
var _closing: bool = false


static func open_over(parent: Node) -> Control:
	if parent == null or parent.get_tree() == null:
		return null

	var root := parent.get_tree().root
	var layer := root.get_node_or_null("StickerAlbumLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "StickerAlbumLayer"
		layer.layer = 120
		root.add_child(layer)

	for child in layer.get_children():
		if child is StickerAlbum:
			return child as StickerAlbum

	var album: Control = STICKER_ALBUM_SCENE.instantiate()
	album.name = "StickerAlbum"
	layer.add_child(album)
	return album as StickerAlbum


func _ready() -> void:
	z_index = ALBUM_Z_INDEX
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	_build_ui()
	_populate_stickers()
	call_deferred("_animate_in")


func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0.55)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.offset_left = 0
	_overlay.offset_top = 0
	_overlay.offset_right = 0
	_overlay.offset_bottom = 0
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	var center := CenterContainer.new()
	center.name = "PanelCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 0
	center.offset_top = 0
	center.offset_right = 0
	center.offset_bottom = 0
	add_child(center)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = DisplayHelper.scale_size(PANEL_DESIGN_SIZE)
	_panel.size = _panel.custom_minimum_size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.28, 0.95)
	style.corner_radius_top_left = 28
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 28
	style.corner_radius_bottom_right = 28
	style.border_color = Color(0.6, 0.75, 1.0, 0.5)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	_panel.add_child(
		MiniGameArt.make_text_art(
			"TitleArt", "Альбом наклеек",
			Vector2(_panel.size.x, 60), Vector2(0, 24),
			{
				"font_size": DisplayHelper.scale_font(40),
				"font_color": Color(1, 0.92, 0.55),
				"outline_color": Color(0.08, 0.12, 0.3, 1),
				"outline_size": 3,
			}
		)
	)

	var header_close := MiniGameArt.make_picture_button(
		"HeaderClose", CLOSE_BUTTON_TEX,
		Vector2(100, 100), Vector2(_panel.size.x - 112, 8), 10
	)
	header_close.pressed.connect(_on_close)
	_panel.add_child(header_close)

	_grid = GridContainer.new()
	_grid.name = "StickerGrid"
	_grid.columns = STICKER_GRID_COLS
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.position = Vector2(40, 100)
	_grid.size = Vector2(_panel.size.x - 80, _panel.size.y - 200)
	_panel.add_child(_grid)

	_close_btn = Button.new()
	_close_btn.name = "CloseButton"
	_close_btn.custom_minimum_size = Vector2(280, 72)
	_close_btn.size = Vector2(280, 72)
	_close_btn.position = Vector2((_panel.size.x - 280) * 0.5, _panel.size.y - 96)
	_close_btn.z_index = 5
	MiniGameArt.make_clear_button_style(_close_btn)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.35, 0.45, 0.85, 0.95)
	close_style.corner_radius_top_left = 22
	close_style.corner_radius_top_right = 22
	close_style.corner_radius_bottom_left = 22
	close_style.corner_radius_bottom_right = 22
	_close_btn.add_theme_stylebox_override("normal", close_style)
	_close_btn.add_theme_stylebox_override("hover", close_style)
	_close_btn.add_theme_stylebox_override("pressed", close_style)
	_close_btn.pressed.connect(_on_close)
	_panel.add_child(_close_btn)
	_panel.add_child(
		MiniGameArt.make_text_art(
			"CloseArt", "Закрыть",
			Vector2(280, 72), _close_btn.position,
			{
				"font_size": DisplayHelper.scale_font(30),
				"font_color": Color(1, 1, 1, 1),
				"outline_color": Color(0.15, 0.05, 0.05, 1),
				"outline_size": 3,
			}
		)
	)


func _populate_stickers() -> void:
	for child in _grid.get_children():
		child.queue_free()

	for world_id in range(GameConstants.TOTAL_WORLDS):
		var games: Array = MiniGameManager.get_world_games(world_id)
		for game_id in range(games.size()):
			var cell := _make_sticker_cell(world_id, game_id, games[game_id].get("completed", false))
			_grid.add_child(cell)


func _make_sticker_cell(world_id: int, game_id: int, unlocked: bool) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = DisplayHelper.scale_size(Vector2(180, 180))
	var style := StyleBoxFlat.new()
	if unlocked or GameState.has_sticker(world_id, game_id):
		style.bg_color = Color(1, 1, 1, 0.15)
		style.border_color = Color(1, 0.85, 0.3, 0.8)
	else:
		style.bg_color = Color(0, 0, 0, 0.2)
		style.border_color = Color(0.4, 0.4, 0.5, 0.5)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	box.add_theme_stylebox_override("panel", style)

	var text_art: Control
	if unlocked or GameState.has_sticker(world_id, game_id):
		text_art = MiniGameArt.make_text_art(
			"StickerText", WorldStory.get_sticker(world_id, game_id),
			box.custom_minimum_size, Vector2.ZERO,
			{
				"font_size": DisplayHelper.scale_font(44),
				"font_color": Color(1, 0.95, 0.8),
				"outline_color": Color(0.08, 0.12, 0.3, 1),
				"outline_size": 3,
			}
		)
	else:
		text_art = MiniGameArt.make_text_art(
			"StickerText", "?",
			box.custom_minimum_size, Vector2.ZERO,
			{
				"font_size": DisplayHelper.scale_font(52),
				"font_color": Color(1, 1, 1, 0.85),
				"outline_color": Color(0.08, 0.12, 0.3, 1),
				"outline_size": 3,
			}
		)
	box.add_child(text_art)
	return box


func _on_overlay_input(event: InputEvent) -> void:
	if _closing:
		return
	if event is InputEventScreenTouch and event.pressed:
		_on_close()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close()


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			_on_close()
			get_viewport().set_input_as_handled()


func _animate_in() -> void:
	if _panel == null:
		return
	modulate.a = 0.0
	_panel.scale = Vector2(0.88, 0.88)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_close() -> void:
	if _closing:
		return
	_closing = true
	if _close_btn:
		JuiceManager.button_pop(_close_btn)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	if _panel:
		tw.tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.2)
	tw.tween_callback(_finish_close)


func _finish_close() -> void:
	emit_signal("album_closed")
	var layer := get_parent()
	queue_free()
	if layer is CanvasLayer:
		layer.queue_free()
