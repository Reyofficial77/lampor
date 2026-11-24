class_name FateCardSystem
extends RefCounted

const LocScript = preload("res://scripts/systems/Loc.gd")
const CARD_BACK_PATH: String = "res://assets/textures/cards/card_back.png"
const PAIRING_MODES: Array[String] = ["curse_curse", "blessing_blessing", "blessing_curse"]

static var _cached_catalog: Array[Dictionary] = []

static func _make_card(
	card_id: String,
	card_type: String,
	name_id: String,
	name_en: String,
	desc_id: String,
	desc_en: String,
	modifiers: Dictionary = {},
	instant: Dictionary = {}
) -> Dictionary:
	return {
		"id": card_id,
		"type": card_type,
		"name": name_id,
		"name_en": name_en,
		"description": desc_id,
		"description_en": desc_en,
		"image_path": "res://assets/textures/cards/%s.png" % card_id,
		"modifiers": modifiers,
		"instant": instant
	}

static func _ensure_catalog() -> void:
	if not _cached_catalog.is_empty():
		return
	_cached_catalog = [
		# 10 KUTUKAN (Curse)
		_make_card(
			"curse_kaki_timah", "curse",
			"Kaki Timah", "Leaden Feet",
			"Kecepatan gerak pemain -15%", "Player movement speed -15%",
			{"player_speed_mult": 0.85}
		),
		_make_card(
			"curse_nafas_sesak", "curse",
			"Nafas Sesak", "Short Breath",
			"Konsumsi stamina lari +30%", "Sprint stamina drain +30%",
			{"stamina_drain_mult": 1.30}
		),
		_make_card(
			"curse_senter_redup", "curse",
			"Senter Redup", "Dimming Torch",
			"Baterai senter boros +35% & jangkauan -18%", "Flashlight drain +35% & range -18%",
			{"flashlight_drain_mult": 1.35, "flashlight_range_mult": 0.82}
		),
		_make_card(
			"curse_bisikan_kubur", "curse",
			"Bisikan Kubur", "Grave Whispers",
			"Penurunan kewarasan +30% & langsung -15% Sanity", "Sanity drain +30% & instant -15% Sanity",
			{"sanity_drain_mult": 1.30},
			{"sanity_delta": -15.0}
		),
		_make_card(
			"curse_tatapan_keranda", "curse",
			"Tatapan Keranda", "Coffin Gaze",
			"Penalti menatap Lampor +35%", "Lampor stare sanity penalty +35%",
			{"stare_drain_mult": 1.35}
		),
		_make_card(
			"curse_angin_lampor", "curse",
			"Angin Lampor", "Lampor's Tempest",
			"Kecepatan patroli & kejar Lampor +14%", "Lampor patrol & chase speed +14%",
			{"lampor_speed_mult": 1.14}
		),
		_make_card(
			"curse_telinga_setan", "curse",
			"Telinga Setan", "Devil's Ear",
			"Jarak pendengaran Lampor +25%", "Lampor hearing range +25%",
			{"lampor_hearing_mult": 1.25}
		),
		_make_card(
			"curse_waktu_terkutuk", "curse",
			"Waktu Terkutuk", "Cursed Clock",
			"Jam malam berjalan +15% lebih cepat", "Night clock progresses +15% faster",
			{"clock_speed_mult": 1.15}
		),
		_make_card(
			"curse_tungku_dingin", "curse",
			"Tungku Dingin", "Cold Furnace",
			"Durasi pembakaran ritual tungku +20% lebih lama", "Furnace ritual burn duration +20% longer",
			{"furnace_duration_mult": 1.20}
		),
		_make_card(
			"curse_langkah_berisik", "curse",
			"Langkah Berisik", "Heavy Footsteps",
			"Suara langkah kaki +30% lebih keras", "Footstep noise +30% louder",
			{"noise_mult": 1.30}
		),

		# 10 KEBERUNTUNGAN (Blessing)
		_make_card(
			"blessing_langkah_angin", "blessing",
			"Langkah Angin", "Wind Stride",
			"Kecepatan gerak pemain +15%", "Player movement speed +15%",
			{"player_speed_mult": 1.15}
		),
		_make_card(
			"blessing_nafas_pendekar", "blessing",
			"Nafas Pendekar", "Warrior's Breath",
			"Konsumsi stamina -25% & pemulihan +25%", "Stamina drain -25% & recovery +25%",
			{"stamina_drain_mult": 0.75, "stamina_regen_mult": 1.25}
		),
		_make_card(
			"blessing_cahaya_pusaka", "blessing",
			"Cahaya Pusaka", "Sacred Light",
			"Baterai hemat 35%, jangkauan senter +22%, & baterai penuh 100%", "Battery drain -35%, range +22%, & full 100% battery",
			{"flashlight_drain_mult": 0.65, "flashlight_range_mult": 1.22},
			{"full_battery": true}
		),
		_make_card(
			"blessing_jiwa_tenang", "blessing",
			"Jiwa Tenang", "Tranquil Spirit",
			"Pemulihan sanity di obor +30%, drain -20%, & +25 Sanity", "Torch sanity regen +30%, drain -20%, & +25 Sanity",
			{"sanity_regen_mult": 1.30, "sanity_drain_mult": 0.80},
			{"sanity_delta": 25.0}
		),
		_make_card(
			"blessing_api_keramat", "blessing",
			"Api Keramat", "Sacred Flame",
			"Durasi pembakaran ritual tungku 25% lebih cepat", "Furnace ritual burn duration 25% faster",
			{"furnace_duration_mult": 0.75}
		),
		_make_card(
			"blessing_bekal_jamu", "blessing",
			"Bekal Jamu", "Herbal Blessing",
			"Dapat 1 Jamu Tolak Bala & +15 Sanity", "Receive 1 Herbal Elixir & +15 Sanity",
			{},
			{"grant_item": "jamu", "sanity_delta": 15.0}
		),
		_make_card(
			"blessing_gema_kentongan", "blessing",
			"Gema Kentongan", "Echoing Kentongan",
			"Efek usir kentongan +50% lebih lama", "Kentongan repel duration +50% longer",
			{"lampor_repel_mult": 1.50}
		),
		_make_card(
			"blessing_langkah_bayangan", "blessing",
			"Langkah Bayangan", "Shadow Step",
			"Kebisingan langkah -35% & pendengaran Lampor -20%", "Footstep noise -35% & Lampor hearing -20%",
			{"noise_mult": 0.65, "lampor_hearing_mult": 0.80}
		),
		_make_card(
			"blessing_waktu_melambat", "blessing",
			"Waktu Melambat", "Slowed Midnight",
			"Jam malam melambat 18% lebih tenang", "Night clock slows down by 18%",
			{"clock_speed_mult": 0.82}
		),
		_make_card(
			"blessing_jimat_pelindung", "blessing",
			"Jimat Pelindung", "Warding Amulet",
			"Kecepatan Lampor -12% & bonus +50 Koin Emas", "Lampor speed -12% & bonus +50 Gold Coins",
			{"lampor_speed_mult": 0.88},
			{"coins_delta": 50}
		)
	]

static func get_all_cards() -> Array[Dictionary]:
	_ensure_catalog()
	var result: Array[Dictionary] = []
	for card: Dictionary in _cached_catalog:
		result.append(card.duplicate(true))
	return result

static func get_card_by_id(card_id: String) -> Dictionary:
	_ensure_catalog()
	for card: Dictionary in _cached_catalog:
		if str(card.get("id", "")) == card_id:
			return card.duplicate(true)
	return {}

static func get_card_title(card: Dictionary) -> String:
	if LocScript.is_en():
		return str(card.get("name_en", card.get("name", "")))
	return str(card.get("name", card.get("name_en", "")))

static func get_card_description(card: Dictionary) -> String:
	if LocScript.is_en():
		return str(card.get("description_en", card.get("description", "")))
	return str(card.get("description", card.get("description_en", "")))

static func get_card_type_label(card: Dictionary) -> String:
	var c_type: String = str(card.get("type", "curse"))
	if c_type == "blessing":
		return LocScript.pick("KEBERUNTUNGAN", "BLESSING")
	return LocScript.pick("KUTUKAN", "CURSE")

static func _pick_from_pool(card_type: String, count: int, exclude_ids: Array[String]) -> Array[Dictionary]:
	_ensure_catalog()
	var excluded_lookup: Dictionary = {}
	for ex_id: String in exclude_ids:
		excluded_lookup[ex_id] = true

	var fresh_pool: Array[Dictionary] = []
	var full_pool: Array[Dictionary] = []
	for card: Dictionary in _cached_catalog:
		if str(card.get("type", "")) != card_type:
			continue
		full_pool.append(card)
		if not excluded_lookup.has(str(card.get("id", ""))):
			fresh_pool.append(card)

	fresh_pool.shuffle()
	full_pool.shuffle()

	var picked: Array[Dictionary] = []
	var picked_ids: Dictionary = {}
	for card: Dictionary in fresh_pool:
		if picked.size() >= count:
			break
		var cid: String = str(card.get("id", ""))
		if not picked_ids.has(cid):
			picked.append(card.duplicate(true))
			picked_ids[cid] = true

	if picked.size() < count:
		for card: Dictionary in full_pool:
			if picked.size() >= count:
				break
			var cid: String = str(card.get("id", ""))
			if not picked_ids.has(cid):
				picked.append(card.duplicate(true))
				picked_ids[cid] = true

	return picked

static func draw_act_pair(exclude_ids: Array[String] = []) -> Dictionary:
	_ensure_catalog()
	var mode: String = PAIRING_MODES[randi() % PAIRING_MODES.size()]
	var pair: Array[Dictionary] = []

	match mode:
		"curse_curse":
			pair = _pick_from_pool("curse", 2, exclude_ids)
		"blessing_blessing":
			pair = _pick_from_pool("blessing", 2, exclude_ids)
		_:
			var blessings: Array[Dictionary] = _pick_from_pool("blessing", 1, exclude_ids)
			var curses: Array[Dictionary] = _pick_from_pool("curse", 1, exclude_ids)
			if not blessings.is_empty():
				pair.append(blessings[0])
			if not curses.is_empty():
				pair.append(curses[0])

	if pair.size() < 2:
		var fallback: Array[Dictionary] = get_all_cards()
		fallback.shuffle()
		for card: Dictionary in fallback:
			if pair.size() >= 2:
				break
			if pair.is_empty() or str(pair[0].get("id", "")) != str(card.get("id", "")):
				pair.append(card)

	pair.shuffle()
	return {
		"pairing": mode,
		"left": pair[0],
		"right": pair[1]
	}
