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
	var fr_ov: Control = mm.get("friends_overlay") as Control
	var fr_panel: Control = mm.get("friends_panel") as Control
	var fr_tab_list: Button = mm.get("friends_tab_list_btn") as Button
	var fr_tab_add: Button = mm.get("friends_tab_add_btn") as Button
	var fr_list_box: Control = mm.get("friends_list_tab_box") as Control
	var fr_add_box: Control = mm.get("friends_add_tab_box") as Control
	var fr_req_list: Control = mm.get("friends_requests_list") as Control
	var fr_list: Control = mm.get("friends_my_list") as Control
	var dir_list: Control = mm.get("friends_directory_list") as Control
	if fr_ov == null or fr_panel == null or fr_tab_list == null or fr_tab_add == null or fr_list_box == null or fr_add_box == null or fr_req_list == null or fr_list == null or dir_list == null:
		errors.append("MainMenu friends_modal or friends tabs controls missing")
	else:
		if not fr_list_box.visible or fr_add_box.visible:
			errors.append("MainMenu friends modal did not default to Daftar Teman tab")
		mm.call("_select_friends_tab", "add")
		if fr_list_box.visible or not fr_add_box.visible:
			errors.append("MainMenu friends modal failed switching to Tambah Teman tab")
		mm.call("_select_friends_tab", "list")
		if not fr_list_box.visible or fr_add_box.visible:
			errors.append("MainMenu friends modal failed switching back to Daftar Teman tab")

	var main_content_node: Node = mm.get("main_content") as Node
	var menu_buttons_node: Node = main_content_node.get_node_or_null("MenuButtons") if main_content_node != null else null
	if menu_buttons_node == null:
		errors.append("MainMenu MenuButtons missing")
	else:
		for mb_child: Node in menu_buttons_node.get_children():
			if mb_child is Button:
				var mb_upper: String = (mb_child as Button).text.to_upper()
				if mb_upper.contains("HAK CIPTA") or mb_upper.contains("CREDITS"):
					errors.append("MainMenu MenuButtons still contains forbidden credits button: " + (mb_child as Button).text)
				if mb_upper.contains("PANDUAN") or mb_upper.contains("GUIDE"):
					errors.append("MainMenu MenuButtons settings/nav button still contains guide text: " + (mb_child as Button).text)

	var ver_lbl: Label = mm.get("version_label") as Label
	if ver_lbl == null or ver_lbl.get_parent() != mm or not is_equal_approx(ver_lbl.anchor_left, 1.0) or not is_equal_approx(ver_lbl.anchor_top, 1.0) or not is_equal_approx(ver_lbl.anchor_right, 1.0) or not is_equal_approx(ver_lbl.anchor_bottom, 1.0):
		errors.append("MainMenu version_label missing, wrong parent, or not anchored bottom-right")
	elif ver_lbl.text != "v1.3.1" or str(ProjectSettings.get_setting("application/config/version", "")) != "1.3.1":
		errors.append("Version mismatch: project.godot=%s, version_label=%s" % [str(ProjectSettings.get_setting("application/config/version", "")), ver_lbl.text])

	if mm.get("account_chip_panel") != null or mm.get("account_chip_badge") != null:
		errors.append("MainMenu account_chip_panel/account_chip_badge above MULAI PERMAINAN must be removed")

	var icon_rail: Control = mm.get("right_icon_rail") as Control
	var rail_friends_btn: Button = mm.get("friends_button") as Button
	var rail_inbox_btn: Button = mm.get("inbox_button") as Button
	var rail_fix_btn: Button = mm.get("fix_notes_button") as Button
	var rail_guide_btn: Button = mm.get("guide_button") as Button
	if icon_rail == null or not is_equal_approx(icon_rail.anchor_left, 1.0) or not is_equal_approx(icon_rail.anchor_right, 1.0) or not is_equal_approx(icon_rail.anchor_top, 0.5) or not is_equal_approx(icon_rail.anchor_bottom, 0.5):
		errors.append("MainMenu right_icon_rail missing or not anchored center-right")
	elif icon_rail.get_child_count() != 4:
		errors.append("MainMenu right_icon_rail child count expected 4, got " + str(icon_rail.get_child_count()))
	else:
		var expected_rail_btns: Array = [rail_friends_btn, rail_inbox_btn, rail_fix_btn, rail_guide_btn]
		for r_btn_var: Variant in expected_rail_btns:
			var r_btn: Button = r_btn_var as Button
			if r_btn == null or r_btn.get_parent() != icon_rail or r_btn.text != "" or not (r_btn.get_node_or_null("IconDraw") is Control):
				errors.append("MainMenu right_icon_rail button invalid, has non-empty text, or missing IconDraw")

	var inb_ov: Control = mm.get("inbox_overlay") as Control
	var inb_panel: Control = mm.get("inbox_panel") as Control
	if inb_ov == null or inb_panel == null:
		errors.append("MainMenu inbox_overlay or inbox_panel missing")
	else:
		mm.call("_open_inbox_modal")
		if not inb_ov.visible:
			errors.append("MainMenu _open_inbox_modal did not make inbox_overlay visible")
		inb_ov.visible = false

	var tr_bar: Control = mm.get("top_right_bar") as Control
	var acc_chip: PanelContainer = mm.get("top_account_chip") as PanelContainer
	var acc_avatar: TextureRect = mm.get("top_account_avatar_rect") as TextureRect
	var acc_lbl: Label = mm.get("top_account_label") as Label
	var exit_btn: Button = mm.get("exit_button") as Button
	if mm.get("admin_panel_btn") != null or mm.get("account_btn") != null:
		errors.append("MainMenu deprecated admin_panel_btn or account_btn must be null")
	if tr_bar == null or acc_chip == null or acc_avatar == null or acc_lbl == null or exit_btn == null:
		errors.append("MainMenu top_right_bar, top_account_chip, top_account_avatar_rect, top_account_label, or exit_button missing")
	else:
		if exit_btn.get_parent() != tr_bar or acc_chip.get_parent() != tr_bar or exit_btn.get_index() != acc_chip.get_index() + 1 or exit_btn.text != "" or not (exit_btn.get_node_or_null("IconDraw") is Control):
			errors.append("MainMenu exit_button must be immediately right of top_account_chip in top_right_bar with empty text and IconDraw")
		if acc_avatar.texture == null:
			errors.append("MainMenu top_account_avatar_rect has null texture")
		var forbidden_chip_tokens: Array[String] = ["AKUN:", "ACCOUNT:", "[ONLINE]", "[OFFLINE]", "[TAMU]", "[GUEST]"]
		for tok: String in forbidden_chip_tokens:
			if acc_lbl.text.contains(tok):
				errors.append("MainMenu top_account_label contains forbidden token: " + tok)
		var gm_top: Variant = root.get_node_or_null("GameManager")
		var am_top: Variant = gm_top.call("get_account_manager") if gm_top != null and gm_top.has_method("get_account_manager") else null
		if am_top != null:
			var orig_top_logged_in: bool = bool(am_top.get("is_logged_in"))
			var orig_top_guest: bool = bool(am_top.get("is_guest_mode"))
			var orig_top_token: String = str(am_top.get("session_token"))
			var orig_top_uname: String = str(am_top.get("username"))
			var orig_top_disp: String = str(am_top.get("display_name"))
			am_top.set("is_logged_in", true)
			am_top.set("is_guest_mode", false)
			am_top.set("session_token", "tok")
			am_top.set("username", "lordreyid")
			am_top.set("display_name", "Lord Rey")
			mm.call("_refresh_account_ui")
			if acc_lbl.text != "Lord Rey":
				errors.append("MainMenu top_account_label expected 'Lord Rey' for mock logged-in user, got: " + acc_lbl.text)
			if acc_avatar.texture == null:
				errors.append("MainMenu top_account_avatar_rect null after mock login refresh")
			for tok: String in forbidden_chip_tokens:
				if acc_lbl.text.contains(tok):
					errors.append("MainMenu top_account_label contains forbidden token after login: " + tok)
			am_top.set("is_logged_in", orig_top_logged_in)
			am_top.set("is_guest_mode", orig_top_guest)
			am_top.set("session_token", orig_top_token)
			am_top.set("username", orig_top_uname)
			am_top.set("display_name", orig_top_disp)
			mm.call("_refresh_account_ui")

	if float(mm.call("_compute_menu_column_width", Vector2(390.0, 844.0), true)) > 300.0:
		errors.append("MainMenu _compute_menu_column_width exceeds 300.0 on 390x844 mobile portrait")

	var acc_close_btn: Button = mm.get("account_close_btn") as Button
	if acc_close_btn == null or acc_close_btn.text != "" or not (acc_close_btn.get_node_or_null("IconDraw") is Control):
		errors.append("MainMenu account_close_btn must be icon-only X button (empty text + IconDraw)")
	for ov_name: String in ["friends_overlay", "inbox_overlay", "settings_overlay", "guide_overlay", "shop_overlay", "fix_notes_overlay", "player_profile_overlay"]:
		var ov_ctrl: Control = mm.get(ov_name) as Control
		var x_btns: Array[Node] = ov_ctrl.find_children("IconDraw", "Control", true, false) if ov_ctrl != null else []
		if x_btns.is_empty():
			errors.append("MainMenu modal missing header X IconDraw close button: " + ov_name)

	var pp_ov: ColorRect = mm.get("player_profile_overlay") as ColorRect
	var pp_avatar_rect: TextureRect = mm.get("player_profile_avatar_rect") as TextureRect
	var pp_disp_lbl: Label = mm.get("player_profile_display_label") as Label
	var pp_uname_lbl: Label = mm.get("player_profile_username_label") as Label
	var pp_bio_lbl: Label = mm.get("player_profile_bio_label") as Label
	if pp_ov == null or pp_avatar_rect == null or pp_disp_lbl == null or pp_uname_lbl == null or pp_bio_lbl == null:
		errors.append("MainMenu player_profile_overlay or its profile labels/avatar_rect missing")
	elif fr_list != null and dir_list != null:
		var mock_friends: Array = [{
			"id": "u_fr_1",
			"username": "temandesa",
			"displayName": "Teman Desa",
			"avatarUrl": "preset:keris",
			"bio": "Penjaga obor desa",
			"totalWins": 4,
			"isVerified": false,
			"isOnline": true
		}]
		var mock_dir: Array = [{
			"id": "u_dir_1",
			"username": "penjagadesa",
			"displayName": "Penjaga Desa",
			"avatarUrl": "preset:keris",
			"bio": "Penjaga obor desa",
			"totalWins": 7,
			"isVerified": true,
			"isOnline": true
		}]
		mm.call("_render_friends_modal", mock_friends, mock_dir)
		await process_frame
		var fr_thumbs: Array[Node] = fr_list.find_children("*", "TextureRect", true, false)
		var dir_thumbs: Array[Node] = dir_list.find_children("*", "TextureRect", true, false)
		var fr_has_tex: bool = false
		for ft_node: Node in fr_thumbs:
			var ft_rect: TextureRect = ft_node as TextureRect
			if ft_rect != null and ft_rect.texture != null:
				fr_has_tex = true
				break
		var dir_has_tex: bool = false
		for dt_node: Node in dir_thumbs:
			var dt_rect: TextureRect = dt_node as TextureRect
			if dt_rect != null and dt_rect.texture != null:
				dir_has_tex = true
				break
		if not fr_has_tex:
			errors.append("MainMenu friends_my_list missing TextureRect avatar thumbnail with non-null texture")
		if not dir_has_tex:
			errors.append("MainMenu friends_directory_list missing TextureRect avatar thumbnail with non-null texture")
		mm.call("_open_player_profile_modal", mock_dir[0])
		if not pp_ov.visible:
			errors.append("MainMenu _open_player_profile_modal did not make player_profile_overlay visible")
		if pp_disp_lbl.text != "Penjaga Desa":
			errors.append("MainMenu player_profile_display_label expected 'Penjaga Desa', got: " + pp_disp_lbl.text)
		if not pp_uname_lbl.text.contains("@penjagadesa"):
			errors.append("MainMenu player_profile_username_label missing @penjagadesa, got: " + pp_uname_lbl.text)
		if pp_bio_lbl.text != "Penjaga obor desa":
			errors.append("MainMenu player_profile_bio_label expected 'Penjaga obor desa', got: " + pp_bio_lbl.text)
		if pp_avatar_rect.texture == null:
			errors.append("MainMenu player_profile_avatar_rect texture is null")
		pp_ov.visible = false
		mm.call("_render_friends_modal", [], [])
		await process_frame

	var settings_ov: Control = mm.get("settings_overlay") as Control
	var guide_ov: Control = mm.get("guide_overlay") as Control
	var guide_scr: ScrollContainer = mm.get("guide_scroll") as ScrollContainer
	var guide_rt: RichTextLabel = mm.get("guide_rich_text") as RichTextLabel
	if settings_ov == null or guide_ov == null or guide_scr == null or guide_rt == null or rail_guide_btn == null:
		errors.append("MainMenu settings/guide separation controls missing")
	else:
		if settings_ov.is_ancestor_of(guide_rt):
			errors.append("MainMenu settings_overlay still contains guide_rich_text")
		if not guide_ov.is_ancestor_of(guide_rt):
			errors.append("MainMenu guide_overlay does not contain guide_rich_text")
		settings_ov.visible = false
		guide_ov.visible = false
		rail_guide_btn.pressed.emit()
		if not guide_ov.visible or settings_ov.visible:
			errors.append("MainMenu guide_button did not open guide_overlay without opening settings_overlay")
		guide_ov.visible = false

	var dv_chk: CheckButton = mm.get("dialog_voice_check") as CheckButton
	if dv_chk == null or stb == null or not stb.is_ancestor_of(dv_chk) or not dv_chk.button_pressed:
		errors.append("MainMenu dialog_voice_check missing, outside settings_tab_box, or not enabled by default")
	var mm_mic_dev_opt: OptionButton = mm.get("mic_device_option") as OptionButton
	var mm_mic_test_btn: Button = mm.get("mic_test_button") as Button
	var mm_mic_status_lbl: Label = mm.get("mic_status_label") as Label
	var mm_mic_lvl_bar: ProgressBar = mm.get("mic_level_bar") as ProgressBar
	if mm_mic_dev_opt == null or mm_mic_test_btn == null or mm_mic_status_lbl == null or mm_mic_lvl_bar == null or stb == null or not stb.is_ancestor_of(mm_mic_test_btn):
		errors.append("MainMenu Settings mic controls missing or outside settings_tab_box")
	else:
		mm_mic_test_btn.pressed.emit()
		var mp_mm: Variant = mm.call("_mp")
		if mp_mm == null or not bool(mp_mm.call("is_mic_enabled")):
			errors.append("MainMenu mic_test_button did not enable mic in headless mode")
		mm.call("_stop_menu_mic_test")
		if mp_mm != null and bool(mp_mm.call("is_mic_enabled")):
			errors.append("MainMenu _stop_menu_mic_test did not disable mic")
	var open_kb_btn: Button = mm.get("open_keybinds_button") as Button
	var kb_ov: Control = mm.get("keybinds_overlay") as Control
	var kb_scr: ScrollContainer = mm.get("keybinds_scroll") as ScrollContainer
	var kb_btns_var: Variant = mm.get("_keybind_buttons")
	if open_kb_btn == null or stb == null or not stb.is_ancestor_of(open_kb_btn):
		errors.append("MainMenu open_keybinds_button missing or not inside settings_tab_box")
	elif kb_ov == null or kb_scr == null or not (kb_btns_var is Dictionary) or (kb_btns_var as Dictionary).size() != 15:
		errors.append("MainMenu keybinds_overlay, keybinds_scroll, or 15 _keybind_buttons missing")
	else:
		for kb_val: Variant in (kb_btns_var as Dictionary).values():
			var kb_btn: Control = kb_val as Control
			if kb_btn == null or not kb_ov.is_ancestor_of(kb_btn) or (settings_ov != null and settings_ov.is_ancestor_of(kb_btn)):
				errors.append("MainMenu keybind button must live inside keybinds_overlay and outside settings_overlay")
				break
		if settings_ov != null:
			settings_ov.visible = false
		kb_ov.visible = false
		open_kb_btn.pressed.emit()
		if not kb_ov.visible or (settings_ov != null and settings_ov.visible):
			errors.append("MainMenu open_keybinds_button did not open keybinds_overlay without settings_overlay")
		kb_ov.visible = false

	var shop_scr: ScrollContainer = mm.get("shop_scroll") as ScrollContainer
	if shop_scr == null:
		errors.append("MainMenu shop_scroll missing")
	else:
		var shop_buy_btns: Array[Node] = shop_scr.find_children("*", "Button", true, false)
		if shop_buy_btns.size() != 8:
			errors.append("MainMenu shop_scroll expected 8 buy buttons, got " + str(shop_buy_btns.size()))
		for sb_node: Node in shop_buy_btns:
			var sb_btn: Button = sb_node as Button
			if sb_btn == null:
				continue
			var price_token: String = sb_btn.text.strip_edges().split(" ")[0]
			if not price_token.is_valid_int() or int(price_token.to_int()) <= 1500:
				errors.append("MainMenu shop buy button price must be > 1500, got: " + sb_btn.text)
	var sp_chk: CheckButton = mm.get("friend_join_sp_check") as CheckButton
	if sp_chk == null or not sp_chk.button_pressed:
		errors.append("MainMenu friend_join_sp_check missing or not enabled by default")

	var am: Variant = root.get_node_or_null("AccountManager")
	var sm_menu: Variant = root.get_node_or_null("SettingsManager")
	var gm: Variant = root.get_node_or_null("GameManager")
	if am == null or gm == null:
		errors.append("AccountManager or GameManager missing")
	else:
		var expected_shop_combos: Array = [
			["baterai", 1], ["energy_drink", 1], ["jamu", 1], ["jamu", 3],
			["kentongan", 1], ["extra_life", 1], ["extra_life", 2], ["extra_life", 3]
		]
		for combo: Array in expected_shop_combos:
			var item_id: String = str(combo[0])
			var qty: int = int(combo[1])
			var item_price: int = int(gm.call("get_shop_item_price", item_id, qty))
			if item_price <= 1500:
				errors.append("Shop item price must be > 1500 for %s x%d, got %d" % [item_id, qty, item_price])

		var prev_am_logged_in: bool = bool(am.get("is_logged_in"))
		am.set("is_logged_in", false)
		var orig_coins: int = int(gm.get("coins"))
		var orig_extra_lives: int = int(gm.get("extra_lives"))
		var orig_stash: Dictionary = (gm.get("item_stash") as Dictionary).duplicate(true)
		var orig_save_seq: int = int(gm.get("save_seq"))
		var test_stash: Dictionary = orig_stash.duplicate(true)
		test_stash["baterai"] = 0
		gm.set("item_stash", test_stash)
		gm.set("coins", 1500)
		var fail_buy: Dictionary = gm.call("purchase_shop_item", "baterai", 1)
		if bool(fail_buy.get("success", true)) or int(gm.get("coins")) != 1500:
			errors.append("purchase_shop_item('baterai', 1) should fail when coins=1500")
		gm.set("coins", 2000)
		var bat_price: int = int(gm.call("get_shop_item_price", "baterai", 1))
		var ok_buy: Dictionary = gm.call("purchase_shop_item", "baterai", 1)
		if not bool(ok_buy.get("success", false)) or int(gm.get("coins")) != 2000 - bat_price:
			errors.append("purchase_shop_item('baterai', 1) failed or deducted wrong coins when coins=2000")
		gm.set("coins", orig_coins)
		gm.set("extra_lives", orig_extra_lives)
		gm.set("item_stash", orig_stash)
		gm.set("save_seq", orig_save_seq)
		gm.call("save_game_data", true, false, false)
		am.set("is_logged_in", prev_am_logged_in)

		if sm_menu == null or not bool(sm_menu.get("allow_friend_join_singleplayer")):
			errors.append("SettingsManager allow_friend_join_singleplayer must default to true")
		else:
			sm_menu.call("set_allow_friend_join_singleplayer", false)
			if bool(sm_menu.get("allow_friend_join_singleplayer")):
				errors.append("SettingsManager set_allow_friend_join_singleplayer(false) failed")
			sm_menu.call("set_allow_friend_join_singleplayer", true)

		var aud_mgr: Variant = root.get_node_or_null("AudioManager")
		if sm_menu == null or not ("dialog_voice_enabled" in sm_menu) or not sm_menu.has_method("set_dialog_voice_enabled") or not sm_menu.has_signal("dialog_voice_changed"):
			errors.append("SettingsManager dialog_voice_enabled property, setter, or signal missing")
		elif not bool(sm_menu.get("dialog_voice_enabled")):
			errors.append("SettingsManager dialog_voice_enabled must default to true")
		elif aud_mgr == null:
			errors.append("AudioManager missing during dialog_voice_enabled check")
		else:
			var orig_dv: bool = bool(sm_menu.get("dialog_voice_enabled"))
			sm_menu.call("set_dialog_voice_enabled", false)
			if bool(sm_menu.get("dialog_voice_enabled")) or (dv_chk != null and dv_chk.button_pressed):
				errors.append("SettingsManager set_dialog_voice_enabled(false) did not update state or MainMenu checkbox")
			if bool(aud_mgr.call("play_voice_by_id", "any_clip")) or bool(aud_mgr.call("play_voice_for_dialog_text", "test")):
				errors.append("AudioManager played voice while dialog_voice_enabled was false")
			sm_menu.call("set_dialog_voice_enabled", orig_dv)
			if not bool(sm_menu.get("dialog_voice_enabled")) or (dv_chk != null and not dv_chk.button_pressed):
				errors.append("SettingsManager failed to restore dialog_voice_enabled to true")

			var orig_vo_lang: String = str(sm_menu.get("language"))
			var orig_vo_model: String = str(sm_menu.get("character_model"))
			sm_menu.call("set_language", "en_US")
			for gender_tag: String in ["male", "female"]:
				sm_menu.call("set_character_model", gender_tag)
				var cands: Array = aud_mgr.call("_voice_candidate_paths", "vo_sanity_mid_01") as Array
				var expected_prefix: String = "res://assets/audio/voice/en/%s/" % gender_tag
				var found_en_cand: bool = false
				for cand_var: Variant in cands:
					var cand_path: String = str(cand_var)
					if cand_path.begins_with(expected_prefix) and FileAccess.file_exists(cand_path):
						found_en_cand = true
						break
				if not found_en_cand:
					errors.append("AudioManager _voice_candidate_paths missing existing EN clip for vo_sanity_mid_01 (%s)" % gender_tag)
			var manifest_raw: String = FileAccess.get_file_as_string("res://assets/audio/voice/voice_manifest.json")
			var manifest_parsed: Variant = JSON.parse_string(manifest_raw)
			if not (manifest_parsed is Dictionary) or not ((manifest_parsed as Dictionary).get("clips") is Array):
				errors.append("voice_manifest.json missing or failed to parse clips array")
			else:
				var clips_arr: Array = (manifest_parsed as Dictionary).get("clips") as Array
				if clips_arr.is_empty():
					errors.append("voice_manifest.json clips array is empty")
				for clip_var: Variant in clips_arr:
					if not (clip_var is Dictionary):
						continue
					var clip_d: Dictionary = clip_var as Dictionary
					var clip_id: String = str(clip_d.get("id", ""))
					var speaker: String = str(clip_d.get("speaker", "Narrator"))
					var stem: String = str(clip_d.get("filename", "")).strip_edges().get_basename()
					if stem.is_empty():
						errors.append("voice_manifest.json clip missing filename: " + clip_id)
						continue
					var role_dirs: Array = ["male", "female"] if speaker.begins_with("Player") else ["narrator"]
					for r_dir_var: Variant in role_dirs:
						var r_dir: String = str(r_dir_var)
						var wav_p: String = "res://assets/audio/voice/en/%s/%s.wav" % [r_dir, stem]
						var mp3_p: String = "res://assets/audio/voice/en/%s/%s.mp3" % [r_dir, stem]
						if not FileAccess.file_exists(wav_p) and not FileAccess.file_exists(mp3_p):
							errors.append("Missing EN voice file for %s (%s): %s(.wav/.mp3)" % [clip_id, speaker, wav_p.get_basename()])
			sm_menu.call("set_language", orig_vo_lang)
			sm_menu.call("set_character_model", orig_vo_model)

		# Verify session persistence keeps optimistic logged-in state across empty storage load / offline verification
		am.set("session_token", "persist-test-token")
		am.set("is_logged_in", true)
		am.set("is_guest_mode", false)
		am.set("account_gate_resolved", true)
		if not bool(am.call("can_access_online_modes")):
			errors.append("AccountManager can_access_online_modes failed with persisted token")
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
		var top_badge: Control = mm.get("top_account_badge") as Control
		if top_badge == null or not top_badge.visible or not acc_chip.visible:
			errors.append("MainMenu top_account_badge or top_account_chip not visible for verified user")
		am.set("incoming_friend_requests", [{"id": "u99", "username": "ReqUser"}])
		mm.call("_refresh_friends_button_badge")
		if rail_friends_btn == null or rail_friends_btn.text != "" or not bool(mm.get("_friends_has_pending_dot")):
			errors.append("MainMenu friends_button pending dot or empty text check failed")
		am.set("incoming_friend_requests", [])
		mm.call("_refresh_friends_button_badge")

		var sb_mm: Node = root.get_node_or_null("SignalBus")
		var inb_list: VBoxContainer = mm.get("inbox_list") as VBoxContainer
		if sb_mm == null or inb_list == null or not am.has_method("fetch_inbox_messages") or not am.has_method("mark_inbox_messages_read"):
			errors.append("MainMenu inbox_list, SignalBus, or inbox fetch/read methods missing")
		else:
			am.set("inbox_messages", [
				{"id": "m1", "scope": "global", "title": "Info Server @username", "bodyMarkdown": "# Halo @username\nPesan **penting** untuk @USERNAME & info@username.com\n- Butir satu", "senderUsername": "admin_lampor", "isRead": false, "createdAt": "2026-11-27T05:00:00Z"},
				{"id": "m2", "scope": "user", "targetUsername": "TestUser_99", "title": "Pesan Pribadi", "bodyMarkdown": "Halo *khusus* @username!", "senderUsername": "admin_lampor", "isRead": false, "createdAt": "2026-11-27T05:01:00Z"}
			])
			am.set("unread_inbox_count", 2)
			sb_mm.emit_signal("inbox_messages_updated", am.get("inbox_messages"), 2)
			mm.call("_render_inbox_modal")
			if not bool(mm.get("_inbox_has_unread_dot")):
				errors.append("MainMenu _inbox_has_unread_dot did not become true when unread_inbox_count=2")
			var rtl_nodes: Array[Node] = inb_list.find_children("*", "RichTextLabel", true, false)
			var inb_lbl_nodes: Array[Node] = inb_list.find_children("*", "Label", true, false)
			var found_penting: bool = false
			var found_khusus: bool = false
			var found_title_uname: bool = false
			var found_body_uname: bool = false
			var found_email_preserved: bool = false
			var found_raw_placeholder: bool = false
			var rx_raw_ph := RegEx.new()
			rx_raw_ph.compile("(?i)(^|[^a-zA-Z0-9_])@username(?![a-zA-Z0-9_])")
			for lbl_var: Node in inb_lbl_nodes:
				var lbl_ctrl: Label = lbl_var as Label
				if lbl_ctrl == null:
					continue
				if lbl_ctrl.text == "Info Server TestUser_99":
					found_title_uname = true
				if rx_raw_ph.search(lbl_ctrl.text) != null:
					found_raw_placeholder = true
			for rtl_var: Node in rtl_nodes:
				var rtl_ctrl: RichTextLabel = rtl_var as RichTextLabel
				if rtl_ctrl == null:
					continue
				var parsed_txt: String = rtl_ctrl.get_parsed_text()
				if parsed_txt.contains("penting"):
					found_penting = true
				if parsed_txt.contains("khusus"):
					found_khusus = true
				if parsed_txt.contains("TestUser_99"):
					found_body_uname = true
				if parsed_txt.contains("info@username.com"):
					found_email_preserved = true
				if rx_raw_ph.search(parsed_txt) != null:
					found_raw_placeholder = true
			if not found_penting or not found_khusus or not found_title_uname or not found_body_uname or not found_email_preserved or found_raw_placeholder:
				errors.append("MainMenu inbox @username formatting failed (penting=%s, khusus=%s, title=%s, body=%s, email=%s, raw=%s)" % [str(found_penting), str(found_khusus), str(found_title_uname), str(found_body_uname), str(found_email_preserved), str(found_raw_placeholder)])
			var prev_guest_inb: bool = bool(am.get("is_guest_mode"))
			am.set("is_guest_mode", true)
			var guest_fmt: String = str(mm.call("_format_inbox_player_text", "Halo @username!"))
			am.set("is_guest_mode", prev_guest_inb)
			if guest_fmt != "Halo Pemain!" and guest_fmt != "Halo Player!":
				errors.append("MainMenu _format_inbox_player_text guest fallback failed: " + guest_fmt)
			am.set("inbox_messages", [])
			am.set("unread_inbox_count", 0)
			mm.call("_refresh_friends_button_badge")
			mm.call("_render_inbox_modal")
			await process_frame

	var fix_file_text: String = FileAccess.get_file_as_string("res://FIX_NOTES.md")
	if fix_file_text.is_empty() or fix_file_text.to_lower().contains("admin") or fix_file_text.to_lower().contains("alt+f2"):
		errors.append("FIX_NOTES.md missing or contains forbidden admin/alt+f2 text")
	var um: Variant = root.get_node_or_null("UpdateManager")
	if um == null:
		errors.append("UpdateManager missing")
	else:
		var um_notes: String = str(um.call("get_fix_notes_markdown"))
		if um_notes.is_empty() or um_notes.to_lower().contains("admin") or um_notes.to_lower().contains("alt+f2"):
			errors.append("UpdateManager.get_fix_notes_markdown() empty or contains admin/alt+f2")
		var sample_notes: String = "- **Dashboard Web Admin (/admin)**:\n  - Sub detail\n- **Fitur Pemain**:\n  - Aman"
		var sanitized_notes: String = str(um.call("sanitize_fix_notes_for_players", sample_notes))
		if sanitized_notes.to_lower().contains("admin") or sanitized_notes.contains("Sub detail") or not sanitized_notes.contains("- **Fitur Pemain**") or not sanitized_notes.contains("Aman"):
			errors.append("UpdateManager.sanitize_fix_notes_for_players failed to strip admin section while keeping player bullet")
	mm.call("_show_fix_notes")
	var fn_view: RichTextLabel = mm.get("fix_notes_view") as RichTextLabel
	var fn_ov: Control = mm.get("fix_notes_overlay") as Control
	if fn_view == null or fn_view.text.to_lower().contains("admin") or fn_view.text.to_lower().contains("alt+f2"):
		errors.append("MainMenu _show_fix_notes rendered admin/alt+f2 content")
	if fn_ov != null:
		fn_ov.visible = false
	var photo_filters: PackedStringArray = mm.call("_get_profile_photo_filters")
	if photo_filters.is_empty() or not photo_filters[0].ends_with(";image/*"):
		errors.append("Profile photo filters must end with ';image/*' for mobile gallery picker")
	var test_img := Image.create(320, 200, false, Image.FORMAT_RGB8)
	test_img.fill(Color(0.35, 0.55, 0.75, 1.0))
	var tmp_paths := [
		["user://_verify_avatar_png_noext", test_img.save_png_to_buffer()],
		["user://_verify_avatar_jpg_noext", test_img.save_jpg_to_buffer(0.85)],
		["user://_verify_avatar_webp_noext", test_img.save_webp_to_buffer()]
	]
	for item: Array in tmp_paths:
		var tmp_path: String = str(item[0])
		var tmp_bytes: PackedByteArray = item[1]
		var fa := FileAccess.open(tmp_path, FileAccess.WRITE)
		if fa == null:
			errors.append("Failed to write temporary avatar test file: " + tmp_path)
			continue
		fa.store_buffer(tmp_bytes)
		fa.close()
		var loaded_img: Variant = mm.call("_load_profile_image_from_source", tmp_path)
		if not (loaded_img is Image) or (loaded_img as Image).is_empty() or (loaded_img as Image).get_width() != 320 or (loaded_img as Image).get_height() != 200:
			errors.append("_load_profile_image_from_source failed on extensionless file: " + tmp_path)
		else:
			var data_url: String = str(mm.call("_encode_profile_avatar_data_url", loaded_img))
			if not data_url.begins_with("data:image/jpeg;base64,") or data_url.length() > 19000:
				errors.append("_encode_profile_avatar_data_url invalid output for " + tmp_path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
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
		var bad_admin_err: String = str(am.call("validate_credentials_format", "admin_lampor", "PassAman123", false))
		if bad_admin_err.is_empty():
			errors.append("validate_credentials_format did not block dashboard-only admin_lampor")
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

		var alt_f2 := InputEventKey.new()
		alt_f2.pressed = true
		alt_f2.echo = false
		alt_f2.keycode = KEY_F2
		alt_f2.physical_keycode = KEY_F2
		alt_f2.alt_pressed = true
		ap_node.call("_input", alt_f2)
		if ap_root != null and ap_root.visible:
			errors.append("AdminPanel Alt+F2 opened for non-admin player!")
		am.set("role", "admin")
		ap_node.call("_input", alt_f2)
		if ap_root == null or not ap_root.visible:
			errors.append("AdminPanel Alt+F2 did not open for admin!")
		await process_frame
		await process_frame

		var ap_panel: Control = ap_node.get("panel") as Control
		var ap_hdr: Control = ap_node.get("drag_header") as Control
		if ap_panel == null or ap_hdr == null:
			errors.append("AdminPanel panel or drag_header missing")
		else:
			ap_panel.position = Vector2(100.0, 50.0)
			await process_frame
			var hdr_rect: Rect2 = ap_hdr.get_global_rect()
			var drag_pt: Vector2 = Vector2(hdr_rect.position.x + 24.0, hdr_rect.position.y + hdr_rect.size.y * 0.5)
			if not bool(ap_node.call("_is_point_in_header_drag_zone", drag_pt)):
				errors.append("AdminPanel header drag zone rejected valid header point")
			var st_down := InputEventScreenTouch.new()
			st_down.index = 0
			st_down.pressed = true
			st_down.position = drag_pt
			ap_node.call("_input", st_down)
			var sd_move := InputEventScreenDrag.new()
			sd_move.index = 0
			sd_move.position = drag_pt + Vector2(80.0, 60.0)
			sd_move.relative = Vector2(80.0, 60.0)
			ap_node.call("_input", sd_move)
			var st_up := InputEventScreenTouch.new()
			st_up.index = 0
			st_up.pressed = false
			st_up.position = drag_pt + Vector2(80.0, 60.0)
			ap_node.call("_input", st_up)
			if ap_panel.position.distance_to(Vector2(180.0, 110.0)) > 2.0:
				errors.append("AdminPanel mobile touch drag failed, expected ~Vector2(180, 110), got " + str(ap_panel.position))

		ap_node.call("close_panel")

		var ap_sv := SubViewport.new()
		ap_sv.size = Vector2i(640, 200)
		ap_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(ap_sv)
		var ap_script: Script = load("res://scripts/ui/AdminPanel.gd") as Script
		var ap_mobile: Node = ap_script.new() as Node
		ap_sv.add_child(ap_mobile)
		ap_mobile.call("toggle_panel")
		await process_frame
		await process_frame
		var ap_mob_scroll: ScrollContainer = ap_mobile.get("body_scroll") as ScrollContainer
		if ap_mob_scroll == null or not ap_mob_scroll.visible:
			errors.append("AdminPanel mobile SubViewport body_scroll missing or hidden")
		else:
			var vbar: VScrollBar = ap_mob_scroll.get_v_scroll_bar()
			if vbar == null or vbar.max_value <= ap_mob_scroll.size.y:
				errors.append("AdminPanel mobile body_scroll did not overflow at height 200 (max=%.1f, size=%.1f)" % [vbar.max_value if vbar else -1.0, ap_mob_scroll.size.y])
			else:
				var scr_rect: Rect2 = ap_mob_scroll.get_global_rect()
				var scr_start: Vector2 = scr_rect.position + Vector2(12.0, minf(16.0, scr_rect.size.y * 0.25))
				var scr_down := InputEventScreenTouch.new()
				scr_down.index = 1
				scr_down.pressed = true
				scr_down.position = scr_start
				ap_mobile.call("_input", scr_down)
				var scr_drag := InputEventScreenDrag.new()
				scr_drag.index = 1
				scr_drag.position = scr_start + Vector2(0.0, -60.0)
				scr_drag.relative = Vector2(0.0, -60.0)
				ap_mobile.call("_input", scr_drag)
				var scr_up := InputEventScreenTouch.new()
				scr_up.index = 1
				scr_up.pressed = false
				scr_up.position = scr_start + Vector2(0.0, -60.0)
				ap_mobile.call("_input", scr_up)
				if ap_mob_scroll.scroll_vertical <= 0:
					errors.append("AdminPanel mobile touch scroll failed: scroll_vertical=" + str(ap_mob_scroll.scroll_vertical))
		ap_mobile.call("close_panel")
		ap_sv.queue_free()

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
		var inv_close_b: Button = hud_node.get("_inv_close_btn") as Button
		if inv_close_b == null or inv_close_b.text != "" or not (inv_close_b.get_node_or_null("IconDraw") is Control):
			errors.append("HUD _inv_close_btn must be icon-only X button (empty text + IconDraw)")
		var mic_btn: Button = hud_node.get("mic_toggle_button") as Button
		if mic_btn == null:
			errors.append("HUD top-left mic_toggle_button missing")
		var vcs: Variant = load("res://scripts/systems/VoiceChatSystem.gd")
		var vcs_inst: Node = null
		if vcs == null:
			errors.append("VoiceChatSystem.gd failed to load")
		else:
			if float(vcs.get("VOICE_RMS_THRESHOLD")) > 0.005 or str(vcs.get("CAPTURE_SINK_BUS_NAME")) != "VoiceMicSink":
				errors.append("VoiceChatSystem capture pipeline threshold or sink bus misconfigured")
			var pcm_in := PackedFloat32Array()
			for si: int in range(160):
				pcm_in.append(sin(float(si) * 0.25) * 0.6)
			var b64: String = str(vcs.call("encode_pcm_to_ulaw_b64", pcm_in))
			var pcm_out: PackedFloat32Array = vcs.call("decode_ulaw_b64_to_pcm", b64)
			if b64.is_empty() or pcm_out.size() != pcm_in.size() or absf(pcm_out[2]) < 0.05:
				errors.append("VoiceChatSystem mu-law roundtrip invalid")
			vcs_inst = (vcs as Script).new() as Node
			vm.add_child(vcs_inst)
			vcs_inst.call("decode_and_route_peer_audio", "u2", {"d": b64}, {})
			if not bool(vcs_inst.call("is_peer_speaking", "u2")):
				errors.append("VoiceChatSystem decode_and_route_peer_audio did not mark peer speaking")

		if gm != null and mp != null:
			mp.set("is_online_session", true)
			mp.set("is_room_owner", true)
			gm.set("current_state", 1)
			gm.set("death_sequence_active", false)
			gm.set("victory_sequence_active", false)
			gm.set("time_accumulator", 0.0)
			var start_min: int = int(gm.get("current_minute"))
			hud_node.call("toggle_pause")
			var pm_ctrl: Control = hud_node.get("pause_menu") as Control
			var p_char: Node = gm.get("player_character") as Node
			if pm_ctrl == null or not pm_ctrl.visible:
				errors.append("Online host toggle_pause did not show pause_menu")
			if self.paused:
				errors.append("Online host toggle_pause froze SceneTree instead of keeping time running")
			if p_char != null and not bool(p_char.get("is_pause_menu_open")):
				errors.append("Online host toggle_pause did not freeze local player input via is_pause_menu_open")
			gm.call("_process", 1.0)
			if float(gm.get("time_accumulator")) <= 0.0 and int(gm.get("current_minute")) == start_min:
				errors.append("Online host time stopped advancing while pause_menu was open")
			hud_node.call("toggle_pause")
			if pm_ctrl != null and pm_ctrl.visible:
				errors.append("Online host second toggle_pause did not close pause_menu")
			if p_char != null and bool(p_char.get("is_pause_menu_open")):
				errors.append("Online host second toggle_pause did not clear is_pause_menu_open")
			mp.call("reset_to_singleplayer")
			gm.set("current_state", 0)

		if sm == null:
			errors.append("SettingsManager missing during voice verification")
		elif mp != null and gm != null:
			var sb_node: Node = root.get_node_or_null("SignalBus")
			if "mic_permission_granted" in sm:
				errors.append("SettingsManager should not retain fake mic_permission_granted gate")
			if sb_node == null or sb_node.has_signal("voice_mic_permission_requested"):
				errors.append("SignalBus missing or still exposes fake voice_mic_permission_requested signal")
			if sb_node == null or not sb_node.has_signal("voice_mic_permission_status"):
				errors.append("SignalBus missing voice_mic_permission_status signal")
			if hud_node.get("mic_permission_overlay") != null or hud_node.has_method("_open_mic_permission_modal") or hud_node.has_method("_build_mic_permission_modal"):
				errors.append("HUD must not define custom mic_permission_overlay or fake consent modal")
			mp.set("is_online_session", true)
			gm.set("current_state", 1)
			var mic_req_status: String = str(mp.call("request_mic_permission_and_enable"))
			if mic_req_status == "needs_consent" or not bool(mp.call("is_mic_enabled")):
				errors.append("Native mic request must enable directly in headless mode instead of needs_consent")
			hud_node.call("_on_mic_toggle_pressed")
			if bool(mp.call("is_mic_enabled")) or self.paused:
				errors.append("HUD _on_mic_toggle_pressed did not disable mic without pausing SceneTree")
			hud_node.call("_on_mic_toggle_pressed")
			if not bool(mp.call("is_mic_enabled")) or self.paused:
				errors.append("HUD _on_mic_toggle_pressed did not re-enable mic natively without fake modal")
			if vcs != null and is_instance_valid(vcs_inst):
				for expected_m: String in ["_start_web_mic_capture", "_stop_web_mic_capture", "_poll_web_mic_capture", "_on_android_permission_result", "_recreate_mic_player", "set_input_device"]:
					if not vcs_inst.has_method(expected_m):
						errors.append("VoiceChatSystem missing native capture method: " + expected_m)
				vcs_inst.call("_on_android_permission_result", "android.permission.RECORD_AUDIO", true)
				if not bool(vcs_inst.get("_android_runtime_granted")) or not bool(vcs_inst.get("mic_enabled")):
					errors.append("VoiceChatSystem _on_android_permission_result(true) did not activate mic")
				vcs_inst.set("_android_perm_requested_msec", Time.get_ticks_msec())
				vcs_inst.set("_android_saw_focus_out", false)
				vcs_inst.call("_on_android_permission_result", "android.permission.RECORD_AUDIO", false)
				var perm_err: String = str(vcs_inst.get("last_permission_error")).strip_edges()
				if bool(vcs_inst.get("_android_runtime_granted")) or bool(vcs_inst.get("mic_enabled")) or not perm_err.contains("RECORD_AUDIO"):
					errors.append("VoiceChatSystem instant Android deny did not surface RECORD_AUDIO APK guidance: " + perm_err)
			var exp_cfg_txt: String = FileAccess.get_file_as_string("res://export_presets.cfg")
			if not exp_cfg_txt.contains("permissions/record_audio=true") or not exp_cfg_txt.contains("permissions/modify_audio_settings=true") or not exp_cfg_txt.contains("android.permission.RECORD_AUDIO"):
				errors.append("export_presets.cfg Android preset missing record_audio/modify_audio_settings or RECORD_AUDIO custom_permissions")
			mp.call("reset_to_singleplayer")
			gm.set("current_state", 0)

		if mp != null:
			mp.set("is_online_session", true)
			mp.set("current_room", {"mode": "multiplayer", "name": "Desa", "roomCode": "ABC123", "hostUserId": "u1"})
			mp.set("room_players", [{"userId": "u1", "username": "lordreyid", "displayName": "Lord Rey", "isHost": true, "isVerified": true, "playerState": {"sanity": 97}}])
			hud_node.call("_refresh_online_room_overlay", true)
			var roster_vbox: VBoxContainer = hud_node.get("mp_roster_vbox") as VBoxContainer
			if roster_vbox == null:
				errors.append("HUD mp_roster_vbox missing")
			else:
				var roster_lbls: Array[Node] = roster_vbox.find_children("*", "Label", true, false)
				var found_lord_rey: bool = false
				for r_node: Node in roster_lbls:
					var r_lbl: Label = r_node as Label
					if r_lbl != null and r_lbl.text.contains("Lord Rey"):
						found_lord_rey = true
						if (r_lbl.size_flags_horizontal & Control.SIZE_EXPAND_FILL) == 0 or r_lbl.custom_minimum_size.x <= 0.0:
							errors.append("HUD mp_roster_vbox display name label can collapse to 0px (size_flags=%d, min_x=%.1f)" % [r_lbl.size_flags_horizontal, r_lbl.custom_minimum_size.x])
						break
				if not found_lord_rey:
					errors.append("HUD mp_roster_vbox missing 'Lord Rey' display name label")
			mp.call("reset_to_singleplayer")
			hud_node.call("_refresh_online_room_overlay", true)

		var p_char_k: Node = gm.get("player_character") as Node if gm != null else null
		var lampors_k: Array[Node] = get_nodes_in_group("lampor")
		if p_char_k == null or lampors_k.is_empty():
			errors.append("VillageMap player_character or lampor group missing for Kentongan test")
		else:
			var inv_k: Node = p_char_k.get("inventory_system") as Node
			if inv_k == null:
				errors.append("PlayerController inventory_system missing for Kentongan test")
			else:
				var lampor_k: Node = lampors_k[0]
				var orig_active_slot: int = int(inv_k.get("active_slot"))
				var orig_slots: Array = (inv_k.get("slots") as Array).duplicate(true)
				var orig_k_cd: float = float(p_char_k.get("kentongan_cooldown"))
				var orig_l_state: Variant = lampor_k.get("current_state")
				var orig_l_repel: float = float(lampor_k.get("repel_timer"))
				var orig_l_chase_cd: float = float(lampor_k.get("chase_cooldown"))
				var orig_l_catching: bool = bool(lampor_k.get("is_catching"))

				var k_slots: Array = orig_slots.duplicate(true)
				k_slots[2] = {"id": "kentongan", "name": "Kentongan Bambu", "type": "consumable", "quantity": 2}
				inv_k.set("slots", k_slots)
				inv_k.call("select_slot", 2)
				p_char_k.set("kentongan_cooldown", 0.0)
				lampor_k.set("current_state", 5)
				lampor_k.set("repel_timer", 0.0)
				lampor_k.set("is_catching", false)

				p_char_k.call("_try_use_equipped_item")
				var slots_after_1: Array = inv_k.get("slots") as Array
				var qty_after_1: int = int((slots_after_1[2] as Dictionary).get("quantity", 0)) if slots_after_1[2] is Dictionary else 0
				if not bool(lampor_k.call("is_repelled")):
					errors.append("Kentongan use did not repel Lampor from State.CHASE")
				if qty_after_1 != 1:
					errors.append("Kentongan first use expected remaining count 1, got " + str(qty_after_1))
				if float(p_char_k.get("kentongan_cooldown")) <= 0.0:
					errors.append("Kentongan first use did not start kentongan_cooldown")

				p_char_k.call("_try_use_equipped_item")
				var slots_after_2: Array = inv_k.get("slots") as Array
				var qty_after_2: int = int((slots_after_2[2] as Dictionary).get("quantity", 0)) if slots_after_2[2] is Dictionary else 0
				if qty_after_2 != 1:
					errors.append("Kentongan second immediate use consumed another Kentongan (anti-spam failed, count=%d)" % qty_after_2)

				lampor_k.set("current_state", orig_l_state)
				lampor_k.set("repel_timer", orig_l_repel)
				lampor_k.set("chase_cooldown", orig_l_chase_cd)
				lampor_k.set("is_catching", orig_l_catching)
				p_char_k.set("kentongan_cooldown", orig_k_cd)
				inv_k.set("slots", orig_slots)
				inv_k.call("select_slot", orig_active_slot)

		var p_dv_chk: CheckButton = hud_node.get("pause_dialog_voice_check") as CheckButton
		var p_open_kb: Button = hud_node.get("pause_open_keybinds_button") as Button
		var p_settings_cont: Control = hud_node.get("pause_settings_container") as Control
		var p_kb_cont: PanelContainer = hud_node.get("pause_keybinds_container") as PanelContainer
		var p_kb_btns_var: Variant = hud_node.get("_pause_keybind_buttons")
		if p_dv_chk == null or not p_dv_chk.button_pressed:
			errors.append("HUD pause_dialog_voice_check missing or not enabled by default")
		elif sm != null:
			sm.call("set_dialog_voice_enabled", false)
			if p_dv_chk.button_pressed:
				errors.append("HUD pause_dialog_voice_check did not sync when dialog_voice_enabled=false")
			sm.call("set_dialog_voice_enabled", true)
			if not p_dv_chk.button_pressed:
				errors.append("HUD pause_dialog_voice_check did not sync back when dialog_voice_enabled=true")
		var p_mic_test: Button = hud_node.get("_pause_mic_test_button") as Button
		var p_mic_lbl: Label = hud_node.get("_pause_mic_status_label") as Label
		if p_mic_test == null or p_mic_lbl == null or p_settings_cont == null or not p_settings_cont.is_ancestor_of(p_mic_test):
			errors.append("HUD pause settings mic test controls missing or outside pause_settings_container")
		if p_settings_cont == null or p_open_kb == null or not p_settings_cont.is_ancestor_of(p_open_kb):
			errors.append("HUD pause_open_keybinds_button missing or not inside pause_settings_container")
		elif p_kb_cont == null or p_settings_cont.is_ancestor_of(p_kb_cont) or not (p_kb_btns_var is Dictionary) or (p_kb_btns_var as Dictionary).size() != 15:
			errors.append("HUD pause_keybinds_container invalid, nested inside pause_settings_container, or missing 15 _pause_keybind_buttons")
		else:
			for pkb_val: Variant in (p_kb_btns_var as Dictionary).values():
				var pkb_btn: Control = pkb_val as Control
				if pkb_btn == null or not p_kb_cont.is_ancestor_of(pkb_btn):
					errors.append("HUD _pause_keybind_buttons entry not inside pause_keybinds_container")
					break
			hud_node.call("_open_pause_keybinds")
			if not p_kb_cont.visible or p_settings_cont.visible:
				errors.append("HUD _open_pause_keybinds did not show pause_keybinds_container and hide pause_settings_container")
			hud_node.call("_close_pause_keybinds_to_settings")
			if p_kb_cont.visible or not p_settings_cont.visible:
				errors.append("HUD _close_pause_keybinds_to_settings did not return to pause_settings_container")
			hud_node.call("_pause_settings_container_hide")
			if p_kb_cont.visible or p_settings_cont.visible:
				errors.append("HUD _pause_settings_container_hide did not hide both pause settings and keybinds containers")
			var pm_node: Node = hud_node.get("pause_menu") as Node
			var pm_center: Control = pm_node.get_node_or_null("Center") as Control if pm_node != null else null
			if pm_center != null:
				pm_center.visible = true

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
		var low_mode: String = str(wb.call("get_active_tree_mode"))
		var trunks_low: Node3D = wb.get_node_or_null("ForestTrunks") as Node3D
		var trees2d_low: Node3D = wb.get_node_or_null("Forest2DTrees") as Node3D
		if low_mode != "2d" or trees2d_low == null or not trees2d_low.visible or (trunks_low != null and trunks_low.visible):
			errors.append("Low graphics must render 2D trees only")
		var test_cam := Camera3D.new()
		vm.add_child(test_cam)
		test_cam.global_position = Vector3(0.0, 2.0, 0.0)
		test_cam.look_at(Vector3(0.0, 2.0, -30.0), Vector3.UP)
		wb.call("force_update_culling_for_camera", test_cam)
		var total_sec: int = int(wb.call("get_total_sector_count"))
		var vis_sec: int = int(wb.call("get_visible_sector_count"))
		if total_sec != 8 or vis_sec <= 0 or vis_sec >= total_sec:
			errors.append("WorldBorder 8-sector culling did not cull rear sectors (vis=%d/%d)" % [vis_sec, total_sec])
		if sm != null:
			sm.call("set_graphics_quality", "medium")
			await process_frame
			if str(wb.call("get_active_tree_mode")) != "2d":
				errors.append("Medium graphics must render 2D trees")
			sm.call("set_graphics_quality", "high")
			await process_frame
			var trunks_high: Node3D = wb.get_node_or_null("ForestTrunks") as Node3D
			var trees2d_high: Node3D = wb.get_node_or_null("Forest2DTrees") as Node3D
			if str(wb.call("get_active_tree_mode")) != "3d" or trunks_high == null or not trunks_high.visible or (trees2d_high != null and trees2d_high.visible):
				errors.append("High graphics must switch to 3D trees")
			sm.call("set_graphics_quality", "low")
		test_cam.queue_free()

	var rp_script: Script = load("res://scripts/player/RemotePlayer.gd") as Script
	var rp: Node3D = rp_script.new() as Node3D
	vm.add_child(rp)
	rp.call("apply_network_state", {"userId": "u2", "username": "PemainTes", "isHost": true, "isVerified": true, "pos": [0.0, 0.0, 2.0], "equippedItem": ""})
	var rp_vs: Sprite3D = rp.get("verified_sprite") as Sprite3D
	if rp_vs == null or not rp_vs.visible or rp_vs.texture == null:
		errors.append("RemotePlayer VerifiedSprite missing or hidden for verified player")

	# Verifikasi tombol Admin Panel dihapus dari PauseMenu
	if hud_node != null:
		var pm_check: Control = hud_node.get("pause_menu") as Control
		if hud_node.get("pause_admin_button") != null or (pm_check != null and pm_check.find_child("AdminPanelButton", true, false) != null):
			errors.append("PauseMenu still contains forbidden AdminPanelButton")

	# Verifikasi animasi mengambil barang dari kantong celana & menggenggam (PlayerController & RemotePlayer)
	var p_char_pocket: Node = gm.get("player_character") as Node if gm != null else null
	if p_char_pocket != null and p_char_pocket.has_method("get_pocket_anim_state"):
		var inv_p: Node = p_char_pocket.get("inventory_system") as Node
		if inv_p != null:
			var orig_p_slot: int = int(inv_p.get("active_slot"))
			var orig_p_slots: Array = (inv_p.get("slots") as Array).duplicate(true)
			var p_slots: Array = orig_p_slots.duplicate(true)
			p_slots[4] = {}
			inv_p.set("slots", p_slots)
			inv_p.call("select_slot", 4)
			for _si: int in range(4):
				p_char_pocket.call("_update_fpp_camera_and_arm", 0.2, false)
			var empty_st: Dictionary = p_char_pocket.call("get_pocket_anim_state")
			if str(empty_st.get("phase", "")) != "empty" or float(empty_st.get("grip_blend", 1.0)) > 0.1:
				errors.append("PlayerController empty slot did not settle to empty/relaxed grip: " + str(empty_st))

			inv_p.call("select_slot", 1) # Jamu
			var reach_st: Dictionary = p_char_pocket.call("get_pocket_anim_state")
			if str(reach_st.get("phase", "")) != "reaching_pocket":
				errors.append("PlayerController switching to jamu did not enter reaching_pocket: " + str(reach_st))
			p_char_pocket.call("_update_fpp_camera_and_arm", 0.28, false)
			var grab_st: Dictionary = p_char_pocket.call("get_pocket_anim_state")
			if str(grab_st.get("phase", "")) != "grabbing_pocket" or str(grab_st.get("visual_equipped_item_id", "")) != "jamu":
				errors.append("PlayerController pocket grab phase/item mismatch: " + str(grab_st))
			p_char_pocket.call("_update_fpp_camera_and_arm", 0.10, false)
			var pull_st: Dictionary = p_char_pocket.call("get_pocket_anim_state")
			if str(pull_st.get("phase", "")) != "pulling_out":
				errors.append("PlayerController pocket pull_out phase mismatch: " + str(pull_st))
			p_char_pocket.call("_update_fpp_camera_and_arm", 0.35, false)
			p_char_pocket.call("_apply_fpp_hand_override")
			var hold_st: Dictionary = p_char_pocket.call("get_pocket_anim_state")
			if str(hold_st.get("phase", "")) != "holding" or float(hold_st.get("grip_blend", 0.0)) < 0.9:
				errors.append("PlayerController did not grip jamu after pulling from pocket: " + str(hold_st))

			inv_p.call("select_slot", 0) # Swap jamu -> flashlight
			var swap_reach: Dictionary = p_char_pocket.call("get_pocket_anim_state")
			if str(swap_reach.get("visual_equipped_item_id", "")) != "jamu":
				errors.append("PlayerController swapped visual item before reaching pocket: " + str(swap_reach))
			p_char_pocket.call("_update_fpp_camera_and_arm", 0.45, false)
			p_char_pocket.call("_apply_fpp_hand_override")
			var swap_done: Dictionary = p_char_pocket.call("get_pocket_anim_state")
			if str(swap_done.get("visual_equipped_item_id", "")) != "flashlight":
				errors.append("PlayerController did not draw flashlight from pocket: " + str(swap_done))
			for _si2: int in range(3):
				p_char_pocket.call("_update_fpp_camera_and_arm", 0.25, false)
			inv_p.set("slots", orig_p_slots)
			inv_p.call("select_slot", orig_p_slot)

	if rp.has_method("get_pocket_anim_state"):
		rp.call("apply_network_state", {"equippedItem": "flashlight"})
		var r_reach: Dictionary = rp.call("get_pocket_anim_state")
		if str(r_reach.get("phase", "")) != "reaching_pocket":
			errors.append("RemotePlayer equip did not enter reaching_pocket: " + str(r_reach))
		rp.call("_process", 0.30)
		var r_grab: Dictionary = rp.call("get_pocket_anim_state")
		if str(r_grab.get("phase", "")) != "grabbing_pocket" or str(r_grab.get("visual_equipped_item", "")) != "flashlight":
			errors.append("RemotePlayer pocket grab mismatch: " + str(r_grab))
		rp.call("_process", 0.45)
		rp.call("_apply_remote_hand_override")
		var r_hold: Dictionary = rp.call("get_pocket_anim_state")
		var rp_props: Dictionary = rp.get("hand_item_props") as Dictionary
		var rp_fl_prop: Node3D = rp_props.get("flashlight", null) as Node3D
		if str(r_hold.get("phase", "")) != "holding" or float(r_hold.get("grip_blend", 0.0)) < 0.9 or rp_fl_prop == null or not rp_fl_prop.visible:
			errors.append("RemotePlayer did not grip/display flashlight after pocket draw: " + str(r_hold))

	# Verifikasi FateCardOverlay: auto-pick 10 detik & tunggu semua pemain di Multiplayer
	if gm != null and mp != null and hud_node != null:
		var fco: Node = hud_node.get("fate_card_overlay") as Node
		if fco == null:
			errors.append("HUD fate_card_overlay missing")
		else:
			gm.call("reset_fate_cards")
			gm.set("current_state", 1)
			gm.set("is_tutorial_mode", false)
			gm.set("is_resuming_saved_run", false)
			var pair_sp: Dictionary = gm.call("request_fate_card_pair_for_act", 1)
			if not bool(fco.call("open_choice", 1, pair_sp)):
				errors.append("FateCardOverlay failed to open singleplayer pair")
			else:
				fco.call("_process", 10.1)
				if not bool(fco.get("_auto_selected")) or (fco.get("_chosen_card") as Dictionary).is_empty():
					errors.append("FateCardOverlay did not auto-select card after 10 seconds")
				fco.call("complete_reveal_immediately")
				if int(fco.get("_phase")) != 4:
					errors.append("FateCardOverlay singleplayer expected READY_CONTINUE(4), got " + str(fco.get("_phase")))
				fco.call("close_overlay")
				if bool(fco.call("is_open")) or bool(gm.call("is_fate_card_selection_blocking")):
					errors.append("FateCardOverlay singleplayer failed to close/unblock")

			# Simulasi 2 pemain online: tunggu pemain kedua selesai memilih sebelum lanjut
			gm.call("reset_fate_cards")
			var orig_uid_fc: String = str(am.get("user_id")) if am != null else ""
			if am != null:
				am.set("user_id", "u1")
			mp.set("is_online_session", true)
			mp.set("is_room_owner", true)
			mp.set("session_mode", "multiplayer")
			mp.set("current_room", {"id": "room-fc", "mode": "multiplayer", "hostUserId": "u1", "status": "playing"})
			mp.set("room_players", [
				{"userId": "u1", "username": "host", "displayName": "Host", "isHost": true, "playerState": {"isAlive": true}},
				{"userId": "u2", "username": "teman", "displayName": "Teman", "isHost": false, "playerState": {"isAlive": true}}
			])
			gm.set("current_state", 1)
			var pair_mp: Dictionary = gm.call("request_fate_card_pair_for_act", 1)
			if not bool(fco.call("open_choice", 1, pair_mp)):
				errors.append("FateCardOverlay failed to open multiplayer pair")
			else:
				fco.call("_select_side", "left", false)
				fco.call("complete_reveal_immediately")
				if int(fco.get("_phase")) != 3:
					errors.append("FateCardOverlay multiplayer expected WAITING_OTHERS(3) while peer pending, got " + str(fco.get("_phase")))
				fco.call("close_overlay")
				if not bool(fco.call("is_open")):
					errors.append("FateCardOverlay closed before all players finished choosing!")
				if not bool(gm.call("is_fate_card_selection_blocking")):
					errors.append("GameManager.is_fate_card_selection_blocking() must be true while waiting for other players")
				gm.set("time_accumulator", 0.0)
				gm.call("_process", 1.0)
				if float(gm.get("time_accumulator")) > 0.0:
					errors.append("GameManager night clock advanced while waiting for FateCardOverlay choices!")

				var rp_arr: Array = mp.get("room_players") as Array
				rp_arr[1]["playerState"] = {"isAlive": true, "fateCardAct": 1, "fateCardDone": true}
				mp.set("room_players", rp_arr)
				gm.call("sync_mp_fate_selection_state")
				if int(fco.get("_phase")) != 4:
					errors.append("FateCardOverlay did not unlock to READY_CONTINUE(4) once all players chose, got " + str(fco.get("_phase")))
				fco.call("close_overlay")
				if bool(fco.call("is_open")) or bool(gm.call("is_fate_card_selection_blocking")):
					errors.append("FateCardOverlay multiplayer remained open/blocking after all players finished")
				gm.call("_process", 1.0)
				if float(gm.get("time_accumulator")) <= 0.0:
					errors.append("GameManager night clock did not resume after all players finished FateCardOverlay")

			if am != null:
				am.set("user_id", orig_uid_fc)
			mp.call("reset_to_singleplayer")
			gm.call("reset_fate_cards")
			gm.set("current_state", 0)
			self.paused = false

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
