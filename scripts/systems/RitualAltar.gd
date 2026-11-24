class_name RitualAltar
extends StaticBody3D

@onready var fire_light: OmniLight3D = $AltarLight
@onready var fire_mesh: MeshInstance3D = $FireMesh
@onready var safe_area: Area3D = $SafeZoneArea

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	safe_area.body_entered.connect(_on_safe_area_entered)
	safe_area.body_exited.connect(_on_safe_area_exited)
	fire_light.visible = false
	fire_mesh.visible = false

const LocScript = preload("res://scripts/systems/Loc.gd")

func get_interaction_prompt(_player: Node) -> String:
	var k: String = SettingsManager.get_action_key_text("interact")
	if GameManager.furnace_burning:
		return LocScript.pick("Tungku Membara! Bertahanlah: %d detik tersisa!" % int(GameManager.furnace_time_left), "Furnace Burning! Hold out: %d seconds left!" % int(GameManager.furnace_time_left))

	if GameManager.current_act == GameManager.Act.BABAK_1:
		return LocScript.pick("Tungku Balai Desa (Selesaikan pertahanan obor & barikade terlebih dahulu)", "Village Hall Furnace (Finish torches & barricades first)")

	var count: int = GameManager.get_ritual_item_count()
	if count < GameManager.TOTAL_RITUAL_ITEMS:
		return LocScript.pick("Tungku Balai Desa (Kumpulkan 4 Benda Ritual dulu: %d/%d)" % [count, GameManager.TOTAL_RITUAL_ITEMS], "Village Hall Furnace (Gather 4 Ritual Relics first: %d/%d)" % [count, GameManager.TOTAL_RITUAL_ITEMS])

	return LocScript.pick("[%s] Bakar Benda Ritual & Mulai Upacara Pemutus Kutukan!" % k, "[%s] Burn Ritual Relics & Start the Ritual!" % k)

func _get_scene_node_path() -> String:
	var root: Node = get_tree().current_scene
	if root and root.is_ancestor_of(self):
		return str(root.get_path_to(self))
	return name

func interact(player: Node) -> void:
	if GameManager.furnace_burning:
		return

	# Nyala api hanya jika ritual benar-benar berhasil dimulai
	if GameManager.try_start_ritual():
		fire_light.visible = true
		fire_mesh.visible = true
		AudioManager.play_sound("lighter_ignite", 3.0)
		AudioManager.play_sound("lampor_roar", 2.0)
		if MultiplayerManager.is_online_session:
			MultiplayerManager.push_event("furnace_started", {
				"node_path": _get_scene_node_path()
			})
		# Pemain sudah berdiri di dalam area aman sebelum api menyala,
		# jadi body_entered tidak akan terpanggil lagi: set manual
		var pc: PlayerController = player as PlayerController
		if pc and pc.sanity_system:
			pc.sanity_system.set_safe_source(self, true)
	else:
		AudioManager.play_sound("item_pickup", -10.0, 0.5)

func apply_network_burning(burning: bool) -> void:
	if fire_light:
		fire_light.visible = burning
	if fire_mesh:
		fire_mesh.visible = burning
	if burning:
		AudioManager.play_sound("lighter_ignite", 1.0)
		AudioManager.play_sound("lampor_roar", 0.5)
	if safe_area:
		for body: Node3D in safe_area.get_overlapping_bodies():
			if body is PlayerController:
				var pc: PlayerController = body as PlayerController
				if pc.sanity_system:
					pc.sanity_system.set_safe_source(self, burning)

func _on_safe_area_entered(body: Node3D) -> void:
	if GameManager.furnace_burning and body is PlayerController:
		var pc: PlayerController = body as PlayerController
		if pc.sanity_system:
			pc.sanity_system.set_safe_source(self, true)

func _on_safe_area_exited(body: Node3D) -> void:
	if body is PlayerController:
		var pc: PlayerController = body as PlayerController
		if pc.sanity_system:
			pc.sanity_system.set_safe_source(self, false)
