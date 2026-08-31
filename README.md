# KeepAwake su un tasto — Mac che non si addormenta col coperchio chiuso, a batteria

Un tasto della riga funzione (qui **F6**) accende e spegne la modalità
«il Mac resta sveglio anche con il coperchio chiuso e senza alimentazione»,
con una notifica di sistema che dice in che stato sei.

Serve quando lasci girare un lavoro lungo — un agente, un build, un rendering, un
download — e vuoi chiudere il portatile e portartelo via senza che il job muoia.

> **Su Apple Silicon `caffeinate` da solo non basta.** A batteria e con il coperchio
> chiuso macOS sospende comunque. La via nativa è `pmset -a disablesleep 1`, che però
> vuole i privilegi di root: da qui tutta la struttura qui sotto.
> Nessun SIP disattivato, nessuna app di terze parti tipo Amphetamine.

---

## Come è fatto

Tre pezzi:

| Pezzo | Cosa fa |
|---|---|
| `keepawake-toggle` | Lo script: legge lo stato, lo inverte, notifica |
| `karabiner/f6-keepawake.json` | La regola che lega il tasto F6 allo script |
| `sudoers.d/keepawake` | Permette **quei due soli comandi** senza password |

### 1. Lo script

```bash
install -d ~/.local/bin
install -m 755 keepawake-toggle ~/.local/bin/keepawake-toggle
```

Legge `pmset -g | SleepDisabled`, inverte con `pmset -a disablesleep 1|0`, e tiene un
`caffeinate -dimsu` in background finché la modalità è attiva. La notifica arriva con
`osascript`: ⚡️ ON con suono *Hero*, ☕️ OFF con suono *Bottle*.

### 2. La regola sudo — leggi prima di incollare

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

### 3. Il tasto

Con [Karabiner-Elements](https://karabiner-elements.pqrs.org/), incolla il contenuto di
`karabiner/f6-keepawake.json` dentro
`~/.config/karabiner/karabiner.json` → `profiles[0].complex_modifications.rules`,
**sostituendo `/Users/TUO_UTENTE/`** con il tuo percorso.
Karabiner ricarica da solo appena salvi.

Verifica che il tasto sia arrivato allo script:

```bash
pmset -g | grep SleepDisabled     # 1 = modalità attiva, 0 = spenta
```

---

## Le due cose che fanno perdere tempo

**`hidutil` non basta per rimappare la riga funzione.** Il driver Apple traduce i tasti
in comandi media *prima* che `hidutil` li veda, quindi non c'è nessun keycode da
intercettare. Karabiner si inserisce più a monte e funziona. Per lo stesso motivo, se
rimappi un tasto che ha già una funzione media (F3 = Mission Control, F4 = Spotlight),
scrivi **più `from` alternativi** nella regola: non è prevedibile in che forma il tasto
si presenti. `Karabiner-EventViewer.app` ti dice il nome vero.
F6 nella configurazione di default non ha funzione media, quindi qui basta `key_code: f6`.

**`disablesleep` è globale e non ha timeout.** Se resti in ON, il Mac non dorme mai —
anche chiuso nello zaino, anche a batteria, finché non si scarica. Non è un bug: è
esattamente ciò che hai chiesto. La notifica ⚡️/☕️ esiste per questo, per non doverti
ricordare in che stato sei. Spegnilo a fine job.

---

## Senza tasto, da riga di comando

Se non vuoi installare Karabiner, lo script funziona lo stesso:

```bash
~/.local/bin/keepawake-toggle
```

Lo puoi anche legare a un Comando Rapido, a un tasto del mouse, o a un alias di shell.

---

## Cosa NON fa

Non tiene lo schermo acceso e non impedisce il blocco schermo o il salvaschermo: quelli
sono altri due settaggi, e questo tocca solo il sonno del sistema. E soprattutto non ha
niente a che vedere con il fatto che tu possa continuare a usare il Mac mentre un agente
ci lavora sopra: quella è una proprietà di *come* l'agente lavora (via shell e API, non
prendendo il controllo di mouse e tastiera), non di questo script.

## Licenza

MIT.
