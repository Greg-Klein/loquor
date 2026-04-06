from __future__ import annotations

import argparse

from speech_to_text.core import (
    PushToTalkRecorder,
    TranscriptionService,
    key_to_label,
    list_input_devices,
    record_audio,
)


DEFAULT_MODEL = "mlx-community/parakeet-tdt-0.6b-v3"
DEFAULT_SAMPLE_RATE = 16_000


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Record audio from the microphone and transcribe it locally with Parakeet."
    )
    parser.add_argument("--duration", type=float, default=5.0, help="Recording duration in seconds.")
    parser.add_argument(
        "--sample-rate",
        type=int,
        default=DEFAULT_SAMPLE_RATE,
        help="Audio sample rate. Parakeet expects 16 kHz mono audio.",
    )
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Parakeet model identifier.")
    parser.add_argument(
        "--device",
        type=int,
        default=None,
        help="Optional input device index from --list-devices.",
    )
    parser.add_argument("--list-devices", action="store_true", help="List available audio devices and exit.")
    parser.add_argument("--keep-audio", action="store_true", help="Keep the recorded WAV file in the project directory.")
    return parser.parse_args()


def list_devices() -> None:
    for device in list_input_devices():
        print(f"{device['id']}: {device['name']} ({device['channels']} in)")


def main() -> None:
    args = parse_args()

    if args.list_devices:
        list_devices()
        return

    audio = record_audio(args.duration, args.sample_rate, args.device)
    transcriber = TranscriptionService(args.model)
    text = transcriber.transcribe_audio(audio, args.sample_rate, keep_audio=args.keep_audio)
    print("\nTranscription:\n")
    print(text or "[No speech detected]")
