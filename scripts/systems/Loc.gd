class_name Loc
extends RefCounted

const LANG_ID: String = "id"
const LANG_EN_US: String = "en_US"

static var lang: String = LANG_ID

static func normalize_language(code: String) -> String:
	var c: String = code.strip_edges().to_lower().replace("-", "_")
	if c == "en" or c == "en_us" or c == "english":
		return LANG_EN_US
	return LANG_ID

static func set_language(code: String) -> void:
	lang = normalize_language(code)

static func get_language() -> String:
	return lang

static func is_en() -> bool:
	return lang == LANG_EN_US

static func pick(id_text: String, en_text: String) -> String:
	return en_text if lang == LANG_EN_US else id_text

static func action_label(action: String) -> String:
	var labels_id: Dictionary = {
		"move_forward": "Maju",
		"move_backward": "Mundur",
		"move_left": "Geser Kiri",
		"move_right": "Geser Kanan",
		"sprint": "Lari (Sprint)",
		"interact": "Interaksi / Gunakan Item",
		"flashlight": "Nyalakan / Matikan Senter",
		"toggle_inventory": "Buka / Tutup Tas",
		"drop_item": "Buang Item",
		"slot_1": "Slot Tas 1",
		"slot_2": "Slot Tas 2",
		"slot_3": "Slot Tas 3",
		"slot_4": "Slot Tas 4",
		"slot_5": "Slot Tas 5"
	}
	var labels_en: Dictionary = {
		"move_forward": "Move Forward",
		"move_backward": "Move Backward",
		"move_left": "Move Left",
		"move_right": "Move Right",
		"sprint": "Sprint (Hold)",
		"interact": "Interact / Use Item",
		"flashlight": "Toggle Flashlight",
		"toggle_inventory": "Toggle Inventory",
		"drop_item": "Drop Item",
		"slot_1": "Hotbar Slot 1",
		"slot_2": "Hotbar Slot 2",
		"slot_3": "Hotbar Slot 3",
		"slot_4": "Hotbar Slot 4",
		"slot_5": "Hotbar Slot 5"
	}
	if is_en():
		return str(labels_en.get(action, action))
	return str(labels_id.get(action, action))

static func item_name(item_id: String, fallback: String = "") -> String:
	var id_names: Dictionary = {
		"flashlight": "Senter",
		"baterai": "Baterai Senter",
		"battery": "Baterai Senter",
		"jamu": "Jamu Tolak Bala",
		"minyak_tanah": "Minyak Tanah & Korek",
		"papan_paku": "Papan & Paku",
		"barricade_kit": "Papan & Paku",
		"kentongan": "Kentongan",
		"energy_drink": "Energy Drink",
		"extra_life": "Nyawa Tambahan",
		"keris": "Keris Pusaka",
		"kemenyan": "Kemenyan Tua",
		"bunga": "Bunga 7 Rupa",
		"tanah": "Tanah Kuburan"
	}
	var en_names: Dictionary = {
		"flashlight": "Flashlight",
		"baterai": "Flashlight Battery",
		"battery": "Flashlight Battery",
		"jamu": "Herbal Elixir",
		"minyak_tanah": "Kerosene & Matches",
		"papan_paku": "Planks & Nails",
		"barricade_kit": "Planks & Nails",
		"kentongan": "Kentongan",
		"energy_drink": "Energy Drink",
		"extra_life": "Extra Life",
		"keris": "Heirloom Keris",
		"kemenyan": "Ancient Incense",
		"bunga": "Seven-Flower Offering",
		"tanah": "Graveyard Soil"
	}
	if is_en():
		return str(en_names.get(item_id, fallback if not fallback.is_empty() else item_id))
	return str(id_names.get(item_id, fallback if not fallback.is_empty() else item_id))

static func dialogue_pool(category: String) -> Array[String]:
	if is_en():
		match category:
			"sanity_mid":
				return [
					"My head feels heavy... is something watching me from the dark?",
					"These whispers in my ears won't stop... keep moving.",
					"My vision blurs around the edges. I can't lose focus now."
				]
			"sanity_low":
				return [
					"No... the shadows are crawling closer. Get out of my head!",
					"My hands won't stop shaking. Every corner feels alive!",
					"I have to find a lit torch or take a herbal tonic soon..."
				]
			"sanity_critical":
				return [
					"My mind is slipping! The darkness is swallowing everything!",
					"I can't breathe... the Lampor curses are tearing into my sanity!",
					"Focus! Don't let the terror break you—one step at a time!"
				]
			"stamina_low":
				return [
					"Hah... my legs feel like lead...",
					"I'm running out of breath... need to catch my wind.",
					"My chest burns... I can't keep sprinting much longer."
				]
			"stamina_exhausted":
				return [
					"I can't run anymore! Give me a second to breathe!",
					"Out of breath... I can only walk right now!",
					"My legs are about to give out! Need stamina..."
				]
			"battery_low":
				return [
					"My flashlight is flickering... the battery is almost dead.",
					"Only a sliver of battery left. I should look for a spare battery."
				]
			"battery_empty":
				return [
					"My flashlight died! It's pitch black out here!",
					"No battery left... I have to rely on street torches now."
				]
			"hiding_enter":
				return [
					"Stay quiet... don't make a single sound.",
					"Hold your breath. Maybe it won't check inside here."
				]
			"hiding_exit":
				return [
					"Alright... I think the coast is clear enough to move.",
					"Still breathing. Time to finish what needs to be done."
				]
			"lampor_near":
				return [
					"That cold wind... Lampor is right around the corner!",
					"I hear the creaking shroud—something is close!"
				]
			"lampor_repel":
				return [
					"The kentongan worked! It's retreating—run while I have the chance!",
					"That loud crack shook Lampor back! Five seconds won't last long!"
				]
			"safezone_relief":
				return [
					"The warm torchlight steadies my nerves a bit.",
					"At least the fire keeps the worst of the dread away."
				]
			"time_02":
				return ["It's past 02:00 WIB... the village feels even colder now."]
			"time_03":
				return ["03:00 WIB—the deadest hour of the night. Stay alert."]
			"time_04":
				return ["04:00 WIB! Dawn isn't far off—almost at the final stretch!"]
		return []
	else:
		match category:
			"sanity_mid":
				return [
					"Kepalaku terasa berat... seperti ada yang mengawasi dari gelap.",
					"Bisikan ini mulai mengganggu telingaku... aku harus tetap fokus.",
					"Pandanganku agak goyah. Jangan sampai pikiranku tumbang."
				]
			"sanity_low":
				return [
					"Bayangan di sekitar mulai bergerak sendiri... keluar dari kepalaku!",
					"Tanganku gemetar hebat. Aku harus cari obor menyala atau minum jamu!",
					"Kewarasanku menipis... suara-suara itu makin keras!"
				]
			"sanity_critical":
				return [
					"Tidak... pikiranku hampir pecah! Kegelapan ini mencekikku!",
					"Nafasku sesak! Kutukan Lampor menggerogoti kewarasanku!",
					"Sadar! Jangan biarkan ketakutan ini menguasai diriku!"
				]
			"stamina_low":
				return [
					"Hah... kakiku mulai terasa berat sekali...",
					"Nafasku terengah-engah... sebentar lagi tenagaku habis.",
					"Dadaku sesak, tidak kuat berlari terus-menerus."
				]
			"stamina_exhausted":
				return [
					"Tenagaku habis! Tidak bisa lari dulu!",
					"Huff... huff... kakiku lemas, harus tarik nafas sebentar!",
					"Staminaku terkuras habis! Aku hanya bisa jalan pelan sekarang."
				]
			"battery_low":
				return [
					"Senterku mulai redup... baterainya hampir habis.",
					"Daya senter tinggal sedikit. Aku harus cari baterai cadangan."
				]
			"battery_empty":
				return [
					"Senterku mati total! Gelap gulita sekali!",
					"Baterai habis! Harus mengandalkan cahaya obor atau segera isi daya."
				]
			"hiding_enter":
				return [
					"Diam... jangan bersuara sedikit pun.",
					"Tahan nafas... semoga makhluk itu tidak mengecek ke dalam sini."
				]
			"hiding_exit":
				return [
					"Sepertinya cukup aman untuk keluar sekarang.",
					"Masih selamat. Ayo lanjutkan sebelum terlambat."
				]
			"lampor_near":
				return [
					"Angin dingin ini... Lampor ada di dekat sini!",
					"Suara keranda itu... dia semakin mendekat!"
				]
			"lampor_repel":
				return [
					"Kentongannya berhasil! Lampor terpukul mundur—cepat manfaatkan waktunya!",
					"Suara kentongan membuatnya kabur sementara! Jangan buang 5 detik ini!"
				]
			"safezone_relief":
				return [
					"Cahaya obor ini sedikit menenangkan pikiranku.",
					"Api ini menahan rasa takutku... setidaknya untuk sesaat."
				]
			"time_02":
				return ["Sudah lewat pukul 02.00 WIB... kampung ini terasa makin mencekam."]
			"time_03":
				return ["Pukul 03.00 WIB—jam paling sunyi dan berbahaya. Tetap waspada."]
			"time_04":
				return ["Pukul 04.00 WIB! Fajar hampir tiba—sebentar lagi semuanya berakhir!"]
		return []
