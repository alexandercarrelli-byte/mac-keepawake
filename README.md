# Un Mac che non si addormenta quando non deve

Due funzioni distinte, con due scopi diversi, in un repo solo. Non sono alternative:
convivono, e nella pratica servono in momenti diversi della stessa giornata.

| | **Metodo 1 — schermo aperto** | **Metodo 2 — coperchio chiuso** |
|---|---|---|
| **Quando** | Sei alla scrivania, un agente sta lavorando | Chiudi il portatile e te ne vai |
| **Cosa fa** | Lo schermo si oscura, il Mac non dorme | Il Mac non dorme e non si blocca **mai** |
| **Chi lo accende** | Da solo, quando parte una sessione Claude Code | Tu, premendo **F6** |
| **Chi lo spegne** | Da solo, a fine turno | Tu, ripremendo F6 |
| **Come** | `caffeinate -ims` legato al processo | `pmset -a disablesleep 1` + `caffeinate -dimsu` |
| **Serve root?** | No | Sì, ma solo per due comandi (regola `sudoers` mirata) |
| **Rischio se te lo dimentichi acceso** | Nessuno: muore con la sessione | Il Mac resta sveglio **nello zaino** finché non si scarica |

---

## Installazione

```bash
git clone https://github.com/alexandercarrelli-byte/mac-keepawake-f6.git
cd mac-keepawake-f6
./install.sh
```

L'installer è **idempotente** e non distrugge niente: se un pezzo c'è già lo dice e
tira dritto, e ogni file di configurazione che tocca (`settings.json`, `karabiner.json`)
viene copiato in un `.bak-keepawake-<data>` prima della modifica.

```bash
./install.sh --check              # non scrive niente: dice solo cosa manca
./install.sh --solo claude-code   # solo il metodo 1
./install.sh --solo f6            # solo il metodo 2
./stato.sh                        # in che stato sono adesso i due metodi
```

L'unico passo che l'installer **non** esegue al posto tuo è la regola `sudoers` del
metodo 2: chiede la password di root, quindi te la prepara già compilata col tuo utente
e ti stampa il comando esatto da lanciare. Tutto il resto è automatico.

---

## Metodo 1 — schermo aperto, sveglio finché l'agente lavora

**Il problema.** Il Mac dorme dopo circa un minuto dallo spegnimento del display.
Se un agente sta girando in una sessione Claude Code, il lavoro si interrompe a metà —
e non c'è nessuno che se ne accorga, perché lo schermo è già nero.

**La soluzione.** `caffeinate -ims`, avviato e fermato dagli hook di Claude Code.

I flag sono scelti uno per uno:

| Flag | Effetto | Perché c'è (o non c'è) |
|---|---|---|
| `-i` | Blocca l'idle system sleep | È questo che tiene vivo il lavoro |
| `-m` | Blocca il disk sleep | |
| `-s` | Blocca il system sleep | macOS lo onora solo sotto alimentazione |
| `-d` | ~~Tiene acceso il display~~ | **Escluso di proposito**: lo schermo deve potersi spegnere |
| `-u` | ~~Simula attività utente~~ | **Escluso**: se il display è già spento, lo **riaccende** |

Il punto non ovvio è proprio l'esclusione di `-d` e `-u`. Sono i due flag che verrebbero
in mente per primi, e sono quelli sbagliati: il risultato sarebbe uno schermo acceso
tutta la notte a illuminare la stanza, per proteggere un lavoro che gira benissimo al
buio.

**Ciclo di vita.** Un `caffeinate` per sessione, con il PID in
`~/.claude/keep-awake/<session_id>.pid`:

- `acquire` su **SessionStart** e su ogni **UserPromptSubmit** — la sessione è viva;
- `release` su **Stop** e **SessionEnd** — il turno è finito, il Mac torna normale.

La rete di sicurezza è `caffeinate -w <pid del processo claude>`: il caffeinate è
**legato** al processo che l'ha generato. Se la sessione muore male — crash, terminale
chiuso, `kill` — non passa da `release`, ma il caffeinate muore lo stesso. Senza quel
`-w` un solo crash lascerebbe il Mac insonne per sempre, e non ci sarebbe niente da
guardare per accorgersene. Se il processo `claude` non viene individuato risalendo la
catena dei parent, si ripiega su `-t 7200`: due ore e poi scade da solo.

Ogni `acquire` fa anche pulizia dei pidfile di sessioni ormai morte, così la directory
non cresce all'infinito.

**File:** `claude-code/keep-awake.sh` → `~/.claude/keep-awake.sh`,
`claude-code/settings-hooks.json` → unito a `~/.claude/settings.json`.

---

## Metodo 2 — coperchio chiuso, il Mac non si blocca mai

**Il problema.** Su Apple Silicon, a batteria e con il coperchio chiuso, `caffeinate`
da solo **non basta**: macOS sospende comunque. Serve quando lasci girare un lavoro
lungo — un agente, un build, un rendering, un download — e vuoi chiudere il portatile
e portartelo via senza che il job muoia.

**La soluzione.** `pmset -a disablesleep 1`, che è la via nativa, più un
`caffeinate -dimsu` di rinforzo. Nessun SIP disattivato, nessuna app di terze parti.
Un tasto lo accende, lo stesso tasto lo spegne, e una notifica di sistema dice sempre
in che stato sei: ⚡️ ON con suono *Hero*, ☕️ OFF con suono *Bottle*.

### La regola sudo — leggi prima di incollare

`pmset -a disablesleep` vuole root. Per non digitare la password a ogni pressione del
tasto si autorizzano **esattamente due invocazioni**, con gli argomenti già scritti dentro:

```
tuoutente ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
```

```bash
sudo visudo -f /etc/sudoers.d/keepawake     # ← sempre visudo: valida prima di salvare
sudo chmod 440 /etc/sudoers.d/keepawake
```

**Perché è scritta così.** Autorizzare `pmset` in generale (`NOPASSWD: /usr/bin/pmset`)
sembra equivalente e non lo è: `pmset` sa spegnere, riavviare e programmare accensioni,
quindi diventerebbe una scorciatoia per fare quelle cose senza password. Le due righe qui
sopra sono vincolate agli argomenti esatti e non fanno nient'altro.

Resta comunque una riga di sudo senza password sulla tua macchina. Se non ti va bene,
togli il file: `sudo rm /etc/sudoers.d/keepawake`. Lo script continuerà a funzionare,
chiedendoti la password nel terminale.

### Il tasto

Con [Karabiner-Elements](https://karabiner-elements.pqrs.org/), `install.sh` aggiunge la
regola al profilo attivo — e Karabiner ricarica da solo appena il file viene salvato.
A mano: incolla `f6-toggle/karabiner-f6.json` dentro
`~/.config/karabiner/karabiner.json` → `profiles[].complex_modifications.rules`,
sostituendo `/Users/TUO_UTENTE/` con il tuo percorso.

**`hidutil` non basta per rimappare la riga funzione.** Il driver Apple traduce i tasti
in comandi media *prima* che `hidutil` li veda, quindi non c'è nessun keycode da
intercettare. Karabiner si inserisce più a monte e funziona. Per lo stesso motivo, se
scegli un tasto che ha già una funzione media (F3 = Mission Control, F4 = Spotlight),
scrivi **più `from` alternativi** nella regola: non è prevedibile in che forma il tasto
si presenti. `Karabiner-EventViewer.app` ti dice il nome vero.
F6 nella configurazione di default non ha funzione media, quindi qui basta `key_code: f6`.

**`disablesleep` è globale e non ha timeout.** Se resti in ON, il Mac non dorme mai —
anche chiuso nello zaino, anche a batteria, finché non si scarica. Non è un bug: è
esattamente ciò che hai chiesto. La notifica ⚡️/☕️ esiste per questo. Spegnilo a fine job.

**Senza Karabiner** lo script funziona lo stesso — `~/.local/bin/keepawake-toggle` —
e lo puoi legare a un Comando Rapido, a un tasto del mouse o a un alias di shell.

**File:** `f6-toggle/keepawake-toggle` → `~/.local/bin/`,
`f6-toggle/karabiner-f6.json` → regola Karabiner,
`f6-toggle/sudoers-keepawake` → `/etc/sudoers.d/keepawake`.

---

## Come convivono i due metodi

Non si pestano i piedi, e non è un caso: i due `caffeinate` hanno righe di comando
diverse (`-ims` il metodo 1, `-dimsu` il metodo 2), e il `pkill` del toggle F6 cerca
**esattamente** `caffeinate -dimsu`. Quindi premere F6 non uccide il caffeinate di una
sessione Claude Code che sta lavorando, e chiudere una sessione non spegne il KeepAwake
che hai acceso col tasto.

Se cambi i flag di uno dei due, ricontrolla quel `pkill`: è lì che i due metodi si
toccano.

Nell'uso reale si sommano: il metodo 1 copre il caso normale senza che tu debba
ricordartene, il metodo 2 lo accendi tu nei dieci minuti in cui stai per chiudere il
coperchio e andartene.

```bash
./stato.sh
#   metodo 1  ATTIVO   — 2 sessione/i Claude Code tengono sveglio il Mac
#   metodo 2  ☕️ OFF   — sonno normale: chiudendo il coperchio il Mac si addormenta
```

A mano, se vuoi guardare direttamente il sistema:

```bash
pmset -g | grep SleepDisabled     # metodo 2: 1 = attivo, 0 = spento
pmset -g assertions | grep -i prevent   # chi sta impedendo il sonno, in questo momento
~/.claude/keep-awake.sh status    # metodo 1: sessioni che stanno trattenendo il sonno
tail ~/.claude/keep-awake/log.txt # gli hook stanno scattando?
```

---

## Disinstallazione

```bash
sudo rm /etc/sudoers.d/keepawake                 # la riga sudo senza password
pmset -g | grep SleepDisabled                    # se e' 1: sudo pmset -a disablesleep 0
rm ~/.local/bin/keepawake-toggle
rm -rf ~/.claude/keep-awake ~/.claude/keep-awake.sh
```

Restano da togliere a mano le due voci nei JSON: la regola F6 in `karabiner.json` e i
quattro hook `keep-awake.sh` in `~/.claude/settings.json`. I backup `.bak-keepawake-*`
che l'installer ha lasciato accanto ai due file contengono la versione precedente.

---

## Cosa NON fanno

Non tengono lo **schermo** acceso, e non impediscono il blocco schermo o il salvaschermo
mentre lavori: quelli sono altri settaggi: qui si tocca solo il sonno del sistema.
Il metodo 2, impedendo il sonno, di fatto impedisce anche il blocco che ne consegue a
coperchio chiuso — ma è una conseguenza, non l'obiettivo.

E nessuno dei due ha a che vedere con il fatto che tu possa continuare a usare il Mac
mentre un agente ci lavora sopra: quella è una proprietà di *come* l'agente lavora
(via shell e API, non prendendo il controllo di mouse e tastiera), non di questi script.

## Licenza

MIT.
