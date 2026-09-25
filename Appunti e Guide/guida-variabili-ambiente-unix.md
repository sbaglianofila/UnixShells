# Guida alle variabili d’ambiente utente su Unix/Linux

Questa guida descrive come organizzare e usare le variabili d’ambiente personali su sistemi Unix/Linux tramite un file centralizzato, sicuro e riutilizzabile.

L’approccio è adatto a Bash, Zsh e shell compatibili POSIX.

---

## Indice

1. [Cosa sono le variabili d’ambiente](#cosa-sono-le-variabili-dambiente)
2. [Struttura consigliata](#struttura-consigliata)
3. [Creazione del file environment](#creazione-del-file-environment)
4. [Esempio completo di file environment](#esempio-completo-di-file-environment)
5. [Come caricare il file](#come-caricare-il-file)
6. [Dove configurare il caricamento automatico](#dove-configurare-il-caricamento-automatico)
7. [Differenza fra file shell e file-env](#differenza-fra-file-shell-e-file-env)
8. [Alias e funzioni](#alias-e-funzioni)
9. [Gestione sicura dei segreti](#gestione-sicura-dei-segreti)
10. [Applicazioni grafiche e servizi systemd](#applicazioni-grafiche-e-servizi-systemd)
11. [Verifica e risoluzione problemi](#verifica-e-risoluzione-problemi)
12. [Procedura rapida](#procedura-rapida)

---

## Cosa sono le variabili d’ambiente

Le variabili d’ambiente sono valori disponibili ai programmi lanciati da una shell o da una sessione utente.

Esempi comuni:

```sh
echo "$HOME"
echo "$PATH"
echo "$EDITOR"
echo "$LANG"
```text

Alcuni usi frequenti:

- definire dove cercare programmi con `PATH`;
- scegliere l’editor predefinito con `EDITOR`;
- impostare lingua e codifica con `LANG`;
- configurare strumenti di sviluppo come Python, Java, Go, Node.js o Docker;
- centralizzare percorsi personali e directory di lavoro.

Una variabile diventa disponibile ai processi figli quando viene esportata:

```sh
export EDITOR="vim"
```text

---

## Struttura consigliata

Si consiglia di salvare le variabili personali in un file centralizzato:

```text
~/.config/shell/environment
```text

Dove:

- `~` indica la home dell’utente, ad esempio `/home/mario`;
- `~/.config` è la directory standard per molte configurazioni utente;
- `shell/environment` contiene le variabili condivise.

La struttura risultante sarà:

```text
~/.config/shell/
+-- environment
```text

Questo evita di disperdere le variabili fra `~/.bashrc`, `~/.zshrc`, `~/.profile` e altri file.

---

## Creazione del file environment

Crea la directory e il file:

```sh
mkdir -p ~/.config/shell
touch ~/.config/shell/environment
```text

Imposta permessi restrittivi:

```sh
chmod 600 ~/.config/shell/environment
```text

Il permesso `600` significa che soltanto il proprietario del file può leggerlo e modificarlo.

Apri il file con il tuo editor:

```sh
nano ~/.config/shell/environment
```text

Oppure:

```sh
vim ~/.config/shell/environment
```text

---

## Esempio completo di file environment

Il seguente contenuto è compatibile con Bash, Zsh e shell POSIX.

```sh
# ~/.config/shell/environment
#
# Variabili d'ambiente personali.
# Questo file deve essere caricato con:
#
#   . ~/.config/shell/environment
#
# oppure:
#
#   source ~/.config/shell/environment

# -----------------------------------------------------------------------------
# Lingua, localizzazione e strumenti base
# -----------------------------------------------------------------------------

export LANG="it_IT.UTF-8"
export LC_ALL="it_IT.UTF-8"

export EDITOR="vim"
export VISUAL="vim"
export PAGER="less"
export LESS="-R -F -X"

# -----------------------------------------------------------------------------
# Directory personali
# -----------------------------------------------------------------------------

export PROJECTS_DIR="$HOME/Progetti"
export WORKSPACE_DIR="$HOME/Workspace"
export NOTES_DIR="$HOME/Documenti/note"

# -----------------------------------------------------------------------------
# Directory standard XDG
# -----------------------------------------------------------------------------
#
# Le variabili XDG permettono di mantenere ordinata la home dell'utente.
# La sintassi ${VARIABILE:-valore} usa il valore predefinito solo se la
# variabile non è già stata impostata.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# -----------------------------------------------------------------------------
# PATH
# -----------------------------------------------------------------------------
#
# Aggiunge directory personali al PATH senza duplicarle.

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$HOME/bin:$PATH" ;;
esac

# Esempio per strumenti installati manualmente:
#
# export PATH="$HOME/strumenti/bin:$PATH"

# -----------------------------------------------------------------------------
# Git
# -----------------------------------------------------------------------------

export GIT_EDITOR="$EDITOR"

# -----------------------------------------------------------------------------
# Python
# -----------------------------------------------------------------------------

export PYTHONUTF8="1"
export PYTHONDONTWRITEBYTECODE="1"

# pipx installa strumenti Python isolati.
export PIPX_HOME="$XDG_DATA_HOME/pipx"
export PIPX_BIN_DIR="$HOME/.local/bin"

# -----------------------------------------------------------------------------
# Node.js e npm
# -----------------------------------------------------------------------------

export NPM_CONFIG_PREFIX="$XDG_DATA_HOME/npm"
export NODE_REPL_HISTORY="$XDG_STATE_HOME/node_repl_history"

# -----------------------------------------------------------------------------
# Go
# -----------------------------------------------------------------------------

export GOPATH="$XDG_DATA_HOME/go"
export GOBIN="$HOME/.local/bin"

# -----------------------------------------------------------------------------
# Rust e Cargo
# -----------------------------------------------------------------------------

export CARGO_HOME="$XDG_DATA_HOME/cargo"

# Se necessario, abilita il PATH di Cargo:
#
# export PATH="$CARGO_HOME/bin:$PATH"

# -----------------------------------------------------------------------------
# Java
# -----------------------------------------------------------------------------
#
# Decommenta e adatta il percorso alla tua installazione.
#
# export JAVA_HOME="/usr/lib/jvm/java-21-openjdk"
# export PATH="$JAVA_HOME/bin:$PATH"

# -----------------------------------------------------------------------------
# Proxy aziendale o di rete
# -----------------------------------------------------------------------------
#
# Abilitare soltanto se necessario.
#
# export HTTP_PROXY="http://proxy.example.local:8080"
# export HTTPS_PROXY="http://proxy.example.local:8080"
# export NO_PROXY="localhost,127.0.0.1,::1,.example.local"

# -----------------------------------------------------------------------------
# File separato per segreti
# -----------------------------------------------------------------------------
#
# Non inserire password, token o chiavi private nel file principale,
# specialmente se viene salvato in Git o sincronizzato nel cloud.
#
# I segreti possono essere caricati da:
#
# ~/.config/shell/secrets
#
# Il file deve avere permessi 600.

if [ -r "$HOME/.config/shell/secrets" ]; then
    . "$HOME/.config/shell/secrets"
fi
```text

---

## Come caricare il file

### Caricamento manuale

Per applicare subito le variabili nella shell corrente:

```sh
source ~/.config/shell/environment
```text

Oppure, in forma POSIX:

```sh
. ~/.config/shell/environment
```text

> Non usare `./environment` oppure `bash environment` se vuoi che le variabili restino attive nella shell attuale.  
> Questi comandi eseguono il file in un processo separato e le variabili non vengono mantenute al termine dell’esecuzione.

### Verificare una variabile

Dopo il caricamento:

```sh
echo "$EDITOR"
echo "$PROJECTS_DIR"
echo "$XDG_CONFIG_HOME"
echo "$PATH"
```text

Per vedere tutte le variabili esportate:

```sh
printenv
```text

Per cercare una variabile specifica:

```sh
printenv | grep '^XDG_'
```text

---

## Dove configurare il caricamento automatico

Il file `environment` deve essere caricato dai file di inizializzazione della shell.

La scelta dipende dalla shell usata e dal tipo di sessione.

| File | Quando viene letto |
|---|---|
| `~/.profile` | Login, SSH e spesso sessioni grafiche |
| `~/.bashrc` | Ogni nuova shell interattiva Bash |
| `~/.zshrc` | Ogni nuova shell interattiva Zsh |
| `~/.config/shell/environment` | File centralizzato delle variabili |

### Bash

Aggiungi questo blocco a `~/.bashrc`:

```sh
if [ -f "$HOME/.config/shell/environment" ]; then
    . "$HOME/.config/shell/environment"
fi
```text

Ricarica il file:

```sh
source ~/.bashrc
```text

### Zsh

Aggiungi questo blocco a `~/.zshrc`:

```sh
if [ -f "$HOME/.config/shell/environment" ]; then
    . "$HOME/.config/shell/environment"
fi
```text

Ricarica il file:

```sh
source ~/.zshrc
```text

### Sessioni di login e SSH

Aggiungi questo blocco anche a `~/.profile`:

```sh
if [ -f "$HOME/.config/shell/environment" ]; then
    . "$HOME/.config/shell/environment"
fi
```text

In questo modo le variabili saranno normalmente disponibili anche dopo il login via SSH o una sessione di login tradizionale.

---

## Differenza fra file shell e file `.env`

Il termine `.env` può indicare formati diversi.

### File shell per la sessione utente

Un file shell può contenere comandi, variabili, commenti, controlli condizionali e riferimenti a `$HOME` o `$PATH`.

Esempio:

```sh
export EDITOR="vim"
export PATH="$HOME/.local/bin:$PATH"
```text

Viene caricato con:

```sh
source ~/.config/shell/environment
```text

Questo formato è consigliato per il profilo personale dell’utente.

### File `.env` di un progetto

Molti framework e strumenti leggono file `.env` con sintassi semplice:

```dotenv
APP_ENV=development
APP_PORT=8080
DATABASE_HOST=localhost
```text

Questi file sono generalmente legati a un solo progetto e spesso non richiedono la parola `export`.

Esempio di struttura:

```text
~/Progetti/mia-app/
+-- .env
+-- .gitignore
+-- package.json
+-- src/
```text

Non è consigliato caricare automaticamente tutti i `.env` dei progetti nell’ambiente utente globale.

---

## Alias e funzioni

Alias e funzioni non sono variabili d’ambiente. Vanno normalmente inseriti nel file della shell:

- `~/.bashrc` per Bash;
- `~/.zshrc` per Zsh.

Esempio:

```sh
alias ll='ls -lah'
alias gs='git status'
alias cproj='cd "$HOME/Progetti"'

mkcd() {
    mkdir -p "$1" && cd "$1"
}
```text

Evita di mettere alias e funzioni nel file `environment` se il file viene caricato anche da script non interattivi.

---

## Gestione sicura dei segreti

Non salvare nel file `environment`:

- password;
- token API;
- token GitHub, GitLab o registry;
- chiavi private;
- credenziali cloud;
- dati di accesso a database.

Se devi temporaneamente usare variabili con dati sensibili, crea un file separato:

```sh
touch ~/.config/shell/secrets
chmod 600 ~/.config/shell/secrets
```text

Esempio di contenuto:

```sh
# ~/.config/shell/secrets

export PRIVATE_REGISTRY_TOKEN="valore-riservato"
export INTERNAL_API_TOKEN="valore-riservato"
```text

Il file viene caricato dal file `environment` tramite:

```sh
if [ -r "$HOME/.config/shell/secrets" ]; then
    . "$HOME/.config/shell/secrets"
fi
```text

Se usi Git per versionare i dotfiles, escludi il file:

```gitignore
.config/shell/secrets
```text

Per una gestione più sicura dei segreti, valuta strumenti come:

- password manager;
- `pass`;
- `gopass`;
- GNOME Keyring;
- KDE Wallet;
- 1Password;
- Bitwarden;
- secret manager del cloud provider.

---

## Applicazioni grafiche e servizi systemd

Le applicazioni lanciate dal desktop grafico potrebbero non leggere `~/.bashrc` o `~/.zshrc`.

Per le variabili necessarie anche in applicazioni grafiche, utilizza preferibilmente `~/.profile`, quando supportato dalla distribuzione e dal display manager.

Per rendere alcune variabili disponibili ai servizi utente `systemd`, puoi eseguire:

```sh
systemctl --user import-environment PATH EDITOR XDG_CONFIG_HOME XDG_DATA_HOME
```text

Per verificare le variabili disponibili a `systemd --user`:

```sh
systemctl --user show-environment
```text

Questa operazione non è normalmente necessaria per il solo uso nel terminale.

---

## Verifica e risoluzione problemi

### Controllare la shell in uso

```sh
echo "$SHELL"
```text

Esempi di risultati:

```text
/bin/bash
```text

oppure:

```text
/usr/bin/zsh
```text

### Controllare se una variabile è impostata

```sh
echo "$EDITOR"
```text

Se non viene visualizzato nulla, la variabile non è stata caricata.

### Controllare il PATH

```sh
printf '%s\n' "$PATH" | tr ':' '\n'
```text

Questo mostra ogni directory del `PATH` su una riga distinta.

### Cercare duplicati nel PATH

```sh
printf '%s\n' "$PATH" | tr ':' '\n' | sort | uniq -d
```text

### Verificare la sintassi del file

Per Bash:

```sh
bash -n ~/.config/shell/environment
```text

Per Zsh:

```sh
zsh -n ~/.config/shell/environment
```text

Se il comando non produce output, la sintassi è normalmente valida.

### Applicare le modifiche

Dopo ogni modifica, carica nuovamente il file:

```sh
source ~/.config/shell/environment
```text

Oppure chiudi e riapri il terminale.

---

## Procedura rapida

### 1. Creare il file

```sh
mkdir -p ~/.config/shell
nano ~/.config/shell/environment
chmod 600 ~/.config/shell/environment
```text

### 2. Inserire una configurazione minima

```sh
export EDITOR="vim"
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export PROJECTS_DIR="$HOME/Progetti"
```text

### 3. Caricare automaticamente il file

Per Bash, aggiungi a `~/.bashrc`:

```sh
if [ -f "$HOME/.config/shell/environment" ]; then
    . "$HOME/.config/shell/environment"
fi
```text

Per Zsh, aggiungi lo stesso blocco a `~/.zshrc`.

### 4. Ricaricare la configurazione

Per Bash:

```sh
source ~/.bashrc
```text

Per Zsh:

```sh
source ~/.zshrc
```text

### 5. Verificare

```sh
echo "$EDITOR"
echo "$PROJECTS_DIR"
echo "$PATH"
```text

---

## Riepilogo

La soluzione consigliata è:

```text
~/.config/shell/environment
```text

con le variabili comuni, caricato da:

```text
~/.profile
~/.bashrc
```text

oppure:

```text
~/.profile
~/.zshrc
```text

Mantieni separati:

- **variabili comuni:** `~/.config/shell/environment`;
- **segreti:** `~/.config/shell/secrets`, con permessi `600`;
- **alias e funzioni:** `~/.bashrc` oppure `~/.zshrc`;
- **variabili di progetto:** file `.env` dentro il progetto.
