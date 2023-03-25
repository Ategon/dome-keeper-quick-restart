extends Stage

var keeperInputProcessor:InputProcessor

var pausedByPlayer: = false
var shouldPlayMusic: = false
var shouldStopMusic: = false

var saveData: = {}

# RM
func _input(ev):
	if ev is InputEventKey and ev.scancode == KEY_R and not ev.echo:
		GameWorld.keptGadgetUsed = false
		
		Audio.sound("gui_loadout_startrun")
		var startData = LevelStartData.new()
		startData.loadout = GameWorld.loadoutStageConfig.duplicate()
		
		StageManager.startStage("stages/landing/landing", [startData])
# End RM

func _ready()->void :

	fadeInTime = 0.1
	
	$BlackBorder.visible = true
	if GameWorld.buildType == CONST.BUILD_TYPE.PLAYTEST:
		find_node("NoStreamContainer").visible = true
		find_node("NoStreamLabel").text += " " + SteamGlobal.STEAM_USERNAME + "."
	else :
		find_node("NoStreamContainer").visible = false
	
	Style.init($Canvas)
	Style.init($ScreenGlitterParticles)
	Style.init($BlackBorder)

func build(data:Array):
	if data.size() == 0 or not data[0] is LevelStartData:
		Logger.error("invalid LevelStage start data", "LevelStage.build", data)
		return 
	
	Level.tutorials = $Canvas / Tutorials
	
	var startData:LevelStartData = data[0]
	
	var worldScene = Data.worldScene(startData.loadout.worldId).instance()
	add_child(worldScene)
	
	var domeId:String = startData.loadout.domeId
	var dome = Data.domeScene(domeId).instance()
	dome.position = find_node("DomePosition").position
	add_child(dome)
	dome.init()
	
	var keeper = Data.keeperScene(startData.loadout.keeperId).instance()
	keeper.position = find_node("KeeperPosition").position
	add_child(keeper)
	
	match dome.primaryWeapon:
		"laser":
			$Canvas / BattlePopup.find_node("ActionWeaponMoveUp").visible = false
			$Canvas / BattlePopup.find_node("ActionWeaponMoveDown").visible = false
		"sword":
			$Canvas / BattlePopup.find_node("ActionWeaponMoveUp").visible = false
			$Canvas / BattlePopup.find_node("ActionWeaponMoveDown").visible = false
		"artillery":
			$Canvas / BattlePopup.find_node("ActionWeaponMoveUp").visible = false
			$Canvas / BattlePopup.find_node("ActionWeaponMoveDown").visible = false
		"obelisk":
			$Canvas / BattlePopup.find_node("ActionWeaponMoveUp").visible = true
			$Canvas / BattlePopup.find_node("ActionWeaponMoveDown").visible = true
		_:
			$Canvas / BattlePopup.find_node("ActionWeaponMoveLeft").visible = false
			$Canvas / BattlePopup.find_node("ActionWeaponMoveRight").visible = false
			
	
	$Canvas / BattlePopup.find_node("LeftRightLabel").text = "level.station.battle.navbar.move"
			
	$Canvas / TechtreeContainer.visible = true
	
	var mode = load("res://content/gamemode/" + startData.loadout.modeId + "/" + startData.loadout.modeId.capitalize() + ".tscn").instance()
	add_child(mode)
	
	Level.map = $Map
	Level.monsters = $Monsters
	Level.keeper = keeper
	Level.dome = dome
	Level.world = worldScene
	Level.hud = find_node("Hud")
	Level.tutorials = $Canvas / Tutorials
	Level.stage = self
	Level.mode = mode
	Level.initialized = true
	Audio.unmuteSounds()
	
	GameWorld.unlockLevelTech(startData.loadout.keeperId)
	GameWorld.unlockLevelTech(startData.loadout.domeId)
	if dome.primaryWeapon:
		GameWorld.unlockLevelTech(dome.primaryWeapon)
	
	if not startData.savegame and startData.loadout.petId != "pet0" and startData.loadout.petId != "":
		
		var pet = load("res://content/pets/" + startData.loadout.petId + "/" + Data.startCaptialized(startData.loadout.petId) + ".tscn").instance()
		dome.add_child(pet)
	
	$Map.setTileData(startData.tileData)
	$Map.init()
	$Map.generateCaves()
	
	mode.init()
	
	var tileCount = float(startData.tileData.get_tile_count())
	var maxIntervalProgression = Data.of("monsters.waveIntervalProgressionPerSqrt1000") * sqrt(tileCount * 0.001)
	Data.apply("monsters.waveintervalProgression", maxIntervalProgression)
	

	$VignetteLayer / Vignette.setTarget(keeper, 2000)
	
	find_node("Cheats").init()

	$Camera2D.set_script(preload("res://systems/camera/CameraSingleTarget.gd"))
	$Camera2D.init(keeper)
	$Camera2D.set_process(true)
	
	find_node("Hud").init()
	
	if Data.gadgets.has(startData.loadout.primaryGadgetId):
		applyGadget(startData.loadout.primaryGadgetId)
	
	$EffectHandler.init()
	
	GameWorld.levelInitialized()
	
	$Map.revealInitialState()
	
	if GameWorld.devMode or startData.savegame:
		startKeeperInput()
	else :
		Level.hud.immediateMoveOut()
		landDome()
	
	Steam.connect("overlay_toggled", self, "steam_overlay_toggled")

func steam_overlay_toggled(active:bool):
	if active and keeperInputProcessor and not GameWorld.paused:
		openPauseMenu()

func landDome():
	var impact = load("res://stages/landing/Impact.tscn").instance()
	impact.connect("landed", self, "startKeeperInput")
	impact.connect("landed", Level.hud, "moveIn")
	Level.stage.add_child(impact)

func leavePlanet():
	Level.stage.stopKeeperInput()
	
	var t = Tween.new()
	add_child(t)
	var p0 = Level.dome.position
	var p1 = p0 + Vector2(0, - 1000)
	t.interpolate_property(Level.dome, "position", p0, p1, 6.0, Tween.TRANS_QUART, Tween.EASE_IN, 1.0)
	t.start()
	
	GameWorld.goalCameraZoom = 2
	InputSystem.getCamera().shake(100, 30, 8)

	var engine = load("res://content/dome/PrestigeEngine.tscn").instance()
	Level.dome.add_child(engine)

func beforeStart():
	GameWorld.setShowMouse(false)
	fadeOutTime = 0.6
	
	if not resuming:
		find_node("Cheats").visible = false
		
		Data.listen(self, "keeper.insidestation")
		Data.listen(self, "monsters.wavepresent")
		Data.listen(self, "monsters.cycle")
		$Monsters.init()
		find_node("Tutorials").visible = true
		find_node("ScreenCover").visible = true
		find_node("BattlePopup").visible = true
		find_node("StationPopup").visible = true
		


	
	Audio.stopMusic()
	
	sendCycleChangeEvent(0)
	
	Input.connect("joy_connection_changed", self, "_on_joy_connection_changed")

func beforeEnd():
	Audio.stopBattleMusic()
	Level.tutorials.clear()
	
	if not GameWorld.won:
		Audio.stopMusic()
	Data.clearListeners()

func end():
	Level.clear()

func _on_joy_connection_changed(device_id, connected):
	if not connected and keeperInputProcessor and not GameWorld.paused:
		openPauseMenu()

func startKeeperInput():
	var id = Level.keeper.techId.capitalize().replace(" ", "")
	keeperInputProcessor = load("res://content/keeper/" + id + "InputProcessor.gd").new()
	keeperInputProcessor.keeper = Level.keeper
	keeperInputProcessor.integrate(self)
	
	Level.tutorials.activate()
	
	if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		var popup = preload("res://stages/level/AbandonedPopup.tscn").instance()
		popup.overlay = find_node("Overlay")
		$Canvas.add_child(popup)
		
		var ei = preload("res://content/keeper/StationAbandonedInputProcessor.gd").new()
		ei.connect("no_inputs", popup, "fadeIn")
		ei.connect("got_input", popup, "fadeOut")
		ei.integrate(self)

func stopKeeperInput():
	if keeperInputProcessor:
		keeperInputProcessor.desintegrate()
		keeperInputProcessor = null
		Level.tutorials.deactivate()

func openPauseMenu():
	GameWorld.setShowMouse(true)
	var i = preload("res://content/pause/PauseInputProcessor.gd").new()
	i.blockAllKeys = true
	i.popup = preload("res://content/pause/PauseMenu.tscn").instance()
	add_child(i.popup)
	i.integrate(self)
	i.connect("stopping", i.popup, "fadeOut", [0.3])
	i.connect("onStop", self, "pauseClosed")
	i.popup.connect("close", i, "desintegrate")
	if not pausedByPlayer:
		pause(false)

func pauseClosed():
	unpause(false)

func _process(delta):
	if GameWorld.devMode and Input.is_action_just_pressed("hide_hud"):
		$Canvas.layer = 1 - $Canvas.layer
	
	if Input.is_action_just_pressed("f5"):
		for light in get_tree().get_nodes_in_group("light"):
			light.light_active = not light.light_active
	
	if GameWorld.won or GameWorld.lost:
		return 
	
	var keeperY:float = Level.keeper.position.y
	var entrancY:float = Level.dome.cellarEntranceY()
	var isInDome:bool = Data.of("keeper.insidedome")
	if keeperY > entrancY:
		if isInDome:
			Data.apply("keeper.insidedome", false)
		var monstersIn = GameWorld.waveDelay + Data.of("monsters.waveCooldown")
		if shouldPlayMusic and not Data.of("monsters.wavepresent") and monstersIn > 40.0 and not Audio.isMusicPlaying():
			Audio.startMusic(GameWorld.currentMusicIndex, 2.0 + randf() * 1.0)
			GameWorld.currentMusicIndex += 1
			shouldPlayMusic = false
			shouldStopMusic = true
	elif not isInDome:
		Data.apply("keeper.insidedome", true)
	
	if shouldStopMusic and GameWorld.waveDelay + Data.of("monsters.waveCooldown") <= 2.0:
		if GameWorld.isUpgradeLimitAvailable("hostile"):
			Audio.stopMusic(0, 10.0)
		shouldStopMusic = false

func playGameLostAnimation()->float:
	var distance = abs($Camera2D.cameraRestPositionInDome.y - $Camera2D.position.y)
	if distance < 10:
		return 0.0
	else :
		$VignetteLayer / Vignette.modulateOnPlayerY = false
		$StageTransitionTween.stop_all()
		$StageTransitionTween.remove_all()
		var duration = 1.0 + abs(distance) / 500.0
		$StageTransitionTween.interpolate_property($Camera2D, "position", $Camera2D.position, Vector2(0, - 75), duration, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
		$StageTransitionTween.start()
		return duration + 0.2

func toggleCheats():
	if not GameWorld.devMode:
		return 
	
	var c = find_node("Cheats")
	c.visible = not c.visible
	if c.visible:
		Audio.sound("gui_cheats")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		GameWorld.setShowMouse(true)
	else :
		Audio.sound("gui_cheats")
		if not GameWorld.showMouse:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func startGadgetChoiceInput():
	var gadgets = GameWorld.generateGadgets()
	var i = preload("res://stages/level/GadgetChoiceInputProcessor.gd").new()
	i.popup = preload("res://stages/level/GadgetChoicePopup.tscn").instance()
	$Canvas.add_child(i.popup)
	i.popup.loadGadgets(gadgets)
	i.connect("onStop", self, "unpause")
	i.connect("gadgetSelected", self, "applyGadget")
	i.connect("dropsSelected", self, "addDropsToDome")
	i.integrate(self)
	pause()

func addDropsToDome(type:String, amount:int):
	for _i in range(0, amount):
		var drop = Data.DROP_SCENES.get(type).instance()
		drop.position = Level.dome.getDropTarget(drop.type).global_position + Vector2(10 - randf() * 30, 10 - randf() * 30)
		drop.type = type
		$Map.call_deferred("addDrop", drop)

var battleInputCount: = 0
func startBattleInput(keeper:Keeper):
	var i = preload("res://content/dome/station/BattleInputProcessor.gd").new()
	i.stopNamed = "UpgradesInputProcessor,BattleInputProcessor"
	i.popup = find_node("BattlePopup")
	i.connect("onStop", self, "onBattleInputStopped")
	i.integrate(self)
	battleInputCount += 1
	unpause()
	
	if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		var popup = preload("res://stages/level/AbandonedPopup.tscn").instance()
		popup.overlay = find_node("Overlay")
		$Canvas.add_child(popup)
		
		var ei = preload("res://content/keeper/StationAbandonedInputProcessor.gd").new()
		ei.connect("no_inputs", popup, "fadeIn")
		ei.connect("got_input", popup, "fadeOut")
		ei.connect("onStop", popup, "fadeOut")
		ei.connect("onStop", popup, "queue_free")
		ei.integrate(self)

func onBattleInputStopped():
	battleInputCount -= 1

func startUpgradesInput(keeper:Keeper):
	var i = preload("res://stages/level/UpgradesInputProcessor.gd").new()
	i.stopNamed = "UpgradesInputProcessor,BattleInputProcessor"
	var techTree = preload("res://content/techtree/TechTreePopup.tscn").instance()
	find_node("TechtreeContainer").add_child(techTree)
	i.popup = techTree
	i.connect("buyUpgrade", techTree, "buyUpgrade")
	i.integrate(self)

func onGameLost():
	stopKeeperInput()
	if Level.keeper.position.y < - 16.0:
		Level.keeper.remove()
	find_node("Hud").visible = false
	Audio.stopBattleMusic()

func flyDomeOut():
	stopKeeperInput()
	var ani = preload("res://content/dome/dome1/RocketDome1.tscn").instance()
	ani.position = Level.dome.position
	add_child(ani)
	$Tween.interpolate_callback(ani, 2, "start")
	$Tween.interpolate_callback(Level.dome, 2 + 3 / 8.0, "set", "visible", false)
	$Tween.interpolate_callback(Level.keeper, 2 + 3 / 8.0, "set", "visible", false)
	$Tween.interpolate_callback(self, 7, "emit_signal", "request_end")
	$Tween.start()

func applyGadget(id:String):
	Data.unlockGadget(id)
	GameWorld.unlockGadget(id)
	var data = Data.gadgets.get(id, {})
	Level.keeper.unlockGadget(data)
	Level.dome.unlockGadget(data)
	Level.map.unlockGadget(data)
	Level.hud.addHudElement(data)

func startEffect(id:String, args: = []):
	match id:
		"screenGlitter":
			$ScreenGlitterParticles.emitting = true
		"dissolveTransition":
			var img = get_viewport().get_texture().get_data()
			img.flip_y()
			yield (get_tree(), "idle_frame")
			var tex = ImageTexture.new()
			tex.create_from_image(img)
			$Canvas / ScreenCover.texture = tex
			$Canvas / ScreenCover.visible = true
			$Canvas / ScreenCover.material.set_shader_param("burn_position", 0.0)
			$Tween.interpolate_method(self, "setDissolveShader", 0, 1.0, args[0])
			$Tween.start()
			$Camera2D.jump()

func setDissolveShader(f:float):
	$Canvas / ScreenCover.material.set_shader_param("burn_position", f)

func stopEffect(id:String):
	match id:
		"screenGlitter":
			$ScreenGlitterParticles.emitting = false

func unpause(byPlayer: = true):
	if byPlayer or not pausedByPlayer:
		pausedByPlayer = false
		GameWorld.unpause()
		$Canvas / PauseLabel.moveOut()
		$Tween.resume_all()
		get_tree().call_group("monster", "unpause")

func pause(byPlayer: = true):
	pausedByPlayer = byPlayer
	GameWorld.pause()
	$Canvas / PauseLabel.moveIn()
	$Tween.stop_all()
	get_tree().call_group("monster", "pause")

func _on_MuteAmbienceButton_pressed():
	AudioServer.set_bus_volume_db(1, - 90 if find_node("MuteAmbienceButton").pressed else 0)

func _on_MuteAllButton_pressed():
	AudioServer.set_bus_volume_db(0, - 90 if find_node("MuteAllButton").pressed else 0)

func _on_SwitchModeButton_pressed():
	if OS.window_fullscreen:
		OS.window_fullscreen = false
		find_node("SwitchModeButton").text = "fullscreen"
	else :
		OS.window_fullscreen = true
		find_node("SwitchModeButton").text = "windowed"

func sendCycleChangeEvent(cycle:int):
	var data: = {
	"cycle":cycle, 
	"health":Data.of("dome.health"), 
	"runtime":GameWorld.runTime, 
	"timebetweenwaves":GameWorld.getTimeBetweenWaves(), 
	"a":Data.getInventory("gadget"), 
	"i":Data.getInventory(CONST.IRON), 
	"w":Data.getInventory(CONST.WATER), 
	"s":Data.getInventory(CONST.SAND), 
	"fi":Data.getInventory("floatingiron"), 
	"fw":Data.getInventory("floatingwater"), 
	"fs":Data.getInventory("floatingsand"), 
	"ti":Data.getInventory("totaliron"), 
	"tw":Data.getInventory("totalwater"), 
	"ts":Data.getInventory("totalsand"), 
	}
	
	var shield = Data.ofOr("shield.absorbeddamage", 0)
	if shield > 0:
		data["shieldeff"] = shield
	var repellent = Data.ofOr("repellent.delayedcycles", 0)
	if repellent > 0:
		data["repellenteff"] = repellent
	var orchard = Data.ofOr("orchard.buffedcycles", 0)
	if orchard > 0:
		data["orchardeff"] = orchard
	
	Level.mode.addCycleData(data)
	
	Backend.event("cycle_change", data)

func propertyChanged(property:String, oldValue, newValue):
	match property:
		"monsters.cycle":
			sendCycleChangeEvent(newValue)
		"monsters.wavepresent":
			if newValue:
				Audio.startBattleMusic()
				Audio.sound("wavestart")
			else :
				Audio.stopBattleMusic()
				
				if shouldPlayMusic:
					return 
				
				GameWorld.musicCountdown -= 1
				if GameWorld.musicCountdown <= 0:
					if Options.cyclesWithoutMusic > 0:
						GameWorld.musicCountdown = Options.cyclesWithoutMusic + randi() % Options.cyclesWithoutMusic
					shouldPlayMusic = true
		"keeper.insidestation":
			if newValue:
				var i = preload("res://content/dome/station/StationInputProcessor.gd").new()
				i.popup = find_node("StationPopup")
				i.connect("startBattleInput", self, "startBattleInput", [Level.keeper])
				i.connect("startUpgradesInput", self, "startUpgradesInput", [Level.keeper])
				i.connect("directlyEnded", Level.keeper, "exitStation")
				i.integrate(self)
			else :
				unpause()

var endingPanel
func showEndingPanel(popup):
	self.endingPanel = popup
	find_node("Overlay").showOverlay()
	endingPanel.visible = false
	$Canvas.add_child(popup)
	endingPanel.rect_position.y += endingPanel.get_viewport_rect().size.y
	endingPanel.visible = true
	endingPanel.call_deferred("moveIn")

func removeEndingPanel():
	endingPanel.moveOut()
	find_node("Overlay").hideOverlay()
	endingPanel = null

func getVignette():
	return $VignetteLayer / Vignette
