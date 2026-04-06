from distutils.core import setup

import py2app  # noqa: F401
from py2app.build_app import py2app as Py2AppCommand


APP = ["src/speech_to_text/macos_app.py"]
OPTIONS = {
    "argv_emulation": False,
    "plist": {
        "CFBundleName": "SpeechToText",
        "CFBundleDisplayName": "SpeechToText",
        "CFBundleIdentifier": "com.gregoryklein.speechtotext",
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "0.1.0",
        "LSUIElement": True,
        "NSMicrophoneUsageDescription": "SpeechToText uses the microphone to transcribe speech locally.",
    },
    "packages": [
        "speech_to_text",
    ],
    "includes": [
        "rumps",
        "pynput",
        "parakeet_mlx",
        "mlx",
        "mlx.core",
        "numpy",
        "sounddevice",
        "soundfile",
    ],
}


class SpeechToTextPy2App(Py2AppCommand):
    def finalize_options(self):
        self.distribution.install_requires = []
        super().finalize_options()


setup(
    app=APP,
    cmdclass={"py2app": SpeechToTextPy2App},
    options={"py2app": OPTIONS},
)
