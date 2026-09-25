# Cron e variabili d’ambiente su Unix/Linux

I job eseguiti da `cron` non caricano automaticamente i file di inizializzazione della shell, come:

```text
~/.bashrc
~/.zshrc
~/.profile
```text

Di conseguenza, un file personale come:

```text
~/.config/shell/environment
```text

non viene letto automaticamente da Cron.

---

## Ambiente disponibile in Cron

Cron esegue i job con un ambiente ridotto. In genere sono disponibili soltanto variabili essenziali:

```text
HOME=/home/nomeutente
LOGNAME=nomeutente
SHELL=/bin/sh
PATH=/usr/bin:/bin
```text

Il `PATH` può variare in base alla distribuzione e alla configurazione del sistema.

Per questo uno script che funziona nel terminale potrebbe non funzionare in Cron: potrebbero mancare variabili come `JAVA_HOME`, `GOPATH`, `PROJECTS_DIR` o directory personalizzate nel `PATH`.

---

## Soluzione consigliata: usare uno script wrapper

La soluzione più affidabile consiste nel creare uno script che:

1. carica esplicitamente il file environment;
2. esegue il comando desiderato;
3. viene richiamato da Cron.

Struttura consigliata:

```text
~/.config/shell/environment
~/.config/shell/secrets
~/.local/bin/mio-script.sh
```text

---

## File environment

File:

```text
~/.config/shell/environment
```text

Esempio:

```sh
# Variabili comuni personali.

export PROJECTS_DIR="$HOME/Progetti"
export BACKUP_DIR="/mnt/backup"

# PATH esplicito e affidabile anche in ambiente Cron.
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

export EDITOR="vim"
```text

È consigliato rendere il file leggibile soltanto dall’utente:

```sh
chmod 600 ~/.config/shell/environment
```text

---

## Script eseguito da Cron

File:

```text
~/.local/bin/backup-progetti
```text

Contenuto:

```sh
#!/bin/sh

# Interrompe lo script in caso di errore o uso di variabili non definite.
set -eu

# Carica le variabili personali.
. "$HOME/.config/shell/environment"

# Crea la directory per i log, se necessario.
mkdir -p "$HOME/.local/state"

# Esegue il backup.
rsync -a --delete \
    "$PROJECTS_DIR/" \
    "$BACKUP_DIR/Progetti/"
```text

Rendi eseguibile lo script:

```sh
chmod +x ~/.local/bin/backup-progetti
```text

---

## Configurare il crontab

Apri il crontab dell’utente corrente:

```sh
crontab -e
```text

Aggiungi, per esempio, un’esecuzione giornaliera alle 02:30:

```cron
30 2 * * * /home/mario/.local/bin/backup-progetti >> /home/mario/.local/state/backup-progetti.log 2>&1
```text

Sostituisci `/home/mario` con il percorso reale della tua home.

La riga Cron esegue lo script e salva sia l’output normale sia gli errori nel file:

```text
/home/mario/.local/state/backup-progetti.log
```text

---

## Caricare l’environment direttamente dal crontab

È possibile caricare il file direttamente nella riga del crontab:

```cron
0 8 * * 1-5 . /home/mario/.config/shell/environment && /home/mario/.local/bin/mio-script.sh >> /home/mario/.local/state/mio-script.log 2>&1
```text

Questa soluzione è valida per comandi brevi, ma è meno leggibile e meno semplice da mantenere.

Per task complessi è preferibile usare sempre uno script wrapper.

---

## Impostare variabili direttamente nel crontab

Puoi definire variabili direttamente nel crontab:

```cron
SHELL=/bin/sh
PATH=/home/mario/.local/bin:/home/mario/bin:/usr/local/bin:/usr/bin:/bin
PROJECTS_DIR=/home/mario/Progetti

0 8 * * 1-5 /home/mario/.local/bin/mio-script.sh
```text

Usa percorsi assoluti.

Evita configurazioni che dipendono dall’espansione di variabili shell, ad esempio:

```cron
PATH=$HOME/.local/bin:$PATH
```text

Meglio dichiarare il valore completo:

```cron
PATH=/home/mario/.local/bin:/usr/local/bin:/usr/bin:/bin
```text

---

## Bash, Zsh e shell predefinita di Cron

Cron usa spesso `/bin/sh`, che non sempre corrisponde a Bash.

Se il tuo script utilizza sintassi specifica di Bash, dichiaralo esplicitamente:

```sh
#!/bin/bash
```text

Oppure imposta la shell nel crontab:

```cron
SHELL=/bin/bash
```text

Per una maggiore compatibilità è preferibile scrivere script POSIX:

```sh
#!/bin/sh
```text

e usare il comando POSIX:

```sh
. "$HOME/.config/shell/environment"
```text

invece di:

```sh
source "$HOME/.config/shell/environment"
```text

`source` è supportato da Bash e Zsh, mentre `.` è compatibile con le shell POSIX.

---

## Attenzione a HOME e ai percorsi

In un crontab utente, creato con:

```sh
crontab -e
```text

la variabile `HOME` corrisponde normalmente alla home dell’utente.

In un crontab di sistema, come `/etc/crontab`, devi specificare anche l’utente:

```cron
0 8 * * * mario /home/mario/.local/bin/mio-script.sh
```text

In questo caso è preferibile usare percorsi assoluti nello script:

```sh
. /home/mario/.config/shell/environment
```text

Questo evita problemi se il job viene eseguito da `root` o da un altro utente.

---

## Test dello script

Prima di affidare il task a Cron, esegui lo script manualmente:

```sh
/home/mario/.local/bin/backup-progetti
```text

Per simulare un ambiente minimale simile a Cron:

```sh
env -i \
    HOME="/home/mario" \
    USER="mario" \
    LOGNAME="mario" \
    PATH="/usr/bin:/bin" \
    SHELL="/bin/sh" \
    /bin/sh /home/mario/.local/bin/backup-progetti
```text

Se lo script funziona anche in questa condizione, dovrebbe funzionare correttamente in Cron.

---

## Debug dell’ambiente Cron

Per vedere quali variabili sono disponibili in Cron, aggiungi temporaneamente questa riga al crontab:

```cron
* * * * * env > /tmp/crontab-environment.txt
```text

Dopo circa un minuto, controlla il risultato:

```sh
cat /tmp/crontab-environment.txt
```text

Ricordati di eliminare la riga dal crontab dopo il test.

---

## Logging

Per salvare output ed errori in un file di log:

```cron
0 8 * * * /home/mario/.local/bin/mio-script.sh >> /home/mario/.local/state/mio-script.log 2>&1
```text

Significato:

- `>> file.log`: aggiunge l’output standard al file di log;
- `2>&1`: aggiunge anche gli errori al medesimo file.

Per visualizzare il log in tempo reale:

```sh
tail -f ~/.local/state/mio-script.log
```text

---

## Email per gli errori

Se il sistema è configurato per inviare posta locale, puoi impostare una destinazione email nel crontab:

```cron
MAILTO="tuoindirizzo@example.com"
```text

Cron invierà l’output del job via email se il job produce output e non viene reindirizzato verso un file di log.

---

## Attenzione al carattere percentuale

Nel crontab, il carattere `%` ha un significato speciale: viene interpretato come separatore dell’input standard.

Questo comando può quindi non comportarsi come previsto:

```cron
0 8 * * * date +"%Y-%m-%d"
```text

Devi fare l’escape del carattere `%`:

```cron
0 8 * * * date +"\%Y-\%m-\%d"
```text

In alternativa, inserisci il comando in uno script shell, dove `%` non richiede l’escape.

---

## Gestione dei segreti

Evita di inserire password, token API o chiavi private direttamente nel crontab.

Puoi creare un file separato:

```text
~/.config/shell/secrets
```text

Con permessi restrittivi:

```sh
chmod 600 ~/.config/shell/secrets
```text

Esempio:

```sh
export PRIVATE_API_TOKEN="valore-riservato"
```text

Nel file `environment`, caricalo solo se leggibile:

```sh
if [ -r "$HOME/.config/shell/secrets" ]; then
    . "$HOME/.config/shell/secrets"
fi
```text

Non aggiungere il file dei segreti a repository Git o servizi cloud non protetti.

---

## Riepilogo

Cron non carica automaticamente:

```text
~/.bashrc
~/.zshrc
~/.profile
~/.config/shell/environment
```text

La soluzione più pulita è:

1. creare un file centralizzato con le variabili;
2. creare uno script che lo carichi esplicitamente;
3. pianificare lo script con una riga semplice nel crontab.

Esempio finale:

```cron
30 2 * * * /home/mario/.local/bin/backup-progetti >> /home/mario/.local/state/backup-progetti.log 2>&1
```text

Lo script `backup-progetti` caricherà:

```sh
. "$HOME/.config/shell/environment"
```text

In questo modo l’esecuzione da Cron è prevedibile, verificabile e indipendente dalle configurazioni della shell interattiva.
