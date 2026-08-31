#!/bin/bash
# stato.sh — in che stato sono i due metodi, adesso.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# --- metodo 1: c'e' un caffeinate legato a una sessione Claude Code?
DIR="$HOME/.claude/keep-awake"
vivi=0
if [ -d "$DIR" ]; then
  for f in "$DIR"/*.pid; do
    [ -e "$f" ] || continue
    pid="$(cat "$f" 2>/dev/null)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      vivi=$((vivi + 1))
    fi
  done
fi
if [ "$vivi" -gt 0 ]; then
  echo "  metodo 1  ATTIVO   — $vivi sessione/i Claude Code tengono sveglio il Mac (schermo libero di spegnersi)"
else
  echo "  metodo 1  a riposo — nessuna sessione Claude Code sta trattenendo il sonno"
fi

# --- metodo 2: disablesleep globale
stato="$(pmset -g 2>/dev/null | awk '/SleepDisabled/{print $2}')"
if [ "${stato:-0}" = "1" ]; then
  echo "  metodo 2  ⚡️ ON    — coperchio chiuso e batteria: il Mac NON dormira'. Ricordati di spegnerlo (F6)."
else
  echo "  metodo 2  ☕️ OFF   — sonno normale: chiudendo il coperchio il Mac si addormenta"
fi
