# Gestione sicura delle password su Linux: applicativi, database e Oracle

Questa guida fornisce una panoramica pratica sulla gestione delle password e dei segreti in ambiente Linux, con un approfondimento dedicato alle connessioni a database Oracle.

L’obiettivo è proteggere credenziali usate da applicazioni, script, servizi `systemd`, processi schedulati e client database, evitando che siano esposte in codice sorgente, file non protetti, riga di comando, log o repository Git.

---

## Indice

1. [Concetti fondamentali](#concetti-fondamentali)
2. [Cosa può essere considerato un segreto](#cosa-può-essere-considerato-un-segreto)
3. [Dove non conservare password e segreti](#dove-non-conservare-password-e-segreti)
4. [Strategie disponibili](#strategie-disponibili)
5. [Scelta della soluzione in base al contesto](#scelta-della-soluzione-in-base-al-contesto)
6. [Permessi Linux e utenti applicativi](#permessi-linux-e-utenti-applicativi)
7. [Gestione con systemd](#gestione-con-systemd)
8. [Script, shell e Cron](#script-shell-e-cron)
9. [Gestione delle password per database Oracle](#gestione-delle-password-per-database-oracle)
10. [Oracle Wallet e Secure External Password Store](#oracle-wallet-e-secure-external-password-store)
11. [Esempio Oracle Wallet con SQL*Plus](#esempio-oracle-wallet-con-sqlplus)
12. [Applicazioni Java/JDBC e Oracle Wallet](#applicazioni-javajdbc-e-oracle-wallet)
13. [Oracle Autonomous Database](#oracle-autonomous-database)
14. [Rotazione delle password](#rotazione-delle-password)
15. [Checklist di sicurezza](#checklist-di-sicurezza)

---

# Concetti fondamentali

Una password di connessione non è un normale parametro di configurazione: è un **segreto**.

Per segreto si intende un’informazione che, se ottenuta da un soggetto non autorizzato, può consentire accessi indebiti a sistemi, dati, servizi o infrastrutture.

La protezione di un segreto deve considerare almeno:

- dove viene salvato;
- chi può leggerlo;
- come viene fornito al processo applicativo;
- se può apparire nei log;
- se può comparire nella lista dei processi;
- se può essere incluso in backup;
- se può essere caricato accidentalmente in Git;
- come viene aggiornato o ruotato;
- cosa accade se viene compromesso.

---

# Cosa può essere considerato un segreto

Esempi comuni:

```text
Password di database
Token API
Password di account di servizio
Chiavi private SSH
Chiavi di cifratura
Token OAuth
Credenziali cloud
Password SMTP
Password LDAP o Active Directory
Certificati client
Cookie di sessione
Stringhe di connessione con password incorporata
```

Esempio di stringa di connessione da considerare segreta:

```text
postgresql://utente:password@database.example.local:5432/appdb
```

Anche se la password non compare esplicitamente, altri dati possono essere sensibili:

```text
DB_HOST=db-produzione.interno.example
DB_NAME=anagrafica_clienti
DB_USER=app_rw
```

---

# Dove non conservare password e segreti

Evita di salvare password nei seguenti punti.

## Codice sorgente

Da evitare:

```python
db_password = "password-riservata"
```

```java
String password = "password-riservata";
```

```bash
DB_PASSWORD="password-riservata"
```

Il codice può essere copiato, versionato, inviato via email, incluso in artifact di build o analizzato da persone non autorizzate.

---

## Repository Git

Non committare file come:

```text
.env
.env.production
secrets.conf
database.properties
application.properties
config.yaml
credentials.json
wallet.zip
cwallet.sso
ewallet.p12
```

Inserisci i file sensibili nel `.gitignore`:

```gitignore
.env
.env.*
*.secret
secrets/
credentials/
wallet/
*.p12
*.sso
```

Mantieni nel repository soltanto file di esempio privi di password:

```text
.env.example
application.properties.example
database.properties.example
```

Esempio:

```text
DB_HOST=database.example.local
DB_PORT=1521
DB_SERVICE_NAME=ORCLPDB1
DB_USER=app_user
DB_PASSWORD=INSERIRE_TRAMITE_SECRET_MANAGER
```

---

## Riga di comando

Da evitare:

```sh
sqlplus app_user/password@ORCLPDB1
```

Da evitare:

```sh
mysql -u app_user -ppassword-riservata
```

Da evitare:

```sh
comando --db-password=password-riservata
```

Una password passata come parametro può comparire in:

- output di `ps`;
- strumenti di monitoraggio;
- audit;
- cronologia della shell;
- log di esecuzione;
- sistemi EDR o di sicurezza.

---

## File di configurazione leggibili da tutti

Da evitare:

```sh
chmod 644 /etc/myapp/secrets.conf
```

Da evitare:

```sh
chmod 777 /etc/myapp
```

Un file con password non deve essere leggibile da utenti non autorizzati.

---

## Variabili esportate nella shell personale

Da evitare nei file utente:

```text
~/.bashrc
~/.zshrc
~/.profile
```

Esempio da evitare:

```sh
export DB_PASSWORD="password-riservata"
```

Questi file possono essere inclusi in backup, sincronizzati nel cloud, caricati in repository di dotfiles o letti durante attività di assistenza.

---

## Crontab

Da evitare:

```cron
0 2 * * * /opt/myapp/bin/backup --password=password-riservata
```

Da evitare:

```cron
0 2 * * * sqlplus app_user/password@ORCLPDB1 @backup.sql
```

---

# Strategie disponibili

Le soluzioni principali, in ordine generale di preferenza, sono:

1. **Secret manager centralizzato**
2. **Credenziali gestite da systemd**
3. **Wallet o meccanismi nativi del database**
4. **File protetti da permessi Linux**
5. **Secret di container o orchestratori**
6. **Variabili d’ambiente iniettate a runtime**
7. **Variabili d’ambiente statiche in file locali**

Le ultime due opzioni possono essere valide in contesti limitati, ma richiedono particolare attenzione.

---

# Scelta della soluzione in base al contesto

| Contesto | Soluzione preferibile |
|---|---|
| Servizio Linux gestito da `systemd` | systemd credentials oppure file protetti |
| Database Oracle | Oracle Wallet / Secure External Password Store |
| PostgreSQL | `.pgpass` con permessi `0600`, secret manager o file protetto |
| MySQL/MariaDB | File client protetto oppure secret manager |
| Docker Swarm | Docker Secrets |
| Kubernetes | Kubernetes Secrets, preferibilmente montati come file |
| AWS | AWS Secrets Manager o Parameter Store |
| Azure | Azure Key Vault |
| Google Cloud | Google Secret Manager |
| Pipeline CI/CD | Secret store della piattaforma CI/CD |
| Script locale occasionale | Password manager, file protetto o input interattivo |

---

# Permessi Linux e utenti applicativi

Ogni applicazione dovrebbe avere un utente Unix dedicato.

Esempio:

```text
Applicazione: myapp
Utente Unix: myapp
Gruppo Unix: myapp
```

L’utente applicativo dovrebbe:

- non avere privilegi `sudo`;
- non avere una password interattiva;
- non essere usato per login SSH;
- avere una shell come `nologin`;
- poter leggere soltanto i file realmente necessari;
- poter scrivere soltanto in directory dedicate a dati, log e cache.

Esempio di creazione di un utente di sistema:

```sh
sudo useradd \
    --system \
    --create-home \
    --home-dir /var/lib/myapp \
    --shell /usr/sbin/nologin \
    myapp
```

Struttura consigliata:

```text
/etc/myapp/                 Configurazione
/etc/myapp/credentials/     Segreti e credenziali
/opt/myapp/                 Codice e binari applicativi
/var/lib/myapp/             Dati persistenti
/var/log/myapp/             Log applicativi
/var/cache/myapp/           Cache
/run/myapp/                 File runtime, socket e PID
```

Esempio di proprietari e permessi:

```text
/opt/myapp/                 root:root      0755
/etc/myapp/                 root:myapp     0750
/etc/myapp/credentials/     root:myapp     0750
/var/lib/myapp/             myapp:myapp    0750
/var/log/myapp/             myapp:myapp    0750
/var/cache/myapp/           myapp:myapp    0750
```

Creazione pratica:

```sh
sudo install -d -m 0750 -o root -g myapp /etc/myapp
sudo install -d -m 0750 -o root -g myapp /etc/myapp/credentials
sudo install -d -m 0755 -o root -g root /opt/myapp
sudo install -d -m 0750 -o myapp -g myapp /var/lib/myapp
sudo install -d -m 0750 -o myapp -g myapp /var/log/myapp
sudo install -d -m 0750 -o myapp -g myapp /var/cache/myapp
``

---

# Gestione con systemd

Per applicazioni eseguite come servizi Linux, `systemd` è spesso il punto corretto in cui gestire la configurazione runtime.

Le variabili non segrete possono essere collocate in:

```text
/etc/myapp/environment
```

Esempio:

```text
APP_ENV=production
APP_LOG_DIR=/var/log/myapp
DB_HOST=oracle-db.example.local
DB_PORT=1521
DB_SERVICE_NAME=ORCLPDB1
DB_USER=MYAPP_USER
```

Permessi:

```sh
sudo chown root:myapp /etc/myapp/environment
sudo chmod 0640 /etc/myapp/environment
```

Nel file di servizio:

```ini
[Service]
User=myapp
Group=myapp

EnvironmentFile=/etc/myapp/environment

ExecStart=/opt/myapp/bin/myapp
```

> Il file `EnvironmentFile=` è adatto soprattutto a valori non segreti.  
> Per password e token, preferisci un wallet, un secret manager o le credenziali gestite da systemd.

---

## systemd credentials

`systemd` può fornire credenziali a un processo tramite file temporanei disponibili soltanto durante l’esecuzione del servizio.

Struttura esempio:

```text
/etc/myapp/credentials/
+-- oracle-db-password
```

Creazione del file:

```sh
sudo nano /etc/myapp/credentials/oracle-db-password
```

Contenuto:

```text
password-lunga-casuale
```

Permessi:

```sh
sudo chown root:myapp /etc/myapp/credentials/oracle-db-password
sudo chmod 0640 /etc/myapp/credentials/oracle-db-password
```

Esempio di servizio:

```ini
[Service]
User=myapp
Group=myapp

LoadCredential=oracle-db-password:/etc/myapp/credentials/oracle-db-password

ExecStart=/opt/myapp/bin/myapp
```

All’interno del processo, `systemd` espone la directory tramite:

```text
$CREDENTIALS_DIRECTORY
```

Il segreto è leggibile nel file:

```text
$CREDENTIALS_DIRECTORY/oracle-db-password
```

Esempio shell:

```sh
DB_PASSWORD="$(cat "$CREDENTIALS_DIRECTORY/oracle-db-password")"
```

Questo approccio è migliore di una normale variabile d’ambiente, ma l’applicazione deve essere in grado di leggere il segreto da file.

---

# Script, shell e Cron

Gli script devono evitare di contenere password in chiaro.

Da evitare:

```sh
#!/bin/sh

sqlplus app_user/password@ORCLPDB1 @/opt/myapp/sql/backup.sql
```

Da evitare:

```sh
export DB_PASSWORD="password-riservata"
```

Se uno script deve collegarsi a Oracle, è preferibile usare Oracle Wallet, illustrato nelle sezioni successive.

Con Cron:

```cron
0 2 * * * /opt/myapp/bin/backup-oracle.sh
```

Lo script deve recuperare le credenziali da un wallet o da un file protetto, non dalla riga del crontab.

Ricorda che Cron non carica automaticamente:

```text
~/.bashrc
~/.zshrc
~/.profile
```

---

# Gestione delle password per database Oracle

Per Oracle, la soluzione più adatta per evitare password in chiaro in script e stringhe di connessione è in genere **Oracle Wallet**, noto anche come:

```text
Secure External Password Store
SEPS
```

Il wallet permette di memorizzare credenziali Oracle in un archivio protetto e di collegarsi senza specificare esplicitamente utente e password.

Invece di eseguire:

```sh
sqlplus MYAPP_USER/password-riservata@ORCLPDB1
```

puoi eseguire:

```sh
sqlplus /@ORCLPDB1
```

dopo aver configurato correttamente wallet e alias di connessione.

---

## Opzioni principali per Oracle

| Soluzione | Quando usarla |
|---|---|
| Oracle Wallet / SEPS | Script, batch, applicazioni e servizi tradizionali |
| Oracle Wallet con TLS/mTLS | Connessioni cifrate e ambienti Oracle Cloud |
| Autenticazione esterna | Utenti locali o integrazione enterprise |
| Kerberos / LDAP / Active Directory | Organizzazioni con identità centralizzata |
| OCI IAM / token | Oracle Cloud e servizi compatibili |
| Password in file protetto | Soluzione di ripiego |
| Password in variabile ambiente | Soluzione di ripiego, con limiti |

---

# Oracle Wallet e Secure External Password Store

Oracle Wallet è un contenitore di credenziali e materiali crittografici.

Può essere usato per memorizzare:

- credenziali di connessione a Oracle Database;
- certificati;
- chiavi;
- configurazioni TLS;
- materiali di autenticazione per Oracle Autonomous Database.

Per la gestione delle password database, l’obiettivo è usare il wallet come **Secure External Password Store**.

---

## Struttura consigliata

Per un’applicazione chiamata `myapp`:

```text
/etc/myapp/
+-- environment
+-- oracle/
¦   +-- tnsnames.ora
¦   +-- sqlnet.ora
+-- wallet/
    +-- cwallet.sso
    +-- ewallet.p12
```

Oppure, se il wallet è dedicato al solo client Oracle:

```text
/opt/oracle/wallets/myapp/
+-- cwallet.sso
+-- ewallet.p12
```

Non inserire il wallet nel repository Git.

---

## Permessi consigliati del wallet

Il wallet deve essere accessibile soltanto all’utente applicativo e agli amministratori autorizzati.

Esempio:

```sh
sudo install -d -m 0750 -o root -g myapp /etc/myapp/wallet
sudo chown root:myapp /etc/myapp/wallet
sudo chmod 0750 /etc/myapp/wallet
```

Per i file del wallet:

```sh
sudo chown root:myapp /etc/myapp/wallet/*
sudo chmod 0640 /etc/myapp/wallet/*
```

Verifica:

```sh
ls -la /etc/myapp/wallet
```

Esempio atteso:

```text
-rw-r----- root myapp cwallet.sso
-rw-r----- root myapp ewallet.p12
```

> Un wallet `cwallet.sso` in modalità auto-login consente l’accesso senza richiedere la password del wallet.  
> Per questo motivo, chi può leggere il file può potenzialmente usare le credenziali in esso contenute. I permessi del filesystem sono fondamentali.

---

# Esempio Oracle Wallet con SQL*Plus

Questa sezione mostra un esempio concettuale per usare Oracle Wallet con SQL*Plus.

I percorsi e i comandi esatti possono variare in base alla versione del client Oracle installato. Verifica sempre la documentazione della versione Oracle effettivamente in uso.

---

## Prerequisiti

Sono necessari:

- Oracle Client oppure Oracle Instant Client;
- strumenti Oracle per la gestione del wallet;
- `sqlplus`, se vuoi usare SQL*Plus;
- file `tnsnames.ora`;
- file `sqlnet.ora`;
- accesso al database Oracle;
- utente database dedicato all’applicazione.

Verifica la disponibilità del client:

```sh
sqlplus -version
```

---

## Configurare `tnsnames.ora`

File:

```text
/etc/myapp/oracle/tnsnames.ora
```

Esempio:

```ora
ORCLPDB1 =
  (DESCRIPTION =
    (ADDRESS =
      (PROTOCOL = TCP)
      (HOST = oracle-db.example.local)
      (PORT = 1521)
    )
    (CONNECT_DATA =
      (SERVICE_NAME = ORCLPDB1)
    )
  )
```

In questo esempio:

```text
ORCLPDB1
```

è l’alias di rete usato per raggiungere il database.

---

## Configurare `sqlnet.ora`

File:

```text
/etc/myapp/oracle/sqlnet.ora
```

Esempio:

```ora
NAMES.DIRECTORY_PATH = (TNSNAMES, EZCONNECT)

WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /etc/myapp/wallet)
    )
  )

SQLNET.WALLET_OVERRIDE = TRUE
```

Significato:

- `WALLET_LOCATION` indica la directory contenente il wallet;
- `SQLNET.WALLET_OVERRIDE = TRUE` indica al client Oracle di usare le credenziali memorizzate nel wallet;
- `NAMES.DIRECTORY_PATH` abilita la risoluzione degli alias definiti in `tnsnames.ora`.

---

## Impostare `TNS_ADMIN`

Il client Oracle deve sapere dove trovare `tnsnames.ora` e `sqlnet.ora`.

Puoi impostare:

```sh
export TNS_ADMIN="/etc/myapp/oracle"
```

In un servizio systemd:

```ini
Environment=TNS_ADMIN=/etc/myapp/oracle
```

Oppure nel file:

```text
/etc/myapp/environment
```

```text
TNS_ADMIN=/etc/myapp/oracle
```

---

## Creazione del wallet

Per creare un wallet, Oracle fornisce strumenti come `mkstore` o `orapki`, in base al client e alla versione utilizzata.

Esempio con `mkstore`:

```sh
mkstore -wrl /etc/myapp/wallet -create
```

Durante la creazione viene richiesta una password del wallet.

Il comando crea normalmente file come:

```text
ewallet.p12
cwallet.sso
```

> I comandi Oracle e le opzioni disponibili possono cambiare tra versioni di Oracle Client.  
> Consulta la documentazione della versione utilizzata prima di eseguire procedure in produzione.

---

## Aggiungere una credenziale al wallet

Concettualmente, una credenziale è associata a:

```text
alias di connessione
utente database
password database
```

Esempio:

```text
ORCLPDB1
MYAPP_USER
password-riservata
```

Un esempio tipico con `mkstore` è:

```sh
mkstore -wrl /etc/myapp/wallet \
  -createCredential ORCLPDB1 MYAPP_USER password-riservata
```

### Attenzione importante

Il comando precedente mostra la password nella riga di comando.

Questo può esporla tramite:

```sh
ps -ef
```

oppure tramite cronologia shell, audit o strumenti di monitoraggio.

Per questa ragione:

- esegui queste attività soltanto in sessioni amministrative controllate;
- evita terminali condivisi;
- non salvare il comando in script;
- non copiarlo in sistemi di ticketing;
- non inserirlo nella cronologia;
- valuta procedure di provisioning automatizzate con secret manager;
- segui le indicazioni della documentazione Oracle della tua versione per metodi di inserimento più sicuri.

Dopo aver creato e popolato il wallet, verifica che proprietà e permessi siano corretti:

```sh
sudo chown -R root:myapp /etc/myapp/wallet
sudo chmod 0750 /etc/myapp/wallet
sudo chmod 0640 /etc/myapp/wallet/*
```

---

## Verificare le credenziali presenti nel wallet

Puoi visualizzare le credenziali memorizzate con un comando simile a:

```sh
mkstore -wrl /etc/myapp/wallet -listCredential
```

L’output dovrebbe mostrare gli alias e gli utenti associati, senza esporre la password.

Esempio concettuale:

```text
List credential (index: connect_string username)
1: ORCLPDB1 MYAPP_USER
```

---

## Collegarsi con SQL*Plus senza password in chiaro

Con wallet, `sqlnet.ora`, `tnsnames.ora` e `TNS_ADMIN` configurati, puoi usare:

```sh
sqlplus /@ORCLPDB1
```

Oppure in modalità silenziosa:

```sh
sqlplus -s /@ORCLPDB1 <<'SQL'
SELECT SYSDATE FROM dual;
EXIT;
SQL
```

La password non compare:

- nella riga di comando;
- nella cronologia della shell;
- nello script;
- nel crontab.

---

## Esempio di script batch Oracle sicuro

File:

```text
/opt/myapp/bin/oracle-batch.sh
```

Contenuto:

```sh
#!/bin/sh

set -eu

export TNS_ADMIN="/etc/myapp/oracle"

exec /opt/oracle/instantclient/sqlplus -s /@ORCLPDB1 <<'SQL'
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT SQL.SQLCODE

SELECT SYSDATE FROM dual;

EXIT SUCCESS
SQL
```

Permessi:

```sh
sudo chown root:myapp /opt/myapp/bin/oracle-batch.sh
sudo chmod 0750 /opt/myapp/bin/oracle-batch.sh
```

Esecuzione come utente applicativo:

```sh
sudo -u myapp -- /opt/myapp/bin/oracle-batch.sh
```

---

# Applicazioni Java/JDBC e Oracle Wallet

Un’applicazione Java può usare Oracle Wallet quando utilizza il driver JDBC Oracle e una configurazione appropriata.

Il principio è lo stesso:

1. il wallet contiene la credenziale;
2. il client Oracle conosce la directory del wallet;
3. l’applicazione usa un alias di connessione;
4. utente e password non sono scritti nel codice.

Esempio concettuale di URL JDBC:

```text
jdbc:oracle:thin:/@ORCLPDB1
```

In questo caso:

```text
ORCLPDB1
```

è l’alias definito in `tnsnames.ora`.

La configurazione esatta può variare in base a:

- versione del driver Oracle JDBC;
- versione del database;
- uso di Oracle Wallet SEPS;
- uso di TLS o mTLS;
- configurazione `sqlnet.ora`;
- tipo di autenticazione scelto.

Per un’applicazione Java, evita configurazioni come:

```properties
spring.datasource.username=MYAPP_USER
spring.datasource.password=password-riservata
```

Preferisci, quando supportato, una configurazione che utilizzi il wallet e l’alias TNS.

---

# Oracle Autonomous Database

Oracle Autonomous Database usa normalmente un wallet scaricabile dalla console Oracle Cloud.

Il wallet può includere elementi come:

```text
tnsnames.ora
sqlnet.ora
cwallet.sso
ewallet.p12
keystore.jks
truststore.jks
```

Questo wallet non va trattato come un file ordinario: contiene materiale sensibile per la connessione al servizio.

Linee guida:

- non caricare il file ZIP del wallet in Git;
- non inviarlo via email non protetta;
- non lasciarlo in directory pubbliche;
- non renderlo leggibile da tutti;
- estrailo in una directory accessibile soltanto all’utente applicativo;
- proteggi backup e copie del wallet;
- segui le indicazioni Oracle Cloud per rotazione o rigenerazione del wallet.

Esempio:

```sh
sudo install -d -m 0750 -o root -g myapp /etc/myapp/oracle-wallet
sudo unzip Wallet_MYDB.zip -d /etc/myapp/oracle-wallet
sudo chown -R root:myapp /etc/myapp/oracle-wallet
sudo chmod 0750 /etc/myapp/oracle-wallet
sudo chmod 0640 /etc/myapp/oracle-wallet/*
```

---

# Rotazione delle password

Le password devono poter essere cambiate in modo controllato.

Procedura generale:

1. genera una nuova password casuale;
2. aggiorna la password dell’utente database;
3. aggiorna il wallet o il secret manager;
4. riavvia o ricarica l’applicazione;
5. verifica la connessione;
6. revoca o rimuovi la password precedente;
7. controlla i log senza esporre il segreto.

Esempio Oracle:

```sql
ALTER USER MYAPP_USER
IDENTIFIED BY "NuovaPasswordLungaCasuale";
```

Dopo il cambio della password, aggiorna la credenziale nel wallet secondo la procedura prevista dalla versione Oracle utilizzata.

Riavvia quindi il servizio:

```sh
sudo systemctl restart myapp.service
```

Verifica lo stato:

```sh
sudo systemctl status myapp.service
sudo journalctl -u myapp.service -n 100
```

---

# Generare password robuste

Puoi generare password casuali su Linux con:

```sh
openssl rand -base64 32
```

Oppure:

```sh
tr -dc 'A-Za-z0-9_@%+=-' < /dev/urandom | head -c 32
printf '\n'
```

Una password efficace dovrebbe essere:

- lunga almeno 24 caratteri;
- unica per ogni servizio;
- generata casualmente;
- non riutilizzata;
- conservata in un secret manager o in un sistema protetto;
- ruotata in base alle policy aziendali.

---

# Checklist di sicurezza

## Archiviazione

- [ ] Le password non sono nel codice sorgente.
- [ ] Le password non sono presenti in repository Git.
- [ ] Le password non sono nei file `.bashrc`, `.zshrc` o `.profile`.
- [ ] Le password non sono nel crontab.
- [ ] Le password non sono passate nella riga di comando.
- [ ] Le password non sono scritte nei log.
- [ ] I backup contenenti segreti sono protetti.

## Linux

- [ ] L’applicazione usa un utente Unix dedicato.
- [ ] L’utente applicativo non dispone di privilegi `sudo`.
- [ ] L’utente applicativo non può effettuare login SSH diretto.
- [ ] Le directory dei segreti hanno permessi restrittivi.
- [ ] I file dei segreti hanno permessi `0640` o `0600`.
- [ ] Le directory dei segreti hanno permessi `0750` o `0700`.

## Oracle

- [ ] L’applicazione usa un utente Oracle dedicato.
- [ ] L’utente Oracle non ha privilegi DBA.
- [ ] Sono assegnati soltanto i privilegi minimi necessari.
- [ ] È configurato Oracle Wallet o Secure External Password Store.
- [ ] Il wallet non è incluso in Git.
- [ ] Il wallet è protetto da permessi Unix.
- [ ] Le connessioni usano TLS quando richiesto.
- [ ] È definita una procedura di rotazione delle credenziali.

---

# Riepilogo

Per servizi Linux che si connettono a Oracle Database, una struttura ordinata può essere:

```text
/etc/myapp/
+-- environment
+-- oracle/
¦   +-- sqlnet.ora
¦   +-- tnsnames.ora
+-- wallet/
    +-- cwallet.sso
    +-- ewallet.p12

/opt/myapp/
+-- bin/
    +-- oracle-batch.sh

/etc/systemd/system/
+-- myapp.service
```

La scelta consigliata per Oracle è usare un Oracle Wallet e connettersi tramite alias:

```sh
sqlplus /@ORCLPDB1
```

anziché usare password in chiaro:

```sh
sqlplus MYAPP_USER/password-riservata@ORCLPDB1
```

Questo riduce il rischio di esposizione delle credenziali in script, file Cron, configurazioni applicative, cronologia shell e lista dei processi.
