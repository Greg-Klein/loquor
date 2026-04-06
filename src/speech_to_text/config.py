from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path


APP_SUPPORT_DIR = Path.home() / "Library" / "Application Support" / "SpeechToText"
CONFIG_PATH = APP_SUPPORT_DIR / "config.json"


@dataclass
class AppConfig:
    model: str = "mlx-community/parakeet-tdt-0.6b-v3"
    sample_rate: int = 16_000
    input_device: int | None = None
    push_to_talk_key: str = "shift"
    paste_into_active_app: bool = True


class ConfigStore:
    def __init__(self, path: Path = CONFIG_PATH) -> None:
        self.path = path

    def load(self) -> AppConfig:
        if not self.path.exists():
            return AppConfig()

        data = json.loads(self.path.read_text())
        defaults = asdict(AppConfig())
        defaults.update(data)
        return AppConfig(**defaults)

    def save(self, config: AppConfig) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(asdict(config), indent=2, sort_keys=True))
