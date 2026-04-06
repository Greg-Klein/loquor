from __future__ import annotations

import tempfile
import threading
from pathlib import Path
from typing import Callable

import numpy as np
import sounddevice as sd
import soundfile as sf
from pynput import keyboard


KeyType = keyboard.Key | keyboard.KeyCode | None


def list_input_devices() -> list[dict[str, object]]:
    devices = []
    for index, device in enumerate(sd.query_devices()):
        max_input_channels = int(device["max_input_channels"])
        if max_input_channels < 1:
            continue
        devices.append(
            {
                "id": index,
                "name": str(device["name"]),
                "channels": max_input_channels,
                "default_samplerate": int(device["default_samplerate"]),
            }
        )
    return devices


def default_input_device() -> int | None:
    default_device = sd.default.device

    if hasattr(default_device, "input"):
        input_device = getattr(default_device, "input")
    elif isinstance(default_device, (list, tuple)):
        input_device = default_device[0]
    else:
        try:
            input_device = default_device[0]
        except Exception:
            input_device = default_device

    if input_device is None:
        return None

    input_device = int(input_device)
    return None if input_device < 0 else input_device


def input_device_info(device: int | None) -> dict[str, object]:
    query_target = device if device is not None else default_input_device()
    if query_target is None:
        return {}
    return dict(sd.query_devices(query_target))


def key_to_id(key: KeyType) -> str | None:
    if key is None:
        return None
    if isinstance(key, keyboard.KeyCode):
        if key.char:
            return f"char:{key.char.lower()}"
        if key.vk is not None:
            return f"vk:{key.vk}"
        return None
    return f"key:{key.name}"


def key_to_label(key_id: str) -> str:
    if key_id.startswith("char:"):
        return key_id.split(":", 1)[1].upper()
    if key_id.startswith("vk:"):
        return f"Key code {key_id.split(':', 1)[1]}"
    if key_id.startswith("key:"):
        raw = key_id.split(":", 1)[1]
        return raw.replace("_", " ").title()
    return key_id


def normalize_key_id(key_id: str) -> str:
    if key_id == "shift":
        return "key:shift"
    if key_id == "ctrl":
        return "key:ctrl"
    if key_id == "alt":
        return "key:alt"
    if key_id == "cmd":
        return "key:cmd"
    if key_id.startswith(("char:", "vk:", "key:")):
        return key_id
    return f"char:{key_id.lower()}"


class TranscriptionService:
    def __init__(self, model_name: str) -> None:
        self.model_name = model_name
        self._model = None
        self._lock = threading.Lock()

    def set_model(self, model_name: str) -> None:
        with self._lock:
            if self.model_name == model_name:
                return
            self.model_name = model_name
            self._model = None

    def _load_model(self):
        from parakeet_mlx import from_pretrained

        if self._model is None:
            print(f"Loading model: {self.model_name}")
            model_path = self._prepare_model_files()
            self._model = from_pretrained(str(model_path))
        return self._model

    def preload_model(self, progress_callback: Callable[[dict[str, object]], None] | None = None) -> None:
        with self._lock:
            model_path = self._prepare_model_files(progress_callback)
            if progress_callback is not None:
                progress_callback(
                    {
                        "stage": "loading",
                        "message": "Loading model...",
                    }
                )

            from parakeet_mlx import from_pretrained

            if self._model is None:
                print(f"Loading model: {self.model_name}")
                self._model = from_pretrained(str(model_path))

            if progress_callback is not None:
                progress_callback(
                    {
                        "stage": "ready",
                        "message": "Model ready",
                        "percent": 100,
                    }
                )

    def _prepare_model_files(
        self, progress_callback: Callable[[dict[str, object]], None] | None = None
    ) -> Path:
        from huggingface_hub import hf_hub_download

        model_dir = self._local_model_dir()
        config_path = model_dir / "config.json"
        weights_path = model_dir / "model.safetensors"

        if config_path.exists() and weights_path.exists():
            if progress_callback is not None:
                progress_callback(
                    {
                        "stage": "cached",
                        "message": "Using cached model...",
                    }
                )
            return model_dir

        model_dir.mkdir(parents=True, exist_ok=True)
        files = ["config.json", "model.safetensors"]
        dry_run_infos = [
            hf_hub_download(
                self.model_name,
                filename,
                local_dir=model_dir,
                dry_run=True,
            )
            for filename in files
        ]
        total_bytes = sum(info.file_size for info in dry_run_infos if info.will_download)

        if progress_callback is not None:
            progress_callback(
                {
                    "stage": "downloading",
                    "message": "Downloading model...",
                    "percent": 0 if total_bytes > 0 else 100,
                }
            )

        downloaded_bytes = 0

        class ProgressReporter:
            def __init__(
                self,
                *,
                total: int | None = None,
                initial: int = 0,
                desc: str | None = None,
                **_: object,
            ) -> None:
                self.total = total or 0
                self.current = initial
                self.desc = desc or ""

            def __enter__(self) -> "ProgressReporter":
                return self

            def __exit__(self, exc_type, exc, tb) -> None:
                return None

            def update(self, amount: int) -> None:
                nonlocal downloaded_bytes
                self.current += amount
                downloaded_bytes += amount
                if progress_callback is None or total_bytes <= 0:
                    return
                percent = min(99, int((downloaded_bytes / total_bytes) * 100))
                progress_callback(
                    {
                        "stage": "downloading",
                        "message": f"Downloading model... {percent}%",
                        "percent": percent,
                    }
                )

            def close(self) -> None:
                return None

        for filename in files:
            hf_hub_download(
                self.model_name,
                filename,
                local_dir=model_dir,
                tqdm_class=ProgressReporter,
            )

        if progress_callback is not None and total_bytes > 0:
            progress_callback(
                {
                    "stage": "downloading",
                    "message": "Downloading model... 100%",
                    "percent": 100,
                }
            )

        return model_dir

    def _local_model_dir(self) -> Path:
        safe_model_name = self.model_name.replace("/", "--")
        return Path.home() / "Library" / "Caches" / "Loquor" / "models" / safe_model_name

    def transcribe_audio(self, audio: np.ndarray, sample_rate: int, keep_audio: bool = False) -> str:
        with self._lock:
            model = self._load_model()
            audio_path = save_audio(audio, sample_rate, keep_audio)
            try:
                print("Transcribing locally...")
                result = model.transcribe(str(audio_path))
                return result.text.strip()
            finally:
                if not keep_audio and audio_path.exists():
                    audio_path.unlink()


def record_audio(duration: float, sample_rate: int, device: int | None) -> np.ndarray:
    frames = int(duration * sample_rate)
    print(f"Recording {duration:.1f}s from microphone...")
    audio = sd.rec(
        frames,
        samplerate=sample_rate,
        channels=1,
        dtype="float32",
        device=device,
    )
    sd.wait()
    print("Recording complete.")
    return audio


def save_audio(audio: np.ndarray, sample_rate: int, keep_audio: bool) -> Path:
    if keep_audio:
        output_path = Path.cwd() / "recording.wav"
        sf.write(output_path, audio, sample_rate)
        return output_path

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_file:
        output_path = Path(tmp_file.name)

    sf.write(output_path, audio, sample_rate)
    return output_path


class PushToTalkRecorder:
    def __init__(self, sample_rate: int, device: int | None) -> None:
        self.sample_rate = sample_rate
        self.device = device
        self._resolved_device: int | None = None
        self._active_sample_rate = sample_rate
        self._lock = threading.Lock()
        self._segments: list[np.ndarray] = []
        self._recording = False
        self._closed = False
        self.stream: sd.InputStream | None = None

    def _create_stream(self) -> sd.InputStream:
        self._resolved_device = self.device if self.device is not None else default_input_device()
        requested_sample_rate = self.sample_rate

        try:
            stream = sd.InputStream(
                samplerate=requested_sample_rate,
                channels=1,
                dtype="float32",
                device=self._resolved_device,
                callback=self._on_audio,
            )
            self._active_sample_rate = requested_sample_rate
            return stream
        except Exception:
            device_info = input_device_info(self._resolved_device)
            fallback_sample_rate = int(device_info.get("default_samplerate", requested_sample_rate))
            if fallback_sample_rate == requested_sample_rate:
                raise

            stream = sd.InputStream(
                samplerate=fallback_sample_rate,
                channels=1,
                dtype="float32",
                device=self._resolved_device,
                callback=self._on_audio,
            )
            self._active_sample_rate = fallback_sample_rate
            return stream

    def _on_audio(self, indata, frames, time_info, status) -> None:
        del frames, time_info
        if status:
            print(f"Audio status: {status}")
        with self._lock:
            if self._recording:
                self._segments.append(indata.copy())

    def _ensure_stream_started(self) -> None:
        if self.stream is None:
            self.stream = self._create_stream()
        self.stream.start()

    def _stop_stream(self) -> None:
        if self.stream is None:
            return
        self.stream.stop()
        self.stream.close()
        self.stream = None
        self._resolved_device = None
        self._active_sample_rate = self.sample_rate

    def reconfigure(self, sample_rate: int, device: int | None) -> None:
        was_recording = self._recording
        self.close()
        self.sample_rate = sample_rate
        self.device = device
        self._resolved_device = None
        self._segments = []
        self._recording = False
        self._closed = False
        if was_recording:
            self.begin_recording()

    def close(self) -> None:
        if self._closed:
            return
        self._stop_stream()
        self._closed = True

    def begin_recording(self) -> None:
        with self._lock:
            if self._recording:
                return
            if self._closed:
                raise RuntimeError("Recorder is closed.")
            if self.device is None:
                self._resolved_device = default_input_device()
            self._segments = []
            self._ensure_stream_started()
            self._recording = True
        print("Recording... release the push-to-talk key to transcribe.")

    def finish_recording(self) -> tuple[np.ndarray, int] | None:
        with self._lock:
            if not self._recording:
                return None
            self._recording = False
            segments = self._segments
            self._segments = []
            sample_rate = self._active_sample_rate
            self._stop_stream()

        if not segments:
            print("No audio captured.")
            return None

        print("Recording complete.")
        return np.concatenate(segments, axis=0), sample_rate


class GlobalHotkeyManager:
    def __init__(
        self,
        key_id: str,
        on_hold_start: Callable[[], None],
        on_hold_end: Callable[[], None],
        on_key_captured: Callable[[str], None],
    ) -> None:
        self.key_id = normalize_key_id(key_id)
        self.on_hold_start = on_hold_start
        self.on_hold_end = on_hold_end
        self.on_key_captured = on_key_captured
        self._listener: keyboard.Listener | None = None
        self._active_keys: set[str] = set()
        self._capture_next_key = False
        self._lock = threading.Lock()

    def start(self) -> None:
        self._listener = keyboard.Listener(on_press=self._on_press, on_release=self._on_release)
        self._listener.start()

    def stop(self) -> None:
        if self._listener is not None:
            self._listener.stop()
            self._listener = None

    def set_key(self, key_id: str) -> None:
        with self._lock:
            self.key_id = normalize_key_id(key_id)
            self._active_keys.clear()

    def capture_next_key(self) -> None:
        with self._lock:
            self._capture_next_key = True
            self._active_keys.clear()

    def _on_press(self, key: KeyType) -> None:
        key_id = key_to_id(key)
        if key_id is None:
            return

        with self._lock:
            if self._capture_next_key:
                self._capture_next_key = False
                self.key_id = normalize_key_id(key_id)
                self._active_keys.clear()
                self.on_key_captured(self.key_id)
                return

            if key_id in self._active_keys:
                return
            self._active_keys.add(key_id)
            should_start = key_id == self.key_id

        if should_start:
            self.on_hold_start()

    def _on_release(self, key: KeyType) -> None:
        key_id = key_to_id(key)
        if key_id is None:
            return

        with self._lock:
            was_active = key_id in self._active_keys
            if was_active:
                self._active_keys.discard(key_id)
            should_stop = was_active and key_id == self.key_id

        if should_stop:
            self.on_hold_end()
