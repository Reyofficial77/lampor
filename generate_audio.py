import wave
import math
import struct
import random
import os

SAMPLE_RATE = 22050

def write_wav(filename, samples, sample_rate=SAMPLE_RATE):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'wb') as wf:
        wf.setnchannels(1)  # mono
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(sample_rate)
        
        # Clip and convert to 16-bit integers
        packed_data = bytearray()
        for s in samples:
            s_clamped = max(-1.0, min(1.0, s))
            val = int(s_clamped * 32767.0)
            packed_data.extend(struct.pack('<h', val))
        wf.writeframes(packed_data)
    print(f"Generated: {filename} ({len(samples)/sample_rate:.2f}s)")

# 1. Ambient Night (wind + crickets + low drone, 5 seconds loop)
def make_ambient():
    duration = 5.0
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    
    # Cricket chirps pattern
    cricket_mod = [0.0] * num_samples
    for i in range(0, num_samples, int(SAMPLE_RATE * 0.4)):
        burst_len = int(SAMPLE_RATE * 0.15)
        for b in range(burst_len):
            if i + b < num_samples:
                # 3 pulses per burst
                pulse = math.sin(b / burst_len * math.pi * 6)
                if pulse > 0:
                    cricket_mod[i + b] = pulse * (1.0 - b / burst_len)

    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Low wind rumble
        wind = math.sin(2 * math.pi * 45 * t + math.sin(2 * math.pi * 0.3 * t) * 3) * 0.25
        wind += (random.random() * 2 - 1) * 0.05 * (0.8 + 0.2 * math.sin(2 * math.pi * 0.5 * t))
        # Crickets around 4500Hz
        cricket = math.sin(2 * math.pi * 4600 * t) * cricket_mod[i] * 0.1
        cricket += math.sin(2 * math.pi * 5200 * t) * cricket_mod[i] * 0.05
        # Distant low drone
        drone = math.sin(2 * math.pi * 70 * t) * 0.15
        val = (wind + cricket + drone) * 0.8
        samples.append(val)
    write_wav("assets/audio/ambient_night.wav", samples)

# 2. Lampor Death Bell (brass gamelan bell strike, 3.5s)
def make_lampor_bell():
    duration = 3.5
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    # Harmonics of a bronze bell: fundamental ~220Hz (A3), with dissonant inharmonic partials
    partials = [(220.0, 1.0, 2.5), (312.0, 0.7, 2.2), (440.0, 0.5, 1.8), (618.0, 0.4, 1.4), (885.0, 0.3, 1.0), (1240.0, 0.2, 0.7)]
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        val = 0.0
        for freq, amp, decay in partials:
            env = math.exp(-t * (4.0 / decay))
            val += math.sin(2 * math.pi * freq * t + math.sin(2 * math.pi * 3.0 * t) * 0.2) * amp * env
        # Initial strike thud
        strike = math.exp(-t * 40.0) * (random.random() * 2 - 1) * 0.4
        samples.append((val * 0.5 + strike) * 0.85)
    write_wav("assets/audio/lampor_bell.wav", samples)

# 3. Lampor Screamer / Roar (1.8s horrifying stinger)
def make_lampor_roar():
    duration = 1.8
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 1.5) if t > 0.05 else (t / 0.05)
        # Pitch descends wildly
        freq = 650.0 - t * 250.0 + math.sin(2 * math.pi * 35 * t) * 80.0
        tone = math.sin(2 * math.pi * freq * t)
        distortion = math.tanh(tone * 3.5)
        noise = (random.random() * 2 - 1) * 0.35 * (1.0 - t / duration)
        samples.append((distortion * 0.6 + noise) * env * 0.9)
    write_wav("assets/audio/lampor_roar.wav", samples)

# 4. Footsteps (dirt & wood)
def make_footsteps():
    # Dirt
    dur = 0.25
    n = int(dur * SAMPLE_RATE)
    s_dirt = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 24.0)
        low_thud = math.sin(2 * math.pi * 80 * t) * 0.6
        crunch = (random.random() * 2 - 1) * 0.4
        s_dirt.append((low_thud + crunch) * env * 0.7)
    write_wav("assets/audio/footstep_dirt.wav", s_dirt)
    
    # Wood
    s_wood = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 20.0)
        wood_tap = math.sin(2 * math.pi * 180 * t) * 0.7 + math.sin(2 * math.pi * 320 * t) * 0.3
        creak = (random.random() * 2 - 1) * 0.15
        s_wood.append((wood_tap + creak) * env * 0.75)
    write_wav("assets/audio/footstep_wood.wav", s_wood)

# 5. Heartbeat (thumping lub-dub)
def make_heartbeat():
    duration = 1.0
    num_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * num_samples
    # Lub at 0.0s, Dub at 0.22s
    for start_t, amp in [(0.0, 0.8), (0.22, 0.6)]:
        start_idx = int(start_t * SAMPLE_RATE)
        hit_len = int(0.2 * SAMPLE_RATE)
        for i in range(hit_len):
            if start_idx + i < num_samples:
                t = i / SAMPLE_RATE
                env = math.sin(t / 0.2 * math.pi) ** 2
                freq = 55.0 - t * 40.0
                samples[start_idx + i] += math.sin(2 * math.pi * freq * t) * env * amp
    write_wav("assets/audio/heartbeat.wav", samples)

# 6. Lighter / Match ignite
def make_lighter():
    dur = 0.6
    n = int(dur * SAMPLE_RATE)
    s = []
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < 0.08:
            # Flint scrape
            val = (random.random() * 2 - 1) * 0.8
        else:
            # Flame whoosh
            env = math.exp(-(t - 0.08) * 6.0)
            whoosh = math.sin(2 * math.pi * 120 * t) * 0.3 + (random.random() * 2 - 1) * 0.3
            val = whoosh * env
        s.append(val * 0.7)
    write_wav("assets/audio/lighter_ignite.wav", s)

# 7. Item pickup
def make_pickup():
    dur = 0.2
    n = int(dur * SAMPLE_RATE)
    s = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 22.0)
        freq = 440.0 + t * 800.0
        val = math.sin(2 * math.pi * freq * t) * env * 0.6
        s.append(val)
    write_wav("assets/audio/item_pickup.wav", s)

# 8. Door creak
def make_door_creak():
    dur = 0.8
    n = int(dur * SAMPLE_RATE)
    s = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(t / dur * math.pi)
        freq = 280.0 + math.sin(2 * math.pi * 12 * t) * 70.0
        val = (math.sin(2 * math.pi * freq * t) * 0.5 + (random.random() * 2 - 1) * 0.2) * env * 0.6
        s.append(val)
    write_wav("assets/audio/door_creak.wav", s)

# 9. Barricade hammer
def make_barricade():
    dur = 0.4
    n = int(dur * SAMPLE_RATE)
    s = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 18.0)
        # Metallic nail ping + heavy wood clank
        metal = math.sin(2 * math.pi * 1200 * t) * 0.4 * math.exp(-t * 40.0)
        thud = math.sin(2 * math.pi * 110 * t) * 0.7
        val = (metal + thud) * env * 0.8
        s.append(val)
    write_wav("assets/audio/barricade_hammer.wav", s)

# 10. Sanity whisper
def make_whisper():
    dur = 2.5
    n = int(dur * SAMPLE_RATE)
    s = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.sin(t / dur * math.pi)
        mod = math.sin(2 * math.pi * 4.0 * t)
        freq = 320.0 + mod * 60.0
        noise = (random.random() * 2 - 1) * 0.25
        val = (math.sin(2 * math.pi * freq * t) * 0.25 + noise) * env * 0.5
        s.append(val)
    write_wav("assets/audio/sanity_whisper.wav", s)

# 11. Victory chime (morning bells / fajar)
def make_victory():
    dur = 4.0
    n = int(dur * SAMPLE_RATE)
    s = []
    chimes = [(440.0, 0.0), (554.37, 0.5), (659.25, 1.0), (880.0, 1.5)]
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        for freq, start_t in chimes:
            if t >= start_t:
                dt = t - start_t
                env = math.exp(-dt * 1.5)
                val += math.sin(2 * math.pi * freq * dt) * 0.3 * env
        s.append(val * 0.8)
    write_wav("assets/audio/victory_chime.wav", s)

# 12. Game over sting (heavy dread boom)
def make_game_over():
    dur = 3.0
    n = int(dur * SAMPLE_RATE)
    s = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 1.2)
        freq = 55.0 - t * 12.0
        rumble = math.sin(2 * math.pi * freq * t) * 0.7
        sub = math.sin(2 * math.pi * (freq * 0.5) * t) * 0.4
        distortion = math.tanh((rumble + sub) * 2.0)
        s.append(distortion * env * 0.85)
    write_wav("assets/audio/game_over_sting.wav", s)

# 13. Rooster crow (kokok ayam jantan, menandakan fajar)
def make_rooster():
    dur = 3.2
    n = int(dur * SAMPLE_RATE)
    s = [0.0] * n
    # (mulai, durasi, freq awal, freq akhir) = "ku-ku-ruu-yuuuk"
    segs = [(0.05, 0.30, 500.0, 700.0), (0.38, 0.25, 650.0, 900.0),
            (0.68, 0.30, 800.0, 1100.0), (1.05, 1.30, 1050.0, 760.0)]
    for st, d, f0, f1 in segs:
        phase = 0.0
        seg_len = int(d * SAMPLE_RATE)
        for i in range(seg_len):
            idx = int(st * SAMPLE_RATE) + i
            if idx >= n:
                break
            p = i / seg_len
            t = i / SAMPLE_RATE
            f = f0 + (f1 - f0) * p + math.sin(2 * math.pi * 28 * t) * 25.0
            phase += 2 * math.pi * f / SAMPLE_RATE
            env = min(1.0, p * 12.0) * min(1.0, (1.0 - p) * 6.0)
            v = sum(math.sin(phase * h) / h for h in (1, 2, 3, 4, 5)) * 0.35
            v += (random.random() * 2 - 1) * 0.05
            s[idx] += v * env * 0.6
    write_wav("assets/audio/rooster_crow.wav", s)

# 14. Azan subuh (sintesis nada vokal bergaya lantunan azan, ~12 detik)
def make_azan():
    # (frekuensi Hz, durasi detik); 0 = jeda napas
    notes = [
        (392.0, 0.7), (466.2, 0.5), (440.0, 1.4), (392.0, 0.5), (349.2, 0.5), (392.0, 1.8),
        (0.0, 0.4),
        (392.0, 0.6), (466.2, 0.5), (523.3, 0.6), (466.2, 0.5), (440.0, 0.6), (392.0, 0.5), (349.2, 0.5), (392.0, 2.0),
    ]
    total = sum(d for _, d in notes) + 0.5
    n = int(total * SAMPLE_RATE)
    s = [0.0] * n
    idx = 0
    phase = 0.0
    cur_f = notes[0][0]
    for freq, d in notes:
        length = int(d * SAMPLE_RATE)
        for i in range(length):
            if idx >= n:
                break
            t = i / SAMPLE_RATE
            if freq > 0.0:
                # Perpindahan nada halus (portamento) + vibrato setelah nada tertahan
                cur_f += (freq - cur_f) * 0.002
                vib = math.sin(2 * math.pi * 5.5 * t) * 6.0 * min(1.0, t / 0.3)
                phase += 2 * math.pi * (cur_f + vib) / SAMPLE_RATE
                env = min(1.0, t / 0.08) * min(1.0, (d - t) / 0.10)
                v = sum(math.sin(phase * h) / h for h in (1, 2, 3, 4, 5, 6)) * 0.2
                s[idx] = v * env * 0.8
            idx += 1
    write_wav("assets/audio/azan_subuh.wav", s)

# 15. Jumpscare (benturan mendadak + jeritan sumbang + dentuman bass, ~2.2s)
def make_jumpscare():
    dur = 2.2
    n = int(dur * SAMPLE_RATE)
    s = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Dentuman bass yang menghantam seketika
        boom = math.sin(2 * math.pi * (75.0 - t * 30.0) * t) * 0.9 * math.exp(-t * 9.0)
        # Ledakan noise di awal supaya terasa mengagetkan
        burst = (random.random() * 2 - 1) * 0.9 * math.exp(-t * 7.0)
        # Jeritan melengking: dua nada sedikit sumbang + getaran cepat
        f1 = 1900.0 + math.sin(2 * math.pi * 9.0 * t) * 500.0 - t * 300.0
        f2 = f1 * 1.06
        screech = (math.sin(2 * math.pi * f1 * t) + math.sin(2 * math.pi * f2 * t)) * 0.35 * math.exp(-t * 2.2)
        # Geraman rendah yang bergetar
        growl = math.sin(2 * math.pi * 48.0 * t + math.sin(2 * math.pi * 23.0 * t) * 4.0) * 0.4 * math.exp(-t * 3.0)
        raw = boom + burst + screech + growl
        val = math.tanh(raw * 2.5)
        # Potong halus di ujung supaya tidak ada bunyi klik
        tail = min(1.0, (dur - t) / 0.05)
        s.append(val * tail * 0.95)
    write_wav("assets/audio/jumpscare.wav", s)

# 16. Kentongan (pukulan bambu/kayu berongga khas ronda malam: "tok-tok-tok!", ~0.95s)
def make_kentongan():
    dur = 0.95
    n = int(dur * SAMPLE_RATE)
    s = [0.0] * n
    # Tiga pukulan beruntun bernada kayu berongga
    strikes = [(0.02, 485.0, 1.0), (0.20, 505.0, 0.92), (0.39, 492.0, 1.0)]
    for st, base_f, amp in strikes:
        start_idx = int(st * SAMPLE_RATE)
        hit_len = int(0.45 * SAMPLE_RATE)
        for i in range(hit_len):
            idx = start_idx + i
            if idx >= n:
                break
            t = i / SAMPLE_RATE
            # Serangan pukul awal (ketukan kayu keras)
            attack = min(1.0, t / 0.003)
            transient = (random.random() * 2 - 1) * math.exp(-t * 140.0) * 0.45
            # Resonansi rongga bambu/kayu (fundamental + overtone tidak harmonis ringan)
            body = (
                math.sin(2 * math.pi * base_f * t) * 0.65 * math.exp(-t * 14.0)
                + math.sin(2 * math.pi * (base_f * 1.58) * t) * 0.35 * math.exp(-t * 22.0)
                + math.sin(2 * math.pi * (base_f * 2.42) * t) * 0.22 * math.exp(-t * 36.0)
                + math.sin(2 * math.pi * (base_f * 0.52) * t) * 0.25 * math.exp(-t * 18.0)
            )
            s[idx] += (body + transient) * attack * amp * 0.85
    write_wav("assets/audio/kentongan.wav", s)

# 17. Energy Drink (bunyi buka tutup kaleng + desis soda + suara tegukan minum, ~1.18s)
def make_energy_drink():
    dur = 1.18
    n = int(dur * SAMPLE_RATE)
    s = [0.0] * n
    prev_noise = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0
        # 0.00 - 0.06s: klik pembuka kaleng aluminium
        if t < 0.08:
            click_env = math.exp(-t * 95.0)
            val += (
                math.sin(2 * math.pi * 2450.0 * t) * 0.42
                + math.sin(2 * math.pi * 4120.0 * t) * 0.28
                + (random.random() * 2 - 1) * 0.45
            ) * click_env
        # 0.04 - 0.34s: desis karbonasi kaleng terbuka ("psshhh!")
        if 0.03 <= t < 0.36:
            ft = t - 0.03
            rn = random.random() * 2 - 1
            hp = rn - prev_noise * 0.65
            prev_noise = rn
            fizz_env = min(1.0, ft / 0.025) * math.exp(-ft * 8.5)
            val += hp * fizz_env * 0.42
        # 0.26 - 1.05s: 3 tegukan minum berurutan ("gluk... gluk... gluk...")
        for g_start, f_hi, f_lo, g_amp in [
            (0.26, 460.0, 210.0, 0.72),
            (0.50, 490.0, 225.0, 0.76),
            (0.74, 430.0, 195.0, 0.68),
        ]:
            if g_start <= t < g_start + 0.19:
                gt = t - g_start
                freq = f_hi - (f_hi - f_lo) * min(1.0, gt / 0.16)
                g_env = math.sin(math.pi * (gt / 0.19)) ** 1.4
                throat = math.sin(2 * math.pi * freq * gt) * 0.65 + math.sin(2 * math.pi * (freq * 1.92) * gt) * 0.25
                liquid_mod = 1.0 + 0.35 * math.sin(2 * math.pi * 34.0 * gt)
                val += throat * g_env * liquid_mod * g_amp
        tail = min(1.0, (dur - t) / 0.05)
        s[i] = max(-0.98, min(0.98, val * tail * 0.85))
    write_wav("assets/audio/energy_drink.wav", s)

# 18. Sorotan UFO (dengung cahaya traktor naik ke langit untuk cutscene menang, ~4.6s)
def make_ufo_beam():
    dur = 4.6
    n = int(dur * SAMPLE_RATE)
    s = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        prog = t / dur
        sweep_freq = 110.0 + 260.0 * (prog ** 1.6)
        wobble = math.sin(2 * math.pi * (5.5 + prog * 9.0) * t) * 14.0
        phase += 2 * math.pi * (sweep_freq + wobble) / SAMPLE_RATE
        beam_hum = (
            math.sin(phase) * 0.45
            + math.sin(phase * 2.0) * 0.22
            + math.sin(phase * 3.01) * 0.14
        )
        shimmer = math.sin(2 * math.pi * (880.0 + 420.0 * prog) * t) * (0.08 + 0.12 * math.sin(2 * math.pi * 6.5 * t))
        env = min(1.0, t / 0.45) * min(1.0, (dur - t) / 0.35)
        s[i] = max(-0.95, min(0.95, (beam_hum + shimmer) * env * 0.72))
    write_wav("assets/audio/ufo_beam.wav", s)

if __name__ == "__main__":
    print("Generating game audio assets...")
    make_ambient()
    make_lampor_bell()
    make_lampor_roar()
    make_footsteps()
    make_heartbeat()
    make_lighter()
    make_pickup()
    make_door_creak()
    make_barricade()
    make_whisper()
    make_victory()
    make_game_over()
    make_rooster()
    make_azan()
    make_jumpscare()
    make_kentongan()
    make_energy_drink()
    make_ufo_beam()
    print("All audio files generated successfully!")
