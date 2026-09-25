# Gestione sicura delle password di connessione ai database

Questa guida spiega come gestire password e credenziali di connessione a database in modo sicuro su Unix/Linux.

L’obiettivo è evitare che password di database finiscano in:

- codice sorgente;
- repository Git;
- file `.env` non protetti;
- parametri della riga di comando;
- log applicativi;
- cron tab;
- file di configurazione leggibili da utenti non autorizzati.

> Le variabili d’ambiente sono comode, ma non sono sempre il metodo più sicuro per gestire segreti.  
> Possono essere lette da processi figli, comparire in dump diagnostici o risultare accessibili a processi con privilegi sufficienti.

---

## Indice

1. [Principi fondamentali](#principi-fondamentali)
2. [Rischi delle variabili d’ambiente](#rischi-delle-variabili-dambiente)
3. [Approccio consigliato](#approccio-consigliato)
4. [Utenti database dedicati](#utenti-database-dedicati)
5. [Soluzione consigliata con systemd credentials](#soluzione-consigliata-con-systemd-credentials)
6. [Gestione tramite file protetti](#gestione-tramite-file-protetti)
7. [Variabili d’ambiente: uso accettabile e limiti](#variabili-dambiente-uso-accettabile-e-limiti)
8. [PostgreSQL: file `.pgpass`](#postgresql-file-pgpass)
9. [MySQL e MariaDB: file di credenziali](#mysql-e-mariadb-file-di-credenziali)
10. [Segreti in container e Kubernetes](#segreti-in-container-e-kubernetes)
11. [Rotazione delle password](#rotazione-delle-password)
12. [Checklist finale](#checklist-finale)

---

# Principi fondamentali

Per proteggere una password di connessione a un database, segui queste regole:

1. **Non inserire segreti nel codice.**
2. **Non passare password come argomento da riga di comando.**
3. **Non salvare segreti in Git.**
4. **Usa un utente database dedicato per ogni applicazione.**
5. **Assegna soltanto i privilegi strettamente necessari.**
6. **Proteggi i file contenenti segreti con permessi minimi.**
7. **Ruota periodicamente password e token.**
8. **Non scrivere mai password nei log.**
9. **Usa TLS per le connessioni al database quando possibile.**
10. **Preferisci secret manager o credenziali gestite da systemd rispetto alle variabili d’ambiente.**

---

# Rischi delle variabili d’ambiente

Una variabile d’ambiente può essere utile:

```sh
export DB_PASSWORD="password-riservata"
```

Tuttavia presenta alcuni rischi.

## Ereditarietà ai processi figli

Un processo figlio eredita normalmente l’ambiente del processo padre.

Se un’applicazione avvia altri processi, la password potrebbe essere ereditata involontariamente.

## Debug, dump e strumenti di diagnostica

L’ambiente può comparire in:

- strumenti di debug;
- core dump;
- report di errore;
- strumenti di monitoraggio;
- log creati in modo non sicuro;
- processi eseguiti con privilegi amministrativi.

## Accesso tramite processi con privilegi elevati

L’utente `root` può normalmente leggere l’ambiente degli altri processi.

In alcune configurazioni, anche processi appartenenti allo stesso utente possono ottenere informazioni su altri processi di quello stesso utente.

## Esposizione accidentale

Il segreto può essere mostrato se qualcuno esegue:

```sh
env
```
text

oppure:

```sh
printenv
```
text

o se viene registrato accidentalmente un comando di debug.

> Le variabili d’ambiente possono essere usate in alcuni contesti, ma non devono essere considerate un vault o un sistema di protezione completo dei segreti.

---

# Approccio consigliato

La strategia preferibile dipende dal contesto.

| Ambiente | Soluzione consigliata |
|---|---|
| Servizio Linux gestito da systemd | `systemd` credentials |
| Applicazione tradizionale su server | File segreto protetto da permessi Unix |
| PostgreSQL CLI o librerie compatibili | File `.pgpass` con permessi `0600` |
| MySQL/MariaDB CLI | File `.my.cnf` con permessi `0600` |
| Docker | Docker Secrets o file montati come secret |
| Kubernetes | Kubernetes Secrets montati come file, preferibilmente con encryption at rest |
| Cloud | Secret manager del provider cloud |
| Pipeline CI/CD | Secret store della piattaforma CI/CD |

---

# Utenti database dedicati

Ogni applicazione dovrebbe usare un utente database dedicato.

Evita di usare utenti amministrativi come:

```text
postgres
root
sa
sys
system
```
text

Esempio di schema consigliato:

```text
Applicazione: myapp
Utente database: myapp_rw
Database: myapp_db
```
text

L’utente `myapp_rw` dovrebbe avere soltanto i permessi necessari sul database dell’applicazione.

## Esempio PostgreSQL

```sql
CREATE ROLE myapp_rw
    LOGIN
    PASSWORD 'password-lunga-e-casuale';

GRANT CONNECT ON DATABASE myapp_db TO myapp_rw;

\c myapp_db

GRANT USAGE ON SCHEMA public TO myapp_rw;
GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public
TO myapp_rw;

GRANT USAGE, SELECT, UPDATE
ON ALL SEQUENCES IN SCHEMA public
TO myapp_rw;
```text

## Esempio MySQL/MariaDB

```sql
CREATE USER 'myapp_rw'@'localhost'
IDENTIFIED BY 'password-lunga-e-casuale';

GRANT SELECT, INSERT, UPDATE, DELETE
ON myapp_db.*
TO 'myapp_rw'@'localhost';

FLUSH PRIVILEGES;
```text

Non assegnare privilegi non necessari, come:

```sql
GRANT ALL PRIVILEGES ON *.* TO ...
```text

Evita in particolare privilegi come:

```text
SUPER
FILE
GRANT OPTION
CREATE USER
DROP
ALTER
```text

se l’applicazione non ne ha una reale necessità.

---

# Soluzione consigliata con systemd credentials

Se l’applicazione è eseguita come servizio `systemd`, una buona soluzione consiste nell’usare le **credenziali di systemd**.

Invece di passare la password come variabile d’ambiente, il segreto viene fornito all’applicazione in un file temporaneo, disponibile soltanto durante l’esecuzione del servizio.

## Struttura consigliata

```text
/etc/myapp/
+-- myapp.conf
+-- credentials/
    +-- db-password

/opt/myapp/
+-- bin/
    +-- myapp

/etc/systemd/system/
+-- myapp.service
```text

## Creazione della directory delle credenziali

```sh
sudo install -d -m 0750 -o root -g myapp /etc/myapp/credentials
```text

## Creazione del file con la password

```sh
sudo nano /etc/myapp/credentials/db-password
```text

Contenuto:

```text
una-password-lunga-casuale-e-non-versionata
```text

Imposta proprietà e permessi:

```sh
sudo chown root:myapp /etc/myapp/credentials/db-password
sudo chmod 0640 /etc/myapp/credentials/db-password
```text

## Configurazione del servizio systemd

File:

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

# Rende disponibile la credenziale db-password al servizio.
LoadCredential=db-password:/etc/myapp/credentials/db-password

# L'applicazione legge la password dal file:
# $CREDENTIALS_DIRECTORY/db-password
ExecStart=/opt/myapp/bin/myapp --config /etc/myapp/myapp.conf

Restart=on-failure
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict

ReadWritePaths=/var/lib/myapp /var/log/myapp /run/myapp

[Install]
WantedBy=multi-user.target
```text

Ricarica systemd e riavvia il servizio:

```sh
sudo systemctl daemon-reload
sudo systemctl restart myapp.service
```text

## Come legge la password l’applicazione

`systemd` mette a disposizione la variabile:

```text
CREDENTIALS_DIRECTORY
```text

L’applicazione può leggere il file:

```text
$CREDENTIALS_DIRECTORY/db-password
```text

Esempio shell:

```sh
DB_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/db-password")"
```text

Esempio Python:

```python
from pathlib import Path
import os

credentials_directory = os.environ["CREDENTIALS_DIRECTORY"]
db_password = Path(credentials_directory, "db-password").read_text().strip()
```text

Esempio Node.js:

```javascript
const fs = require("fs");
const path = require("path");

const credentialsDirectory = process.env.CREDENTIALS_DIRECTORY;
const dbPassword = fs
  .readFileSync(path.join(credentialsDirectory, "db-password"), "utf8")
  .trim();
```text

> Evita di stampare `dbPassword` nei log, nei messaggi di errore o nella console.

---

# Gestione tramite file protetti

Se l’applicazione non supporta le credenziali di systemd, puoi usare un file di configurazione protetto.

Esempio:

```text
/etc/myapp/secrets.conf
```text

Contenuto:

```ini
[database]
host=127.0.0.1
port=5432
name=myapp_db
user=myapp_rw
password=una-password-lunga-casuale
sslmode=require
```text

Permessi:

```sh
sudo chown root:myapp /etc/myapp/secrets.conf
sudo chmod 0640 /etc/myapp/secrets.conf
```text

In questo modo:

- `root` può leggere e modificare il file;
- il gruppo `myapp` può leggerlo;
- gli altri utenti non possono accedervi.

## Limiti di questo approccio

Il file contiene comunque il segreto in chiaro sul filesystem.

È accettabile se:

- il server è amministrato correttamente;
- l’accesso al filesystem è controllato;
- i permessi sono restrittivi;
- il file non viene copiato in repository o backup non protetti;
- il disco è cifrato, se richiesto dal contesto di sicurezza.

---

# Variabili d’ambiente: uso accettabile e limiti

Puoi usare variabili d’ambiente quando:

- l’applicazione è progettata per riceverle soltanto a runtime;
- il sistema di deployment le inietta in modo sicuro;
- il segreto non viene scritto in file o log;
- esiste un controllo adeguato sui processi e sugli accessi al server;
- non hai a disposizione un meccanismo migliore.

Esempio di file environment per systemd:

```text
/etc/myapp/environment
```text

```text
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=myapp_db
DB_USER=myapp_rw
DB_SSLMODE=require
```text

Questo file può contenere informazioni non strettamente segrete:

```sh
sudo chown root:myapp /etc/myapp/environment
sudo chmod 0640 /etc/myapp/environment
```text

Nel servizio systemd:

```ini
EnvironmentFile=/etc/myapp/environment
```text

## Password in un file `EnvironmentFile`

Puoi tecnicamente inserire anche la password:

```text
DB_PASSWORD=una-password-lunga-casuale
```text

ma è preferibile evitarlo quando l’applicazione può leggere un file segreto dedicato oppure una credenziale systemd.

Se devi usarlo temporaneamente:

```sh
sudo chown root:myapp /etc/myapp/environment
sudo chmod 0640 /etc/myapp/environment
```text

e assicurati di non inserire il file in Git.

> Non usare `export` nei file caricati con `EnvironmentFile=` di systemd.

Corretto:

```text
DB_USER=myapp_rw
DB_PASSWORD=password-riservata
```text

Da evitare:

```sh
export DB_USER=myapp_rw
export DB_PASSWORD=password-riservata
```text

---

# PostgreSQL: file `.pgpass`

PostgreSQL supporta un file specifico per le password chiamato `.pgpass`.

Posizione tipica:

```text
~/.pgpass
```text

Per un utente applicativo con home `/var/lib/myapp`:

```text
/var/lib/myapp/.pgpass
```text

Formato:

```text
host:porta:database:utente:password
```text

Esempio:

```text
127.0.0.1:5432:myapp_db:myapp_rw:una-password-lunga-casuale
```text

Imposta proprietà e permessi:

```sh
sudo chown myapp:myapp /var/lib/myapp/.pgpass
sudo chmod 0600 /var/lib/myapp/.pgpass
```text

PostgreSQL ignora il file se i permessi sono troppo aperti.

Puoi anche indicare un percorso specifico:

```sh
export PGPASSFILE="/etc/myapp/pgpass"
```text

Oppure nel servizio systemd:

```ini
Environment=PGPASSFILE=/etc/myapp/pgpass
```text

Con permessi:

```sh
sudo chown root:myapp /etc/myapp/pgpass
sudo chmod 0640 /etc/myapp/pgpass
```text

---

# MySQL e MariaDB: file di credenziali

MySQL e MariaDB possono usare un file di configurazione dedicato.

Per esempio:

```text
/etc/myapp/mysql-client.cnf
```text

Contenuto:

```ini
[client]
host=127.0.0.1
port=3306
user=myapp_rw
password=una-password-lunga-casuale
database=myapp_db
```text

Proteggi il file:

```sh
sudo chown root:myapp /etc/myapp/mysql-client.cnf
sudo chmod 0640 /etc/myapp/mysql-client.cnf
```text

Utilizzo:

```sh
mysql --defaults-extra-file=/etc/myapp/mysql-client.cnf
```text

Evita questa sintassi:

```sh
mysql -u myapp_rw -puna-password-lunga-casuale
```text

La password potrebbe essere visibile nella lista dei processi, nella cronologia della shell o in strumenti di monitoraggio.

---

# Segreti in container e Kubernetes

## Docker

Non inserire password direttamente nel file `docker-compose.yml`:

```yaml
environment:
  DB_PASSWORD: password-riservata
```text

Preferisci Docker Secrets, quando disponibili.

Esempio:

```yaml
services:
  myapp:
    image: esempio/myapp:latest
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```text

La password sarà disponibile nel container come file:

```text
/run/secrets/db_password
```text

## Kubernetes

In Kubernetes, usa un `Secret` e montalo come file invece di esporlo direttamente come variabile d’ambiente, quando l’applicazione lo supporta.

Esempio concettuale:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-db
type: Opaque
stringData:
  db-password: una-password-lunga-casuale
```text

Il Secret dovrebbe essere:

- gestito tramite un sistema esterno, se possibile;
- cifrato a riposo nel cluster;
- protetto con RBAC;
- montato soltanto nei pod che ne hanno realmente bisogno.

---

# Rotazione delle password

Le password devono poter essere cambiate senza rendere indisponibile l’applicazione per troppo tempo.

Procedura generale:

1. genera una nuova password lunga e casuale;
2. aggiorna la password nel database;
3. aggiorna il secret manager o il file protetto;
4. riavvia o ricarica l’applicazione;
5. verifica la nuova connessione;
6. rimuovi la vecchia password, se era mantenuta temporaneamente.

Esempio PostgreSQL:

```sql
ALTER ROLE myapp_rw
WITH PASSWORD 'nuova-password-lunga-casuale';
```text

Poi aggiorna il file segreto:

```sh
sudo nano /etc/myapp/credentials/db-password
```text

Infine riavvia il servizio:

```sh
sudo systemctl restart myapp.service
```text

Verifica:

```sh
sudo systemctl status myapp.service
sudo journalctl -u myapp.service -n 100
```text

Non inserire mai la nuova password direttamente nella cronologia della shell o nella riga di comando.

---

# Generare password sicure

Puoi generare una password casuale con:

```sh
openssl rand -base64 32
```text

Oppure:

```sh
tr -dc 'A-Za-z0-9_@%+=-' < /dev/urandom | head -c 32
printf '\n'
```text

Una password robusta dovrebbe:

- essere lunga almeno 24-32 caratteri;
- essere unica per ogni applicazione;
- non essere riutilizzata;
- essere generata casualmente;
- essere archiviata in un sistema protetto.

---

# Evitare esposizioni accidentali

Non fare:

```sh
echo "$DB_PASSWORD"
```text

Non abilitare il debug shell con segreti caricati:

```sh
set -x
```text

Evita comandi come:

```sh
ps aux
```text

con password nella riga di comando.

Evita di salvare segreti in file di shell personali:

```text
~/.bashrc
~/.zshrc
~/.profile
```text

Evita di inserire password nel crontab:

```cron
0 2 * * * comando --password=password-riservata
```text

Evita di committare file come:

```text
.env
secrets.conf
credentials.json
pgpass
mysql-client.cnf
```text

Se devi tenere un modello di configurazione nel repository, usa un file senza segreti:

```text
.env.example
```text

Esempio:

```text
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=myapp_db
DB_USER=myapp_rw
DB_PASSWORD=INSERIRE_SEGRETO_ESTERNAMENTE
```text

---

# Checklist finale

## Utente applicativo

- [ ] L’applicazione usa un utente Unix dedicato.
- [ ] L’utente Unix non dispone di accesso SSH diretto.
- [ ] L’utente Unix non possiede privilegi `sudo`.
- [ ] L’applicazione è gestita tramite `systemd`.

## Utente database

- [ ] Esiste un utente database dedicato all’applicazione.
- [ ] L’utente database non è amministratore.
- [ ] Sono assegnati soltanto i privilegi necessari.
- [ ] La password è lunga, casuale e unica.
- [ ] La connessione usa TLS quando disponibile.

## Segreti

- [ ] Le password non sono nel codice sorgente.
- [ ] Le password non sono in Git.
- [ ] Le password non sono passate nella riga di comando.
- [ ] Le password non sono scritte nei log.
- [ ] I file con segreti hanno permessi restrittivi.
- [ ] I segreti sono separati dalla configurazione non sensibile.
- [ ] Esiste una procedura di rotazione delle credenziali.

## Approccio tecnico

- [ ] Preferenza per secret manager o systemd credentials.
- [ ] File protetti soltanto se necessario.
- [ ] Variabili d’ambiente soltanto se strettamente richiesto dall’applicazione.
- [ ] Uso di meccanismi specifici del database, come `.pgpass`, quando appropriato.

---

# Riepilogo

La soluzione preferibile per un’applicazione Linux gestita da `systemd` è:

```text
/etc/myapp/environment                 Variabili non segrete
/etc/myapp/credentials/db-password     Password protetta
/etc/systemd/system/myapp.service      Configurazione del servizio
```text

Nel file del servizio:

```ini
EnvironmentFile=/etc/myapp/environment
LoadCredential=db-password:/etc/myapp/credentials/db-password
```text

L’applicazione legge la password dal file:

```text
$CREDENTIALS_DIRECTORY/db-password
```text

In questo modo la password non viene inserita nel codice, nella riga di comando o nelle normali variabili d’ambiente dell’applicazione.
