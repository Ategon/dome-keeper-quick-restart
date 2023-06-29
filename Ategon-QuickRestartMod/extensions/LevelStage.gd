extends "res://stages/level/LevelStage.gd"

func _input(ev):
	if ev is InputEventKey and ev.scancode == KEY_R and not ev.echo:
		GameWorld.keptGadgetUsed = false
		
		Audio.sound("gui_loadout_startrun")
		var startData = LevelStartData.new()
		startData.loadout = GameWorld.loadoutStageConfig.duplicate()
		
		StageManager.startStage("stages/landing/landing", [startData])
