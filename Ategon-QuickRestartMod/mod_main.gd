extends Node

const MOD_DIR := "Ategon-QuickRestartMod/"

func _init(modLoader: ModLoader):
	var dir = modLoader.UNPACKED_DIR + MOD_DIR
	var ext_dir = dir + "extensions/"
	
	ModLoaderMod.install_script_extension("%s/LevelStage.gd" % [ext_dir])
