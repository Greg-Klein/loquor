from __future__ import annotations

import threading

import rumps

from speech_to_text.config import ConfigStore
from speech_to_text.core import (
    GlobalHotkeyManager,
    PushToTalkRecorder,
    TranscriptionService,
    key_to_label,
    list_input_devices,
)
from speech_to_text.macos import copy_and_paste


class SpeechToTextMenuBarApp(rumps.App):
    def __init__(self) -> None:
        super().__init__("STT", quit_button=None)
        self.config_store = ConfigStore()
        self.config = self.config_store.load()
        self.transcriber = TranscriptionService(self.config.model)
        self.recorder = PushToTalkRecorder(
            sample_rate=self.config.sample_rate,
            device=self.config.input_device,
        )
        self.hotkey = GlobalHotkeyManager(
            key_id=self.config.push_to_talk_key,
            on_hold_start=self._start_recording,
            on_hold_end=self._stop_recording,
            on_key_captured=self._set_captured_key,
        )
        self.is_transcribing = False
        self.status_item = rumps.MenuItem("Status: Ready")
        self.current_key_item = rumps.MenuItem("")
        self.current_mic_item = rumps.MenuItem("")
        self.paste_toggle_item = rumps.MenuItem("")
        self.capture_key_item = rumps.MenuItem("Change push-to-talk key...", callback=self.change_hotkey)
        self.refresh_mics_item = rumps.MenuItem("Refresh microphones", callback=self.refresh_microphones)
        self.quit_item = rumps.MenuItem("Quit", callback=self.quit_app)
        self._rebuild_menu()
        self.hotkey.start()

    def _rebuild_menu(self) -> None:
        self.current_key_item.title = f"Push-to-talk key: {key_to_label(self.config.push_to_talk_key)}"
        self.current_mic_item.title = f"Microphone: {self._current_microphone_label()}"
        paste_state = "On" if self.config.paste_into_active_app else "Off"
        self.paste_toggle_item.title = f"Auto-paste into active field: {paste_state}"
        self.paste_toggle_item.set_callback(self.toggle_auto_paste)

        microphone_menu = rumps.MenuItem("Input microphone")
        for device in list_input_devices():
            item = rumps.MenuItem(
                title=device["name"],
                callback=self.select_microphone,
            )
            item.device_id = device["id"]
            item.state = int(device["id"] == self.config.input_device)
            microphone_menu.add(item)
        microphone_menu.add(rumps.separator)
        microphone_menu.add(self.refresh_mics_item)

        self.menu = [
            self.status_item,
            None,
            self.current_key_item,
            self.capture_key_item,
            self.current_mic_item,
            microphone_menu,
            self.paste_toggle_item,
            None,
            self.quit_item,
        ]

    def _current_microphone_label(self) -> str:
        devices = {device["id"]: device["name"] for device in list_input_devices()}
        if self.config.input_device is None:
            return "Default system input"
        return str(devices.get(self.config.input_device, f"Device {self.config.input_device}"))

    def _persist(self) -> None:
        self.config_store.save(self.config)

    def _set_status(self, text: str) -> None:
        self.status_item.title = f"Status: {text}"

    def _start_recording(self) -> None:
        if self.is_transcribing:
            return
        self._set_status("Recording")
        self.recorder.begin_recording()

    def _stop_recording(self) -> None:
        recording = self.recorder.finish_recording()
        if recording is None:
            self._set_status("Ready")
            return
        audio, sample_rate = recording
        self.is_transcribing = True
        self._set_status("Transcribing")
        threading.Thread(target=self._transcribe_and_output, args=(audio, sample_rate), daemon=True).start()

    def _transcribe_and_output(self, audio, sample_rate: int) -> None:
        try:
            text = self.transcriber.transcribe_audio(audio, sample_rate)
            if text:
                copy_and_paste(text, should_paste=self.config.paste_into_active_app)
                self._set_status("Copied to clipboard")
                rumps.notification("Speech to Text", "Transcription ready", text)
            else:
                self._set_status("No speech detected")
        except Exception as exc:
            self._set_status("Error")
            rumps.notification("Speech to Text", "Transcription failed", str(exc))
        finally:
            self.is_transcribing = False

    def _set_captured_key(self, key_id: str) -> None:
        self.config.push_to_talk_key = key_id
        self.hotkey.set_key(key_id)
        self._persist()
        self._rebuild_menu()
        self._set_status(f"Hotkey set to {key_to_label(key_id)}")

    def change_hotkey(self, _) -> None:
        self._set_status("Press a key to set push-to-talk")
        self.hotkey.capture_next_key()

    def select_microphone(self, sender) -> None:
        self.config.input_device = sender.device_id
        self.recorder.reconfigure(
            sample_rate=self.config.sample_rate,
            device=self.config.input_device,
        )
        self._persist()
        self._rebuild_menu()
        self._set_status("Microphone updated")

    def refresh_microphones(self, _) -> None:
        self._rebuild_menu()
        self._set_status("Microphone list refreshed")

    def toggle_auto_paste(self, _) -> None:
        self.config.paste_into_active_app = not self.config.paste_into_active_app
        self._persist()
        self._rebuild_menu()
        self._set_status("Paste setting updated")

    def quit_app(self, _) -> None:
        self.hotkey.stop()
        self.recorder.close()
        rumps.quit_application()


def run_menubar_app() -> None:
    app = SpeechToTextMenuBarApp()
    app.run()
