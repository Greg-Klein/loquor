from __future__ import annotations

import time

from AppKit import NSPasteboard, NSPasteboardTypeString
from Quartz import (
    CGEventCreateKeyboardEvent,
    CGEventPost,
    kCGAnnotatedSessionEventTap,
    kCGEventFlagMaskCommand,
)


COMMAND_KEYCODE = 0x37
V_KEYCODE = 0x09


def copy_to_clipboard(text: str) -> None:
    pasteboard = NSPasteboard.generalPasteboard()
    pasteboard.clearContents()
    pasteboard.setString_forType_(text, NSPasteboardTypeString)


def paste_into_active_app() -> None:
    command_down = CGEventCreateKeyboardEvent(None, COMMAND_KEYCODE, True)
    v_down = CGEventCreateKeyboardEvent(None, V_KEYCODE, True)
    v_up = CGEventCreateKeyboardEvent(None, V_KEYCODE, False)
    command_up = CGEventCreateKeyboardEvent(None, COMMAND_KEYCODE, False)

    v_down.setFlags_(kCGEventFlagMaskCommand)
    v_up.setFlags_(kCGEventFlagMaskCommand)

    CGEventPost(kCGAnnotatedSessionEventTap, command_down)
    CGEventPost(kCGAnnotatedSessionEventTap, v_down)
    CGEventPost(kCGAnnotatedSessionEventTap, v_up)
    CGEventPost(kCGAnnotatedSessionEventTap, command_up)


def copy_and_paste(text: str, should_paste: bool) -> None:
    if not text:
        return
    copy_to_clipboard(text)
    if should_paste:
        time.sleep(0.05)
        paste_into_active_app()
