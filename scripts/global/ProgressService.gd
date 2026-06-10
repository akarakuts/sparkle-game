extends Node

## ProgressService — autoload: minigame completion, shards, stickers, world unlock.


func handle_minigame_completed(world_id: int, game_id: int, scene_path: String = "") -> Dictionary:
	var result := {"got_shard": false, "celebration_world": -1}

	game_id = MiniGameManager.resolve_game_id(world_id, game_id, scene_path)
	MiniGameManager.complete_minigame(world_id, game_id, scene_path)
	GameState.collect_sticker(world_id, game_id)
	JuiceManager.celebrate_at(DisplayHelper.center())
	JuiceManager.sparkle_burst(DisplayHelper.center())
	AudioManager.play_sfx("success")
	SaveManager.save_game(GameState.current_save_slot)

	if MiniGameManager.is_world_ready(world_id):
		if GameState.collect_shard(world_id):
			result["got_shard"] = true
			AudioManager.play_sfx("shard")
			JuiceManager.screen_flash(Color(0.5, 0.8, 1.0), 0.45, 0.4)
		if GameState.complete_world(world_id):
			result["celebration_world"] = world_id

	if result["got_shard"]:
		JuiceManager.confetti_at(DisplayHelper.center(), null, 48)

	return result
