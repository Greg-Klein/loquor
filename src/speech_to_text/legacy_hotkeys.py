from __future__ import annotations

import threading
from typing import Callable

from pynput import keyboard


KeyType = keyboard.Key | keyboard.KeyCode | None


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
