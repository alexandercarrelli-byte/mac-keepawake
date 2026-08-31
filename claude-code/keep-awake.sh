#!/bin/bash
# keep-awake.sh — impedisce a macOS di addormentarsi mentre Claude Code sta lavorando.
#
# Perché serve: il Mac dorme dopo ~1 minuto dallo spegnimento del display (sleep 1),
# interrompendo il lavoro in corso. Cambiare quei valori con `pmset` richiede sudo,
# quindi qui si usa `caffeinate`, che non richiede privilegi.
#
# Flag usati: -ims
#   -i  impedisce l'idle system sleep  <- questo è ciò che tiene vivo il lavoro
#   -m  impedisce il disk sleep
#   -s  impedisce il system sleep (macOS lo onora solo sotto alimentazione)
# NON si usano -d né -u di proposito: lo SCHERMO deve poter spegnersi normalmente
# (2 min) mentre il Mac continua a girare. In particolare -u non si limita a tenere
# acceso il display: se è già spento lo RIACCENDE.
#
# Uso (dai hook di Claude Code, riceve il JSON dell'hook su stdin):
#   keep-awake.sh acquire   -> avvia caffeinate per questa sessione
#   keep-awake.sh release   -> termina il caffeinate di questa sessione
#
# Il caffeinate viene legato (-w) al processo `claude` che lo ha generato: se la
# sessione muore senza passare da release, il caffeinate muore con lei.

set -u

ACTION="${1:-acquire}"
DIR="$HOME/.claude/keep-awake"
mkdir -p "$DIR" 2>/dev/null

# session_id dallo stdin JSON dell'hook; fallback su una chiave fissa.
STDIN_JSON="$(cat 2>/dev/null || true)"
SID="$(printf '%s' "$STDIN_JSON" \
  | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -1)"
case "$SID" in
  ''|*[!A-Za-z0-9._-]*) SID="default" ;;
esac
PIDFILE="$DIR/$SID.pid"
LOG="$DIR/log.txt"

# Traccia leggera, utile solo per capire se gli hook stanno scattando.
note() {
  printf '%s  %-8s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$ACTION" "$1" >> "$LOG" 2>/dev/null
  # tiene il log corto
  if [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 400 ]; then
    tail -200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null
  fi
}

# Risale la catena dei parent fino al processo `claude` che ha lanciato l'hook.
find_claude_ancestor() {
  local pid="$PPID" comm i
  for i in 1 2 3 4 5 6 7 8; do
    [ -z "$pid" ] && return 1
    [ "$pid" -le 1 ] 2>/dev/null && return 1
    comm="$(ps -o comm= -p "$pid" 2>/dev/null)"
    case "$comm" in
      claude|*/claude) printf '%s' "$pid"; return 0 ;;
    esac
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
  return 1
}

# Rimuove i pidfile di sessioni ormai morte.
prune_stale() {
  local f pid
  for f in "$DIR"/*.pid; do
    [ -e "$f" ] || continue
    pid="$(cat "$f" 2>/dev/null)"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$f"
    fi
  done
}

case "$ACTION" in
  acquire)
    prune_stale
    if [ -f "$PIDFILE" ]; then
      OLD="$(cat "$PIDFILE" 2>/dev/null)"
      if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
        exit 0   # già sveglio per questa sessione
      fi
    fi
    FLAGS="-ims"
    if CPID="$(find_claude_ancestor)"; then
      caffeinate "$FLAGS" -w "$CPID" >/dev/null 2>&1 &
      MODE="legato a claude pid $CPID"
    else
      # nessun processo claude individuato: backstop a tempo, max 2 ore
      caffeinate "$FLAGS" -t 7200 >/dev/null 2>&1 &
      MODE="timeout 2h (nessun claude trovato)"
    fi
    printf '%s' "$!" > "$PIDFILE"
    note "$SID caffeinate $! $FLAGS, $MODE"
    ;;

  release)
    if [ -f "$PIDFILE" ]; then
      PID="$(cat "$PIDFILE" 2>/dev/null)"
      [ -n "$PID" ] && kill "$PID" 2>/dev/null   # SIGTERM, mai -9
      rm -f "$PIDFILE"
      note "$SID caffeinate $PID terminato"
    fi
    prune_stale
    ;;

  status)
    prune_stale
    if ls "$DIR"/*.pid >/dev/null 2>&1; then
      echo "attivo:"
      for f in "$DIR"/*.pid; do
        echo "  $(basename "$f" .pid) -> pid $(cat "$f")"
      done
    else
      echo "nessun caffeinate attivo"
    fi
    ;;
esac

exit 0
