extends SceneTree

func _init() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var errors: PackedStringArray = PackedStringArray()
	var t0: int = Time.get_ticks_msec()

	print("[1/7] Memeriksa MainMenu UI, profil, & lencana VerifiedBadge...")
	var vb_script: Variant = load("res://scripts/ui/VerifiedBadge.gd")
	if vb_script == null:
		errors.append("VerifiedBadge.gd failed to load")
	else:
		var vb_ctrl: Control = vb_script.call("create_control", 16.0) as Control
		var vb_tex: Texture2D = vb_script.call("get_texture", 32) as Texture2D
		if vb_ctrl == null or vb_tex == null or vb_tex.get_width() != 32:
			errors.append("VerifiedBadge vector control or texture invalid")
		if vb_ctrl:
			vb_ctrl.queue_free()

	var mm_scene: PackedScene = load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var mm: Node = mm_scene.instantiate()
	root.add_child(mm)
	await process_frame

	var stb: VBoxContainer = mm.get("settings_tab_box") as VBoxContainer
	if stb == null or stb.get_child_count() <= 10:
		errors.append("MainMenu settings_tab_box missing or too few children")
	var uname_in: LineEdit = mm.get("profile_username_input") as LineEdit
	if uname_in == null or uname_in.editable:
		errors.append("profile_username_input missing or editable")

	var am: Variant = root.get_node_or_null("AccountManager")
	var gm: Variant = root.get_node_or_null("GameManager")
	if am == null or gm == null:
		errors.append("AccountManager or GameManager missing")
	else:
		print("[2/7] Memeriksa sinkronisasi realtime (koin 99999 & centang biru)...")
		am.set("is_logged_in", true)
		am.set("is_guest_mode", false)
		am.set("session_token", "dummy-token")
		am.set("user_id", "00000000-0000-0000-0000-000000000001")
		am.set("username", "TestUser_99")
		gm.set("coins", 100)
		gm.set("save_seq", 5)
		am.call("apply_live_server_user", {
			"id": "00000000-0000-0000-0000-000000000001",
			"username": "TestUser_99",
			"displayName": "Pemburu Test",
			"bio": "Bio",
			"avatarUrl": "preset:keris",
			"role": "player",
			"isVerified": true,
			"coins": 99999,
			"totalWins": 3,
			"extraLives": 2,
			"saveSeq": 105
		})
		if int(gm.get("coins")) != 99999:
			errors.append("apply_live_server_user did not update coins to 99999: " + str(gm.get("coins")))
		if int(gm.get("save_seq")) != 105:
			errors.append("save_game_data incremented save_seq during cloud pull! expected 105, got " + str(gm.get("save_seq")))
		if not bool(am.get("is_verified")):
			errors.append("is_verified did not become true after apply_live_server_user")
		mm.call("_refresh_account_ui")
		var badge_ctrl: Control = mm.get("account_chip_badge") as Control
		var top_badge: Control = mm.get("top_account_badge") as Control
		if badge_ctrl == null or not badge_ctrl.visible or top_badge == null or not top_badge.visible:
			errors.append("MainMenu verified badges not visible for verified user")
	mm.queue_free()

	print("[3/7] Memeriksa ProfanityFilter & rewrite nama file avatar...")
	var pf: Variant = load("res://scripts/systems/ProfanityFilter.gd")
	if pf == null:
		errors.append("ProfanityFilter.gd failed to load")
	else:
		if str(pf.call("censor", "halo anjing b4ngs4t!")) != "halo *** ***!":
			errors.append("ProfanityFilter Indonesian failed")
		if str(pf.call("censor", "what the f*ck and fuuuuck puta くそ 씨발 блять شرموطة")) != "what the *** and *** *** *** *** *** ***":
			errors.append("ProfanityFilter multilingual failed")
		if str(pf.call("censor", "classic assassin night malam lampor")) != "classic assassin night malam lampor":
			errors.append("ProfanityFilter false positive")
	if am != null:
		var bad_uname_err: String = str(am.call("validate_credentials_format", "anjing_123", "PassAman123", true))
		if bad_uname_err.is_empty():
			errors.append("validate_credentials_format did not reject profane username")
		var rewritten_fname: String = str(am.call("generate_safe_avatar_filename", "jpg"))
		var rx_av := RegEx.new()
		rx_av.compile("^avatar_[a-f0-9]{16}\\.jpg$")
		if rx_av.search(rewritten_fname) == null:
			errors.append("Invalid rewritten avatar filename: " + rewritten_fname)

	print("[4/7] Memeriksa AdminPanel role gate & Sandbox host...")
	var ap_node: Node = gm.get("admin_panel") if gm != null else null
	if ap_node == null:
		errors.append("AdminPanel is null")
	else:
		am.set("role", "player")
		ap_node.call("toggle_panel")
		var ap_root: Control = ap_node.get("root_control") as Control
		if ap_root != null and ap_root.visible:
			errors.append("AdminPanel opened for non-admin player!")
		am.set("role", "admin")
		ap_node.call("toggle_panel")
		if ap_root == null or not ap_root.visible:
			errors.append("AdminPanel did not open for admin!")
		ap_node.call("close_panel")
		am.set("role", "player")

	var mp: Variant = root.get_node_or_null("MultiplayerManager")
	if gm != null and mp != null:
		mp.set("is_online_session", true)
		mp.set("is_room_owner", true)
		mp.set("session_mode", "sandbox")
		mp.set("current_room", {"mode": "sandbox"})
		gm.set("is_sandbox_mode", true)
		gm.set("current_state", 1)
		if not bool(gm.call("is_sandbox_owner_active")):
			errors.append("Sandbox host detection failed")
		mp.call("reset_to_singleplayer")
		gm.set("is_sandbox_mode", false)
		gm.set("current_state", 0)

	print("[5/7] Memeriksa VillageMap + Grafik Low + Hutan WorldBorder + RemotePlayer...")
	var sm: Variant = root.get_node_or_null("SettingsManager")
	if sm != null:
		sm.call("set_graphics_quality", "low")
	var vm_scene: PackedScene = load("res://scenes/world/VillageMap.tscn") as PackedScene
	var vm: Node = vm_scene.instantiate()
	root.add_child(vm)
	await process_frame
	await process_frame
	if sm != null:
		sm.call("_apply_graphics_quality")

	var dlight: DirectionalLight3D = vm.get_node_or_null("MoonLight") as DirectionalLight3D
	if dlight and dlight.shadow_enabled:
		errors.append("Low graphics did not disable DirectionalLight3D shadow_enabled")
	var wenv: WorldEnvironment = vm.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if wenv and wenv.environment and wenv.environment.background_mode != Environment.BG_COLOR:
		errors.append("Low graphics did not switch WorldEnvironment background_mode to BG_COLOR")
	var hud_node: Node = vm.get_node_or_null("HUD")
	if hud_node == null:
		errors.append("VillageMap HUD missing")
	else:
		var ho: CanvasItem = hud_node.get("post_process_rect") as CanvasItem
		if ho != null and ho.visible:
			errors.append("Low graphics did not hide HorrorOverlay")
		hud_node.call("_begin_cutscene_ui", "victory", "VictoryCutscene", "FAJAR MENYINGSING: KUTUKAN MUSNAH", Color.GOLD, "Sub", true)
		var ov: Control = hud_node.get("descent_cutscene_overlay") as Control
		var t_lbl: Label = ov.get_node_or_null("CutsceneTitle") as Label if ov else null
		if t_lbl == null or absf((t_lbl.anchor_left + t_lbl.anchor_right) * 0.5 - 0.5) > 0.001:
			errors.append("CutsceneTitle not centered")

	var wb: Node = vm.get_node_or_null("WorldBorder")
	if wb == null or wb.get_node_or_null("ForestGroundSkirt") == null or wb.get_node_or_null("ForestTrunks") == null:
		errors.append("WorldBorder forest perimeter missing")
	else:
		for i: int in range(4):
			if wb.get_node_or_null("BorderWall" + str(i)) == null:
				errors.append("Missing BorderWall" + str(i))

	var rp_script: Script = load("res://scripts/player/RemotePlayer.gd") as Script
	var rp: Node3D = rp_script.new() as Node3D
	vm.add_child(rp)
	rp.call("apply_network_state", {"userId": "u2", "username": "PemainTes", "isHost": true, "isVerified": true, "pos": [0.0, 0.0, 2.0]})
	var rp_vs: Sprite3D = rp.get("verified_sprite") as Sprite3D
	if rp_vs == null or not rp_vs.visible or rp_vs.texture == null:
		errors.append("RemotePlayer VerifiedSprite missing or hidden for verified player")
	vm.queue_free()

	print("[6/7] Memeriksa VictoryScreen & GameOverScreen centering...")
	var vs: Control = (load("res://scenes/ui/VictoryScreen.tscn") as PackedScene).instantiate() as Control
	root.add_child(vs)
	await process_frame
	if (vs.get("title_label") as Label).horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		errors.append("VictoryScreen title_label not centered")
	vs.queue_free()

	var go: Control = (load("res://scenes/ui/GameOverScreen.tscn") as PackedScene).instantiate() as Control
	root.add_child(go)
	await process_frame
	if (go.get("title_label") as Label).horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		errors.append("GameOverScreen title_label not centered")
	go.queue_free()

	print("[7/7] Selesai dalam %d ms." % (Time.get_ticks_msec() - t0))
	if errors.is_empty():
		print("ALL_CHECKS_PASSED")
		quit(0)
	else:
		for e: String in errors:
			printerr("CHECK_FAILED: " + e)
		quit(1)
