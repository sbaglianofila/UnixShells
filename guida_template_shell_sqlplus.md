# Guida completa ai template Shell e SQLPlus

## Obiettivo della guida

Questa guida descrive come usare i template introdotti nel progetto per:

- standardizzare le shell batch
- separare la logica Shell dalla logica SQL
- centralizzare logging, utility, mail e configurazione environment
- rendere più semplice la manutenzione operativa
- ridurre errori in esecuzione e facilitare il troubleshooting

I file di riferimento attuali sono:

- `template_shell.sh`
- `template_sqlplus_launcher.sh`
- `lib/log_msg.sh`
- `lib/utility.sh`
- `lib/mail_util.sh`
- `lib/env_example.sh`

---

# 1. Architettura generale

L’idea generale è separare le responsabilità:

## 1.1 Shell template
La shell template gestisce:
- parsing parametri
- logging
- creazione file `.log` e `.err`
- invocazione di fasi
- controlli preliminari
- eventuali notifiche mail
- orchestrazione generale del job

## 1.2 Utility condivise
Le librerie `lib/*.sh` contengono funzioni comuni riusabili:
- log
- mail
- check operativi
- connessione Oracle
- controlli di single instance

## 1.3 SQL separato dalla shell
Con `template_sqlplus_launcher.sh`:
- la shell non contiene SQL inline
- il codice SQL risiede in file `.sql` separati
- la shell fa solo da “launcher”
- il file SQL contiene tutta la logica Oracle

Questo approccio è fortemente consigliato perché mantiene il codice più pulito e leggibile.

---

# 2. File disponibili

## 2.1 `template_shell.sh`

È il template generale per shell batch multi-fase.

Funzioni principali:
- supporta `main()`
- espone `usage()`
- gestisce fasi (`fase_1`, `fase_2`, `fase_3`, ...)
- produce `log` e `err`
- esegue controlli iniziali
- supporta invio mail
- supporta delay opzionale di avvio
- supporta chiamata di script esterni

### Quando usarlo
Usalo quando vuoi costruire un job shell strutturato con:
- più fasi
- log standardizzati
- error handling chiaro
- integrazione con utility comuni

---

## 2.2 `template_sqlplus_launcher.sh`

È un launcher dedicato per eseguire file SQL esterni via `sqlplus -s`.

Funzioni principali:
- riceve un file `.sql`
- opzionalmente riceve parametri
- esegue `sqlplus -s`
- separa la logica SQL dalla shell
- produce `.log` e `.err`
- verifica la configurazione Oracle

### Quando usarlo
Usalo quando vuoi:
- chiamare query SQL
- eseguire procedure/package PL/SQL
- fare spool
- evitare blocchi SQL direttamente dentro la shell

---

## 2.3 `lib/log_msg.sh`

Libreria per logging standardizzato.

In generale contiene funzioni come:
- `log_msg`
- `log_info`
- `log_warn`
- `log_err`

### Scopo
Permette di centralizzare il formato del log e uniformare il comportamento di tutti gli script.

---

## 2.4 `lib/utility.sh`

Libreria per funzioni operative condivise.

Nel contesto del template contiene o può contenere funzioni come:
- `single_instance_check`
- `check_oracle_connection`

### Scopo
Evitare duplicazione di funzioni trasversali nei vari script.

---

## 2.5 `lib/mail_util.sh`

Libreria per invio mail.

Funzioni tipiche:
- `send_mail_notification`
- `send_error_mail`

### Scopo
Permettere alle shell di inviare notifiche standard senza duplicare codice.

---

## 2.6 `lib/env_example.sh`

Esempio di file environment da caricare via `source`.

Serve a centralizzare configurazioni come:
- connection string Oracle
- parametri di job
- percorsi base
- indirizzi mail
- timeout
- delay di avvio

---

# 3. Come usare `template_shell.sh`

## 3.1 Avvio base

Esempi:
```sh
./template_shell.sh
```

Esegue tutte le fasi disponibili.

```sh
./template_shell.sh 2 3
```

Esegue solo le fasi dalla 2 alla 3.

---

## 3.2 Concetto di fase

Le funzioni:
- `fase_1`
- `fase_2`
- `fase_3`

rappresentano step logici del job.

Esempi di possibili fasi:
- estrazione dati
- validazione file
- chiamata a script esterno
- caricamento dati
- invio notifica finale

Il dispatcher `run_phase()` richiama la funzione corretta in base al numero fase.

---

## 3.3 Gestione parametri

La funzione `validate_parameters()` controlla:
- numero parametri
- valori numerici
- ordine corretto (`fase_inizio <= fase_fine`)
- rispetto dei limiti consentiti

Convenzione attuale:
- errori di template/pre-check: exit code > 100
- errori di business/fase: exit code = numero della fase

Questa convenzione è molto utile per il monitoraggio batch.

---

## 3.4 Variabili condivise nel template

Nel `main()` vengono valorizzate variabili accessibili anche dalle fasi:

- `SCRIPT_NAME`
- `TIMESTAMP`
- `PID`
- `LOG_FILE`
- `ERR_FILE`
- `INFO_FILE`
- `JOB_ID`

Queste variabili non sono `local`, proprio per permettere alle singole fasi di usarle.

---

## 3.5 Concetto di `JOB_ID`

`JOB_ID` è l’identificativo univoco della singola esecuzione del job.

Formato:
```sh
JOB_ID="${SCRIPT_NAME}_${TIMESTAMP}_${PID}"
```

### A cosa serve
Serve per:
- distinguere due run diverse dello stesso script
- correlare log, err, mail e messaggi
- identificare in modo univoco una sessione batch
- fare troubleshooting in modo più rapido

### Esempio
Se lanci due volte lo stesso script, avrai:
- `template_shell_20260901_120102_1234`
- `template_shell_20260901_120132_9876`

Quindi non è un doppione del nome script: rappresenta la singola run.

---

## 3.6 Gestione log e stderr

Nel `main()` viene eseguito:

```sh
exec 3>&1
exec >"$LOG_FILE" 2>"$ERR_FILE"
```

### Significato
- `STDOUT` va nel file `.log`
- `STDERR` va nel file `.err`
- il file descriptor `3` mantiene una copia dell’output video originale

### Vantaggio
Anche dopo la redirezione puoi scrivere a video con:
```sh
echo "messaggio" >&3
```

Questo è utile per mostrare all’operatore:
- avvio job
- file di log
- fine job
- eventuali messaggi essenziali

---

## 3.7 Funzione `print_startup_info()`

Questa funzione stampa informazioni iniziali su log e, in parte, a video.

Informazioni tipiche:
- riga di comando
- utente
- pid
- host
- log file
- err file
- job id

### Perché è utile
Permette di avere sempre un’intestazione tecnica standard per ogni run.

---

## 3.8 Funzione `print_end_info()`

Questa funzione stampa informazioni di chiusura:
- `OK`
- `ERRORE`

Stampa anche i riferimenti ai file log ed err.

### Perché è utile
Chiude in modo uniforme il job, rendendo i log più leggibili.

---

## 3.9 Funzione `send_standard_error_mail()`

È una funzione helper che serve a non sporcare il `main()`.

Costruisce una mail standard di errore contenente:
- subject
- motivo
- nome script
- host
- job id
- log file
- err file
- eventuale testo extra

Inoltre allega automaticamente:
- `ERR_FILE`
- `LOG_FILE`

### Vantaggio
Centralizza la costruzione della mail di errore e rende il codice del `main()` più pulito.

---

## 3.10 Funzione `apply_start_delay()`

Questa funzione applica un ritardo opzionale all’avvio del job.

### Obiettivo
Consentire all’operatore di interrompere un job partito per errore prima che esegua azioni potenzialmente impattanti.

### Logica
Usa due possibili variabili:

1. `JOB_START_DELAY_SEC_SHELL`
2. `JOB_START_DELAY_SEC`

La priorità è:
- prima la variabile locale shell
- poi fallback sul valore environment

### Nota importante
Se `JOB_START_DELAY_SEC_SHELL=0`, stai dicendo esplicitamente:
- nessun delay locale
- nessun fallback env

Se invece vuoi che il fallback avvenga, la variabile locale deve essere vuota:
```sh
JOB_START_DELAY_SEC_SHELL=""
```

### Esempio
```sh
JOB_START_DELAY_SEC_SHELL=30
```

oppure in env:
```sh
export JOB_START_DELAY_SEC=15
```

---

## 3.11 Esempio di chiamata a shell esterna

Nel template è stato inserito anche un esempio commentato dentro `fase_1()`.

Esempio:
```sh
./script_esterno.sh "$JOB_ID" "elaborazione_tipoA" "/percorso/file.csv"
rc_esterno=$?

if [ "$rc_esterno" -ne 0 ]; then
    log_err "script_esterno.sh terminato con errore (rc=$rc_esterno)"
    return 97
fi
```

### Best practice
Quando chiami una shell esterna:
- passa sempre i parametri tra doppi apici
- passa `JOB_ID` se può essere utile al tracciamento
- controlla sempre l’exit code
- fai `return` o `exit` esplicito se fallisce

### Importante
Chiama la shell come comando:
```sh
./script_esterno.sh ...
```
e non con:
```sh
source ./script_esterno.sh
```

per evitare interferenze di variabili nel processo chiamante.

---

# 4. Come usare `template_sqlplus_launcher.sh`

## 4.1 Obiettivo

Questo template serve a lanciare file SQL esterni mantenendo:
- shell semplice
- SQL separato
- log standard

È particolarmente utile quando lavori spesso con:
- query
- spool
- procedure PL/SQL
- script SQL batch

---

## 4.2 Esempio di utilizzo

```sh
./template_sqlplus_launcher.sh ./sql/mia_query.sql
```

oppure:

```sh
./template_sqlplus_launcher.sh ./sql/mia_query.sql 20260901 REPARTO1
```

I parametri aggiuntivi vengono passati al file SQL come:
- `&1`
- `&2`
- `&3`
- ...

---

## 4.3 Esecuzione SQLPlus

La chiamata usata nel template è:

```sh
sqlplus -s "$ORACLE_CONNECT_STRING" @"$sql_file" "$@"
```

### Significato
- `-s`: modalità silent
- `"$ORACLE_CONNECT_STRING"`: connessione Oracle
- `@"$sql_file"`: esecuzione del file SQL
- `"$@"`: passaggio dei parametri al file SQL

---

## 4.4 Perché conviene questo approccio

È un’ottima soluzione perché:
- non lasci SQL dentro la shell
- rendi i file `.sql` indipendenti e riusabili
- semplifichi la shell
- semplifichi il versioning delle query
- migliori la leggibilità generale

---

## 4.5 Best practice per il file SQL

Nel file SQL conviene mettere sempre in testa qualcosa di simile:

```sql
whenever sqlerror exit sql.sqlcode
whenever oserror exit 99

set echo off
set feedback off
set heading off
set verify off
set pagesize 0
set linesize 32767
```

### Perché
- `whenever sqlerror` fa propagare l’errore Oracle alla shell
- `whenever oserror` gestisce errori OS/spool/file
- i `set` riducono rumore e rendono l’output più controllato

---

## 4.6 Esempio file SQL per query/spool

```sql
whenever sqlerror exit sql.sqlcode
whenever oserror exit 99

set echo off
set feedback off
set heading off
set verify off
set pagesize 0
set linesize 32767

spool output.txt

select 'CIAO' from dual;

spool off
exit 0
```

---

## 4.7 Esempio file SQL per procedura

```sql
whenever sqlerror exit sql.sqlcode
whenever oserror exit 99

set serveroutput on
set feedback off

exec mio_package.mia_procedura('&1', '&2');

exit 0
```

---

## 4.8 Parametri nel file SQL

Se chiami:
```sh
./template_sqlplus_launcher.sh ./sql/mia_query.sql 20260901 REPARTO1
```

nel SQL puoi usare:
- `&1` = `20260901`
- `&2` = `REPARTO1`

Ad esempio:

```sql
select '&1', '&2' from dual;
```

---

## 4.9 Sovrapposizione con shell chiamante

Una domanda importante è: il launcher SQLPlus può interferire con la shell chiamante?

## Risposta breve
No, se lo lanci come processo separato:
```sh
./template_sqlplus_launcher.sh ...
```

## Perché
- gira in un processo figlio
- non modifica le variabili del padre
- ha log propri
- genera `JOB_ID`, `LOG_FILE`, `ERR_FILE` propri

## Attenzione
Evita di lanciarlo con:
```sh
source ./template_sqlplus_launcher.sh ...
```

perché in quel caso le variabili vivrebbero nello stesso processo.

---

# 5. Environment file

## 5.1 A cosa serve

Il file environment serve a centralizzare parametri di configurazione condivisi.

Esempio tipico:
- connessione Oracle
- destinatari mail
- directory
- timeout
- delay di avvio

---

## 5.2 Esempio

File: `lib/env_example.sh`

Contiene ad esempio:
```sh
export ORACLE_CONNECT_STRING="utente/password@SID"
export BASE_DATA_DIR="/dati/elaborazioni"
export ARCHIVE_DIR="/dati/archive"
export MAIL_RECIPIENTS="group_am@example.com altro_dest@example.com"
export JOB_CUSTOM_PARAM="ELAB_MENSILE"
export JOB_TIMEOUT_SEC=5400
export JOB_MAX_ATTEMPTS=3
```

### Uso consigliato
Copia l’esempio:
```sh
cp ./lib/env_example.sh ./lib/env.sh
```

poi personalizzalo.

---

## 5.3 Come viene caricato

Nei template è previsto il caricamento opzionale:

```sh
if [ -f "./lib/env.sh" ]; then
    source "./lib/env.sh"
fi
```

Quindi:
- se il file esiste, viene caricato
- se non esiste, il template può continuare
- se il `source` fallisce, lo script esce con errore

---

# 6. Best practice generali

## 6.1 Separare shell e SQL
Best practice consigliata:
- la shell orchestra
- il file SQL esegue la logica database

Questo rende tutto più chiaro.

---

## 6.2 Quotare sempre i parametri
Quando passi variabili a comandi o script esterni, usa:
```sh
"$VAR"
"$@"
```

Questo evita problemi con:
- spazi
- caratteri speciali
- word splitting

---

## 6.3 Controllare sempre l’exit code
Dopo una chiamata importante:
```sh
comando_esterno
rc=$?

if [ "$rc" -ne 0 ]; then
    ...
fi
```

---

## 6.4 Usare funzioni helper
Se una logica si ripete:
- logging finale
- costruzione mail
- delay
- controllo ambiente

conviene incapsularla in una funzione separata.

---

## 6.5 Tenere il `main()` pulito
Il `main()` dovrebbe restare leggibile e breve:
- setup
- pre-check
- orchestrazione fasi
- chiusura

La logica dettagliata va spostata in funzioni dedicate.

---

## 6.6 Non usare `source` per eseguire job esterni
Usa:
```sh
./script.sh
```

non:
```sh
source ./script.sh
```

a meno che il tuo obiettivo sia proprio condividere lo stesso ambiente di processo.

---

## 6.7 Standardizzare log e mail
Avere:
- stessi nomi log
- stessi subject mail
- stessi campi minimi

aiuta tantissimo operations e supporto.

---

# 7. Esempi di utilizzo pratico

## 7.1 Job shell multi-fase
```sh
./template_shell.sh
./template_shell.sh 1 2
```

---

## 7.2 Job con delay locale
Nel template o in una shell derivata:
```sh
JOB_START_DELAY_SEC_SHELL=30
```

---

## 7.3 Job con delay da environment
Nel file `env.sh`:
```sh
export JOB_START_DELAY_SEC=15
```

---

## 7.4 Chiamata script esterno
Dentro una fase:
```sh
./script_esterno.sh "$JOB_ID" "TIPO_A" "/tmp/file.csv"
```

---

## 7.5 Chiamata SQLPlus
```sh
./template_sqlplus_launcher.sh ./sql/carica_dati.sql 20260901 REPARTO1
```

---

# 8. Miglioramenti futuri consigliati

Possibili evoluzioni:
- aggiunta di `trap` per SIGINT/SIGTERM
- funzione `--help`
- directory dedicata ai log
- template SQL standard aggiuntivo
- validazioni più forti sui parametri
- check presenza binari (`sqlplus`, `mailx`, ecc.)
- README per convenzioni exit code

---

# 9. Conclusione

I template introdotti permettono di costruire shell batch più ordinate, robuste e manutenibili.

## In sintesi
- `template_shell.sh` gestisce job multi-fase
- `template_sqlplus_launcher.sh` lancia file SQL esterni
- `lib/*.sh` centralizzano funzioni condivise
- `env.sh` centralizza configurazione
- `JOB_ID` aiuta il tracciamento
- `apply_start_delay()` protegge da partenze accidentali
- `send_standard_error_mail()` standardizza le notifiche
- la separazione shell/SQL è la scelta consigliata

Questo approccio è adatto a contesti operativi reali, con attenzione a leggibilità, standardizzazione e troubleshooting.
