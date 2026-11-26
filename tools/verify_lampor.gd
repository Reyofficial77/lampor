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
	var acc_btn: Button = mm.get("account_btn") as Button
	var exit_btn: Button = mm.get("exit_button") as Button
	if tr_bar == null or acc_btn == null or exit_btn == null:
		errors.append("MainMenu top_right_bar, account_btn, or exit_button missing")
	else:
		if exit_btn.get_parent() != tr_bar or acc_btn.get_parent() != tr_bar or exit_btn.get_index() != acc_btn.get_index() + 1 or exit_btn.text != "" or not (exit_btn.get_node_or_null("IconDraw") is Control):
			errors.append("MainMenu exit_button must be immediately right of account_btn in top_right_bar with empty text and IconDraw")

	if float(mm.call("_compute_menu_column_width", Vector2(390.0, 844.0), true)) > 300.0:
		errors.append("MainMenu _compute_menu_column_width exceeds 300.0 on 390x844 mobile portrait")

	var acc_close_btn: Button = mm.get("account_close_btn") as Button
	if acc_close_btn == null or acc_close_btn.text != "" or not (acc_close_btn.get_node_or_null("IconDraw") is Control):
		errors.append("MainMenu account_close_btn must be icon-only X button (empty text + IconDraw)")
	for ov_name: String in ["friends_overlay", "inbox_overlay", "settings_overlay", "guide_overlay", "shop_overlay", "fix_notes_overlay"]:
		var ov_ctrl: Control = mm.get(ov_name) as Control
		var x_btns: Array[Node] = ov_ctrl.find_children("IconDraw", "Control", true, false) if ov_ctrl != null else []
		if x_btns.is_empty():
			errors.append("MainMenu modal missing header X IconDraw close button: " + ov_name)

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
		var badge_ctrl: Control = mm.get("account_chip_badge") as Control
		var top_badge: Control = mm.get("top_account_badge") as Control
		if badge_ctrl == null or not badge_ctrl.visible or top_badge == null or not top_badge.visible:
			errors.append("MainMenu verified badges not visible for verified user")
		am.set("incoming_friend_requests", [{"id": "u99", "username": "ReqUser"}])
		mm.call("_refresh_friends_button_badge")
		if rail_friends_btn == null or rail_friends_btn.text != "" or not bool(mm.get("_friends_has_pending_dot")):
			errors.append("MainMenu friends_button pending dot or empty text check failed")
		am.set("incoming_friend_requests", [])
		mm.call("_refresh_friends_button_badge")

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
			var vcs_inst: Node = (vcs as Script).new() as Node
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

		if sm == null or not ("mic_permission_granted" in sm) or not sm.has_method("set_mic_permission_granted"):
			errors.append("SettingsManager missing mic_permission_granted or set_mic_permission_granted")
		elif mp != null and gm != null:
			sm.call("set_mic_permission_granted", false)
			mp.set("is_online_session", true)
			gm.set("current_state", 1)
			if str(mp.call("request_mic_permission_and_enable")) != "needs_consent" or bool(mp.call("is_mic_enabled")):
				errors.append("Voice mic permission should require consent before enabling")
			var mic_perm_ov: Control = hud_node.get("mic_permission_overlay") as Control
			if mic_perm_ov == null:
				errors.append("HUD mic_permission_overlay missing")
			else:
				hud_node.call("_on_mic_toggle_pressed")
				if not mic_perm_ov.visible or self.paused:
					errors.append("HUD _on_mic_toggle_pressed did not show mic_permission_overlay without pausing SceneTree")
				hud_node.call("_on_mic_permission_allow_pressed")
				if mic_perm_ov.visible or not bool(sm.get("mic_permission_granted")) or not bool(mp.call("is_mic_enabled")):
					errors.append("HUD _on_mic_permission_allow_pressed did not close modal, grant permission, and enable mic")
				mp.call("deny_mic_permission")
				if bool(sm.get("mic_permission_granted")) or bool(mp.call("is_mic_enabled")):
					errors.append("deny_mic_permission did not revoke mic_permission_granted and disable mic")
			mp.call("reset_to_singleplayer")
			gm.set("current_state", 0)
			sm.call("set_mic_permission_granted", false)

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
