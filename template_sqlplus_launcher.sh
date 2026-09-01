#!/bin/bash

###############################################################################
# TEMPLATE LANCIO SQLPLUS ESTERNO
#
# Obiettivo:
# - tenere la shell separata dalla logica SQL
# - invocare sempre sqlplus in modalità silent (-s)
# - eseguire un file .sql esterno
# - lasciare nel file SQL tutta la logica applicativa:
#     * spool
#     * select
#     * exec procedure/package
#     * exit code SQL/OS
#
# Approccio:
#   ./template_sqlplus_launcher.sh /percorso/script.sql [param1] [param2] ...
#
# Esempio:
#   ./template_sqlplus_launcher.sh ./sql/mia_query.sql 20260901 REPARTO1
#
# Nota:
# - la connection string Oracle è letta preferibilmente da ORACLE_CONNECT_STRING
# - opzionalmente può arrivare da ./lib/env.sh
# - il file .sql viene eseguito con @file.sql
###############################################################################

usage() {
    echo "Usage: $0 <file.sql> [param1] [param2] ..."
    echo
    echo "Esempi:"
    echo "  $0 ./sql/mia_query.sql"
    echo "  $0 ./sql/mia_query.sql 20260901 REPARTO1"
}

# Caricamento environment opzionale
if [ -f "./lib/env.sh" ]; then
    if ! source "./lib/env.sh"; then
        echo "Errore nel caricare environment (./lib/env.sh)" >&2
        exit 109
    fi
fi

# Logging
if ! source "./lib/log_msg.sh"; then
    echo "Errore nel caricare funzione di log (./lib/log_msg.sh)" >&2
    exit 110
fi

# Utility
if ! source "./lib/utility.sh"; then
    echo "Errore nel caricare funzione utility (./lib/utility.sh)" >&2
    exit 111
fi

SCRIPT_NAME="$(basename "$0" .sh)"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
PID="$$"
JOB_ID="${SCRIPT_NAME}_${TIMESTAMP}_${PID}"

LOG_FILE="${SCRIPT_NAME}_${TIMESTAMP}_${PID}.log"
ERR_FILE="${SCRIPT_NAME}_${TIMESTAMP}_${PID}.err"

main() {
    local sql_file
    local sqlplus_rc

    if [ "$#" -lt 1 ]; then
        log_err "Parametro file SQL mancante."
        usage
        exit 101
    fi

    sql_file="$1"
    shift

    if [ ! -f "$sql_file" ]; then
        log_err "File SQL non trovato: $sql_file"
        exit 102
    fi

    if [ -z "${ORACLE_CONNECT_STRING:-}" ]; then
        log_err "Variabile ORACLE_CONNECT_STRING non valorizzata."
        exit 103
    fi

    exec 3>&1
    exec >"$LOG_FILE" 2>"$ERR_FILE"

    log_info "Avvio launcher SQLPlus"
    log_info "JOB_ID: $JOB_ID"
    log_info "SQL file: $sql_file"
    log_info "Log file: $LOG_FILE"
    log_info "Err file: $ERR_FILE"

    echo "Avvio launcher SQLPlus - JOB_ID=$JOB_ID" >&3
    echo "SQL file: $sql_file" >&3
    echo "Log file: $LOG_FILE" >&3

    if ! check_oracle_connection; then
        log_err "Connessione Oracle fallita."
        echo "FINE JOB: ERRORE" >&3
        exit 120
    fi

    # Esecuzione sqlplus:
    # -s             -> silent
    # @file.sql      -> esegue il file SQL esterno
    # "$@"           -> parametri passati al file SQL come &1, &2, ...
    #
    # Importante:
    # nel file SQL conviene sempre usare:
    #   whenever sqlerror exit sql.sqlcode
    #   whenever oserror  exit 99
    #
    # Esempio SQL:
    #   @mio_script.sql valore1 valore2
    #
    sqlplus -s "$ORACLE_CONNECT_STRING" @"$sql_file" "$@"
    sqlplus_rc=$?

    if [ "$sqlplus_rc" -ne 0 ]; then
        log_err "sqlplus terminato con errore (rc=$sqlplus_rc)."
        echo "FINE JOB: ERRORE" >&3
        echo "Err file: $ERR_FILE" >&3
        exit "$sqlplus_rc"
    fi

    log_info "sqlplus terminato correttamente."
    echo "FINE JOB: OK" >&3
    echo "Log file: $LOG_FILE" >&3
    echo "Err file: $ERR_FILE" >&3
}

main "$@"
