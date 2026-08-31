#!/usr/bin/env python3
"""Unisce gli hook keep-awake a ~/.claude/settings.json, senza toccare il resto.

Idempotente: se il comando c'e' gia' per quell'evento, non fa nulla.
Con --check non scrive niente e dice solo cosa manca (exit 1 se manca qualcosa).
"""
import json
import os
import shutil
import sys
from datetime import datetime

HOME = os.path.expanduser("~")
SETTINGS = os.path.join(HOME, ".claude", "settings.json")
FRAMMENTO = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "..", "claude-code", "settings-hooks.json")

CHECK = "--check" in sys.argv


def comandi_presenti(gruppi):
    """Tutti i `command` gia' registrati per un evento."""
    visti = set()
    for gruppo in gruppi or []:
        for h in gruppo.get("hooks", []) or []:
            if h.get("command"):
                visti.add(h["command"])
    return visti


def main():
    with open(FRAMMENTO) as f:
        voluti = json.load(f)["hooks"]

    if os.path.exists(SETTINGS):
        with open(SETTINGS) as f:
            settings = json.load(f)
    else:
        settings = {}

    hooks = settings.setdefault("hooks", {})
    mancanti = []

    for evento, gruppi_voluti in voluti.items():
        presenti = comandi_presenti(hooks.get(evento))
        for gruppo in gruppi_voluti:
            nuovi = [h for h in gruppo["hooks"] if h["command"] not in presenti]
            if not nuovi:
                continue
            mancanti.append((evento, [h["command"] for h in nuovi]))
            if not CHECK:
                hooks.setdefault(evento, []).append({"hooks": nuovi})

    if not mancanti:
        print("  hook keep-awake: gia' presenti tutti e quattro, non tocco niente")
        return 0

    for evento, comandi in mancanti:
        for c in comandi:
            print(f"  {'manca' if CHECK else 'aggiungo'}: {evento} -> {c}")

    if CHECK:
        return 1

    if os.path.exists(SETTINGS):
        backup = f"{SETTINGS}.bak-keepawake-{datetime.now():%Y%m%d-%H%M%S}"
        shutil.copy2(SETTINGS, backup)
        print(f"  backup: {backup}")

    os.makedirs(os.path.dirname(SETTINGS), exist_ok=True)
    tmp = SETTINGS + ".tmp"
    with open(tmp, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, SETTINGS)
    print(f"  scritto: {SETTINGS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
