# LAMPOR — Production Voice Script & Google AI Studio TTS Guide

**Project:** LAMPOR (v1.3.0)  
**Total Unique Voice Clips:** `91` (`35` Player Male/Female lines + `56` Narrator lines)  
**Languages:** Indonesian (`id`) & English (`en_US`) — extracted 100% verbatim from `scripts/**/*.gd` and `scenes/ui/*.tscn`.

---

## Google AI Studio Batch Generation Guide

### 1. Recommended Gemini TTS Models
- **Primary Expressive TTS (`gemini-3.8-flash-tts`):** Best control via `speech_metadata` acting directions, native `24 kHz` WAV output, and consistent breath/emotion pacing across all horror monologues, cutscenes, and system cues.
- **High-Throughput Batch (`gemini-3.8-flash-lite-tts`):** Faster, lower-cost variant for bulk tutorial or quick iteration runs.

### 2. Suggested Male, Female & Narrator Voice Pairings
| Role | Target Folders | Primary Prebuilt Voice | Optional Character Alternatives | Casting Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Player (Adult Male)** | `assets/audio/voice/id/male/`<br>`assets/audio/voice/en/male/` | **`Enceladus`** *(Breathy lower-middle)* | `Orus` *(firm)*, `Fenrir` *(intense panic)* | Grounded, breathy adult Indonesian male survivor; matches `adult_male.glb`. |
| **Player (Adult Female)** | `assets/audio/voice/id/female/`<br>`assets/audio/voice/en/female/` | **`Vindemiatrix`** *(Gentle intimate tone)* | `Achernar` *(soft)*, `Kore` *(firm)*, `Gacrux` *(mature poise)* | Natural gentle/breathy counterpart to `Enceladus`; matches `adult_female.glb`. |
| **Narrator (Folklore & System)** | `assets/audio/voice/id/narrator/`<br>`assets/audio/voice/en/narrator/` | **`Algenib`** *(Gravelly lower pitch)* | `Charon` *(calm authoritative guide)* | Use `Algenib` for cutscenes, warnings & deaths; `Charon` optionally for tutorial steps. |

### 3. Audio Format & Folder Layout
- **Target Audio Format:** `WAV` (`24 kHz`, `16-bit PCM`, `Mono`) — native Gemini 3.8 TTS WAV output (`AudioStreamWAV` ready for Godot 4).
- **Mastering Target:** Normalize speech to `-16 LUFS`, true peak ceiling `-1.0 dBTP`, trim leading/trailing silence below `80 ms`.
- **Narrator Sharing Note:** `Player (Male / Female)` clips (`35` IDs) are generated twice per language into `male/` and `female/`. `Narrator` clips (`56` IDs) are generated once per language into `narrator/`.

```text
assets/audio/voice/
├── voice_manifest.json
├── id/
│   ├── male/        # 35 Player Male lines (Indonesian - Enceladus)
│   ├── female/      # 35 Player Female lines (Indonesian - Vindemiatrix)
│   └── narrator/    # 56 Narrator lines (Indonesian - Algenib)
└── en/
    ├── male/        # 35 Player Male lines (English - Enceladus)
    ├── female/      # 35 Player Female lines (English - Vindemiatrix)
    └── narrator/    # 56 Narrator lines (English - Algenib)
```

### 4. Copy-Pasteable Google AI Studio UI Prompt Template
Use **Audio / Speech Generation** in Google AI Studio (`gemini-3.8-flash-tts`), select the prebuilt voice above (`Enceladus`, `Vindemiatrix`, or `Algenib`), set Style Instruction, and enter the exact transcript:

```text
Style direction: Natural Indonesian (id-ID) [or English (en-US)], Javanese folklore survival-horror tone. <INSERT Emotion / Style Prompt>

<INSERT Exact Text (or TTS Speakable Text if placeholders are present)>
```

### 5. Automated Batch Generator (`tools/voice/generate_voice_lines.py`)
Run directly from the `Lampor` project root using the official `google-genai` Interactions API:

```powershell
# Preview seluruh job tanpa API key
py -3.11 tools/voice/generate_voice_lines.py --dry-run

# Generate semua suara Indonesia (126 WAV: Enceladus + Vindemiatrix + Algenib)
$env:GEMINI_API_KEY="YOUR_AI_STUDIO_KEY"
py -3.11 tools/voice/generate_voice_lines.py --lang id

# Generate dwibahasa lengkap Indonesia + Inggris (252 WAV)
py -3.11 tools/voice/generate_voice_lines.py --lang both
```

API pattern used (`google-genai >= 3.5.0`):

```python
import base64
from google import genai

client = genai.Client(http_options={"api_version": "v1beta"})
interaction = client.interactions.create(
    model="gemini-3.8-flash-tts",
    input=[{
        "type": "user_input",
        "content": [{
            "type": "text",
            "text": spoken_text,
            "annotations": [{
                "type": "speech_metadata",
                "style": style_direction,
            }],
        }],
    }],
    response_format={"type": "audio"},
    generation_config={"speech_config": [{"voice": "Enceladus"}]},
    store=False,
)
wav_bytes = base64.b64decode(interaction.output_audio.data)
```

### 6. Placeholder & Source Gap Conventions
- **Format Placeholders (`%s`, `%d`, `%.1f`):** Lines with runtime variables (e.g. `vo_item_energy_active_01`, `vo_revive_extra_life_01`, `vo_tutorial_*`) list the **exact verbatim GDScript string** first, followed by a clean **`TTS Speakable Adaptation`** (also stored in `tts_text_id` / `tts_text_en` inside `voice_manifest.json`) so TTS never reads `%s` or `%d` literally.
- **Indonesian-Only Source Strings:** Four legacy/direct strings in the codebase (`HUD.gd:2391`, `GameManager.gd:1768`, `TutorialOverlay.gd:210`, and static scene text in `VictoryScreen.tscn:48-50` / `GameOverScreen.tscn:48`) lack `LocScript.pick(...)` English strings. Verbatim ID text is preserved and tagged `[ID-only in code; recommended EN TTS]` with an accurate English translation.

---

## 1. Monolog Kewarasan / Sanity (`sanity_mid`, `sanity_low`, `sanity_critical`)

*Clips in section: **9***

### `vo_sanity_mid_01`
- **Clip ID:** `vo_sanity_mid_01`
- **Source:** `Loc.gd :: dialogue_pool("sanity_mid")[0] (SanitySystem.gd:126)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Low, uneasy inner monologue; slightly dizzy and suspicious, glancing nervously into the dark at a measured whisper-talk.
- **Exact Teks Indonesia (ID):** `Kepalaku terasa berat... seperti ada yang mengawasi dari gelap.`
- **Exact English Text (EN):** `My head feels heavy... is something watching me from the dark?`
- **Suggested Filename:** `vo_sanity_mid_01.wav`

### `vo_sanity_mid_02`
- **Clip ID:** `vo_sanity_mid_02`
- **Source:** `Loc.gd :: dialogue_pool("sanity_mid")[1] (SanitySystem.gd:126)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Tense, hushed mutter; trying to tune out eerie whispers while pushing forward nervously.
- **Exact Teks Indonesia (ID):** `Bisikan ini mulai mengganggu telingaku... aku harus tetap fokus.`
- **Exact English Text (EN):** `These whispers in my ears won't stop... keep moving.`
- **Suggested Filename:** `vo_sanity_mid_02.wav`

### `vo_sanity_mid_03`
- **Clip ID:** `vo_sanity_mid_03`
- **Source:** `Loc.gd :: dialogue_pool("sanity_mid")[2] (SanitySystem.gd:126)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Shaken yet determined; slightly strained breathing, forcing mental clarity through creeping disorientation.
- **Exact Teks Indonesia (ID):** `Pandanganku agak goyah. Jangan sampai pikiranku tumbang.`
- **Exact English Text (EN):** `My vision blurs around the edges. I can't lose focus now.`
- **Suggested Filename:** `vo_sanity_mid_03.wav`

### `vo_sanity_low_01`
- **Clip ID:** `vo_sanity_low_01`
- **Source:** `Loc.gd :: dialogue_pool("sanity_low")[0] (SanitySystem.gd:126)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Frightened, trembling voice building to a panicked plea; paranoid and breathless as hallucinations close in.
- **Exact Teks Indonesia (ID):** `Bayangan di sekitar mulai bergerak sendiri... keluar dari kepalaku!`
- **Exact English Text (EN):** `No... the shadows are crawling closer. Get out of my head!`
- **Suggested Filename:** `vo_sanity_low_01.wav`

### `vo_sanity_low_02`
- **Clip ID:** `vo_sanity_low_02`
- **Source:** `Loc.gd :: dialogue_pool("sanity_low")[1] (SanitySystem.gd:126)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Anxious, shivering urgency; fast uneven breathing, desperate to find relief from encroaching terror.
- **Exact Teks Indonesia (ID):** `Tanganku gemetar hebat. Aku harus cari obor menyala atau minum jamu!`
- **Exact English Text (EN):** `My hands won't stop shaking. Every corner feels alive!`
- **Suggested Filename:** `vo_sanity_low_02.wav`

### `vo_sanity_low_03`
- **Clip ID:** `vo_sanity_low_03`
- **Source:** `Loc.gd :: dialogue_pool("sanity_low")[2] (SanitySystem.gd:126)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Distressed, edge-of-panic tone; wavering voice pressured by louder supernatural whispers.
- **Exact Teks Indonesia (ID):** `Kewarasanku menipis... suara-suara itu makin keras!`
- **Exact English Text (EN):** `I have to find a lit torch or take a herbal tonic soon...`
- **Suggested Filename:** `vo_sanity_low_03.wav`

### `vo_sanity_critical_01`
- **Clip ID:** `vo_sanity_critical_01`
- **Source:** `Loc.gd :: dialogue_pool("sanity_critical")[0] (SanitySystem.gd:126)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Raw, suffocating terror; cracking voice on the verge of breakdown, choked breath and frantic desperation.
- **Exact Teks Indonesia (ID):** `Tidak... pikiranku hampir pecah! Kegelapan ini mencekikku!`
- **Exact English Text (EN):** `My mind is slipping! The darkness is swallowing everything!`
- **Suggested Filename:** `vo_sanity_critical_01.wav`

### `vo_sanity_critical_02`
- **Clip ID:** `vo_sanity_critical_02`
- **Source:** `Loc.gd :: dialogue_pool("sanity_critical")[1] (SanitySystem.gd:126)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Gasping, claustrophobic panic; tight throat, strained whisper-shout fighting overwhelming dread.
- **Exact Teks Indonesia (ID):** `Nafasku sesak! Kutukan Lampor menggerogoti kewarasanku!`
- **Exact English Text (EN):** `I can't breathe... the Lampor curses are tearing into my sanity!`
- **Suggested Filename:** `vo_sanity_critical_02.wav`

### `vo_sanity_critical_03`
- **Clip ID:** `vo_sanity_critical_03`
- **Source:** `Loc.gd :: dialogue_pool("sanity_critical")[2] (SanitySystem.gd:126)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Fierce, trembling self-command; shaking breath pulling back from madness with sheer willpower.
- **Exact Teks Indonesia (ID):** `Sadar! Jangan biarkan ketakutan ini menguasai diriku!`
- **Exact English Text (EN):** `Focus! Don't let the terror break you—one step at a time!`
- **Suggested Filename:** `vo_sanity_critical_03.wav`

## 2. Monolog Stamina & Fisik (`stamina_low`, `stamina_exhausted`)

*Clips in section: **6***

### `vo_stamina_low_01`
- **Clip ID:** `vo_stamina_low_01`
- **Source:** `Loc.gd :: dialogue_pool("stamina_low")[0] (PlayerController.gd:377)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Winded, heavy breathing mid-jog; tired sigh and physical strain in the legs.
- **Exact Teks Indonesia (ID):** `Hah... kakiku mulai terasa berat sekali...`
- **Exact English Text (EN):** `Hah... my legs feel like lead...`
- **Suggested Filename:** `vo_stamina_low_01.wav`

### `vo_stamina_low_02`
- **Clip ID:** `vo_stamina_low_02`
- **Source:** `Loc.gd :: dialogue_pool("stamina_low")[1] (PlayerController.gd:377)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Panting between phrases; short urgent inhales while trying to keep moving.
- **Exact Teks Indonesia (ID):** `Nafasku terengah-engah... sebentar lagi tenagaku habis.`
- **Exact English Text (EN):** `I'm running out of breath... need to catch my wind.`
- **Suggested Filename:** `vo_stamina_low_02.wav`

### `vo_stamina_low_03`
- **Clip ID:** `vo_stamina_low_03`
- **Source:** `Loc.gd :: dialogue_pool("stamina_low")[2] (PlayerController.gd:377)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Tight, winded chest strain; laboured speech forced out through rapid breathing.
- **Exact Teks Indonesia (ID):** `Dadaku sesak, tidak kuat berlari terus-menerus.`
- **Exact English Text (EN):** `My chest burns... I can't keep sprinting much longer.`
- **Suggested Filename:** `vo_stamina_low_03.wav`

### `vo_stamina_exhausted_01`
- **Clip ID:** `vo_stamina_exhausted_01`
- **Source:** `Loc.gd :: dialogue_pool("stamina_exhausted")[0] (PlayerController.gd:374)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Completely spent, ragged panting; urgent and breathless as sprint gives out.
- **Exact Teks Indonesia (ID):** `Tenagaku habis! Tidak bisa lari dulu!`
- **Exact English Text (EN):** `I can't run anymore! Give me a second to breathe!`
- **Suggested Filename:** `vo_stamina_exhausted_01.wav`

### `vo_stamina_exhausted_02`
- **Clip ID:** `vo_stamina_exhausted_02`
- **Source:** `Loc.gd :: dialogue_pool("stamina_exhausted")[1] (PlayerController.gd:374)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Audible exhausted gasps at the start, weak trembling knees, desperately catching breath.
- **Exact Teks Indonesia (ID):** `Huff... huff... kakiku lemas, harus tarik nafas sebentar!`
- **Exact English Text (EN):** `Out of breath... I can only walk right now!`
- **Suggested Filename:** `vo_stamina_exhausted_02.wav`

### `vo_stamina_exhausted_03`
- **Clip ID:** `vo_stamina_exhausted_03`
- **Source:** `Loc.gd :: dialogue_pool("stamina_exhausted")[2] (PlayerController.gd:374)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Drained, shaky exhale; anxious frustration at being forced down to a slow walk.
- **Exact Teks Indonesia (ID):** `Staminaku terkuras habis! Aku hanya bisa jalan pelan sekarang.`
- **Exact English Text (EN):** `My legs are about to give out! Need stamina...`
- **Suggested Filename:** `vo_stamina_exhausted_03.wav`

## 3. Monolog Senter & Baterai (`battery_low`, `battery_empty`)

*Clips in section: **4***

### `vo_battery_low_01`
- **Clip ID:** `vo_battery_low_01`
- **Source:** `Loc.gd :: dialogue_pool("battery_low")[0] (PlayerController.gd:448)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Concerned, quiet alarm; watching the flashlight beam flicker in a dark village alley.
- **Exact Teks Indonesia (ID):** `Senterku mulai redup... baterainya hampir habis.`
- **Exact English Text (EN):** `My flashlight is flickering... the battery is almost dead.`
- **Suggested Filename:** `vo_battery_low_01.wav`

### `vo_battery_low_02`
- **Clip ID:** `vo_battery_low_02`
- **Source:** `Loc.gd :: dialogue_pool("battery_low")[1] (PlayerController.gd:448)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Cautious, worried urgency; quick low mutter realizing spare batteries are needed immediately.
- **Exact Teks Indonesia (ID):** `Daya senter tinggal sedikit. Aku harus cari baterai cadangan.`
- **Exact English Text (EN):** `Only a sliver of battery left. I should look for a spare battery.`
- **Suggested Filename:** `vo_battery_low_02.wav`

### `vo_battery_empty_01`
- **Clip ID:** `vo_battery_empty_01`
- **Source:** `Loc.gd :: dialogue_pool("battery_empty")[0] (PlayerController.gd:452)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Sudden startled gasp and dread as light cuts out completely into pitch blackness.
- **Exact Teks Indonesia (ID):** `Senterku mati total! Gelap gulita sekali!`
- **Exact English Text (EN):** `My flashlight died! It's pitch black out here!`
- **Suggested Filename:** `vo_battery_empty_01.wav`

### `vo_battery_empty_02`
- **Clip ID:** `vo_battery_empty_02`
- **Source:** `Loc.gd :: dialogue_pool("battery_empty")[1] (PlayerController.gd:452)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Tense, hurried resolve in the dark; scanning for distant torch flames while speaking low.
- **Exact Teks Indonesia (ID):** `Baterai habis! Harus mengandalkan cahaya obor atau segera isi daya.`
- **Exact English Text (EN):** `No battery left... I have to rely on street torches now.`
- **Suggested Filename:** `vo_battery_empty_02.wav`

## 4. Persembunyian & Rumah Aman (`hiding_enter`, `hiding_exit`, `safezone_relief`, `house_refuge`)

*Clips in section: **7***

### `vo_hiding_enter_01`
- **Clip ID:** `vo_hiding_enter_01`
- **Source:** `Loc.gd :: dialogue_pool("hiding_enter")[0] (PlayerController.gd:615)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Barely audible breathy whisper; intense stealth tension inside a tight wooden closet.
- **Exact Teks Indonesia (ID):** `Diam... jangan bersuara sedikit pun.`
- **Exact English Text (EN):** `Stay quiet... don't make a single sound.`
- **Suggested Filename:** `vo_hiding_enter_01.wav`

### `vo_hiding_enter_02`
- **Clip ID:** `vo_hiding_enter_02`
- **Source:** `Loc.gd :: dialogue_pool("hiding_enter")[1] (PlayerController.gd:615)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Hushed, trembling whisper holding breath; terrified hope that Lampor walks past.
- **Exact Teks Indonesia (ID):** `Tahan nafas... semoga makhluk itu tidak mengecek ke dalam sini.`
- **Exact English Text (EN):** `Hold your breath. Maybe it won't check inside here.`
- **Suggested Filename:** `vo_hiding_enter_02.wav`

### `vo_hiding_exit_01`
- **Clip ID:** `vo_hiding_exit_01`
- **Source:** `Loc.gd :: dialogue_pool("hiding_exit")[0] (PlayerController.gd:640)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Soft, cautious exhale; low guarded tone testing whether the coast is clear.
- **Exact Teks Indonesia (ID):** `Sepertinya cukup aman untuk keluar sekarang.`
- **Exact English Text (EN):** `Alright... I think the coast is clear enough to move.`
- **Suggested Filename:** `vo_hiding_exit_01.wav`

### `vo_hiding_exit_02`
- **Clip ID:** `vo_hiding_exit_02`
- **Source:** `Loc.gd :: dialogue_pool("hiding_exit")[1] (PlayerController.gd:640)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Quiet, steadying relief mixed with grim determination to keep moving.
- **Exact Teks Indonesia (ID):** `Masih selamat. Ayo lanjutkan sebelum terlambat.`
- **Exact English Text (EN):** `Still breathing. Time to finish what needs to be done.`
- **Suggested Filename:** `vo_hiding_exit_02.wav`

### `vo_safezone_relief_01`
- **Clip ID:** `vo_safezone_relief_01`
- **Source:** `Loc.gd :: dialogue_pool("safezone_relief")[0] (SanitySystem.gd:81)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Warm, trembling exhale of relief; tension easing slightly beside a flickering torch.
- **Exact Teks Indonesia (ID):** `Cahaya obor ini sedikit menenangkan pikiranku.`
- **Exact English Text (EN):** `The warm torchlight steadies my nerves a bit.`
- **Suggested Filename:** `vo_safezone_relief_01.wav`

### `vo_safezone_relief_02`
- **Clip ID:** `vo_safezone_relief_02`
- **Source:** `Loc.gd :: dialogue_pool("safezone_relief")[1] (SanitySystem.gd:81)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Soft, grateful sigh; calmer breathing while acknowledging safety is only temporary.
- **Exact Teks Indonesia (ID):** `Api ini menahan rasa takutku... setidaknya untuk sesaat.`
- **Exact English Text (EN):** `At least the fire keeps the worst of the dread away.`
- **Suggested Filename:** `vo_safezone_relief_02.wav`

### `vo_house_refuge_01`
- **Clip ID:** `vo_house_refuge_01`
- **Source:** `PlayerController.gd:381-384 :: _physics_process()`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Guarded relief stepping indoors; calmer pace yet keeping an alert edge.
- **Exact Teks Indonesia (ID):** `Rumah ini sedikit melindungiku dari udara dingin di luar, tapi aku tetap harus waspada.`
- **Exact English Text (EN):** `This house offers a brief shelter from the cold outside, though I still need to stay sharp.`
- **Suggested Filename:** `vo_house_refuge_01.wav`

## 5. Ancaman Lampor & Kentongan (`lampor_near`, `lampor_repel`, `kentongan_not_yet`, `kentongan_hit`, `kentongan_expired`, Alerts)

*Clips in section: **9***

### `vo_lampor_near_01`
- **Clip ID:** `vo_lampor_near_01`
- **Source:** `Loc.gd :: dialogue_pool("lampor_near")[0] (LamporStateMachine.gd:725)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Sharp, chilled whisper-gasp; sudden dread sensing icy supernatural wind nearby.
- **Exact Teks Indonesia (ID):** `Angin dingin ini... Lampor ada di dekat sini!`
- **Exact English Text (EN):** `That cold wind... Lampor is right around the corner!`
- **Suggested Filename:** `vo_lampor_near_01.wav`

### `vo_lampor_near_02`
- **Clip ID:** `vo_lampor_near_02`
- **Source:** `Loc.gd :: dialogue_pool("lampor_near")[1] (LamporStateMachine.gd:725)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Tight, terrified whisper-urgency; flinching at the creaking sound of the flying coffin.
- **Exact Teks Indonesia (ID):** `Suara keranda itu... dia semakin mendekat!`
- **Exact English Text (EN):** `I hear the creaking shroud—something is close!`
- **Suggested Filename:** `vo_lampor_near_02.wav`

### `vo_lampor_repel_01`
- **Clip ID:** `vo_lampor_repel_01`
- **Source:** `Loc.gd :: dialogue_pool("lampor_repel")[0] (defined in Loc.gd, currently unused in call sites)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Fierce, breathless surge of adrenaline; urgent shout of victory while sprinting away.
- **Exact Teks Indonesia (ID):** `Kentongannya berhasil! Lampor terpukul mundur—cepat manfaatkan waktunya!`
- **Exact English Text (EN):** `The kentongan worked! It's retreating—run while I have the chance!`
- **Suggested Filename:** `vo_lampor_repel_01.wav`
- **Notes:** Defined in Loc.gd dialogue_pool("lampor_repel"); PlayerController.gd:722 currently uses a static Narrator string instead.

### `vo_lampor_repel_02`
- **Clip ID:** `vo_lampor_repel_02`
- **Source:** `Loc.gd :: dialogue_pool("lampor_repel")[1] (defined in Loc.gd, currently unused in call sites)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Fast, urgent sprint energy; relieved yet acutely aware the 5-second window is slipping.
- **Exact Teks Indonesia (ID):** `Suara kentongan membuatnya kabur sementara! Jangan buang 5 detik ini!`
- **Exact English Text (EN):** `That loud crack shook Lampor back! Five seconds won't last long!`
- **TTS Speakable Adaptation (ID):** `Suara kentongan membuatnya kabur sementara! Jangan buang lima detik ini!`
- **TTS Speakable Adaptation (EN):** `That loud crack shook Lampor back! Five seconds won't last long!`
- **Suggested Filename:** `vo_lampor_repel_02.wav`
- **Notes:** Defined in Loc.gd dialogue_pool("lampor_repel"); currently unused by active callers.

### `vo_kentongan_not_yet_01`
- **Clip ID:** `vo_kentongan_not_yet_01`
- **Source:** `PlayerController.gd:714-717 :: _try_use_equipped_item()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Calm, firm tactical warning; steady low horror-advisor tone advising restraint.
- **Exact Teks Indonesia (ID):** `Lampor belum turun ke desa. Simpan kentongan untuk nanti!`
- **Exact English Text (EN):** `Lampor hasn't descended into the village yet. Save your kentongan!`
- **Suggested Filename:** `vo_kentongan_not_yet_01.wav`

### `vo_kentongan_hit_01`
- **Clip ID:** `vo_kentongan_hit_01`
- **Source:** `PlayerController.gd:722-725 :: _try_use_equipped_item()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Punchy, urgent dramatic announcement; clear high-stakes callout of temporary reprieve.
- **Exact Teks Indonesia (ID):** `Kentongan dibunyikan! Lampor terusir selama 5 detik!`
- **Exact English Text (EN):** `Kentongan struck! Lampor driven back for 5 seconds!`
- **TTS Speakable Adaptation (ID):** `Kentongan dibunyikan! Lampor terusir selama lima detik!`
- **TTS Speakable Adaptation (EN):** `Kentongan struck! Lampor driven back for five seconds!`
- **Suggested Filename:** `vo_kentongan_hit_01.wav`

### `vo_kentongan_expired_01`
- **Clip ID:** `vo_kentongan_expired_01`
- **Source:** `LamporStateMachine.gd:667 :: _process_repelled()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Ominous, sudden drop in tone; urgent dread signaling the threat has returned.
- **Exact Teks Indonesia (ID):** `Efek kentongan habis — Lampor kembali mengejar!`
- **Exact English Text (EN):** `Kentongan effect wore off — Lampor is hunting again!`
- **TTS Speakable Adaptation (ID):** `Efek kentongan habis! Lampor kembali mengejar!`
- **TTS Speakable Adaptation (EN):** `Kentongan effect wore off! Lampor is hunting again!`
- **Suggested Filename:** `vo_kentongan_expired_01.wav`

### `vo_lampor_descended_chase_01`
- **Clip ID:** `vo_lampor_descended_chase_01`
- **Source:** `HUD.gd:2391 :: _play_lampor_descent_cutscene() (ID-only in code; EN translated for voice)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** High-intensity, commanding horror warning; sharp urgency pushing the player to run immediately.
- **Exact Teks Indonesia (ID):** `LAMPOR TELAH TURUN DAN MENGEJARMU! Lari atau sembunyi di dalam rumah!`
- **Exact English Text (EN):** *(ID-only in code — recommended EN TTS:)* `LAMPOR HAS DESCENDED AND IS HUNTING YOU! Run or hide inside a house!`
- **TTS Speakable Adaptation (ID):** `Lampor telah turun dan mengejarmu! Lari atau sembunyi di dalam rumah!`
- **TTS Speakable Adaptation (EN):** `Lampor has descended and is hunting you! Run or hide inside a house!`
- **Suggested Filename:** `vo_lampor_descended_chase_01.wav`
- **Notes:** HUD.gd:2391 passes an ID-only literal without LocScript.pick; text_en/tts_text_en provided for EN TTS parity.

### `vo_lampor_stare_warning_01`
- **Clip ID:** `vo_lampor_stare_warning_01`
- **Source:** `HUD.gd:2810 :: _on_lampor_stare()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Sharp, alarming imperative warning; tense urgent rasp demanding instant reaction.
- **Exact Teks Indonesia (ID):** `JANGAN MENATAP LANGSUNG! ALIHKAN PANDANGANMU!`
- **Exact English Text (EN):** `DO NOT STARE DIRECTLY! LOOK AWAY NOW!`
- **TTS Speakable Adaptation (ID):** `Jangan menatap langsung! Alihkan pandanganmu!`
- **TTS Speakable Adaptation (EN):** `Do not stare directly! Look away now!`
- **Suggested Filename:** `vo_lampor_stare_warning_01.wav`
- **Notes:** HUD StareWarning label triggered whenever Lampor stare intensity > 0.4.

## 6. Progres Waktu Malam (`time_02`, `time_03`, `time_04`, `time_04_reminder`)

*Clips in section: **4***

### `vo_time_02_01`
- **Clip ID:** `vo_time_02_01`
- **Source:** `Loc.gd :: dialogue_pool("time_02")[0] (GameManager.gd:1446)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Low, chilled observation; hushed dread noticing the night deepening around 02:00 AM.
- **Exact Teks Indonesia (ID):** `Sudah lewat pukul 02.00 WIB... kampung ini terasa makin mencekam.`
- **Exact English Text (EN):** `It's past 02:00 WIB... the village feels even colder now.`
- **TTS Speakable Adaptation (ID):** `Sudah lewat pukul dua dini hari... kampung ini terasa makin mencekam.`
- **TTS Speakable Adaptation (EN):** `It's past two A.M.... the village feels even colder now.`
- **Suggested Filename:** `vo_time_02_01.wav`

### `vo_time_03_01`
- **Clip ID:** `vo_time_03_01`
- **Source:** `Loc.gd :: dialogue_pool("time_03")[0] (GameManager.gd:1450)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Grave, tense whisper-resolve; hyper-alert at the deadest hour of the night.
- **Exact Teks Indonesia (ID):** `Pukul 03.00 WIB—jam paling sunyi dan berbahaya. Tetap waspada.`
- **Exact English Text (EN):** `03:00 WIB—the deadest hour of the night. Stay alert.`
- **TTS Speakable Adaptation (ID):** `Pukul tiga dini hari—jam paling sunyi dan berbahaya. Tetap waspada.`
- **TTS Speakable Adaptation (EN):** `Three A.M.—the deadest hour of the night. Stay alert.`
- **Suggested Filename:** `vo_time_03_01.wav`

### `vo_time_04_01`
- **Clip ID:** `vo_time_04_01`
- **Source:** `Loc.gd :: dialogue_pool("time_04")[0] (defined in Loc.gd, unused by GameManager.gd)`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Desperate, hopeful urgency; breathless push toward survival with dawn finally in sight.
- **Exact Teks Indonesia (ID):** `Pukul 04.00 WIB! Fajar hampir tiba—sebentar lagi semuanya berakhir!`
- **Exact English Text (EN):** `04:00 WIB! Dawn isn't far off—almost at the final stretch!`
- **TTS Speakable Adaptation (ID):** `Pukul empat pagi! Fajar hampir tiba—sebentar lagi semuanya berakhir!`
- **TTS Speakable Adaptation (EN):** `Four A.M.! Dawn isn't far off—almost at the final stretch!`
- **Suggested Filename:** `vo_time_04_01.wav`
- **Notes:** Defined in Loc.gd dialogue_pool("time_04"); GameManager.gd:1420 instead emits time_04_reminder.

### `vo_time_04_reminder_01`
- **Clip ID:** `vo_time_04_reminder_01`
- **Source:** `GameManager.gd:1420-1423 :: _sync_act_with_time()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Urgent, stern deadline warning; crisp dramatic pacing reminding the player dawn is near.
- **Exact Teks Indonesia (ID):** `Pukul 04.00 WIB tiba! Segera lengkapi Benda Ritual sebelum pukul 05.00 WIB!`
- **Exact English Text (EN):** `It's 04:00 WIB! Gather the remaining Ritual Relics before 05:00 WIB!`
- **TTS Speakable Adaptation (ID):** `Pukul empat pagi tiba! Segera lengkapi Benda Ritual sebelum pukul lima pagi!`
- **TTS Speakable Adaptation (EN):** `It's four A.M.! Gather the remaining Ritual Relics before five A.M.!`
- **Suggested Filename:** `vo_time_04_reminder_01.wav`

## 7. Progres Misi Babak I, II, III & Ritual (Act Starts, Banners, Torches, Barricades, Ritual Relics)

*Clips in section: **14***

### `vo_act1_start_01`
- **Clip ID:** `vo_act1_start_01`
- **Source:** `GameManager.gd:1476-1479 :: _enter_act_1()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Solemn, atmospheric horror narrator; slow ominous opening transitioning into clear mission briefing.
- **Exact Teks Indonesia (ID):** `Malam mencekam dimulai... Nyalakan 5 obor penolak bala dan barikade 3 pintu sebelum pukul 02.30 WIB!`
- **Exact English Text (EN):** `The cursed night begins... Light 5 repellent torches and barricade 3 doors before 02:30 WIB!`
- **TTS Speakable Adaptation (ID):** `Malam mencekam dimulai... Nyalakan lima obor penolak bala dan barikade tiga pintu sebelum pukul setengah tiga dini hari!`
- **TTS Speakable Adaptation (EN):** `The cursed night begins... Light five repellent torches and barricade three doors before two thirty A.M.!`
- **Suggested Filename:** `vo_act1_start_01.wav`

### `vo_act1_banner_01`
- **Clip ID:** `vo_act1_banner_01`
- **Source:** `HUD.gd:2733 :: _show_act_banner()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Deep, cinematic chapter title announcement; measured, ominous resonance.
- **Exact Teks Indonesia (ID):** `BABAK I: PERTAHANAN AWAL (01.00 WIB)`
- **Exact English Text (EN):** `ACT I: EARLY DEFENSE (01:00 WIB)`
- **TTS Speakable Adaptation (ID):** `Babak Satu: Pertahanan Awal. Pukul satu dini hari.`
- **TTS Speakable Adaptation (EN):** `Act One: Early Defense. One A.M.`
- **Suggested Filename:** `vo_act1_banner_01.wav`
- **Notes:** Chapter card title callout shown in HUD._show_act_banner().

### `vo_torch_progress_4_01`
- **Clip ID:** `vo_torch_progress_4_01`
- **Source:** `GameManager.gd:1561-1564 :: _on_torch_lit()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Encouraging yet tense guidance; brisk pacing acknowledging one final torch remains.
- **Exact Teks Indonesia (ID):** `Ayo semangat, sedikit lagi! Obor penolak bala sudah 4/5 menyala.`
- **Exact English Text (EN):** `Almost there! 4/5 repellent torches are now lit.`
- **TTS Speakable Adaptation (ID):** `Ayo semangat, sedikit lagi! Obor penolak bala sudah empat dari lima menyala.`
- **TTS Speakable Adaptation (EN):** `Almost there! Four out of five repellent torches are now lit.`
- **Suggested Filename:** `vo_torch_progress_4_01.wav`

### `vo_torch_complete_5_01`
- **Clip ID:** `vo_torch_complete_5_01`
- **Source:** `GameManager.gd:1566-1569 :: _on_torch_lit()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Crisp, decisive confirmation shifting immediately to the next defense task.
- **Exact Teks Indonesia (ID):** `Kelima obor telah menyala. Sekarang amankan pintu rumah!`
- **Exact English Text (EN):** `All 5 torches are lit! Now secure the remaining house doors!`
- **TTS Speakable Adaptation (ID):** `Kelima obor telah menyala. Sekarang amankan pintu rumah!`
- **TTS Speakable Adaptation (EN):** `All five torches are lit! Now secure the remaining house doors!`
- **Suggested Filename:** `vo_torch_complete_5_01.wav`

### `vo_barricade_progress_2_01`
- **Clip ID:** `vo_barricade_progress_2_01`
- **Source:** `GameManager.gd:1586-1589 :: record_door_barricaded()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Urgent, supportive momentum; pushing the survivor toward the final barricade.
- **Exact Teks Indonesia (ID):** `Ayo semangat, sedikit lagi! Dua dari tiga pintu sudah diamankan.`
- **Exact English Text (EN):** `Keep going! Two out of three doors are now barricaded.`
- **Suggested Filename:** `vo_barricade_progress_2_01.wav`

### `vo_barricade_complete_3_01`
- **Clip ID:** `vo_barricade_complete_3_01`
- **Source:** `GameManager.gd:1591-1594 :: record_door_barricaded()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Firm, brisk tactical pivot directing focus toward the remaining unlit torches.
- **Exact Teks Indonesia (ID):** `Semua pintu penting sudah dibarikade. Nyalakan seluruh obor penolak bala!`
- **Exact English Text (EN):** `All key doors barricaded! Light every repellent torch!`
- **Suggested Filename:** `vo_barricade_complete_3_01.wav`

### `vo_act2_fastforward_01`
- **Clip ID:** `vo_act2_fastforward_01`
- **Source:** `GameManager.gd:1489-1492 :: _enter_act_2() (fast_forwarded == true)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Dramatic, escalating horror announcement; triumphant completion turning swiftly into grave danger.
- **Exact Teks Indonesia (ID):** `Semua misi Babak I selesai! Waktu dipercepat ke 02.30 WIB — Babak II dimulai, Lampor turun ke desa!`
- **Exact English Text (EN):** `All Act I objectives complete! Time advances to 02:30 WIB — Act II begins, Lampor descends into the village!`
- **TTS Speakable Adaptation (ID):** `Semua misi Babak Satu selesai! Waktu dipercepat ke setengah tiga dini hari. Babak Dua dimulai, Lampor turun ke desa!`
- **TTS Speakable Adaptation (EN):** `All Act One objectives complete! Time advances to two thirty A.M. Act Two begins, Lampor descends into the village!`
- **Suggested Filename:** `vo_act2_fastforward_01.wav`

### `vo_act2_start_01`
- **Clip ID:** `vo_act2_start_01`
- **Source:** `GameManager.gd:1494-1497 :: _enter_act_2() (fast_forwarded == false)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Dark, chilling warning; slow and menacing emphasis on never looking at the coffin.
- **Exact Teks Indonesia (ID):** `Lampor telah turun ke desa. Jangan menatap kerandanya!`
- **Exact English Text (EN):** `Lampor has descended into the village. Do not stare at its coffin!`
- **Suggested Filename:** `vo_act2_start_01.wav`

### `vo_act2_banner_01`
- **Clip ID:** `vo_act2_banner_01`
- **Source:** `HUD.gd:2736 :: _show_act_banner()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Foreboding, dramatic chapter title callout; darker and heavier than Act I.
- **Exact Teks Indonesia (ID):** `BABAK II: LAMPOR TURUN KE DESA`
- **Exact English Text (EN):** `ACT II: LAMPOR DESCENDS ON THE VILLAGE`
- **TTS Speakable Adaptation (ID):** `Babak Dua: Lampor turun ke desa.`
- **TTS Speakable Adaptation (EN):** `Act Two: Lampor descends on the village.`
- **Suggested Filename:** `vo_act2_banner_01.wav`
- **Notes:** Chapter card title callout shown when descent cutscene is skipped/inactive.

### `vo_ritual_progress_3_01`
- **Clip ID:** `vo_ritual_progress_3_01`
- **Source:** `GameManager.gd:1622-1625 :: _on_ritual_item_collected()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Tense, whispering urgency; tightening suspense as Lampor stalks closer.
- **Exact Teks Indonesia (ID):** `Tinggal satu benda ritual lagi. Jangan lengah, Lampor semakin dekat!`
- **Exact English Text (EN):** `Only one ritual relic left! Stay alert, Lampor draws nearer!`
- **Suggested Filename:** `vo_ritual_progress_3_01.wav`

### `vo_ritual_complete_4_01`
- **Clip ID:** `vo_ritual_complete_4_01`
- **Source:** `GameManager.gd:1627-1630 :: _on_ritual_item_collected()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Urgent, focused directive; rallying the player back to the Village Hall furnace.
- **Exact Teks Indonesia (ID):** `Semua benda ritual terkumpul. Kembali ke tungku balai desa!`
- **Exact English Text (EN):** `All ritual relics collected! Return to the Village Hall furnace!`
- **Suggested Filename:** `vo_ritual_complete_4_01.wav`

### `vo_act3_fastforward_01`
- **Clip ID:** `vo_act3_fastforward_01`
- **Source:** `GameManager.gd:1510-1513 :: _enter_act_3() (fast_forwarded == true)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Climactic, intense announcement; high stakes driving straight into the final ritual burn.
- **Exact Teks Indonesia (ID):** `Semua benda ritual terkumpul! Waktu dipercepat ke 04.00 WIB — Bakar semuanya di Tungku Balai Desa!`
- **Exact English Text (EN):** `All ritual relics gathered! Time advances to 04:00 WIB — Burn them all at the Village Hall Furnace!`
- **TTS Speakable Adaptation (ID):** `Semua benda ritual terkumpul! Waktu dipercepat ke pukul empat pagi. Bakar semuanya di Tungku Balai Desa!`
- **TTS Speakable Adaptation (EN):** `All ritual relics gathered! Time advances to four A.M. Burn them all at the Village Hall Furnace!`
- **Suggested Filename:** `vo_act3_fastforward_01.wav`

### `vo_act3_start_01`
- **Clip ID:** `vo_act3_start_01`
- **Source:** `GameManager.gd:1515-1518 :: _enter_act_3() (fast_forwarded == false)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Fierce, solemn determination; commanding the player to end the curse now.
- **Exact Teks Indonesia (ID):** `Waktunya memutus kutukan. Bakar semua benda ritual!`
- **Exact English Text (EN):** `Time to break the curse. Burn all ritual relics at the furnace!`
- **Suggested Filename:** `vo_act3_start_01.wav`

### `vo_act3_banner_01`
- **Clip ID:** `vo_act3_banner_01`
- **Source:** `HUD.gd:2740 :: _show_act_banner()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Intense, thunderous chapter title callout signaling the final stand.
- **Exact Teks Indonesia (ID):** `BABAK III: KLIMAKS PEMBAKARAN`
- **Exact English Text (EN):** `ACT III: BURNING CLIMAX`
- **TTS Speakable Adaptation (ID):** `Babak Tiga: Klimaks Pembakaran.`
- **TTS Speakable Adaptation (EN):** `Act Three: Burning Climax.`
- **Suggested Filename:** `vo_act3_banner_01.wav`
- **Notes:** Chapter card title callout shown in HUD._show_act_banner().

## 8. Item, Survival & Multiplayer (Jamu, Battery, Energy Drink, Revives, Shop, Server & Debug)

*Clips in section: **10***

### `vo_item_jamu_01`
- **Clip ID:** `vo_item_jamu_01`
- **Source:** `PlayerController.gd:657-660 :: _try_use_equipped_item()`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Deep, soothing exhale of sudden clarity; trembling nerves calming down after drinking herbal medicine.
- **Exact Teks Indonesia (ID):** `Rasa hangat jamu ini langsung menjernihkan kepalaku...`
- **Exact English Text (EN):** `The warm herbal elixir steadies my racing mind...`
- **Suggested Filename:** `vo_item_jamu_01.wav`
- **Notes:** Triggers when drinking Jamu while sanity < 50.

### `vo_item_battery_full_01`
- **Clip ID:** `vo_item_battery_full_01`
- **Source:** `PlayerController.gd:666 :: _try_use_equipped_item()`
- **Speaker:** `Player (Male / Female)`
- **Google AI Studio Emotion / Style Prompt:** Matter-of-fact, hushed self-reminder while checking the flashlight in hand.
- **Exact Teks Indonesia (ID):** `Baterai senter masih penuh.`
- **Exact English Text (EN):** `Flashlight battery is already full.`
- **Suggested Filename:** `vo_item_battery_full_01.wav`

### `vo_item_energy_active_01`
- **Clip ID:** `vo_item_energy_active_01`
- **Source:** `PlayerController.gd:681-684 :: _try_use_equipped_item()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Brisk, concise system status callout; neutral and clear without breaking tension.
- **Exact Teks Indonesia (ID):** `Efek Energy Drink masih aktif (%.1f detik)! Tidak dapat di-spam.`
- **Exact English Text (EN):** `Energy Drink effect is still active (%.1fs)! Cannot spam.`
- **Format Placeholders:** `%.1f`
- **TTS Speakable Adaptation (ID):** `Efek Energy Drink masih aktif! Tidak dapat dipakai terus-menerus.`
- **TTS Speakable Adaptation (EN):** `Energy Drink effect is still active! Wait before using another.`
- **Suggested Filename:** `vo_item_energy_active_01.wav`
- **Notes:** Contains %.1f format placeholder for remaining seconds; tts_text omits variable number for static audio clip.

### `vo_item_energy_cooldown_01`
- **Clip ID:** `vo_item_energy_cooldown_01`
- **Source:** `PlayerController.gd:687-690 :: _try_use_equipped_item()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Short, steady cooldown reminder; crisp and direct.
- **Exact Teks Indonesia (ID):** `Tunggu %.1f detik sebelum minum Energy Drink lagi.`
- **Exact English Text (EN):** `Wait %.1fs before drinking another Energy Drink.`
- **Format Placeholders:** `%.1f`
- **TTS Speakable Adaptation (ID):** `Tunggu sebentar sebelum minum Energy Drink lagi.`
- **TTS Speakable Adaptation (EN):** `Wait a moment before drinking another Energy Drink.`
- **Suggested Filename:** `vo_item_energy_cooldown_01.wav`
- **Notes:** Contains %.1f format placeholder for cooldown timer; tts_text replaces %.1f detik / %.1fs with static phrasing.

### `vo_item_energy_used_01`
- **Clip ID:** `vo_item_energy_used_01`
- **Source:** `PlayerController.gd:699-702 :: _try_use_equipped_item()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Energetic, brisk surge callout; sharp adrenaline boost cue.
- **Exact Teks Indonesia (ID):** `Energy Drink diminum! Stamina penuh 100% selama 3 detik!`
- **Exact English Text (EN):** `Energy Drink consumed! Full 100% stamina for 3 seconds!`
- **TTS Speakable Adaptation (ID):** `Energy Drink diminum! Stamina penuh seratus persen selama tiga detik!`
- **TTS Speakable Adaptation (EN):** `Energy Drink consumed! Full one hundred percent stamina for three seconds!`
- **Suggested Filename:** `vo_item_energy_used_01.wav`

### `vo_revive_extra_life_01`
- **Clip ID:** `vo_revive_extra_life_01`
- **Source:** `GameManager.gd:1720-1723 :: _execute_player_death()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Somber yet urgent second-chance announcement; breathless relief returning from the brink of death.
- **Exact Teks Indonesia (ID):** `Nyawa tambahan terpakai! Kamu kembali ke desa. Sisa nyawa: %d`
- **Exact English Text (EN):** `Extra life used! You returned to the village. Lives left: %d`
- **Format Placeholders:** `%d`
- **TTS Speakable Adaptation (ID):** `Nyawa tambahan terpakai! Kamu kembali ke desa.`
- **TTS Speakable Adaptation (EN):** `Extra life used! You have returned to the village.`
- **Suggested Filename:** `vo_revive_extra_life_01.wav`
- **Notes:** Contains %d format placeholder for remaining extra_lives; tts_text uses static line without count.

### `vo_revive_teammate_01`
- **Clip ID:** `vo_revive_teammate_01`
- **Source:** `PlayerController.gd:1985-1988 :: try_friendly_revive()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Urgent, relieved co-op callout; pulling a survivor back into the fight.
- **Exact Teks Indonesia (ID):** `Rekan satu tim membantumu bangkit kembali!`
- **Exact English Text (EN):** `A teammate helped revive you!`
- **Suggested Filename:** `vo_revive_teammate_01.wav`

### `vo_mp_shop_disabled_01`
- **Clip ID:** `vo_mp_shop_disabled_01`
- **Source:** `GameManager.gd:1097-1100 :: deliver_stored_items()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Calm, neutral multiplayer rule notice; clear and authoritative.
- **Exact Teks Indonesia (ID):** `Penggunaan Item Toko dinonaktifkan oleh Host di room ini.`
- **Exact English Text (EN):** `Shop items are disabled by the Host in this room.`
- **Suggested Filename:** `vo_mp_shop_disabled_01.wav`

### `vo_mp_server_broadcast_01`
- **Clip ID:** `vo_mp_server_broadcast_01`
- **Source:** `GameManager.gd:2063 :: _on_multiplayer_event_received()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Short, clean system alert chime-in tone; crisp notification lead-in for dynamic server messages.
- **Exact Teks Indonesia (ID):** `[SERVER] %s`
- **Exact English Text (EN):** `[SERVER] %s`
- **Format Placeholders:** `%s`
- **TTS Speakable Adaptation (ID):** `Perhatian, ada pengumuman baru dari server.`
- **TTS Speakable Adaptation (EN):** `Attention, incoming announcement from the server.`
- **Suggested Filename:** `vo_mp_server_broadcast_01.wav`
- **Notes:** Source constructs "[SERVER] " + b_msg dynamically; tts_text provides a generic alert cue since payload varies.

### `vo_admin_god_mode_0500_01`
- **Clip ID:** `vo_admin_god_mode_0500_01`
- **Source:** `GameManager.gd:1459-1462 :: trigger_dawn_lampor_devour()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Dry, calm developer/system confirmation tone.
- **Exact Teks Indonesia (ID):** `[GOD MODE] Pukul 05.00 WIB terlewati tanpa dilahap Lampor.`
- **Exact English Text (EN):** `[GOD MODE] Passed 05:00 WIB without being devoured by Lampor.`
- **TTS Speakable Adaptation (ID):** `Mode Dewa aktif. Pukul lima pagi terlewati tanpa dilahap Lampor.`
- **TTS Speakable Adaptation (EN):** `God Mode active. Passed five A.M. without being devoured by Lampor.`
- **Suggested Filename:** `vo_admin_god_mode_0500_01.wav`
- **Notes:** Admin/Sandbox God Mode debug guard when 05:00 WIB arrives.

## 9. Cutscene & Ending Narration (`HUD.gd`, `VictoryScreen.gd`, `GameOverScreen.gd`, Death Reasons)

*Clips in section: **18***

### `vo_cutscene_descent_title_01`
- **Clip ID:** `vo_cutscene_descent_title_01`
- **Source:** `HUD.gd:2338 :: _play_lampor_descent_cutscene()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Booming, ominous horror narrator; slow chilling gravitas as the flying coffin descends.
- **Exact Teks Indonesia (ID):** `BABAK II: KERANDA LAMPOR TURUN KE DESA`
- **Exact English Text (EN):** `ACT II: LAMPOR'S COFFIN DESCENDS`
- **TTS Speakable Adaptation (ID):** `Babak Dua: Keranda Lampor turun ke desa.`
- **TTS Speakable Adaptation (EN):** `Act Two: Lampor's Coffin Descends.`
- **Suggested Filename:** `vo_cutscene_descent_title_01.wav`

### `vo_cutscene_descent_sub_01`
- **Clip ID:** `vo_cutscene_descent_sub_01`
- **Source:** `HUD.gd:2340 :: _play_lampor_descent_cutscene()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Dramatic cinematic horror narration; ominous drop building rapidly into immediate chase urgency.
- **Exact Teks Indonesia (ID):** `Lampor mendarat dari langit malam... Bersiaplah, Lampor langsung mengejarmu!`
- **Exact English Text (EN):** `Lampor lands from the night sky... Brace yourself, the hunt begins now!`
- **Suggested Filename:** `vo_cutscene_descent_sub_01.wav`

### `vo_cutscene_victory_title_01`
- **Clip ID:** `vo_cutscene_victory_title_01`
- **Source:** `HUD.gd:2411 :: play_victory_cutscene_and_wait()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Majestic, triumphant relief; warm resonant awe as dawn finally breaks over the village.
- **Exact Teks Indonesia (ID):** `FAJAR MENYINGSING: KUTUKAN MUSNAH`
- **Exact English Text (EN):** `DAWN BREAKS: THE CURSE SHATTERS`
- **TTS Speakable Adaptation (ID):** `Fajar menyingsing: kutukan musnah.`
- **TTS Speakable Adaptation (EN):** `Dawn breaks: the curse shatters.`
- **Suggested Filename:** `vo_cutscene_victory_title_01.wav`

### `vo_cutscene_victory_sub_01`
- **Clip ID:** `vo_cutscene_victory_sub_01`
- **Source:** `HUD.gd:2413 :: play_victory_cutscene_and_wait()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Sweeping, dramatic climax narration; intense wonder as heavenly light destroys Lampor's coffin.
- **Exact Teks Indonesia (ID):** `Cahaya langit menyambar dan menarik Keranda Lampor ke atas hingga lenyap!`
- **Exact English Text (EN):** `Heavenly light strikes down, pulling Lampor's coffin skyward until it vanishes!`
- **Suggested Filename:** `vo_cutscene_victory_sub_01.wav`

### `vo_cutscene_death_title_01`
- **Clip ID:** `vo_cutscene_death_title_01`
- **Source:** `HUD.gd:2595 :: play_death_cutscene_and_wait()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Cold, tragic horror finality; deep sorrowful menace.
- **Exact Teks Indonesia (ID):** `DITANGKAP KERANDA LAMPOR`
- **Exact English Text (EN):** `CLAIMED BY LAMPOR'S COFFIN`
- **TTS Speakable Adaptation (ID):** `Ditangkap Keranda Lampor.`
- **TTS Speakable Adaptation (EN):** `Claimed by Lampor's Coffin.`
- **Suggested Filename:** `vo_cutscene_death_title_01.wav`

### `vo_cutscene_death_sub_01`
- **Clip ID:** `vo_cutscene_death_sub_01`
- **Source:** `HUD.gd:2597 :: play_death_cutscene_and_wait()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Haunting, slow despairing narration fading off into dark finality.
- **Exact Teks Indonesia (ID):** `Lampor mengangkat tubuhmu dan membawamu pergi ke dalam kegelapan malam...`
- **Exact English Text (EN):** `Lampor hoists you skyward and carries you into the pitch-black night...`
- **Suggested Filename:** `vo_cutscene_death_sub_01.wav`

### `vo_ending_victory_title_01`
- **Clip ID:** `vo_ending_victory_title_01`
- **Source:** `VictoryScreen.gd:59 :: _ready()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Solemn, peaceful triumph; warm resolution after surviving the cursed night.
- **Exact Teks Indonesia (ID):** `KUTUKAN TELAH BERAKHIR`
- **Exact English Text (EN):** `THE CURSE IS BROKEN`
- **TTS Speakable Adaptation (ID):** `Kutukan telah berakhir.`
- **TTS Speakable Adaptation (EN):** `The curse is broken.`
- **Suggested Filename:** `vo_ending_victory_title_01.wav`

### `vo_ending_victory_sub_01`
- **Clip ID:** `vo_ending_victory_sub_01`
- **Source:** `VictoryScreen.gd:75 :: _ready()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Calm, lyrical dawn epilogue; gentle relief and closure.
- **Exact Teks Indonesia (ID):** `Fajar menyingsing. Benda keramat musnah dan Lampor pun lenyap.`
- **Exact English Text (EN):** `Dawn breaks at last. The cursed relics are burned and Lampor is banished.`
- **Suggested Filename:** `vo_ending_victory_sub_01.wav`

### `vo_ending_victory_legacy_01`
- **Clip ID:** `vo_ending_victory_legacy_01`
- **Source:** `VictoryScreen.tscn:48-50 :: TitleBox/SubTitle (ID-only scene text overwritten by VictoryScreen.gd:75)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Atmospheric, evocative folklore epilogue; serene dawn ambiance contrasting lingering ash and relief.
- **Exact Teks Indonesia (ID):** `Pukul 05.00 Pagi. Suara kokok ayam dan azan berkumandang dari kejauhan. / Keranda Lampor hangus terbakar menjadi abu di udara. / Kutukan desa telah berhasil kau putuskan!`
- **Exact English Text (EN):** *(ID-only in code — recommended EN TTS:)* `05:00 AM. The crowing of roosters and the dawn call to prayer echo from afar. / Lampor's coffin burns to ash in midair. / You have broken the village curse!`
- **TTS Speakable Adaptation (ID):** `Pukul lima pagi. Suara kokok ayam dan azan berkumandang dari kejauhan. Keranda Lampor hangus terbakar menjadi abu di udara. Kutukan desa telah berhasil kau putuskan!`
- **TTS Speakable Adaptation (EN):** `Five A.M. The crowing of roosters and the dawn call to prayer echo from afar. Lampor's coffin burns to ash in midair. You have broken the village curse!`
- **Suggested Filename:** `vo_ending_victory_legacy_01.wav`
- **Notes:** Static ID-only scene text in VictoryScreen.tscn:48-50 (paired with Title 'FAJAR TELAH MENYINGSING' on line 41), overridden at runtime by VictoryScreen.gd.

### `vo_ending_death_title_coffin_01`
- **Clip ID:** `vo_ending_death_title_coffin_01`
- **Source:** `GameOverScreen.gd:27 :: _ready()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Deep, chilling death title; slow grim horror finality.
- **Exact Teks Indonesia (ID):** `DITELAN KERANDA LAMPOR`
- **Exact English Text (EN):** `SWALLOWED BY LAMPOR'S COFFIN`
- **TTS Speakable Adaptation (ID):** `Ditelan Keranda Lampor.`
- **TTS Speakable Adaptation (EN):** `Swallowed by Lampor's Coffin.`
- **Suggested Filename:** `vo_ending_death_title_coffin_01.wav`

### `vo_ending_death_title_dawn_01`
- **Clip ID:** `vo_ending_death_title_dawn_01`
- **Source:** `GameOverScreen.gd:29 :: _ready()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Bleak, hopeless solemnity; tragic announcement of failing just before salvation.
- **Exact Teks Indonesia (ID):** `FAJAR TAK MENYELAMATKANMU`
- **Exact English Text (EN):** `DAWN DID NOT SAVE YOU`
- **TTS Speakable Adaptation (ID):** `Fajar tak menyelamatkanmu.`
- **TTS Speakable Adaptation (EN):** `Dawn did not save you.`
- **Suggested Filename:** `vo_ending_death_title_dawn_01.wav`

### `vo_ending_death_title_sanity_01`
- **Clip ID:** `vo_ending_death_title_sanity_01`
- **Source:** `GameOverScreen.gd:31 :: _ready()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Eerie, fractured horror narration; hollow and chilling.
- **Exact Teks Indonesia (ID):** `JIWAMU TELAH HANCUR`
- **Exact English Text (EN):** `YOUR SANITY SHATTERED`
- **TTS Speakable Adaptation (ID):** `Jiwamu telah hancur.`
- **TTS Speakable Adaptation (EN):** `Your sanity shattered.`
- **Suggested Filename:** `vo_ending_death_title_sanity_01.wav`

### `vo_death_reason_coffin_01`
- **Clip ID:** `vo_death_reason_coffin_01`
- **Source:** `LamporStateMachine.gd:628 :: _start_catch() (SignalBus.player_death_requested)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Cold, visceral horror epilogue; low and unforgiving.
- **Exact Teks Indonesia (ID):** `Kamu ditarik ke dalam keranda Lampor!`
- **Exact English Text (EN):** `You were dragged into Lampor's coffin!`
- **Suggested Filename:** `vo_death_reason_coffin_01.wav`

### `vo_death_reason_sanity_01`
- **Clip ID:** `vo_death_reason_sanity_01`
- **Source:** `SanitySystem.gd:134-137 :: _process() (SignalBus.player_death_requested)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Dark, tragic whisper-narration; coldly explaining the fatal price of staring at Lampor.
- **Exact Teks Indonesia (ID):** `Kewarasanmu hancur total karena menatap Lampor!`
- **Exact English Text (EN):** `Your sanity shattered completely from staring at Lampor!`
- **Suggested Filename:** `vo_death_reason_sanity_01.wav`

### `vo_death_reason_dawn_01`
- **Clip ID:** `vo_death_reason_dawn_01`
- **Source:** `GameManager.gd:1465-1468 :: trigger_dawn_lampor_devour()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Grand, terrifying folklore doom; slow heavy cadence lingering on eternal darkness.
- **Exact Teks Indonesia (ID):** `Waktu telah menunjukkan pukul 05.00 WIB sebelum ritual penolak bala tuntas! Keranda Lampor langsung melahap dan menyeret jiwamu ke dalam kegelapan abadi.`
- **Exact English Text (EN):** `05:00 WIB struck before the warding ritual was complete! Lampor's coffin devoured your soul into eternal darkness.`
- **TTS Speakable Adaptation (ID):** `Waktu telah menunjukkan pukul lima pagi sebelum ritual penolak bala tuntas! Keranda Lampor langsung melahap dan menyeret jiwamu ke dalam kegelapan abadi.`
- **TTS Speakable Adaptation (EN):** `Five A.M. struck before the warding ritual was complete! Lampor's coffin devoured your soul into eternal darkness.`
- **Suggested Filename:** `vo_death_reason_dawn_01.wav`

### `vo_death_reason_fallback_01`
- **Clip ID:** `vo_death_reason_fallback_01`
- **Source:** `GameOverScreen.gd:24 :: _ready()`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Soft, melancholic horror epitaph; quiet and cold.
- **Exact Teks Indonesia (ID):** `Malam ini belum menjadi milikmu.`
- **Exact English Text (EN):** `The night claimed you before dawn.`
- **Suggested Filename:** `vo_death_reason_fallback_01.wav`

### `vo_death_reason_legacy_01`
- **Clip ID:** `vo_death_reason_legacy_01`
- **Source:** `GameOverScreen.tscn:48 :: TitleBox/ReasonLabel (ID-only scene text overwritten by GameOverScreen.gd:24)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Creepy, lingering horror narration trailing softly into silence.
- **Exact Teks Indonesia (ID):** `Jiwa dan ragamu telah diseret masuk ke dalam keranda terbang...`
- **Exact English Text (EN):** *(ID-only in code — recommended EN TTS:)* `Your soul and body have been dragged into the flying coffin...`
- **Suggested Filename:** `vo_death_reason_legacy_01.wav`
- **Notes:** Static ID-only scene text in GameOverScreen.tscn:48, overridden at runtime by GameOverScreen.gd.

### `vo_death_reason_admin_01`
- **Clip ID:** `vo_death_reason_admin_01`
- **Source:** `GameManager.gd:1768 :: admin_instant_lose() (ID-only debug string)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Dry, dramatic debug death notice.
- **Exact Teks Indonesia (ID):** `Ditelan Keranda Lampor secara instan melalui Admin Panel.`
- **Exact English Text (EN):** *(ID-only in code — recommended EN TTS:)* `Swallowed instantly by Lampor's Coffin via the Admin Panel.`
- **Suggested Filename:** `vo_death_reason_admin_01.wav`
- **Notes:** ID-only debug string in GameManager.gd:1768; EN translated for manifest parity.

## 10. Panduan / Tutorial Prompts (`TutorialOverlay.gd` Steps 1–7)

*Clips in section: **10***

### `vo_tutorial_01_desktop`
- **Clip ID:** `vo_tutorial_01_desktop`
- **Source:** `TutorialOverlay.gd:289-294 :: _refresh_step_content() (Step 1, Desktop)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Calm, steady tutorial mentor in an eerie night setting; clear, reassuring, atmospheric pacing.
- **Exact Teks Indonesia (ID):** `1. Pergerakan & Senter — [%s] untuk jalan, [%s] untuk lari, [Mouse] menoleh, dan [%s] menyalakan Senter. Target: Berjalanlah beberapa langkah di jalan desa.`
- **Exact English Text (EN):** `1. Movement & Flashlight — [%s] to move, [%s] to sprint, [Mouse] to look around, and [%s] for Flashlight. Goal: Take a few steps along the village road.`
- **Format Placeholders:** `%s`, `%s`, `%s`
- **TTS Speakable Adaptation (ID):** `Langkah satu: Pergerakan dan Senter. Gunakan tombol gerak untuk berjalan, tombol lari untuk sprint, geser mouse untuk menoleh, dan tombol senter untuk menyalakan lampu. Targetmu: berjalanlah beberapa langkah di jalan desa.`
- **TTS Speakable Adaptation (EN):** `Step one: Movement and Flashlight. Use your movement keys to walk, sprint key to run, mouse to look around, and flashlight key to toggle your light. Goal: Take a few steps along the village road.`
- **Suggested Filename:** `vo_tutorial_01_desktop.wav`
- **Notes:** Combines Step 1 title, desktop body (with move_k, sprint_k, flash_k placeholders), and goal.

### `vo_tutorial_01_touch`
- **Clip ID:** `vo_tutorial_01_touch`
- **Source:** `TutorialOverlay.gd:289-294 :: _refresh_step_content() (Step 1, Touch/Mobile)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Calm, clear mobile tutorial mentor; warm yet atmospheric pacing.
- **Exact Teks Indonesia (ID):** `1. Pergerakan & Senter — Joystick kiri untuk jalan, ikon Lari untuk sprint, dan ikon Senter untuk lampu. Target: Berjalanlah beberapa langkah di jalan desa.`
- **Exact English Text (EN):** `1. Movement & Flashlight — Left joystick to walk, Sprint icon to run, and Flashlight icon for light. Goal: Take a few steps along the village road.`
- **TTS Speakable Adaptation (ID):** `Langkah satu: Pergerakan dan Senter. Gunakan joystick kiri untuk berjalan, ikon Lari untuk sprint, dan ikon Senter untuk lampu. Targetmu: berjalanlah beberapa langkah di jalan desa.`
- **TTS Speakable Adaptation (EN):** `Step one: Movement and Flashlight. Use the left joystick to walk, the Sprint icon to run, and the Flashlight icon for light. Goal: Take a few steps along the village road.`
- **Suggested Filename:** `vo_tutorial_01_touch.wav`
- **Notes:** Combines Step 1 title, mobile touch body, and goal.

### `vo_tutorial_02_desktop`
- **Clip ID:** `vo_tutorial_02_desktop`
- **Source:** `TutorialOverlay.gd:296-301 :: _refresh_step_content() (Step 2, Desktop)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Clear, instructive survival mentor; deliberate pacing highlighting item interactions.
- **Exact Teks Indonesia (ID):** `2. Ambil & Pakai Barang [%s] — Tekan [%s] untuk semua interaksi: ambil barang, buka pintu, sembunyi, atau minum Jamu/Baterai di hotbar [%s]. Target: Ambil 1 barang di sekitar desa (Minyak / Papan).`
- **Exact English Text (EN):** `2. Pick Up & Use Items [%s] — Press [%s] to interact: pick up items, open doors, hide, or use Elixir/Battery on hotbar [%s]. Goal: Pick up 1 supply item around the village (Kerosene / Planks).`
- **Format Placeholders:** `%s`, `%s`, `%s`
- **TTS Speakable Adaptation (ID):** `Langkah dua: Ambil dan Pakai Barang. Tekan tombol interaksi untuk semua aksi: mengambil barang, membuka pintu, bersembunyi, atau menggunakan Jamu dan Baterai di hotbar. Targetmu: ambil satu barang di sekitar desa, seperti Minyak atau Papan.`
- **TTS Speakable Adaptation (EN):** `Step two: Pick Up and Use Items. Press the interact key to pick up items, open doors, hide, or use Elixir and Battery from your hotbar. Goal: Pick up one supply item around the village, such as Kerosene or Planks.`
- **Suggested Filename:** `vo_tutorial_02_desktop.wav`
- **Notes:** Combines Step 2 title, desktop body (with act_k, slot_k placeholders), and goal.

### `vo_tutorial_02_touch`
- **Clip ID:** `vo_tutorial_02_touch`
- **Source:** `TutorialOverlay.gd:296-301 :: _refresh_step_content() (Step 2, Touch/Mobile)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Clear, encouraging mobile tutorial guide; articulate and steady.
- **Exact Teks Indonesia (ID):** `2. Ambil & Pakai Barang [%s] — Ketuk ikon Tangan untuk semua interaksi: ambil barang, buka pintu, sembunyi, atau minum Jamu yang dipilih di hotbar. Target: Ambil 1 barang di sekitar desa (Minyak / Papan).`
- **Exact English Text (EN):** `2. Pick Up & Use Items [%s] — Tap the Hand icon for all interactions: loot items, open doors, hide, or drink elixirs from your hotbar. Goal: Pick up 1 supply item around the village (Kerosene / Planks).`
- **Format Placeholders:** `%s`
- **TTS Speakable Adaptation (ID):** `Langkah dua: Ambil dan Pakai Barang. Ketuk ikon Tangan untuk semua interaksi: mengambil barang, membuka pintu, bersembunyi, atau meminum Jamu yang dipilih di hotbar. Targetmu: ambil satu barang di sekitar desa, seperti Minyak atau Papan.`
- **TTS Speakable Adaptation (EN):** `Step two: Pick Up and Use Items. Tap the Hand icon for all interactions: loot items, open doors, hide, or drink elixirs from your hotbar. Goal: Pick up one supply item around the village, such as Kerosene or Planks.`
- **Suggested Filename:** `vo_tutorial_02_touch.wav`
- **Notes:** Combines Step 2 title (with act_k placeholder), mobile touch body, and goal.

### `vo_tutorial_03`
- **Clip ID:** `vo_tutorial_03`
- **Source:** `TutorialOverlay.gd:303-308 :: _refresh_step_content() (Step 3)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Steady, slightly ominous guide; emphasizing warmth and sanity recovery around torches.
- **Exact Teks Indonesia (ID):** `3. Nyalakan 5 Obor Penolak Bala — Bawa Minyak Tanah & Korek, dekati obor padam di pinggir jalan, lalu tekan [%s]. Cahaya obor memulihkan Waras. Target: Nyalakan Obor Penolak Bala (%d/5).`
- **Exact English Text (EN):** `3. Light 5 Repellent Torches — Carry Kerosene & Matches, approach an unlit roadside torch, then press [%s]. Torchlight restores Sanity. Goal: Light Repellent Torches (%d/5).`
- **Format Placeholders:** `%s`, `%d`
- **TTS Speakable Adaptation (ID):** `Langkah tiga: Nyalakan lima Obor Penolak Bala. Bawa Minyak Tanah dan Korek, dekati obor padam di pinggir jalan, lalu tekan tombol interaksi. Cahaya obor memulihkan kewarasanmu. Targetmu: nyalakan lima Obor Penolak Bala.`
- **TTS Speakable Adaptation (EN):** `Step three: Light five Repellent Torches. Carry Kerosene and Matches, approach an unlit roadside torch, then press interact. Torchlight restores your Sanity. Goal: Light five Repellent Torches.`
- **Suggested Filename:** `vo_tutorial_03.wav`
- **Notes:** Combines Step 3 title, body (act_k placeholder), and goal (torches_lit %d/5 placeholder).

### `vo_tutorial_04`
- **Clip ID:** `vo_tutorial_04`
- **Source:** `TutorialOverlay.gd:310-315 :: _refresh_step_content() (Step 4)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Grounded, cautionary tactical mentor; explaining door defense and indoor closet hiding.
- **Exact Teks Indonesia (ID):** `4. Barikade 3 Pintu & Lemari Sembunyi — Pilih Papan & Paku di hotbar, berdiri di luar pintu rumah yang tertutup, lalu tekan [%s]. Di dalam rumah ada Lemari untuk bersembunyi. Target: Palang Pintu Rumah (%d/3).`
- **Exact English Text (EN):** `4. Barricade 3 Doors & Closet Hiding — Equip Planks & Nails, stand outside a closed house door, and press [%s]. Inside houses you can hide in closets. Goal: Barricade House Doors (%d/3).`
- **Format Placeholders:** `%s`, `%d`
- **TTS Speakable Adaptation (ID):** `Langkah empat: Barikade tiga pintu dan lemari sembunyi. Pilih Papan dan Paku di hotbar, berdiri di luar pintu rumah yang tertutup, lalu tekan tombol interaksi. Di dalam rumah ada lemari untuk bersembunyi. Targetmu: palang tiga pintu rumah.`
- **TTS Speakable Adaptation (EN):** `Step four: Barricade three doors and use closet hiding. Equip Planks and Nails, stand outside a closed house door, and press interact. Inside houses you can hide in closets. Goal: Barricade three house doors.`
- **Suggested Filename:** `vo_tutorial_04.wav`
- **Notes:** Combines Step 4 title, body (act_k placeholder), and goal (doors_barricaded %d/3 placeholder).

### `vo_tutorial_05`
- **Clip ID:** `vo_tutorial_05`
- **Source:** `TutorialOverlay.gd:317-322 :: _refresh_step_content() (Step 5)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Focused, urgent mentor setting the Act I clock deadline.
- **Exact Teks Indonesia (ID):** `5. Selesaikan Pertahanan Babak I — Selesaikan 5 Obor dan 3 Barikade Pintu sebelum 02.30 WIB untuk memulai Babak II. Target: Obor %d/5  ·  Barikade Pintu %d/3.`
- **Exact English Text (EN):** `5. Finish Act I Defense — Complete 5 Torches and 3 Barricaded Doors before 02:30 WIB to begin Act II. Goal: Torches %d/5  ·  Door Barricades %d/3.`
- **Format Placeholders:** `%d`, `%d`
- **TTS Speakable Adaptation (ID):** `Langkah lima: Selesaikan pertahanan Babak Satu. Selesaikan lima obor dan tiga barikade pintu sebelum pukul setengah tiga dini hari untuk memulai Babak Dua.`
- **TTS Speakable Adaptation (EN):** `Step five: Finish Act One Defense. Complete five torches and three barricaded doors before two thirty A.M. to begin Act Two.`
- **Suggested Filename:** `vo_tutorial_05.wav`
- **Notes:** Combines Step 5 title, body, and goal (%d/5 torches, %d/3 barricades placeholders).

### `vo_tutorial_06`
- **Clip ID:** `vo_tutorial_06`
- **Source:** `TutorialOverlay.gd:324-329 :: _refresh_step_content() (Step 6)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Grave, hushed horror warning; serious tone teaching survival rules against Lampor.
- **Exact Teks Indonesia (ID):** `6. Jangan Menatap Lampor — Dilarang menatap Keranda Hijau Lampor. Saat lonceng dekat, palingkan pandangan, matikan senter [%s], dan sembunyi sambil mencari 4 Benda Ritual. Target: Kumpulkan 4 Benda Ritual (%d/4) tanpa menatap Lampor.`
- **Exact English Text (EN):** `6. Never Stare at Lampor — Never look directly at Lampor's green coffin. When bells ring close, look away, turn off flashlight [%s], and hide while seeking 4 Ritual Relics. Goal: Collect 4 Ritual Relics (%d/4) safely.`
- **Format Placeholders:** `%s`, `%d`
- **TTS Speakable Adaptation (ID):** `Langkah enam: Jangan menatap Lampor. Dilarang menatap Keranda Hijau Lampor. Saat lonceng dekat, palingkan pandangan, matikan senter, dan bersembunyilah sambil mencari empat Benda Ritual.`
- **TTS Speakable Adaptation (EN):** `Step six: Never stare at Lampor. Never look directly at Lampor's green coffin. When bells ring close, look away, turn off your flashlight, and hide while seeking four Ritual Relics.`
- **Suggested Filename:** `vo_tutorial_06.wav`
- **Notes:** Combines Step 6 title, body (flash_k placeholder), and goal (%d/4 ritual count placeholder).

### `vo_tutorial_07`
- **Clip ID:** `vo_tutorial_07`
- **Source:** `TutorialOverlay.gd:331-336 :: _refresh_step_content() (Step 7)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Climactic, urgent tutorial callout; firm final briefing before the ritual burn.
- **Exact Teks Indonesia (ID):** `7. Bakar di Tungku Sebelum 05.00 WIB — Bakar 4 Benda Ritual di Tungku Balai Desa [%s] dan bertahan %d detik sebelum pukul 05.00 WIB tiba. Target: Bakar Benda Ritual di Tungku Balai Desa dengan [%s].`
- **Exact English Text (EN):** `7. Burn at Furnace Before 05:00 WIB — Burn 4 Ritual Relics in the Village Hall Furnace [%s] and survive %d seconds before 05:00 WIB. Goal: Burn the Ritual Relics at the Village Hall Furnace with [%s].`
- **Format Placeholders:** `%s`, `%d`, `%s`
- **TTS Speakable Adaptation (ID):** `Langkah tujuh: Bakar di tungku sebelum pukul lima pagi. Bakar empat Benda Ritual di Tungku Balai Desa dan bertahanlah hingga selesai sebelum pukul lima pagi tiba.`
- **TTS Speakable Adaptation (EN):** `Step seven: Burn at the furnace before five A.M. Burn four Ritual Relics in the Village Hall Furnace and survive until the ritual completes before five A.M.`
- **Suggested Filename:** `vo_tutorial_07.wav`
- **Notes:** Combines Step 7 title, body (act_k, furnace_total_time placeholders), and goal (act_k placeholder).

### `vo_tutorial_07_burning`
- **Clip ID:** `vo_tutorial_07_burning`
- **Source:** `TutorialOverlay.gd:210 :: _process() (ID-only in code; EN translated for voice)`
- **Speaker:** `Narrator`
- **Google AI Studio Emotion / Style Prompt:** Intense, encouraging final-stand reminder while the furnace blazes.
- **Exact Teks Indonesia (ID):** `Target: Bertahanlah %d detik hingga pembakaran ritual selesai.`
- **Exact English Text (EN):** *(ID-only in code — recommended EN TTS:)* `Goal: Survive %d seconds until the ritual burning finishes.`
- **Format Placeholders:** `%d`
- **TTS Speakable Adaptation (ID):** `Bertahanlah hingga pembakaran ritual selesai.`
- **TTS Speakable Adaptation (EN):** `Hold out until the ritual burning finishes.`
- **Suggested Filename:** `vo_tutorial_07_burning.wav`
- **Notes:** ID-only string in TutorialOverlay.gd:210 with %d furnace_total_time placeholder (varies by difficulty: 60/45/15/8s).

---

## Summary & Clip Count Breakdown

| # | Section | Category Key | Clips | Player Clips | Narrator Clips |
| :-: | :--- | :--- | :-: | :-: | :-: |
| 1 | Monolog Kewarasan / Sanity (`sanity_mid`, `sanity_low`, `sanity_critical`) | `sanity` | 9 | 9 | 0 |
| 2 | Monolog Stamina & Fisik (`stamina_low`, `stamina_exhausted`) | `stamina` | 6 | 6 | 0 |
| 3 | Monolog Senter & Baterai (`battery_low`, `battery_empty`) | `battery` | 4 | 4 | 0 |
| 4 | Persembunyian & Rumah Aman (`hiding_enter`, `hiding_exit`, `safezone_relief`, `house_refuge`) | `shelter` | 7 | 7 | 0 |
| 5 | Ancaman Lampor & Kentongan (`lampor_near`, `lampor_repel`, `kentongan_not_yet`, `kentongan_hit`, `kentongan_expired`, Alerts) | `lampor_threat` | 9 | 4 | 5 |
| 6 | Progres Waktu Malam (`time_02`, `time_03`, `time_04`, `time_04_reminder`) | `time_progression` | 4 | 3 | 1 |
| 7 | Progres Misi Babak I, II, III & Ritual (Act Starts, Banners, Torches, Barricades, Ritual Relics) | `mission_progression` | 14 | 0 | 14 |
| 8 | Item, Survival & Multiplayer (Jamu, Battery, Energy Drink, Revives, Shop, Server & Debug) | `items_survival` | 10 | 2 | 8 |
| 9 | Cutscene & Ending Narration (`HUD.gd`, `VictoryScreen.gd`, `GameOverScreen.gd`, Death Reasons) | `cutscene_ending` | 18 | 0 | 18 |
| 10 | Panduan / Tutorial Prompts (`TutorialOverlay.gd` Steps 1–7) | `tutorial` | 10 | 0 | 10 |
| — | **TOTAL** | **All Categories** | **91** | **35** | **56** |

**Total WAV Files for Full Bilingual Production:** `(35 Male + 35 Female + 56 Narrator) × 2 languages (id, en) = 252 WAV files`.
