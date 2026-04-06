from __future__ import annotations

import json
import sys
import traceback
from dataclasses import asdict, dataclass
from typing import Any

from speech_to_text.core import PushToTalkRecorder, TranscriptionService, list_input_devices


@dataclass
class BackendState:
    model: str = "mlx-community/parakeet-tdt-0.6b-v3"
    sample_rate: int = 16_000
    input_device: int | None = None


class BackendService:
    def __init__(self) -> None:
        self.state = BackendState()
        self.transcriber = TranscriptionService(self.state.model)
        self.recorder = PushToTalkRecorder(
            sample_rate=self.state.sample_rate,
            device=self.state.input_device,
        )

    def shutdown(self) -> None:
        self.recorder.close()

    def handle(self, payload: dict[str, Any]) -> dict[str, Any]:
        command = payload.get("command")
        if command == "ping":
            return {"ok": True, "state": asdict(self.state)}
        if command == "list_devices":
            return {"ok": True, "devices": list_input_devices()}
        if command == "configure":
            return self.configure(payload)
        if command == "preload_model":
            self.transcriber.preload_model(self.emit_progress)
            return {"ok": True, "ready": True}
        if command == "begin_recording":
            self.recorder.begin_recording()
            return {"ok": True}
        if command == "end_recording":
            return self.end_recording()
        raise ValueError(f"Unsupported command: {command}")

    def configure(self, payload: dict[str, Any]) -> dict[str, Any]:
        model = payload.get("model", self.state.model)
        sample_rate = int(payload.get("sample_rate", self.state.sample_rate))
        input_device = payload.get("input_device", self.state.input_device)

        if input_device is not None:
            input_device = int(input_device)

        self.state = BackendState(
            model=model,
            sample_rate=sample_rate,
            input_device=input_device,
        )
        self.transcriber.set_model(model)
        self.recorder.reconfigure(sample_rate=sample_rate, device=input_device)
        return {"ok": True, "state": asdict(self.state)}

    def end_recording(self) -> dict[str, Any]:
        audio = self.recorder.finish_recording()
        if audio is None:
            return {"ok": True, "text": "", "empty": True}
        text = self.transcriber.transcribe_audio(audio, sample_rate=self.state.sample_rate)
        return {"ok": True, "text": text, "empty": False}

    def emit_progress(self, payload: dict[str, Any]) -> None:
        sys.stdout.write(json.dumps({"event": "preload_progress", **payload}, ensure_ascii=True) + "\n")
        sys.stdout.flush()


def write_response(request_id: Any, response: dict[str, Any]) -> None:
    payload = {"id": request_id, **response}
    sys.stdout.write(json.dumps(payload, ensure_ascii=True) + "\n")
    sys.stdout.flush()


def main() -> None:
    service = BackendService()
    try:
        for raw_line in sys.stdin:
            line = raw_line.strip()
            if not line:
                continue

            request_id = None
            try:
                payload = json.loads(line)
                request_id = payload.get("id")
                response = service.handle(payload)
                write_response(request_id, response)
            except Exception as exc:
                write_response(
                    request_id,
                    {
                        "ok": False,
                        "error": str(exc),
                        "traceback": traceback.format_exc(),
                    },
                )
    finally:
        service.shutdown()


if __name__ == "__main__":
    main()
