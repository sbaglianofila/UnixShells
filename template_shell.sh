#!/bin/bash

###############################################################################
# TEMPLATE SHELL RIUTILIZZABILE
#
# Questo script:
# - espone una main()
# - gestisce una Usage
# - esegue una o più fasi
# - redirige STDOUT su file .log
# - redirige STDERR su file .err
# - carica da source una libreria esterna di logging
#
# ESEMPI:
#   ./template_shell.sh
#       Esegue tutte le fasi disponibili
#
#   ./template_shell.sh 2 3
#       Esegue solo le fasi dalla 2 alla 3
#
# FILE DI OUTPUT:
#   Se lo script si chiama template_shell.sh, genera file tipo:
#     template_shell_20260828_180100_12345.log
#     template_shell_20260828_180100_12345.err
#
# NOTA IMPORTANTE:
#   Le chiamate log_info/log_warn/log_err scrivono su STDOUT o STDERR.
#   Siccome in main() facciamo:
#       exec >"$LOG_FILE" 2>"$ERR_FILE"
#   allora:
#     - tutto ciò che va su STDOUT finisce nel file .log
#     - tutto ciò che va su STDERR finisce nel file .err
###############################################################################

#####################################
############################# usage #####################################
usage() {
    echo "Usage: $0 [FaseIni] [FaseFin]"
    echo "Se FaseIni e FaseFin sono omessi, vengono eseguite tutte le fasi."
    echo
    echo "Esempi:"
    echo "  $0       -> esegue tutte le fasi"
    echo "  $0 1 2   -> esegue dalla fase 1 alla fase 2"
}

# Carica il file di environment opzionale, se presente.
# Qui puoi definire variabili di contesto come:
#   ORACLE_CONNECT_STRING
#   MAIL_RECIPIENTS
#   BASE_DATA_DIR
#   ARCHIVE_DIR
#   JOB_CUSTOM_PARAM
#   ecc.
#
# Se il file non esiste, lo script prosegue senza bloccare l'esecuzione.
if [ -f "./lib/env.sh" ]; then
    if ! source "./lib/env.sh"; then
        echo "Errore nel caricare environment (./lib/env.sh)" >&2
        exit 109
    fi
fi

# Carica la libreria esterna di logging.
#
# Il file ./lib/log_msg.sh definisce:
#   - log_msg
#   - log_info
#   - log_warn
#   - log_err
#
# Se il source fallisce, lo script termina subito.
if ! source "./lib/log_msg.sh"; then
    echo "Errore nel caricare funzione di log (./lib/log_msg.sh)" >&2
    exit 110
fi

# Carica libreria utility con funzioni di utility come check single instance e connessione Oracle
if ! source "./lib/utility.sh"; then
    echo "Errore nel caricare funzione utility (./lib/utility.sh)" >&2
    exit 111
fi

# Carica libreria mail con funzioni riusabili per invio notifiche e allegati.
if ! source "./lib/mail_util.sh"; then
    echo "Errore nel caricare funzione mail (./lib/mail_util.sh)" >&2
    exit 112
fi

# Ogni funzione fase può leggere le variabili valorizzate in main()
# purché NON siano dichiarate local.
#
# Esempi di variabili condivise:
#   SCRIPT_NAME
#   TIMESTAMP
#   PID
#   LOG_FILE
#   ERR_FILE
#   JOB_ID
#
# In questo modo definisci i dati una sola volta in main()
# e li riusi in tutte le fasi.
fase_1() {
    log_info "Esecuzione fase 1 (JOB_ID=$JOB_ID)"
    # Esempio:
    # local input_file="/tmp/file1.txt"
    # log_info "Leggo il file $input_file"

    # ESEMPIO: Chiamata a una shell esterna con passaggio di parametri:
    # Supponiamo di avere un file "script_esterno.sh" da chiamare.
    # È buona pratica passare JOB_ID o altri parametri di contesto!
    #
    # script_esterno.sh "$JOB_ID" "parametro1" "parametro2"
    #
    # Esempio concreto:
    # ./script_esterno.sh "$JOB_ID" "elaborazione_tipoA" "/percorso/file.csv"
    #
    # Dopo la chiamata puoi gestire errori e logging:
    # rc_esterno=$?
    # if [ "$rc_esterno" -ne 0 ]; then
    #     log_err "script_esterno.sh terminato con errore (rc=$rc_esterno)"
    #     return 97
    # fi
}

fase_2() {
    log_info "Esecuzione fase 2 (JOB_ID=$JOB_ID)"
    # Esempio:
    # log_warn "La fase 2 usa una configurazione temporanea"
}

fase_3() {
    log_info "Esecuzione fase 3 (JOB_ID=$JOB_ID)"
    # Esempio:
    # log_err "Errore funzionale nella fase 3"
}

run_phase() {
    local fase="$1"

    case "$fase" in
        1) fase_1 ;;
        2) fase_2 ;;
        3) fase_3 ;;
        *)
            log_err "Fase non gestita: $fase"
            return 1
            ;;
    esac
}

validate_parameters() {
    # Sono ammessi:
    #   0 parametri -> esegue tutte le fasi
    #   2 parametri -> esegue solo l'intervallo richiesto
    #
    # Esempi:
    #   ./template_shell.sh
    #   ./template_shell.sh 1 3
    #
    # Convenzione codici di uscita:
    # - errori "di sistema"/template (parametri, pre-check, ecc.) > 100
    # - errori "di processo" (fasi) = numero fase (1..N)
    #
    if [ "$#" -gt 2 ]; then
        log_err "Numero parametri non valido."
        usage
        exit 101
    fi

    fase_inizio="${1:-$FASE_MIN}"
    fase_fine="${2:-$FASE_MAX}"

    if ! [[ "$fase_inizio" =~ ^[0-9]+$ ]]; then
        log_err "FaseIni deve essere numerico."
        usage
        exit 102
    fi

    if ! [[ "$fase_fine" =~ ^[0-9]+$ ]]; then
        log_err "FaseFin deve essere numerico."
        usage
        exit 102
    fi

    if (( fase_inizio > fase_fine )); then
        log_err "FaseIni deve essere minore o uguale a FaseFin."
        usage
        exit 103
    fi

    if (( fase_inizio < FASE_MIN || fase_fine > FASE_MAX )); then
        log_err "Fasi ammesse da $FASE_MIN a $FASE_MAX."
        usage
        exit 104
    fi
}

print_startup_info() {
    # ========================================================================
    # Stampa info utili di avvio/job sia su log che a video (stdout vero, non rediretto).
    # Alcuni messaggi saranno duplicati: uno finisce nel file .log (tramite log_info),
    # l'altro appare immediatamente a video tramite echo >&3.
    #
    # NB: il fd 3 è aperto come copia dello stdout "vero", vedi setup in main.
    # ========================================================================
    log_info "Riga di comando: $0 $*"
    log_info "Utente di lancio: ${USER:-$(whoami 2>/dev/null)}"
    log_info "PID: $$, PPID: ${PPID:-unknown}, Host: $(hostname 2>/dev/null)"
    log_info "Log file: $LOG_FILE"
    log_info "Err file: $ERR_FILE"
    log_info "Info file: $INFO_FILE"
    log_info "JOB_ID: $JOB_ID"

    # Print solo i messaggi d'avvio principali a video (personalizzabile)
    echo "Avvio: $(date +%Y-%m-%dT%H:%M:%S) - $0 $*" >&3
    echo "Log file: $LOG_FILE" >&3
    echo "Per dettagli vedi log." >&3
}

print_end_info() {
    # ========================================================================
    # Stampa messaggi di fine sia su log che su video.
    #
    # Uso:
    #   print_end_info           -> default OK
    #   print_end_info OK        -> OK
    #   print_end_info ERRORE    -> ERRORE
    #
    # NB: usa fd 3 per stampare a video anche se stdout è rediretto su file.
    # ========================================================================
    local esito="${1:-OK}"

    if [ "$esito" = "OK" ]; then
        log_info "FINE JOB: OK"
        echo "FINE JOB: OK" >&3
    else
        log_err "FINE JOB: ERRORE"
        echo "FINE JOB: ERRORE" >&3
    fi

    echo "Log file: $LOG_FILE" >&3
    echo "Err file: $ERR_FILE" >&3
}

send_standard_error_mail() {
    # Helper per tenere il template pulito: costruisce una mail di errore "standard"
    # con campi ricorrenti (host, JOB_ID, LOG/ERR) e allega automaticamente
    # $ERR_FILE e $LOG_FILE (se presenti).
    #
    # Parametri:
    #   $1 = subject (già completo, es: "[ERRORE] ...")
    #   $2 = reason  (testo breve della motivazione, es: "Connessione Oracle fallita")
    #   $3 = extra   (testo addizionale opzionale, può essere multilinea)
    #
    # Note:
    # - usa send_error_mail (lib/mail_util.sh)
    # - i file vengono passati come lista separata da ';' (come richiesto dalla libreria)
    local subject="$1"
    local reason="$2"
    local extra="${3:-}"

    send_error_mail \
        "$subject" \
        "${reason}
Script: $0
Host: $(hostname 2>/dev/null)
JOB_ID: $JOB_ID
Log file: $LOG_FILE
Err file: $ERR_FILE
$extra" \
        "${ERR_FILE};${LOG_FILE}"
}

apply_start_delay() {
    # Gestisce il ritardo opzionale di partenza del job.
    #
    # Obiettivo:
    # - dare un piccolo margine per interrompere manualmente la shell
    #   in caso di lancio accidentale
    #
    # Priorità configurazione:
    # 1) JOB_START_DELAY_SEC_SHELL  -> override definito nella singola shell
    # 2) JOB_START_DELAY_SEC        -> fallback da environment comune (es. ./lib/env.sh)
    #
    # Comportamento:
    # - se il valore finale è vuoto o pari a 0 -> nessun ritardo
    # - se il valore finale è > 0 -> fa sleep N secondi
    #
    # Note tecniche:
    # - questa funzione va chiamata DOPO:
    #     exec 3>&1
    #     exec >"$LOG_FILE" 2>"$ERR_FILE"
    #   così:
    #   * il messaggio di delay viene scritto nel log
    #   * il messaggio a video via fd 3 funziona correttamente
    local delay_shell="${JOB_START_DELAY_SEC_SHELL:-}"
    local delay_env="${JOB_START_DELAY_SEC:-}"
    local delay_final="$delay_shell"

    if [ -z "$delay_final" ]; then
        delay_final="$delay_env"
    fi

    if [ -n "$delay_final" ] && [ "$delay_final" -gt 0 ] 2>/dev/null; then
        log_info "Ritardo avvio richiesto: $delay_final secondi. Puoi interrompere ora con CTRL+C se la partenza è accidentale."
        echo "Sleep $delay_final secondi... (CTRL+C per interrompere)" >&3
        sleep "$delay_final"
    fi
}

# Variabile che permette il delay nel lancio della shell.
# Se valorizzato (0 o maggiore) mantiene quel valore, se invece è NULLO (JOB_START_DELAY_SEC_SHELL="")
# allora fa Fallback su equello a livello di Environemnt(JOB_START_DELAY_SEC)
JOB_START_DELAY_SEC_SHELL=0

main() {
    # ===========================================================================================
    # Esempio di utilizzo delle utility esterne nel template principale.
    #
    # Esempi di invio mail disponibili dopo il source di ./lib/mail_util.sh:
    #
    # Possibilità di inserire un delay opzionale all'avvio (es. per sicurezza per stop manuale).
    # Se la variabile JOB_START_DELAY_SEC>0, il programma farà sleep di quel valore in secondi.
    # Puoi impostarla in ./lib/env.sh oppure da linea di comando:
    #   export JOB_START_DELAY_SEC=30
    # (se non definita o zero, non introduce alcun ritardo.)
    #
    # Invio esplicito generico:
    #   send_mail_notification \
    #       "[INFO] Job ${JOB_ID} terminato" \
    #       "Elaborazione completata correttamente" \
    #       "$LOG_FILE"
    #
    # Invio in caso di errore con allegati multipli:
    #   send_error_mail \
    #       "[ERRORE] Job ${JOB_ID}" \
    #       "Errore durante l'elaborazione. Vedi allegati." \
    #       "$ERR_FILE;$LOG_FILE"
    #
    # Destinatari:
    # - di default usa DEFAULT_MAIL_RECIPIENTS definito nella libreria
    # - opzionalmente lo script chiamante può fare:
    #       export MAIL_RECIPIENTS="am@azienda.it ops@azienda.it"
    #
    # Nota su tracciamento errori "pre-fasi":
    # - i controlli di single instance e connessione Oracle vengono eseguiti DOPO
    #   la creazione e la redirezione dei file .log/.err, così eventuali errori
    #   risultano tracciati nei file e (se desiderato) notificabili via mail.
    # ===========================================================================================

    # Variabili condivise tra tutte le funzioni dello script.
    # NON usiamo "local" perché devono essere leggibili anche dentro fase_1/fase_2/fase_3.
    SCRIPT_NAME="$(basename "$0" .sh)"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    PID="$$"

    # Nomi file di output:
    #   STDOUT -> .log
    #   STDERR -> .err
    LOG_FILE="${SCRIPT_NAME}_${TIMESTAMP}_${PID}.log"
    ERR_FILE="${SCRIPT_NAME}_${TIMESTAMP}_${PID}.err"
    INFO_FILE="${SCRIPT_NAME}.err"


    # Identificativo univoco del job/batch corrente.
    #
    # Costruzione: JOB_ID = <nome-script>_<timestamp_inizio>_<pid>
    #
    # JOB_ID viene creato PRIMA della creazione dei file log/err e riusato:
    # - per formare i nomi di LOG_FILE ed ERR_FILE
    # - per comparire nei log, email, warning, subject mail, messaggi di errore
    # - in qualunque scenario sia necessario identificare/sigillare univocamente la sessione
    #
    # Concetto: puoi avere più istanze dello stesso script che girano anche in parallelo,
    # ognuna con il suo LOG_FILE/ERR_FILE: JOB_ID ti dà la chiave univoca di quella run.
    #
    # Esempio:
    #   ./template_shell.sh           (run alle 12:01:02, pid=1234)
    #   => JOB_ID=template_shell_20260901_120102_1234
    #
    #   ./template_shell.sh 1 3       (stesso script lanciato 30s dopo, pid=9876)
    #   => JOB_ID=template_shell_20260901_120132_9876
    #
    # Quindi:
    # - NON è un doppione: serve a identificare sessione-run singola, non solo "nome script".
    # - se vuoi puoi anche esportarla (es: per usarla nei subjob/step/file output temporanei)
    # - aiuta a fare "tracing" su incidenti/mails/analisi logs.
    #
    JOB_ID="${SCRIPT_NAME}_${TIMESTAMP}_${PID}"

    # Queste costanti definiscono il range di fasi gestite dal template.
    # Se aggiungi fase_4, fase_5, ecc. ricordati di aggiornare FASE_MAX.
    FASE_MIN=1
    FASE_MAX=3

    # Prima di redirigere tutto, salviamo una copia dello stdout originale su fd 3
    # così da poter stampare su video anche dopo la ridirezione.
    exec 3>&1

    # Da questo punto in poi:
    # - tutto lo standard output finisce nel file $LOG_FILE
    # - tutto lo standard error finisce nel file $ERR_FILE
    #
    # Conseguenza pratica:
    # - log_info  -> va nel .log
    # - log_warn  -> dipende da come lo implementi nella libreria
    # - log_err   -> se scritto su STDERR va nel .err
    # - echo normale -> va nel .log
    # - echo "...errore..." >&2 -> va nel .err
    exec >"$LOG_FILE" 2>"$ERR_FILE"

    # La validazione dei parametri è stata estratta in una funzione dedicata
    # per mantenere il main più pulito e leggibile.
    validate_parameters "$@"

    log_info "Avvio elaborazione: fasi da $fase_inizio a $fase_fine"
    print_startup_info "$@"

    # Applica l'eventuale ritardo di partenza, con priorità:
    # - JOB_START_DELAY_SEC_SHELL (specifico della shell)
    # - JOB_START_DELAY_SEC       (fallback environment)
    apply_start_delay

    # Controlla istanza unica (dopo la redirezione log/err, così l'evento resta tracciato).
    log_info "Controllo configurazione environment completato."
    if ! single_instance_check; then
        log_err "Script già in esecuzione (single instance check fallito). Uscita."

        # Prima scrivo fine job su log, poi mando la mail, così l'allegato contiene anche la chiusura.
        print_end_info "ERRORE"

        send_standard_error_mail \
            "[ERRORE] $JOB_ID - istanza già in esecuzione" \
            "Rilevata esecuzione contemporanea dello script."
        exit 120
    fi

    # Verifica connessione Oracle (dopo la redirezione log/err, così l'evento resta tracciato).
    if ! check_oracle_connection; then
        log_err "Connessione Oracle fallita. Uscita."

        # Prima scrivo fine job su log, poi mando la mail, così l'allegato contiene anche la chiusura.
        print_end_info "ERRORE"

        send_standard_error_mail \
            "[ERRORE] $JOB_ID - connessione Oracle fallita" \
            "Connessione Oracle non disponibile."
        exit 121
    fi

    # Loop principale:
    # esegue in sequenza tutte le fasi richieste.
    for ((fase=fase_inizio; fase<=fase_fine; fase++)); do
        log_info "Inizio fase $fase"

        # Eseguo la fase e salvo l'esito in una variabile.
        # Questo consente di:
        # - fare log esplicito dell'exit code
        # - decidere in modo più leggibile cosa fare (mail/exit) in caso di errore
        run_phase "$fase"
        phase_rc=$?

        if [ "$phase_rc" -ne 0 ]; then
            log_err "Fase $fase terminata con errore (rc=$phase_rc)."

            # Prima chiudo "pulitamente" il job lato log (così nei file allegati c'è anche la fine job).
            print_end_info "ERRORE"

            # Notifica mail automatica in caso di errore fase.
            # Se ERR_FILE/LOG_FILE esistono già, vengono allegati entrambi.
            send_standard_error_mail \
                "[ERRORE] $JOB_ID - fase $fase (rc=$phase_rc)" \
                "Errore durante l'esecuzione della fase $fase." \
                "RC fase: $phase_rc"

            # In convenzione, l'errore di fase deve ritornare il numero della fase.
            exit "$fase"
        fi

        log_info "Fine fase $fase"
    done

    # Esempio opzionale di mail esplicita a fine job OK.
    # Decommentare se si desidera inviare una notifica anche in caso di successo.
    #
    # send_mail_notification \
    #     "[OK] ${JOB_ID}" \
    #     "Elaborazione completata correttamente.
    # Host: $(hostname 2>/dev/null)
    # JOB_ID: ${JOB_ID}
    # Log file: ${LOG_FILE}
    # Err file: ${ERR_FILE}" \
    #     "${LOG_FILE}"
    #
    print_end_info "OK"
}

main "$@"
