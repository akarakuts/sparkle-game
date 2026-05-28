extends Control

## Parent gate: arithmetic challenge, screen-time meter, save slots, full progress reset.

signal parent_gate_closed
signal save_slot_selected(slot: int)
signal reset_game_requested

const MiniGameArt := preload("res://scripts/ui/MiniGameArt.gd")

@onready var overlay = $Overlay
@onready var gate_panel = $GatePanel
@onready var title_label = $GatePanel/TitleLabel
@onready var challenge_label = $GatePanel/ChallengeLabel
@onready var answer_input = $GatePanel/AnswerInput
@onready var submit_button = $GatePanel/SubmitButton
@onready var screen_time_progress = $GatePanel/ScreenTimeProgress
@onready var screen_time_fill = $GatePanel/ScreenTimeProgress/ScreenTimeFill
@onready var save_slot1 = $GatePanel/SaveSlot1
@onready var save_slot2 = $GatePanel/SaveSlot2
@onready var save_slot3 = $GatePanel/SaveSlot3
@onready var reset_game_button = $GatePanel/ResetGameButton

const CORRECT_ANSWER = 5
const MAX_SCREEN_TIME_MINUTES = 60.0

var is_authenticated: bool = false
var screen_time_elapsed: float = 0.0
var screen_time_tween: Tween
var _title_art: Control = null
var _challenge_art: Control = null
var _input_art: Control = null
var _input_placeholder_art: Control = null
var _confirm_overlay: ColorRect = null
var _confirm_panel: Panel = null

func _ready():
	DisplayHelper.fill_control(self)
	for btn in [submit_button, save_slot1, save_slot2, save_slot3, reset_game_button]:
		DisplayHelper.make_button_clickable(btn)
	_replace_labels_with_art()
	_connect_signals()
	_setup_close_controls()
	_setup_enter_animation()
	_load_screen_time()
	_start_screen_time_tracking()


func _setup_close_controls() -> void:
	# Тап по затемнению закрывает окно (как в Settings).
	if overlay:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		if not overlay.gui_input.is_connected(_on_overlay_input):
			overlay.gui_input.connect(_on_overlay_input)
	# Крестик в правом верхнем углу панели.
	if gate_panel and gate_panel.get_node_or_null("CloseButton") == null:
		var close_btn := Button.new()
		close_btn.name = "CloseButton"
		close_btn.size = Vector2(64, 64)
		close_btn.position = Vector2(gate_panel.size.x - 78, 14)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.85, 0.3, 0.35, 0.95)
		style.set_corner_radius_all(32)
		close_btn.add_theme_stylebox_override("normal", style)
		DisplayHelper.make_button_clickable(close_btn)
		close_btn.add_child(
			MiniGameArt.make_text_art(
				"CloseArt", "✕",
				close_btn.size, Vector2.ZERO,
				{"font_size": 34, "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.2, 0.05, 0.05, 1), "outline_size": 2}
			)
		)
		close_btn.pressed.connect(_on_close_requested)
		gate_panel.add_child(close_btn)


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_close_requested()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_requested()


func _on_close_requested() -> void:
	# Если открыт диалог подтверждения сброса — сначала закрываем его.
	if _confirm_panel != null and is_instance_valid(_confirm_panel):
		_clear_confirm_reset()
		return
	close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_requested()
		get_viewport().set_input_as_handled()


func _replace_labels_with_art() -> void:
	if title_label:
		title_label.visible = false
		_title_art = MiniGameArt.make_text_art(
			"TitleArt", "Родители",
			Vector2(400, 70), Vector2(150, 30),
			{"font_size": 36, "font_color": Color(1, 0.92, 0.55), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 3}
		)
		gate_panel.add_child(_title_art)
	if challenge_label:
		challenge_label.visible = false
		_challenge_art = MiniGameArt.make_text_art(
			"ChallengeArt", challenge_label.text,
			Vector2(540, 90), Vector2(80, 110),
			{"font_size": 28, "font_color": Color(0.95, 0.97, 1.0), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 2}
		)
		gate_panel.add_child(_challenge_art)
	answer_input.add_theme_color_override("font_color", Color(1, 1, 1, 0.0))
	answer_input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.0))
	answer_input.placeholder_text = ""
	_input_placeholder_art = MiniGameArt.make_text_art(
		"InputPlaceholderArt", "?",
		answer_input.size, answer_input.position,
		{"font_size": 40, "font_color": Color(1, 1, 1, 0.35), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 2}
	)
	gate_panel.add_child(_input_placeholder_art)
	_input_art = MiniGameArt.make_text_art(
		"InputArt", "",
		answer_input.size, answer_input.position,
		{"font_size": 40, "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 2}
	)
	gate_panel.add_child(_input_art)
	_update_input_art()
	var screen_time_label := gate_panel.get_node_or_null("ScreenTimeLabel") as Label
	if screen_time_label:
		screen_time_label.visible = false
		gate_panel.add_child(
			MiniGameArt.make_text_art(
				"ScreenTimeArt", "Экранное время",
				Vector2(500, 60), Vector2(100, 460),
				{"font_size": 26, "font_color": Color(0.95, 0.97, 1.0), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 2}
			)
		)
	var save_slots_label := gate_panel.get_node_or_null("SaveSlotsLabel") as Label
	if save_slots_label:
		save_slots_label.visible = false
		gate_panel.add_child(
			MiniGameArt.make_text_art(
				"SaveSlotsArt", "Слоты сохранения",
				Vector2(500, 60), Vector2(100, 610),
				{"font_size": 26, "font_color": Color(0.95, 0.97, 1.0), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 2}
			)
		)
	for slot_data in [
		{"button": save_slot1, "text": "Слот 1"},
		{"button": save_slot2, "text": "Слот 2"},
		{"button": save_slot3, "text": "Слот 3"}
	]:
		var btn: BaseButton = slot_data["button"]
		var slot_label := btn.get_node_or_null("SlotLabel")
		if slot_label:
			slot_label.visible = false
		btn.add_child(
			MiniGameArt.make_text_art(
				"SlotArt", str(slot_data["text"]),
				btn.size, Vector2.ZERO,
				{"font_size": 28, "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.14, 0.16, 0.34, 1), "outline_size": 3}
			)
		)
	var submit_label := submit_button.get_node_or_null("SubmitLabel")
	if submit_label:
		submit_label.visible = false
	submit_button.add_child(
		MiniGameArt.make_text_art(
			"SubmitArt", "Войти",
			submit_button.size, Vector2.ZERO,
			{"font_size": 32, "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.1, 0.2, 0.1, 1), "outline_size": 3}
		)
	)
	var reset_label := reset_game_button.get_node_or_null("ResetLabel")
	if reset_label:
		reset_label.visible = false
	reset_game_button.add_child(
		MiniGameArt.make_text_art(
			"ResetArt", "Сбросить игру",
			reset_game_button.size, Vector2.ZERO,
			{"font_size": 24, "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.2, 0.05, 0.05, 1), "outline_size": 2}
		)
	)


func _set_challenge_message(text: String) -> void:
	challenge_label.text = text
	if _challenge_art:
		MiniGameArt.set_text_art(_challenge_art, text)

func _connect_signals():
	submit_button.pressed.connect(_on_submit_pressed)
	answer_input.text_changed.connect(_on_answer_text_changed)
	answer_input.text_submitted.connect(func(_text: String): _on_submit_pressed())
	save_slot1.pressed.connect(_on_save_slot_pressed.bind(1))
	save_slot2.pressed.connect(_on_save_slot_pressed.bind(2))
	save_slot3.pressed.connect(_on_save_slot_pressed.bind(3))
	reset_game_button.pressed.connect(_on_reset_game_pressed)

func _setup_enter_animation():
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	gate_panel.scale = Vector2(0.85, 0.85)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(gate_panel, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _load_screen_time():
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		screen_time_elapsed = gs.play_time / 60.0
		_update_screen_time_bar()
	else:
		screen_time_elapsed = 0.0
		_update_screen_time_bar()

func _start_screen_time_tracking():
	var timer = Timer.new()
	timer.wait_time = 60.0  # Update every minute
	timer.timeout.connect(_on_screen_time_tick)
	add_child(timer)
	timer.start()

func _on_screen_time_tick():
	screen_time_elapsed += 1.0
	_update_screen_time_bar()
	_save_screen_time()

func _update_screen_time_bar():
	var ratio = clamp(screen_time_elapsed / MAX_SCREEN_TIME_MINUTES, 0.0, 1.0)
	var bar_width = screen_time_progress.size.x
	screen_time_fill.size.x = bar_width * ratio

	# Change color based on time usage
	if ratio < 0.5:
		screen_time_fill.color = Color(0.3, 0.8, 0.5, 0.9)  # Green
	elif ratio < 0.8:
		screen_time_fill.color = Color(0.9, 0.7, 0.3, 0.9)  # Yellow
	else:
		screen_time_fill.color = Color(0.9, 0.3, 0.3, 0.9)  # Red

func _save_screen_time() -> void:
	SaveManager.save_game(GameState.current_save_slot)


func _on_answer_text_changed(_text: String) -> void:
	_update_input_art()


func _update_input_art() -> void:
	if _input_art:
		MiniGameArt.set_text_art(_input_art, answer_input.text)
	if _input_placeholder_art:
		_input_placeholder_art.visible = answer_input.text.strip_edges().is_empty()

func _on_submit_pressed():
	var text = answer_input.text.strip_edges()
	if text.is_empty():
		_shake_element(answer_input)
		return

	var answer = text.to_int()
	if answer == CORRECT_ANSWER:
		_on_authenticated()
	else:
		_wrong_answer_feedback()

func _on_authenticated():
	is_authenticated = true
	answer_input.editable = false
	submit_button.modulate = Color(0.3, 0.8, 0.3, 1.0)
	_set_challenge_message("Верно! Доступ открыт.")
	_update_input_art()
	_shake_element(gate_panel)

func _wrong_answer_feedback():
	_shake_element(answer_input)
	answer_input.text = ""
	_update_input_art()
	_set_challenge_message("Неверно! Попробуйте ещё раз.")

func _shake_element(element: Control):
	if screen_time_tween and screen_time_tween.is_valid():
		screen_time_tween.kill()

	var original_pos = element.position
	screen_time_tween = create_tween().set_parallel(false)
	screen_time_tween.tween_property(element, "position", original_pos + Vector2(-8, 0), 0.04)
	screen_time_tween.tween_property(element, "position", original_pos + Vector2(8, 0), 0.04)
	screen_time_tween.tween_property(element, "position", original_pos + Vector2(-6, 0), 0.04)
	screen_time_tween.tween_property(element, "position", original_pos + Vector2(6, 0), 0.04)
	screen_time_tween.tween_property(element, "position", original_pos, 0.04)

func _on_save_slot_pressed(slot: int):
	if not is_authenticated:
		_shake_element(submit_button)
		_set_challenge_message("Сначала решите пример!")
		return

	emit_signal("save_slot_selected", slot)
	_load_save_slot(slot)

func _load_save_slot(slot: int) -> void:
	var save_index: int = slot - 1
	var had_save: bool = SaveManager.has_save(save_index)
	SaveManager.select_slot(save_index)
	if had_save:
		_set_challenge_message("Загружен слот " + str(slot))
	else:
		_set_challenge_message("Новая игра в слоте " + str(slot))

func _on_reset_game_pressed():
	if not is_authenticated:
		_shake_element(reset_game_button)
		_set_challenge_message("Сначала решите пример!")
		return

	_confirm_reset()

func _confirm_reset():
	_clear_confirm_reset()

	_confirm_overlay = ColorRect.new()
	_confirm_overlay.name = "ConfirmOverlay"
	_confirm_overlay.color = Color(0, 0, 0, 0.55)
	DisplayHelper.fill_control(_confirm_overlay)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.z_index = 500
	add_child(_confirm_overlay)

	_confirm_panel = Panel.new()
	_confirm_panel.name = "ConfirmPanel"
	_confirm_panel.size = Vector2(560, 320)
	_confirm_panel.position = (DisplayHelper.get_viewport_size() - _confirm_panel.size) * 0.5
	_confirm_panel.z_index = 501
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.3, 0.97)
	panel_style.set_corner_radius_all(28)
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.6, 0.75, 1.0, 0.5)
	_confirm_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_confirm_panel)

	_confirm_panel.add_child(
		MiniGameArt.make_text_art(
			"ConfirmTitleArt", "Подтверждение",
			Vector2(520, 60), Vector2(20, 24),
			{"font_size": 34, "font_color": Color(1, 0.92, 0.55), "outline_color": Color(0.08, 0.12, 0.3, 1), "outline_size": 3}
		)
	)
	_confirm_panel.add_child(
		MiniGameArt.make_text_art(
			"ConfirmMessageArt", "Сбросить всю игру?\nВсе данные будут удалены!",
			Vector2(500, 120), Vector2(30, 92),
			{
				"font_size": 28,
				"font_color": Color(0.95, 0.97, 1.0),
				"outline_color": Color(0.08, 0.12, 0.3, 1),
				"outline_size": 2,
				"autowrap": TextServer.AUTOWRAP_WORD_SMART
			}
		)
	)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.size = Vector2(200, 80)
	cancel_btn.position = Vector2(50, 220)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.45, 0.5, 0.7, 0.95)
	cancel_style.set_corner_radius_all(20)
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	DisplayHelper.make_button_clickable(cancel_btn)
	cancel_btn.add_child(
		MiniGameArt.make_text_art(
			"CancelArt", "Отмена",
			cancel_btn.size, Vector2.ZERO,
			{"font_size": 28, "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.14, 0.16, 0.34, 1), "outline_size": 3}
		)
	)
	cancel_btn.pressed.connect(_clear_confirm_reset)
	_confirm_panel.add_child(cancel_btn)

	var ok_btn := Button.new()
	ok_btn.name = "OkButton"
	ok_btn.size = Vector2(200, 80)
	ok_btn.position = Vector2(310, 220)
	var ok_style := StyleBoxFlat.new()
	ok_style.bg_color = Color(0.8, 0.3, 0.3, 0.95)
	ok_style.set_corner_radius_all(20)
	ok_btn.add_theme_stylebox_override("normal", ok_style)
	DisplayHelper.make_button_clickable(ok_btn)
	ok_btn.add_child(
		MiniGameArt.make_text_art(
			"OkArt", "Сбросить",
			ok_btn.size, Vector2.ZERO,
			{"font_size": 28, "font_color": Color(1, 1, 1, 1), "outline_color": Color(0.2, 0.05, 0.05, 1), "outline_size": 3}
		)
	)
	ok_btn.pressed.connect(_on_confirm_reset_pressed)
	_confirm_panel.add_child(ok_btn)

	_confirm_panel.scale = Vector2(0.9, 0.9)
	_confirm_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_confirm_panel, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_confirm_panel, "modulate:a", 1.0, 0.18)


func _on_confirm_reset_pressed() -> void:
	_clear_confirm_reset()
	_do_reset_game()


func _clear_confirm_reset() -> void:
	if _confirm_panel and is_instance_valid(_confirm_panel):
		_confirm_panel.queue_free()
	if _confirm_overlay and is_instance_valid(_confirm_overlay):
		_confirm_overlay.queue_free()
	_confirm_panel = null
	_confirm_overlay = null

func _do_reset_game() -> void:
	emit_signal("reset_game_requested")
	GameState.reset_game()
	SaveManager.save_game(GameState.current_save_slot)
	_set_challenge_message("Игра сброшена!")
	screen_time_elapsed = 0.0
	_update_screen_time_bar()
	answer_input.text = ""
	answer_input.editable = true
	is_authenticated = false
	submit_button.modulate = Color(0.3, 0.7, 0.4, 0.9)
	_update_input_art()

var _closing: bool = false

func close():
	if _closing:
		return
	_closing = true
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(gate_panel, "scale", Vector2(0.85, 0.85), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func():
		emit_signal("parent_gate_closed")
		queue_free()
	)

func _exit_tree():
	if screen_time_tween and screen_time_tween.is_valid():
		screen_time_tween.kill()
	_clear_confirm_reset()
