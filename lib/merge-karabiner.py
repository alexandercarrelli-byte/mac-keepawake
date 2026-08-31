#!/usr/bin/env python3
"""Aggiunge la regola F6 -> keepawake-toggle al profilo Karabiner attivo.

Idempotente: riconosce la regola gia' installata dallo shell_command, non dalla
descrizione (la descrizione la puoi cambiare, il comando no).
Con --check non scrive niente (exit 1 se la regola manca).
"""
import json
import os
import shutil
import sys
from datetime import datetime

HOME = os.path.expanduser("~")
KARABINER = os.path.join(HOME, ".config", "karabiner", "karabiner.json")
REGOLA = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "..", "f6-toggle", "karabiner-f6.json")
COMANDO = os.path.join(HOME, ".local", "bin", "keepawake-toggle")

CHECK = "--check" in sys.argv


def contiene_comando(nodo):
    """Cerca ricorsivamente il nostro shell_command dentro una regola."""
    if isinstance(nodo, dict):
        if nodo.get("shell_command", "").endswith("keepawake-toggle"):
            return True
        return any(contiene_comando(v) for v in nodo.values())
    if isinstance(nodo, list):
        return any(contiene_comando(v) for v in nodo)
    return False


def main():
    if not os.path.exists(KARABINER):
        print("  karabiner.json non trovato: apri Karabiner-Elements almeno una volta")
        return 1

    with open(REGOLA) as f:
        regola = json.load(f)
    # il file nel repo porta il placeholder: qui diventa il percorso vero
    for m in regola.get("manipulators", []):
        for azione in m.get("to", []):
            if "shell_command" in azione:
                azione["shell_command"] = COMANDO

    with open(KARABINER) as f:
        conf = json.load(f)

    profili = conf.get("profiles", [])
    if not profili:
        print("  nessun profilo Karabiner nel file")
        return 1
    profilo = next((p for p in profili if p.get("selected")), profili[0])

    regole = profilo.setdefault("complex_modifications", {}).setdefault("rules", [])

    if any(contiene_comando(r) for r in regole):
        print(f"  regola F6: gia' presente nel profilo \"{profilo.get('name')}\", non tocco niente")
        return 0

    print(f"  {'manca' if CHECK else 'aggiungo'}: regola F6 nel profilo \"{profilo.get('name')}\"")
    if CHECK:
        return 1

    regole.append(regola)
    backup = f"{KARABINER}.bak-keepawake-{datetime.now():%Y%m%d-%H%M%S}"
    shutil.copy2(KARABINER, backup)
    print(f"  backup: {backup}")

    tmp = KARABINER + ".tmp"
    with open(tmp, "w") as f:
        json.dump(conf, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, KARABINER)
    print(f"  scritto: {KARABINER} (Karabiner ricarica da solo)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
