#!/usr/bin/env python3
"""Batch-generate LAMPOR in-game voice lines via Gemini 3.8 TTS (Interactions API).

Reads `assets/audio/voice/voice_manifest.json` and writes 24 kHz 16-bit Mono WAV
clips into:
  assets/audio/voice/{id,en}/{male,female,narrator}/<clip>.wav

Default voice casting:
  - male     -> Enceladus (Breathy male survivor)
  - female   -> Vindemiatrix (Gentle female counterpart)
  - narrator -> Algenib (Gravelly folklore narrator)
"""

from __future__ import annotations

import argparse
import base64
from concurrent.futures import CancelledError, ThreadPoolExecutor, as_completed
import http.client
import io
import json
import os
from pathlib import Path
import random
import re
import socket
import threading
import time
from typing import Any, Dict, List, Optional, Tuple
import urllib.error
import urllib.request
import wave

INTERACTIONS_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/interactions"

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
MANIFEST_PATH = PROJECT_ROOT / "assets" / "audio" / "voice" / "voice_manifest.json"
VOICE_OUT_ROOT = PROJECT_ROOT / "assets" / "audio" / "voice"
ENV_VOICE_PATH = PROJECT_ROOT / ".env.voice"


def resolve_api_key() -> Optional[str]:
    """Resolve GEMINI_API_KEY from env, Windows User registry, GOOGLE_API_KEY, or .env.voice."""
    for env_name in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
        val = os.environ.get(env_name, "").strip()
        if val:
            return val
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Environment") as reg_key:
            for env_name in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
                try:
                    val, _ = winreg.QueryValueEx(reg_key, env_name)
                    if isinstance(val, str) and val.strip():
                        return val.strip()
                except FileNotFoundError:
                    continue
    except Exception:
        pass
    if ENV_VOICE_PATH.exists():
        for raw_line in ENV_VOICE_PATH.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            key_name = k.strip()
            if key_name in ("GEMINI_API_KEY", "GOOGLE_API_KEY"):
                cleaned = v.strip().strip('"').strip("'")
                if cleaned:
                    return cleaned
    return None


def decode_audio_to_wav(raw_data: Any) -> bytes:
    """Decode Interactions output_audio payload (base64 str or bytes) into valid WAV bytes."""
    if isinstance(raw_data, (bytes, bytearray)):
        raw_bytes = bytes(raw_data)
        if not raw_bytes.startswith(b"RIFF"):
            # Could be ASCII base64 bytes
            try:
                decoded = base64.b64decode(raw_bytes, validate=True)
                raw_bytes = decoded
            except Exception:
                pass
    elif isinstance(raw_data, str):
        raw_bytes = base64.b64decode(raw_data)
    else:
        raise ValueError(f"Unsupported output_audio.data type: {type(raw_data)}")

    if raw_bytes[:4] == b"RIFF" and raw_bytes[8:12] == b"WAVE":
        return raw_bytes

    # Fallback: wrap raw 24 kHz 16-bit mono PCM into RIFF/WAVE header
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(24000)
        wf.writeframes(raw_bytes)
    return buf.getvalue()


def extract_interaction_audio_bytes(resp_json: Dict[str, Any]) -> bytes:
    """Extract WAV bytes from Interactions JSON response (`output_audio` or `steps` fallback)."""
    out_audio = resp_json.get("output_audio")
    if isinstance(out_audio, dict) and out_audio.get("data"):
        return decode_audio_to_wav(out_audio["data"])

    for step in resp_json.get("steps") or []:
        if not isinstance(step, dict) or step.get("type") != "model_output":
            continue
        for item in step.get("content") or []:
            if isinstance(item, dict) and item.get("type") == "audio" and item.get("data"):
                return decode_audio_to_wav(item["data"])

    raise RuntimeError(
        f"No audio payload found in Gemini Interaction response (keys={list(resp_json.keys())})."
    )


def build_style_prompt(lang: str, clip_style: str) -> str:
    prefix = (
        "Natural Indonesian (id-ID), Javanese folklore survival-horror tone."
        if lang == "id"
        else "Natural English (en-US), tense folklore survival-horror tone."
    )
    style = clip_style.strip()
    return f"{prefix} {style}".strip()


def collect_jobs(
    manifest: Dict[str, Any],
    langs: List[str],
    roles_filter: set[str],
    voice_map: Dict[str, str],
    category_filter: Optional[str],
    clip_id_filter: Optional[str],
    overwrite: bool,
    limit: Optional[int],
) -> List[Dict[str, str]]:
    """Build deterministic list of TTS generation jobs from manifest."""
    jobs: List[Dict[str, str]] = []
    for clip in manifest.get("clips", []):
        cid = clip["id"]
        if category_filter and clip.get("category") != category_filter:
            continue
        if clip_id_filter and cid != clip_id_filter:
            continue

        speaker = str(clip.get("speaker", "Narrator"))
        target_roles = ["male", "female"] if speaker.startswith("Player") else ["narrator"]
        active_roles = [r for r in target_roles if r in roles_filter]
        if not active_roles:
            continue

        for lang in langs:
            spoken = str(clip.get(f"tts_text_{lang}") or clip.get(f"text_{lang}") or "").strip()
            if not spoken:
                continue
            style = build_style_prompt(lang, str(clip.get("style_prompt", "")))
            for role in active_roles:
                out_path = VOICE_OUT_ROOT / lang / role / clip["filename"]
                if out_path.exists() and out_path.stat().st_size >= 1024 and not overwrite:
                    continue
                jobs.append({
                    "clip_id": cid,
                    "category": str(clip.get("category", "")),
                    "lang": lang,
                    "role": role,
                    "voice": voice_map[role],
                    "text": spoken,
                    "style": style,
                    "out_path": str(out_path),
                })
                if limit is not None and len(jobs) >= limit:
                    return jobs
    return jobs


class AuthError(RuntimeError):
    """Non-retryable authentication or permission failure."""


class DailyQuotaExhaustedError(RuntimeError):
    """All configured TTS models hit daily quota."""


def _sanitize_err(msg: str, api_key: str) -> str:
    if api_key and api_key in msg:
        return msg.replace(api_key, "***")
    return msg


class SharedPacer:
    """Thread-safe RPM spacer and automatic daily-quota fallback switcher."""

    def __init__(self, primary_model: str, fallback_model: Optional[str], base_delay: float) -> None:
        self._lock = threading.Lock()
        self.primary_model = primary_model
        cleaned_fb = (fallback_model or "").strip()
        if not cleaned_fb or cleaned_fb.lower() == "none" or cleaned_fb == primary_model:
            cleaned_fb = None
        self.fallback_model = cleaned_fb
        self.active_model = primary_model
        self.exhausted_models: set[str] = set()
        self.all_exhausted_error: Optional[str] = None
        self.abort_auth_error: Optional[str] = None
        self.base_delay = max(0.0, float(base_delay))
        self.next_allowed_at = 0.0

    def abort_auth(self, err_msg: str) -> None:
        with self._lock:
            if self.abort_auth_error is None:
                self.abort_auth_error = err_msg

    def wait_slot(self) -> Optional[str]:
        while True:
            with self._lock:
                if self.abort_auth_error is not None or self.all_exhausted_error is not None:
                    return None
                now = time.monotonic()
                wait_s = self.next_allowed_at - now
                if wait_s <= 0.0:
                    self.next_allowed_at = now + self.base_delay
                    return self.active_model
            time.sleep(min(wait_s, 1.0))

    def backoff_until(self, seconds: float) -> None:
        with self._lock:
            target = time.monotonic() + max(1.0, seconds)
            if target > self.next_allowed_at:
                self.next_allowed_at = target

    @staticmethod
    def is_daily_quota_error(err_msg: str) -> bool:
        low = err_msg.lower()
        return (
            "perday" in low
            or "per day" in low
            or "requestsperday" in low
            or "requests per day" in low
            or "per_day" in low
            or "daily" in low
            or "rpd" in low
        )

    def switch_to_fallback_if_daily_quota(
        self,
        err_msg: str,
        failed_model: Optional[str] = None,
    ) -> Optional[str]:
        if not self.is_daily_quota_error(err_msg):
            return None
        with self._lock:
            hit_model = failed_model or self.active_model
            self.exhausted_models.add(hit_model)
            if self.fallback_model and self.fallback_model not in self.exhausted_models:
                if self.active_model != self.fallback_model:
                    self.active_model = self.fallback_model
                    return self.active_model
                return None
            if self.primary_model in self.exhausted_models and (
                self.fallback_model is None or self.fallback_model in self.exhausted_models
            ):
                if self.all_exhausted_error is None:
                    self.all_exhausted_error = err_msg[:400]
        return None


def parse_retry_delay_seconds(err_msg: str, retry_after_header: Optional[str] = None) -> Optional[float]:
    if retry_after_header:
        try:
            return min(65.0, max(1.0, float(retry_after_header.strip())))
        except ValueError:
            pass
    for pat in (
        r"retry[^\d\n]{0,20}(\d+(?:\.\d+)?)\s*s",
        r"retryDelay[\"'\s:]+(\d+(?:\.\d+)?)",
    ):
        m = re.search(pat, err_msg, flags=re.IGNORECASE)
        if m:
            try:
                return min(65.0, float(m.group(1)))
            except ValueError:
                pass
    return None


def synthesize_job(
    api_key: str,
    pacer: SharedPacer,
    job: Dict[str, str],
    max_retries: int = 6,
) -> Tuple[str, int]:
    """Synthesize a single WAV file via Gemini Interactions REST endpoint with urllib."""
    last_err: Optional[Exception] = None
    for attempt in range(max_retries + 1):
        model_to_use = pacer.wait_slot()
        if model_to_use is None:
            if pacer.abort_auth_error is not None:
                raise AuthError(pacer.abort_auth_error)
            raise DailyQuotaExhaustedError(
                pacer.all_exhausted_error or "Daily quota exhausted on all configured models."
            )

        payload = {
            "model": model_to_use,
            "input": [{
                "type": "user_input",
                "content": [{
                    "type": "text",
                    "text": job["text"],
                    "annotations": [{
                        "type": "speech_metadata",
                        "style": job["style"],
                    }],
                }],
            }],
            "response_format": {"type": "audio"},
            "generation_config": {"speech_config": [{"voice": job["voice"]}]},
        }
        req_bytes = json.dumps(payload).encode("utf-8")
        headers = {
            "x-goog-api-key": api_key,
            "Content-Type": "application/json",
            "Connection": "close",
        }
        req = urllib.request.Request(
            INTERACTIONS_ENDPOINT,
            data=req_bytes,
            headers=headers,
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=35) as resp:
                raw_resp = resp.read().decode("utf-8")
            resp_json = json.loads(raw_resp)
            wav_bytes = extract_interaction_audio_bytes(resp_json)
            if len(wav_bytes) < 1024 or wav_bytes[:4] != b"RIFF":
                raise RuntimeError(f"Invalid WAV output received ({len(wav_bytes)} bytes).")
            out_path = Path(job["out_path"])
            out_path.parent.mkdir(parents=True, exist_ok=True)
            tmp_path = out_path.with_suffix(".wav.tmp")
            tmp_path.write_bytes(wav_bytes)
            tmp_path.replace(out_path)
            return job["out_path"], len(wav_bytes)

        except (AuthError, DailyQuotaExhaustedError):
            raise

        except urllib.error.HTTPError as exc:
            try:
                full_body = exc.read().decode("utf-8", "replace")
            except Exception:
                full_body = ""
            finally:
                try:
                    exc.close()
                except Exception:
                    pass

            full_body = _sanitize_err(full_body, api_key)
            short_body = full_body.replace("\r", " ").replace("\n", " ")[:400]
            retry_after_hdr = exc.headers.get("Retry-After") if exc.headers else None

            if exc.code in (401, 403) or "API_KEY_INVALID" in full_body:
                err_txt = f"HTTP {exc.code}: {short_body}"
                pacer.abort_auth(err_txt)
                raise AuthError(err_txt) from exc

            switched = pacer.switch_to_fallback_if_daily_quota(full_body, failed_model=model_to_use)
            if pacer.all_exhausted_error is not None:
                raise DailyQuotaExhaustedError(f"HTTP {exc.code}: {short_body}") from exc

            if switched:
                print(
                    f"[FALLBACK] {job['clip_id']} ({job['lang']}/{job['role']}): "
                    f"daily quota reached on {model_to_use}; switching to {switched}",
                    flush=True,
                )
                if attempt < max_retries:
                    time.sleep(max(0.5, pacer.base_delay))
                    continue

            if SharedPacer.is_daily_quota_error(full_body) and pacer.active_model != model_to_use:
                if attempt < max_retries:
                    time.sleep(max(0.5, pacer.base_delay))
                    continue

            last_err = RuntimeError(f"HTTP {exc.code}: {short_body}")
            if attempt >= max_retries:
                break

            parsed_delay = parse_retry_delay_seconds(full_body, retry_after_hdr)
            backoff = (
                min(65.0, max(1.0, parsed_delay + 1.0))
                if parsed_delay is not None
                else min(65.0, (2.0 * (2 ** attempt)) + random.uniform(0.2, 1.0))
            )
            if exc.code == 429 or exc.code >= 500 or "RESOURCE_EXHAUSTED" in full_body or parsed_delay is not None:
                pacer.backoff_until(backoff)

            print(
                f"[RETRY {attempt + 1}/{max_retries}] {job['clip_id']} ({job['lang']}/{job['role']}) "
                f"status={exc.code} wait={backoff:.1f}s err={short_body}",
                flush=True,
            )
            time.sleep(backoff)

        except (
            urllib.error.URLError,
            TimeoutError,
            socket.timeout,
            json.JSONDecodeError,
            http.client.HTTPException,
            OSError,
            RuntimeError,
            ValueError,
        ) as exc:
            last_err = exc
            err_msg = _sanitize_err(str(exc), api_key)
            if attempt >= max_retries:
                break
            backoff = min(65.0, (2.0 * (2 ** attempt)) + random.uniform(0.2, 1.0))
            short_err = err_msg.replace("\r", " ").replace("\n", " ")[:400]
            print(
                f"[RETRY {attempt + 1}/{max_retries}] {job['clip_id']} ({job['lang']}/{job['role']}) "
                f"wait={backoff:.1f}s err={short_err}",
                flush=True,
            )
            time.sleep(backoff)

    raise RuntimeError(f"Failed {job['clip_id']} [{job['lang']}/{job['role']}]: {last_err}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate LAMPOR voice lines using Gemini 3.8 TTS.")
    parser.add_argument("--lang", choices=["id", "en", "both"], default="both", help="Languages to generate (default: both).")
    parser.add_argument("--roles", default="male,female,narrator", help="Comma-separated roles: male,female,narrator.")
    parser.add_argument("--male-voice", default="Enceladus", help="Prebuilt/voice ID for male player (default: Enceladus).")
    parser.add_argument("--female-voice", default="Vindemiatrix", help="Prebuilt/voice ID for female player (default: Vindemiatrix).")
    parser.add_argument("--narrator-voice", default="Algenib", help="Prebuilt/voice ID for narrator (default: Algenib).")
    parser.add_argument("--model", default="gemini-3.8-flash-tts", choices=["gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts"], help="Gemini 3.8 TTS model.")
    parser.add_argument("--fallback-model", default="gemini-3.8-flash-lite-tts", help="Fallback TTS model if primary hits daily quota.")
    parser.add_argument("--delay", type=float, default=0.5, help="Minimum seconds between paced API calls across workers (default: 0.5).")
    parser.add_argument("--category", default=None, help="Filter to a single manifest category.")
    parser.add_argument("--clip-id", default=None, help="Filter to a single clip ID.")
    parser.add_argument("--limit", type=int, default=None, help="Maximum number of files to generate.")
    parser.add_argument("--workers", type=int, default=2, help="Parallel worker threads (default: 2).")
    parser.add_argument("--overwrite", action="store_true", help="Regenerate existing .wav files.")
    parser.add_argument("--dry-run", action="store_true", help="Inspect jobs and payload without calling Gemini API.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    langs = ["id", "en"] if args.lang == "both" else [args.lang]
    roles_filter = {r.strip().lower() for r in args.roles.split(",") if r.strip()}
    voice_map = {
        "male": args.male_voice.strip(),
        "female": args.female_voice.strip(),
        "narrator": args.narrator_voice.strip(),
    }

    jobs = collect_jobs(
        manifest=manifest,
        langs=langs,
        roles_filter=roles_filter,
        voice_map=voice_map,
        category_filter=args.category,
        clip_id_filter=args.clip_id,
        overwrite=args.overwrite,
        limit=args.limit,
    )

    by_role: Dict[str, int] = {}
    for j in jobs:
        by_role[j["role"]] = by_role.get(j["role"], 0) + 1

    print(f"Manifest clips : {manifest.get('total_clips')} (model={args.model}, fallback={args.fallback_model})")
    print(f"Voices         : male={voice_map['male']} | female={voice_map['female']} | narrator={voice_map['narrator']}")
    print(f"Pending jobs   : {len(jobs)} ({by_role})")

    if args.dry_run:
        if jobs:
            sample = jobs[0]
            print("DRY_RUN_SAMPLE :", json.dumps({
                "model": args.model,
                "voice": sample["voice"],
                "lang": sample["lang"],
                "role": sample["role"],
                "style": sample["style"],
                "text": sample["text"],
                "out_path": sample["out_path"],
            }, ensure_ascii=False))
        print("DRY_RUN_OK")
        return 0

    if not jobs:
        print("All requested voice files already exist. Pass --overwrite to regenerate.")
        return 0

    api_key = resolve_api_key()
    if not api_key:
        print("ERROR: GEMINI_API_KEY is not set in environment or Lampor/.env.voice.", flush=True)
        return 3

    pacer = SharedPacer(primary_model=args.model, fallback_model=args.fallback_model, base_delay=args.delay)
    done_count = 0
    err_count = 0
    fatal_quota_err: Optional[str] = None
    fatal_auth_err: Optional[str] = None
    workers = max(1, min(args.workers, len(jobs)))

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(synthesize_job, api_key, pacer, job): job
            for job in jobs
        }
        for fut in as_completed(futures):
            job = futures[fut]
            try:
                out_path, size_bytes = fut.result()
                done_count += 1
                print(f"[{done_count}/{len(jobs)}] OK {Path(out_path).relative_to(PROJECT_ROOT)} ({size_bytes} B)", flush=True)
            except CancelledError:
                pass
            except DailyQuotaExhaustedError as exc:
                err_count += 1
                if fatal_quota_err is None:
                    fatal_quota_err = str(exc)
                    print(f"[QUOTA_EXHAUSTED] {fatal_quota_err}", flush=True)
                for pending in futures:
                    pending.cancel()
            except AuthError as exc:
                err_count += 1
                if fatal_auth_err is None:
                    fatal_auth_err = str(exc)
                    print(f"[AUTH_ERROR] {fatal_auth_err}", flush=True)
                for pending in futures:
                    pending.cancel()
            except Exception as exc:
                err_count += 1
                print(f"[ERR] {job['clip_id']} ({job['lang']}/{job['role']}): {exc}", flush=True)

    if fatal_auth_err is not None:
        print(f"ABORTED_AUTH ok={done_count} remaining={len(jobs) - done_count} err={fatal_auth_err}", flush=True)
        return 3
    if fatal_quota_err is not None:
        print(f"STOPPED_DAILY_QUOTA ok={done_count} remaining={len(jobs) - done_count} err={fatal_quota_err}", flush=True)
        return 4

    print(f"FINISHED ok={done_count} errors={err_count}")
    return 0 if err_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
