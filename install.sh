#!/bin/bash
# install.sh — installa i due metodi «il Mac non si addormenta».
#
#   ./install.sh            installa tutto quello che manca (idempotente)
#   ./install.sh --check    non scrive niente: dice solo cosa manca
#   ./install.sh --solo claude-code    solo il metodo 1 (schermo aperto)
#   ./install.sh --solo f6             solo il metodo 2 (coperchio chiuso)
#
# Nessun passo e' distruttivo: ogni file di configurazione toccato viene
# copiato in un .bak-keepawake-<data> prima della modifica.
# L'unico passo che chiede la password e' la regola sudoers, ed e' l'unico
# che lo script NON esegue al posto tuo: te lo stampa e lo lanci tu.

set -u

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK=""
SOLO="tutto"

while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK="--check" ;;
    --solo)  SOLO="${2:-tutto}"; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "argomento non riconosciuto: $1"; exit 2 ;;
  esac
  shift
done

esito=0
titolo() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# ---------------------------------------------------------------- metodo 1
if [ "$SOLO" = "tutto" ] || [ "$SOLO" = "claude-code" ]; then
  titolo "METODO 1 — schermo aperto: sveglio finche' Claude Code lavora"

  DEST="$HOME/.claude/keep-awake.sh"
  if [ -n "$CHECK" ]; then
    if cmp -s "$QUI/claude-code/keep-awake.sh" "$DEST" 2>/dev/null; then
      echo "  script: gia' installato e aggiornato ($DEST)"
    else
      echo "  manca (o e' diverso): $DEST"; esito=1
    fi
  else
    mkdir -p "$HOME/.claude"
    install -m 755 "$QUI/claude-code/keep-awake.sh" "$DEST"
    echo "  script: $DEST"
  fi

  python3 "$QUI/lib/merge-settings.py" $CHECK || esito=1
fi

# ---------------------------------------------------------------- metodo 2
if [ "$SOLO" = "tutto" ] || [ "$SOLO" = "f6" ]; then
  titolo "METODO 2 — coperchio chiuso: F6 e il Mac non si blocca mai"

  DEST="$HOME/.local/bin/keepawake-toggle"
  if [ -n "$CHECK" ]; then
    if cmp -s "$QUI/f6-toggle/keepawake-toggle" "$DEST" 2>/dev/null; then
      echo "  script: gia' installato e aggiornato ($DEST)"
    else
      echo "  manca (o e' diverso): $DEST"; esito=1
    fi
  else
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$QUI/f6-toggle/keepawake-toggle" "$DEST"
    echo "  script: $DEST"
  fi

  # --- regola sudoers: la scrive l'utente, non lo script
  if sudo -n -l /usr/bin/pmset -a disablesleep 1 >/dev/null 2>&1 &&
     sudo -n -l /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1; then
    echo "  sudoers: regola attiva, i due pmset girano senza password"
  else
    esito=1
    TMP="${TMPDIR:-/tmp}/keepawake.sudoers"
    sed "s/^TUO_UTENTE /$(whoami) /" "$QUI/f6-toggle/sudoers-keepawake" > "$TMP"
    echo "  sudoers: MANCA — e' l'unico passo che devi fare tu (chiede la password):"
    echo ""
    echo "      sudo install -m 440 -o root -g wheel $TMP /etc/sudoers.d/keepawake"
    echo "      sudo visudo -c"
    echo ""
    echo "    (file gia' pronto col tuo utente: $(whoami). Per disfare: sudo rm /etc/sudoers.d/keepawake)"
  fi

  # --- regola Karabiner
  if [ ! -d "/Applications/Karabiner-Elements.app" ]; then
    echo "  Karabiner-Elements non installato: brew install --cask karabiner-elements"
    esito=1
  else
    python3 "$QUI/lib/merge-karabiner.py" $CHECK || esito=1
  fi
fi

titolo "STATO ATTUALE"
"$QUI/stato.sh"

if [ -n "$CHECK" ] && [ "$esito" -ne 0 ]; then
  printf '\n\033[1mQualcosa manca\033[0m — rilancia senza --check per installarlo.\n'
fi
exit "$esito"
