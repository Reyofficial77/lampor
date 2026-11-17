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

func get_interaction_prompt(_player: Node) -> String:
	if GameManager.furnace_burning:
		return "Tungku Membara! Bertahanlah: %d detik tersisa!" % int(GameManager.furnace_time_left)

	if GameManager.current_act == GameManager.Act.BABAK_1:
		return "Tungku Balai Desa (Selesaikan pertahanan obor & barikade terlebih dahulu)"

	var count: int = GameManager.get_ritual_item_count()
	if count < GameManager.TOTAL_RITUAL_ITEMS:
		return "Tungku Balai Desa (Kumpulkan 4 Benda Ritual dulu: %d/%d)" % [count, GameManager.TOTAL_RITUAL_ITEMS]

	return "[E] Bakar Benda Ritual & Mulai Upacara Pemutus Kutukan!"

func interact(player: Node) -> void:
	if GameManager.furnace_burning:
		return

	# Nyala api hanya jika ritual benar-benar berhasil dimulai
	if GameManager.try_start_ritual():
		fire_light.visible = true
		fire_mesh.visible = true
		AudioManager.play_sound("lighter_ignite", 3.0)
		AudioManager.play_sound("lampor_roar", 2.0)
		# Pemain sudah berdiri di dalam area aman sebelum api menyala,
		# jadi body_entered tidak akan terpanggil lagi: set manual
		var pc: PlayerController = player as PlayerController
		if pc and pc.sanity_system:
			pc.sanity_system.set_safe_source(self, true)
	else:
		AudioManager.play_sound("item_pickup", -10.0, 0.5)

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
