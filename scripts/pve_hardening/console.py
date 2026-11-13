"""Sortie console coloree, portable Windows / Linux / macOS.

Sur Windows, PowerShell 5.1 interprete toute ecriture sur **stderr** comme
une erreur bloquante (``ErrorActionPreference = Stop``). C'est la raison
historique de plusieurs bugs du lab : les messages de succes sont donc
ecrits sur **stdout**, et les messages d'**erreur** seulement sur stderr.

Ce module centralise la regle et fournit les couleurs ANSI.
"""

from __future__ import annotations

import os
import sys
from typing import TextIO

_CODES = {
    "reset": "\033[0m",
    "bold": "\033[1m",
    "dim": "\033[2m",
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "blue": "\033[34m",
    "magenta": "\033[35m",
    "cyan": "\033[36m",
    "grey": "\033[90m",
}


def _color_enabled() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    if os.environ.get("PVE_HARDENING_COLOR") == "always":
        return True
    if os.environ.get("PVE_HARDENING_COLOR") == "never":
        return False
    # Windows : il faut activer le traitement ANSI (VT100) sur la console.
    if sys.platform == "win32":
        try:
            import ctypes

            kernel32 = ctypes.windll.kernel32
            handle = kernel32.GetStdHandle(-11)  # STD_OUTPUT_HANDLE
            mode = ctypes.c_uint32()
            if not kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                return False
            # ENABLE_VIRTUAL_TERMINAL_PROCESSING
            if not kernel32.SetConsoleMode(handle, mode.value | 0x0004):
                return False
            return True
        except Exception:
            return False
    return sys.stdout.isatty()


class Console:
    """Ecriture coloree sur stdout (succes) ou stderr (erreurs)."""

    def __init__(self, stream: TextIO | None = None, err: TextIO | None = None) -> None:
        self.stream = stream or sys.stdout
        self.err = err or sys.stderr
        self.enabled = _color_enabled()

    def _paint(self, text: str, color: str | None) -> str:
        if not color or not self.enabled or color not in _CODES:
            return text
        return f"{_CODES[color]}{text}{_CODES['reset']}"

    def write(self, text: str = "", color: str | None = None) -> None:
        """Ecrit sur stdout : jamais interprete comme une erreur."""
        print(self._paint(text, color), file=self.stream, flush=True)

    def error(self, text: str = "") -> None:
        """Ecrit sur stderr : a reservuer aux vraies erreurs."""
        print(self._paint(text, "red"), file=self.err, flush=True)

    def step(self, text: str) -> None:
        self.write("")
        self.write(f"=== {text} ===", "cyan")

    def info(self, text: str) -> None:
        self.write(text)

    def dim(self, text: str) -> None:
        self.write(text, "grey")

    def ok(self, text: str) -> None:
        self.write(text, "green")

    def warn(self, text: str) -> None:
        self.write(text, "yellow")

    def bad(self, text: str) -> None:
        self.error(text)


console = Console()


def indent(text: str, prefix: str = "  ") -> str:
    """Prefixe chaque ligne de ``text``."""
    return "\n".join(prefix + line for line in text.splitlines())
