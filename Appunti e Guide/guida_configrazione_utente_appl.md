# Configurare correttamente un utente applicativo su Unix/Linux

Questa guida descrive come creare e organizzare un **utente applicativo** su Unix/Linux.

Un utente applicativo è un account dedicato all’esecuzione di un servizio, di un demone, di un’applicazione web, di un processo schedulato o di un insieme di script. Non dovrebbe essere usato come utente personale per accedere al sistema e lavorare da terminale.

Esempi di utenti applicativi:

```text
nginx
postgres
www-data
tomcat
myapp
backup
etl
```text

---

## Obiettivi

Un utente applicativo ben configurato deve:

- eseguire solamente l’applicazione assegnata;
- avere i minimi privilegi necessari;
- non avere password interattiva;
- non consentire normalmente login SSH;
- possedere soltanto le directory e i file che deve modificare;
- mantenere separati configurazione, dati, log, file temporanei e codice;
- essere facilmente gestibile tramite `systemd`.

---

## Differenza fra utente personale e utente applicativo

| Aspetto | Utente personale | Utente applicativo |
|---|---|---|
| Uso | Accesso umano al sistema | Esecuzione di processi o servizi |
| Login SSH | Normalmente consentito | Normalmente disabilitato |
| Password | Può essere presente | Generalmente bloccata |
| Shell | Bash, Zsh o simili | `/usr/sbin/nologin` o `/bin/false` |
| File `.bashrc`, `.profile` | Utili | In genere inutili |
| Home directory | `/home/nomeutente` | Spesso `/var/lib/nomeapp` |
| Privilegi sudo | Eventualmente presenti | Da evitare |

---

# 1. Creare l’utente applicativo

Supponiamo di voler creare un utente chiamato:

```text
myapp
```text

## Debian e Ubuntu

```sh
sudo adduser \
    --system \
    --group \
    --home /var/lib/myapp \
    --shell /usr/sbin/nologin \
    myapp
```text

## RHEL, Rocky Linux, AlmaLinux, Fedora

```sh
sudo useradd \
    --system \
    --create-home \
    --home-dir /var/lib/myapp \
    --shell /sbin/nologin \
    myapp
```text

Verifica l’utente:

```sh
id myapp
```text

Esempio di output:

```text
uid=995(myapp) gid=995(myapp) groups=995(myapp)
```text

Verifica shell e home directory:

```sh
getent passwd myapp
```text

Esempio:

```text
myapp:x:995:995::/var/lib/myapp:/usr/sbin/nologin
```text

---

## Perché usare una shell `nologin`

Un utente applicativo non dovrebbe normalmente ricevere un terminale interattivo.

Le shell più comuni per bloccare il login sono:

```text
/usr/sbin/nologin
/sbin/nologin
/bin/false
```text

La scelta dipende dalla distribuzione.

Puoi trovare il percorso disponibile con:

```sh
command -v nologin
```text

Una shell `nologin` riduce il rischio di utilizzo improprio dell’account per login locali, SSH o sessioni interattive.

---

# 2. Struttura consigliata delle directory

Per un’applicazione chiamata `myapp`, una struttura ordinata può essere:

```text
/etc/myapp/                 Configurazione dell'applicazione
/opt/myapp/                 Codice applicativo e binari distribuiti dal team
/var/lib/myapp/             Dati persistenti generati o gestiti dall'applicazione
/var/log/myapp/             File di log
/var/cache/myapp/           Cache rigenerabile
/run/myapp/                 PID file, socket Unix e dati runtime temporanei
/tmp/                       File temporanei generici, se inevitabile
```text

## Significato delle directory

| Directory | Scopo | Proprietario consigliato |
|---|---|---|
| `/etc/myapp` | Configurazione | `root:myapp` oppure `root:root` |
| `/opt/myapp` | Codice e binari dell’applicazione | `root:root` |
| `/var/lib/myapp` | Dati persistenti | `myapp:myapp` |
| `/var/log/myapp` | Log | `myapp:myapp` oppure gestione tramite journald |
| `/var/cache/myapp` | Cache rigenerabile | `myapp:myapp` |
| `/run/myapp` | Dati runtime temporanei | Creati da `systemd` |

Questa separazione è importante:

- il codice non deve normalmente essere modificabile dall’utente applicativo;
- la configurazione non deve normalmente essere modificabile dall’utente applicativo;
- dati e log devono essere scrivibili soltanto dove necessario;
- i file runtime non devono essere persistenti dopo il riavvio.

---

# 3. Creare le directory e impostare proprietari e permessi

Crea le directory:

```sh
sudo install -d -m 0750 -o root -g myapp /etc/myapp
sudo install -d -m 0755 -o root -g root /opt/myapp
sudo install -d -m 0750 -o myapp -g myapp /var/lib/myapp
sudo install -d -m 0750 -o myapp -g myapp /var/log/myapp
sudo install -d -m 0750 -o myapp -g myapp /var/cache/myapp
```text

Controlla il risultato:

```sh
ls -ld \
    /etc/myapp \
    /opt/myapp \
    /var/lib/myapp \
    /var/log/myapp \
    /var/cache/myapp
```text

Esempio di risultato atteso:

```text
drwxr-x--- root  myapp /etc/myapp
drwxr-xr-x root  root  /opt/myapp
drwxr-x--- myapp myapp /var/lib/myapp
drwxr-x--- myapp myapp /var/log/myapp
drwxr-x--- myapp myapp /var/cache/myapp
```text

---

# 4. Dove inserire il codice dell’applicazione

Per applicazioni distribuite internamente o installate manualmente, una posizione comune è:

```text
/opt/myapp/
```text

Esempio:

```text
/opt/myapp/
+-- bin/
¦   +-- myapp
+-- lib/
+-- migrations/
+-- scripts/
+-- requirements/
+-- VERSION
```text

I file applicativi dovrebbero essere di proprietà di `root`:

```sh
sudo chown -R root:root /opt/myapp
```text

Permessi tipici:

```sh
sudo find /opt/myapp -type d -exec chmod 0755 {} \;
sudo find /opt/myapp -type f -exec chmod 0644 {} \;
sudo chmod 0755 /opt/myapp/bin/myapp
```text

L’utente `myapp` deve poter **leggere ed eseguire** il software, ma non modificarlo.

Questo evita che un errore applicativo o una compromissione del processo possa alterare il codice installato.

---

# 5. Configurazione dell’applicazione

La configurazione dovrebbe stare in:

```text
/etc/myapp/
```text

Esempio:

```text
/etc/myapp/
+-- myapp.conf
+-- environment
+-- secrets
```text

## File principale di configurazione

File:

```text
/etc/myapp/myapp.conf
```text

Esempio:

```ini
[app]
environment=production
listen_address=127.0.0.1
listen_port=8080
data_directory=/var/lib/myapp
log_directory=/var/log/myapp
```text

Permessi suggeriti:

```sh
sudo chown root:myapp /etc/myapp/myapp.conf
sudo chmod 0640 /etc/myapp/myapp.conf
```text

Così:

- `root` può modificare il file;
- il gruppo `myapp` può leggerlo;
- altri utenti non possono leggerlo.

---

# 6. Variabili d’ambiente dell’applicazione

Le variabili dell’applicazione non dovrebbero stare in:

```text
~/.bashrc
~/.zshrc
~/.profile
```text

Un utente applicativo non esegue normalmente login interattivi, quindi quei file non vengono usati.

È preferibile usare un file dedicato, ad esempio:

```text
/etc/myapp/environment
```text

Esempio:

```sh
# /etc/myapp/environment

APP_ENV=production
APP_DATA_DIR=/var/lib/myapp
APP_CACHE_DIR=/var/cache/myapp
APP_LOG_DIR=/var/log/myapp
APP_CONFIG_FILE=/etc/myapp/myapp.conf

LANG=it_IT.UTF-8
TZ=Europe/Rome
```text

Imposta proprietari e permessi:

```sh
sudo chown root:myapp /etc/myapp/environment
sudo chmod 0640 /etc/myapp/environment
```text

> Il file `environment` destinato a `systemd` dovrebbe contenere righe semplici nel formato `CHIAVE=valore`.  
> Evita comandi shell, `export`, `source`, funzioni, `$(...)` o riferimenti a `$HOME`.

Corretto:

```text
APP_ENV=production
APP_PORT=8080
```text

Da evitare:

```sh
export APP_ENV=production
APP_HOME=$HOME/myapp
APP_DATE=$(date)
```text

---

# 7. Gestione dei segreti

Password, token e chiavi non dovrebbero essere inseriti nel codice né nei file generici di configurazione.

Puoi usare un file separato:

```text
/etc/myapp/secrets
```text

Esempio:

```text
DATABASE_PASSWORD=valore-riservato
API_TOKEN=valore-riservato
```text

Proteggilo:

```sh
sudo chown root:myapp /etc/myapp/secrets
sudo chmod 0640 /etc/myapp/secrets
```text

Non salvare il file in Git.

Per ambienti più strutturati, considera strumenti dedicati:

- HashiCorp Vault;
- AWS Secrets Manager;
- Azure Key Vault;
- Google Secret Manager;
- Kubernetes Secrets;
- Ansible Vault;
- systemd credentials.

---

# 8. File eseguiti al login

## Caso normale: utente applicativo senza login

Se l’utente ha una shell come:

```text
/usr/sbin/nologin
```text

non effettua login interattivi.

In questo scenario non è necessario creare:

```text
/var/lib/myapp/.bashrc
/var/lib/myapp/.profile
/var/lib/myapp/.zshrc
```text

La configurazione deve essere gestita da:

```text
/etc/myapp/
```text

e dal file di servizio `systemd`.

## Caso eccezionale: accesso operativo temporaneo

Per eseguire un comando come utente applicativo, senza consentire login diretto, usa:

```sh
sudo -u myapp -- /opt/myapp/bin/myapp --help
```text

Per aprire temporaneamente una shell di debug:

```sh
sudo -u myapp -H /bin/sh
```text

Oppure, se Bash è disponibile:

```sh
sudo -u myapp -H /bin/bash
```text

Questo metodo è preferibile rispetto a dare password o accesso SSH diretto all’utente applicativo.

---

# 9. Configurazione del servizio con systemd

Il metodo standard per avviare un’applicazione su molte distribuzioni Linux moderne è `systemd`.

Crea il file:

```text
/etc/systemd/system/myapp.service
```text

Esempio:

```ini
[Unit]
Description=Servizio MyApp
After=network.target

[Service]
Type=simple

User=myapp
Group=myapp

WorkingDirectory=/var/lib/myapp

EnvironmentFile=/etc/myapp/environment
EnvironmentFile=-/etc/myapp/secrets

ExecStart=/opt/myapp/bin/myapp --config /etc/myapp/myapp.conf

Restart=on-failure
RestartSec=5

# systemd crea /run/myapp con proprietario myapp:myapp.
RuntimeDirectory=myapp
RuntimeDirectoryMode=0750

# systemd può creare e gestire queste directory.
StateDirectory=myapp
StateDirectoryMode=0750

CacheDirectory=myapp
CacheDirectoryMode=0750

LogsDirectory=myapp
LogsDirectoryMode=0750

# Protezioni consigliate.
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true

ReadWritePaths=/var/lib/myapp /var/log/myapp /var/cache/myapp /run/myapp

[Install]
WantedBy=multi-user.target
```text

Ricarica la configurazione di systemd:

```sh
sudo systemctl daemon-reload
```text

Abilita l’avvio automatico:

```sh
sudo systemctl enable myapp.service
```text

Avvia il servizio:

```sh
sudo systemctl start myapp.service
```text

Controlla lo stato:

```sh
sudo systemctl status myapp.service
```text

Visualizza i log:

```sh
sudo journalctl -u myapp.service -f
```text

---

# 10. Note sulle direttive di protezione systemd

Queste direttive migliorano la sicurezza del servizio:

```ini
NoNewPrivileges=true
```text

Impedisce al processo di acquisire privilegi aggiuntivi.

```ini
PrivateTmp=true
```text

Assegna un’area temporanea isolata al servizio.

```ini
ProtectSystem=strict
```text

Rende la maggior parte del filesystem in sola lettura per il processo.

```ini
ProtectHome=true
```text

Impedisce al servizio di accedere alle home degli utenti.

```ini
ReadWritePaths=/var/lib/myapp /var/log/myapp /var/cache/myapp /run/myapp
```text

Specifica le directory nelle quali il servizio può scrivere.

Queste opzioni potrebbero richiedere adattamenti se l’applicazione deve scrivere in ulteriori posizioni.

---

# 11. Esecuzione di task schedulati

Per task periodici, è preferibile usare un timer `systemd` anziché Cron, quando possibile.

Crea il servizio:

```text
/etc/systemd/system/myapp-backup.service
```text

```ini
[Unit]
Description=Backup MyApp

[Service]
Type=oneshot
User=myapp
Group=myapp

EnvironmentFile=/etc/myapp/environment
EnvironmentFile=-/etc/myapp/secrets

ExecStart=/opt/myapp/bin/backup
```text

Crea il timer:

```text
/etc/systemd/system/myapp-backup.timer
```text

```ini
[Unit]
Description=Esecuzione giornaliera del backup MyApp

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
```text

Abilita il timer:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now myapp-backup.timer
```text

Verifica i timer:

```sh
systemctl list-timers --all | grep myapp
```text

---

# 12. Uso di Cron, se necessario

Se devi usare Cron, non aspettarti che legga automaticamente:

```text
~/.bashrc
~/.profile
~/.config/shell/environment
```text

Usa script con percorsi assoluti e carica esplicitamente la configurazione, se il file è in formato shell.

Esempio:

```sh
#!/bin/sh

set -eu

. /etc/myapp/runtime-shell.env

exec /opt/myapp/bin/backup
```text

Tuttavia, per applicazioni gestite da `systemd`, un timer `systemd` è spesso più pulito, più sicuro e più facile da monitorare.

---

# 13. Permessi: principio del minimo privilegio

L’utente applicativo deve poter scrivere soltanto dove necessario.

Esempio di permessi corretti:

```text
/opt/myapp               root:root    Lettura/esecuzione
/etc/myapp               root:myapp   Lettura configurazione
/var/lib/myapp           myapp:myapp  Scrittura dati
/var/log/myapp           myapp:myapp  Scrittura log
/var/cache/myapp         myapp:myapp  Scrittura cache
/run/myapp               myapp:myapp  Runtime temporaneo
```text

Evita:

```sh
chmod -R 777 /var/lib/myapp
```text

Evita anche di assegnare la proprietà dell’intero filesystem applicativo a `myapp`:

```sh
chown -R myapp:myapp /opt/myapp
```text

Questo consentirebbe al processo applicativo di modificare il proprio codice.

---

# 14. Checklist finale

## Utente

- [ ] Utente dedicato, ad esempio `myapp`
- [ ] Gruppo dedicato `myapp`
- [ ] Nessuna password interattiva
- [ ] Shell `nologin`
- [ ] Nessun accesso SSH diretto
- [ ] Nessun privilegio `sudo`, salvo esigenze documentate

## Directory

- [ ] Codice in `/opt/myapp`
- [ ] Configurazione in `/etc/myapp`
- [ ] Dati persistenti in `/var/lib/myapp`
- [ ] Log in `/var/log/myapp` oppure journald
- [ ] Cache in `/var/cache/myapp`
- [ ] File runtime in `/run/myapp`

## Sicurezza

- [ ] Codice applicativo non modificabile dall’utente applicativo
- [ ] Configurazione modificabile soltanto da `root`
- [ ] Segreti protetti con permessi restrittivi
- [ ] Nessun segreto nel repository Git
- [ ] Permessi minimi sulle directory
- [ ] Servizio avviato con utente non privilegiato

## Gestione

- [ ] Servizio definito in `systemd`
- [ ] Riavvio automatico in caso di errore
- [ ] Log consultabili con `journalctl`
- [ ] Task schedulati gestiti con timer `systemd`, se possibile

---

# Riepilogo

Un utente applicativo non va trattato come un utente personale.

Non dovrebbe avere login interattivo, `.bashrc`, `.zshrc` o `.profile` come meccanismo principale di configurazione.

La struttura consigliata è:

```text
/etc/myapp/                 Configurazione e segreti
/opt/myapp/                 Codice e binari, di proprietà root
/var/lib/myapp/             Dati persistenti, scrivibili da myapp
/var/log/myapp/             Log, se non si usa soltanto journald
/var/cache/myapp/           Cache
/run/myapp/                 PID, socket e file runtime
/etc/systemd/system/        Definizione del servizio systemd
```text

L’applicazione dovrebbe essere eseguita tramite `systemd`, con:

```ini
User=myapp
Group=myapp
EnvironmentFile=/etc/myapp/environment
```text

e con il minor numero possibile di permessi.
