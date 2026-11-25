extends RefCounted

# Multilingual Profanity Filter (mirrored with backend api/_lib/profanity.js)
# Censors profanity from Indonesian/Malay, regional languages, English, Spanish,
# French, German, Portuguese, Italian, Russian, Japanese, Korean, Chinese,
# Arabic, Tagalog, Turkish, Hindi, Polish, and Dutch with "***".

const EXACT_WORDS: Array[String] = [
	# Indonesian & Malay & Javanese/Sundanese
	"anjing", "anjir", "anjrit", "anjay", "anying", "asu", "bangsat", "bajingan",
	"babi", "bacot", "bego", "bebal", "bencong", "banci", "brengsek", "brengsex",
	"cibai", "cok", "coeg", "cuk", "cukimai", "dancok", "dancuk", "entot", "ewe",
	"gathel", "gatel", "goblok", "goblog", "idiot", "jancok", "jancuk", "jangkrik",
	"jembut", "kampret", "kampang", "keparat", "kerek", "kimak", "kontol", "kntl",
	"koplok", "kunyuk", "lonte", "matamu", "memek", "mmk", "monyet", "ndasmu",
	"ngentot", "ngtd", "ngewe", "pantek", "peler", "pepek", "perek", "pukimak",
	"raimu", "sialan", "setan", "sinting", "sompret", "sundal", "taek", "tai",
	"tahi", "tetek", "toket", "tolol", "udik", "colmek", "coli", "bokep",
	"pelacur", "jalang", "bejad", "biadab", "bedebah", "modar", "mampus",
	"bangke", "bangkai", "sarap", "pecun", "jablay", "bloon", "dungu", "laknat",
	"titit", "burit", "dubur", "kehed", "belegug", "bedes", "kirik",
	# English
	"fuck", "fucker", "fucking", "fucked", "fck", "fuk", "motherfucker", "mf",
	"shit", "shitty", "bullshit", "bitch", "bitches", "bastard", "asshole",
	"arsehole", "dick", "dickhead", "cock", "cunt", "pussy", "whore", "slut",
	"hoe", "wanker", "twat", "prick", "bollocks", "bugger", "crap", "douche",
	"douchebag", "faggot", "fag", "nigger", "nigga", "retard", "retarded",
	"porn", "hentai", "blowjob", "handjob", "jackass", "dumbass", "dipshit",
	"shithead", "stfu", "gtfo", "wtf", "kys", "cum", "jizz", "dildo", "boobs",
	"tits", "milf", "thot", "skank", "scumbag", "rape", "rapist", "ass",
	# Spanish
	"puta", "puto", "pendejo", "cabron", "mierda", "chinga", "chingar", "chingada",
	"pinche", "verga", "culero", "maricon", "joder", "cono", "gilipollas",
	"capullo", "hijodeputa", "malparido", "gonorrea", "boludo", "pelotudo",
	"carajo", "mamada", "zorra", "perra",
	# French
	"merde", "putain", "salope", "connard", "connasse", "encule", "enculer",
	"foutre", "bordel", "batard", "petasse", "nique", "ntm", "fdp", "filsdepute",
	"couille", "bite", "chatte", "cul", "abruti", "crevard",
	# German
	"scheisse", "arschloch", "hurensohn", "fotze", "wichser", "schlampe", "ficken",
	"fick", "miststuck", "drecksau", "spast", "vollidiot", "verdammt", "kacke",
	"schwanz", "nutte",
	# Portuguese
	"porra", "caralho", "buceta", "foder", "foda", "fodase", "filhodaputa",
	"desgraca", "viado", "arrombado", "cuzao", "babaca", "otario", "vagabunda",
	"cacete",
	# Italian
	"cazzo", "vaffanculo", "stronzo", "puttana", "troia", "coglione", "bastardo",
	"minchia", "fanculo", "deficiente",
	# Russian (romanized)
	"blyat", "blyad", "suka", "cyka", "khuy", "hui", "pizda", "ebat", "yebat",
	"pidor", "pidoras", "mudak", "gandon", "nahui", "nakhui",
	# Japanese (romanized)
	"kuso", "kusoyaro", "chikusho", "chinko", "manko", "yariman", "kutabare",
	"fuzakeruna", "bakayaro", "aho",
	# Korean (romanized)
	"ssibal", "shibal", "sibal", "byeongsin", "byungsin", "gaesaekki", "saekki",
	"jiral", "jonna",
	# Chinese (pinyin)
	"cnm", "tmd", "nmsl", "shabi", "caonima", "tamade", "wocaonima", "gundan",
	"hundan", "biaozi",
	# Arabic (romanized)
	"kosomak", "kuss", "sharmouta", "sharmuta", "kahba", "qahba", "ibnelkalb",
	"khawal", "manyouk",
	# Tagalog
	"putangina", "tangina", "gago", "gagu", "ulol", "tarantado", "bobo", "tanga",
	"pakyu", "kantot", "pokpok", "punyeta", "leche", "kupal", "burat", "puke",
	"tite", "hindot",
	# Turkish / Hindi / Polish / Dutch
	"amk", "aq", "siktir", "sik", "orospu", "pic", "yarrak", "anani",
	"madarchod", "bhenchod", "behenchod", "chutiya", "bhosdike", "gandu",
	"harami", "kamina", "randi", "lund", "chut", "kurwa", "chuj", "pierdol",
	"jebac", "spierdalaj", "kanker", "klootzak", "tering", "hoer", "lul"
]

const SUBSTRING_ROOTS: Array[String] = [
	"motherfucker", "filhodaputa", "spierdalaj", "madarchod", "behenchod",
	"hijodeputa", "vaffanculo", "putangina", "sharmouta", "wocaonima",
	"filsdepute", "gaesaekki", "hurensohn", "arschloch", "malparido",
	"arrombado", "byeongsin", "bhenchod", "bhosdike", "scheisse",
	"klootzak", "bajingan", "brengsek", "bullshit", "dickhead",
	"chingada", "sharmuta", "asshole", "arsehole", "fucking",
	"bangsat", "ngentot", "pukimak", "pelacur", "dipshit",
	"shithead", "scumbag", "pendejo", "chingar", "tangina",
	"kosomak", "chutiya", "caralho", "enculer", "caonima",
	"anjing", "dancok", "dancuk", "goblok", "goblog",
	"jancok", "jancuk", "jembut", "kampret", "keparat",
	"kontol", "pantek", "sundal", "colmek", "fucker",
	"faggot", "nigger", "retard", "blowjob", "handjob",
	"cabron", "mierda", "stronzo", "puttana", "buceta",
	"putain", "salope", "connard", "gandon", "ssibal",
	"shibal", "memek", "ngewe", "pepek", "tolol",
	"bokep", "bitch", "bastard", "whore", "nigga",
	"blyat", "pizda", "pidor", "mudak", "shabi",
	"kurwa", "fuck"
]

const NON_LATIN_PATTERNS: Array[String] = [
	"блядь", "блять", "сука", "хуй", "пизда", "ебать", "ёбаный", "ебаный",
	"пидор", "пидорас", "мудак", "гандон", "дерьмо", "уёбок", "уебок",
	"залупа", "шлюха",
	"くそ", "クソ", "糞", "死ね", "しね", "シネ", "馬鹿", "ばか", "バカ",
	"アホ", "あほ", "ちんこ", "チンコ", "まんこ", "マンコ", "ファック",
	"ビッチ", "くたばれ", "きもい", "ざけんな", "ふざけんな", "ちくしょう",
	"씨발", "시발", "ㅅㅂ", "ㅆㅂ", "병신", "ㅂㅅ", "개새끼", "새끼", "지랄",
	"ㅈㄹ", "미친놈", "미친년", "존나", "좆", "보지", "자지", "창녀",
	"꺼져", "닥쳐", "썅", "호로",
	"操你妈", "草泥马", "妈的", "他妈的", "傻逼", "傻B", "煞笔", "牛逼",
	"滚蛋", "混蛋", "王八蛋", "去死", "尼玛", "婊子", "贱人", "畜生", "狗娘养的",
	"كسمك", "شرموطة", "شرموط", "قحبة", "قحبه", "زبي", "طيز", "ابن الكلب",
	"يلعن", "عاهرة", "منيك", "خول"
]

const PHRASES: Array[String] = [
	"putang ina",
	"tang ina",
	"figlio di puttana",
	"testa di cazzo",
	"porco dio",
	"suck my"
]

const SAFE_ALLOWLIST: Array[String] = [
	"classic", "assassin", "night", "malam", "lampor", "desa", "obor", "keris",
	"hello", "pass", "class", "grass", "skill", "title", "shell", "bass",
	"glass", "mass", "compass", "embassy", "harass", "scunthorpe", "cockpit",
	"peacock", "dickens", "hancock", "scrap", "scrape", "scraping"
]

static var _exact_set: Dictionary = {}
static var _allow_set: Dictionary = {}
static var _sets_ready: bool = false
static var _rx_token: RegEx = null
static var _rx_spaced: RegEx = null
static var _rx_multi_censor: RegEx = null

static func _ensure_init() -> void:
	if _sets_ready:
		return
	_sets_ready = true
	for w: String in EXACT_WORDS:
		_exact_set[w] = true
	for a: String in SAFE_ALLOWLIST:
		_allow_set[a] = true
	_rx_token = RegEx.new()
	_rx_token.compile("[A-Za-z0-9_\\*\\@\\!\\$\\+\\|\\x{00C0}-\\x{024F}]+")
	_rx_spaced = RegEx.new()
	_rx_spaced.compile("\\b(?:[a-zA-Z0-9@$!*](?:[\\s.*_-]+)){2,}[a-zA-Z0-9@$!*]\\b")
	_rx_multi_censor = RegEx.new()
	_rx_multi_censor.compile("(\\*\\*\\*){2,}")

static func _strip_diacritics_basic(s: String) -> String:
	var out: String = s.replace("ß", "ss").replace("ø", "o").replace("ñ", "n")
	for pair: Array in [
		["à", "a"], ["á", "a"], ["â", "a"], ["ä", "a"], ["ã", "a"], ["å", "a"],
		["è", "e"], ["é", "e"], ["ê", "e"], ["ë", "e"],
		["ì", "i"], ["í", "i"], ["î", "i"], ["ï", "i"],
		["ò", "o"], ["ó", "o"], ["ô", "o"], ["ö", "o"], ["õ", "o"],
		["ù", "u"], ["ú", "u"], ["û", "u"], ["ü", "u"],
		["ç", "c"], ["ğ", "g"], ["ş", "s"], ["ı", "i"]
	]:
		out = out.replace(pair[0], pair[1])
	return out

static func _normalize_leet(s: String) -> String:
	var out: String = _strip_diacritics_basic(s.to_lower())
	out = out.replace("0", "o").replace("1", "i").replace("!", "i").replace("|", "i")
	out = out.replace("3", "e").replace("4", "a").replace("@", "a")
	out = out.replace("5", "s").replace("$", "s").replace("7", "t").replace("+", "t").replace("8", "b")
	return out

static func _only_latin_alpha(s: String) -> String:
	var out: String = ""
	for i: int in range(s.length()):
		var c: int = s.unicode_at(i)
		if c >= 97 and c <= 122:
			out += s[i]
	return out

static func _collapse_runs(s: String, max_run: int = 1) -> String:
	var out: String = ""
	var prev: String = ""
	var cnt: int = 0
	for i: int in range(s.length()):
		var ch: String = s[i]
		if ch == prev:
			cnt += 1
			if cnt <= max_run:
				out += ch
		else:
			prev = ch
			cnt = 1
			out += ch
	return out

static func _is_token_profane(raw_token: String) -> bool:
	_ensure_init()
	if raw_token.is_empty():
		return false
	var low_raw: String = _strip_diacritics_basic(raw_token.to_lower())
	if _allow_set.has(low_raw):
		return false
	var alpha_raw: String = _only_latin_alpha(low_raw)
	if _allow_set.has(alpha_raw):
		return false

	var leet: String = _normalize_leet(raw_token)
	var leet_alpha: String = _only_latin_alpha(leet)

	var candidates: Array[String] = [
		low_raw, alpha_raw,
		_collapse_runs(low_raw, 1), _collapse_runs(low_raw, 2),
		leet, leet_alpha,
		_collapse_runs(leet, 1), _collapse_runs(leet, 2),
		_collapse_runs(leet_alpha, 1), _collapse_runs(leet_alpha, 2)
	]

	for seg: String in raw_token.split("_", false):
		if seg.length() >= 2:
			var sl: String = _strip_diacritics_basic(seg.to_lower())
			var sleet: String = _normalize_leet(seg)
			candidates.append(sl)
			candidates.append(_collapse_runs(sl, 1))
			candidates.append(_collapse_runs(sl, 2))
			candidates.append(sleet)
			candidates.append(_collapse_runs(sleet, 1))
			candidates.append(_collapse_runs(sleet, 2))

	for cand: String in candidates:
		if not cand.is_empty() and _exact_set.has(cand):
			return true

	var had_mask: bool = raw_token.contains("*") or raw_token.contains("@") or raw_token.contains("$") or raw_token.contains("!") or raw_token.contains("_")
	for cand: String in candidates:
		if cand.length() < 4:
			continue
		for root: String in SUBSTRING_ROOTS:
			if cand.contains(root):
				if not had_mask and root == "fuck" and cand.contains("fuchs"):
					continue
				return true

	if raw_token.contains("*"):
		var star_cnt: int = raw_token.count("*")
		if star_cnt < raw_token.length():
			var t_len: int = raw_token.length()
			for w: String in EXACT_WORDS:
				if w.length() == t_len:
					var ok_match: bool = true
					for i: int in range(t_len):
						var tc: String = raw_token[i].to_lower()
						if tc != "*" and tc != w[i] and _normalize_leet(tc) != w[i]:
							ok_match = false
							break
					if ok_match:
						return true
		var stripped_star: String = low_raw.replace("*", "")
		if _exact_set.has(stripped_star):
			return true

	return false

static func censor(input: String) -> String:
	_ensure_init()
	if input.is_empty():
		return ""
	var text: String = input

	# 1. Non-Latin patterns
	for pat: String in NON_LATIN_PATTERNS:
		if text.to_lower().contains(pat.to_lower()):
			text = text.replacen(pat, "***")

	# 2. Multi-word phrases
	for phrase: String in PHRASES:
		var rx_p := RegEx.new()
		var joined: String = "[\\s._*\\-]+".join(phrase.split(" "))
		rx_p.compile("(?i)\\b" + joined + "\\b")
		text = rx_p.sub(text, "***", true)

	# 3. Separated letter sequences (e.g. "f.u.c.k", "a n j i n g", "k-o-n-t-o-l")
	var spaced_matches: Array[RegExMatch] = _rx_spaced.search_all(text)
	for idx: int in range(spaced_matches.size() - 1, -1, -1):
		var m: RegExMatch = spaced_matches[idx]
		var span_str: String = m.get_string()
		var compact: String = _only_latin_alpha(_normalize_leet(span_str))
		var collapsed: String = _collapse_runs(compact, 1)
		var is_bad: bool = _exact_set.has(compact) or _exact_set.has(collapsed)
		if not is_bad:
			for r: String in SUBSTRING_ROOTS:
				if compact.contains(r) or collapsed.contains(r):
					is_bad = true
					break
		if is_bad:
			text = text.left(m.get_start()) + "***" + text.substr(m.get_end())

	# 4. Token-by-token scan preserving trailing '!' / '+'
	var tok_matches: Array[RegExMatch] = _rx_token.search_all(text)
	for idx: int in range(tok_matches.size() - 1, -1, -1):
		var m: RegExMatch = tok_matches[idx]
		var raw_tok: String = m.get_string()
		var trailing: String = ""
		var core: String = raw_tok
		while core.length() > 1 and (core.ends_with("!") or core.ends_with("+")):
			trailing = core.right(1) + trailing
			core = core.left(core.length() - 1)
		if _is_token_profane(core):
			text = text.left(m.get_start()) + "***" + trailing + text.substr(m.get_end())

	text = _rx_multi_censor.sub(text, "***", true)
	return text

static func contains_profanity(input: String) -> bool:
	if input.strip_edges().is_empty():
		return false
	return censor(input) != input
