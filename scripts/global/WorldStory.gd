extends Node

## WorldStory — autoload: intro lines, sticker ids, world names for UI copy.

const WORLD_NAMES: Array[String] = [
	"Светящийся лес", "Ледяные вершины", "Облачные сады",
	"Подводный город", "Пустыня эха", "Механическая роща", "Земля снов"
]

const WORLD_MAP_ICONS: Array[String] = ["🌲", "❄️", "☁️", "🌊", "🏜️", "⚙️", "💜"]

const WORLD_STICKERS: Array[String] = ["🍄", "⛄", "🌸", "🐠", "🌵", "🪲", "🌙"]

const INTRO_LINES: Array[Dictionary] = [
	{"text": "Привет! Я Искорка! Кристалл Дружбы разбился на осколки… Помоги мне в Светящем лесу!", "emotion": "happy"},
	{"text": "Brrr! Здесь холодно, но друзья ждут! Собери снежные загадки!", "emotion": "excited"},
	{"text": "Смотри — облачные сады! Посади цветы и покорми пчёлок!", "emotion": "happy"},
	{"text": "Погрузимся в Подводный город! Рыбки нуждаются в помощи!", "emotion": "surprise"},
	{"text": "Пустыня хранит древние эхо… Разгадай звёздные тайны!", "emotion": "think"},
	{"text": "Шестерёнки крутятся! Почини механических друзей!", "emotion": "excited"},
	{"text": "Земля снов — рисуй и мечтай! Здесь всё возможно!", "emotion": "love"},
]

const COMPLETE_LINES: Array[String] = [
	"Ура! Лес снова светится!",
	"Молодец! Горы сияют!",
	"Красота! Сады расцвели!",
	"Супер! Город ожил!",
	"Замечательно! Звёзды поют!",
	"Отлично! Роща заработала!",
	"Волшебно! Сны стали ярче!",
]

const MINIGAME_HINTS: Dictionary = {
	"Puzzle.tscn": "Перетащи предметы в правильные корзинки!",
	"Memory.tscn": "Найди пары одинаковых карточек!",
	"Sequencing.tscn": "Запомни и повтори последовательность!",
	"Drawing.tscn": "Нарисуй что-нибудь красивое!",
}


static func get_intro(world_id: int) -> Dictionary:
	if world_id >= 0 and world_id < INTRO_LINES.size():
		return INTRO_LINES[world_id]
	return {"text": "Помоги мне!", "emotion": "happy"}


static func get_complete_line(world_id: int) -> String:
	if world_id >= 0 and world_id < COMPLETE_LINES.size():
		return COMPLETE_LINES[world_id]
	return "Ура! Молодец!"


static func get_sticker(world_id: int, game_id: int) -> String:
	var base: String = WORLD_STICKERS[world_id] if world_id < WORLD_STICKERS.size() else "⭐"
	return base + str(game_id + 1)
