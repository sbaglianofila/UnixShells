#!/bin/bash

###############################################################################
# LIBRERIA LOGGING PER SHELL
#
# Deve essere inclusa con:
#     source ./lib/log_msg.sh
#
# Definisce le seguenti funzioni:
#   log_info "Messaggio info"
#   log_warn "Messaggio warning"
#   log_err  "Messaggio error"
#   log_msg  LIVELLO "Messaggio"
#
# Queste funzioni scrivono su STDOUT.
# Se lo script chiamante redirige STDOUT su file .log e STDERR su file .err,
# allora i messaggi saranno instradati nei rispettivi file.
#
# Le funzioni si aspettano che lo script principale definisca:
#   SCRIPT_NAME (es: template_shell)
#   JOB_ID      (es: template_shell_YYYYMMDD_HHMMSS_PID)
#
# Esempio di uso:
#   log_info "Avvio script"
#   log_warn "Parametro x non valorizzato"
#   log_err  "Errore bloccante"
#   log_msg "DEBUG" "Info di debug"
###############################################################################

log_msg() {
    # log_msg LIVELLO messaggio
    # Esempio: log_msg "INFO" "Messaggio di test"
    local level="$1"
    shift
    local msg="$*"
    # Le seguenti variabili sono attese nello script principale:
    # SCRIPT_NAME, JOB_ID
    # Stampa compattata: timestamp - livello - PID (se disponibile) - messaggio
    printf "%s [%s] [%s] %s\n" \
        "$(date +%Y-%m-%dT%H:%M:%S)" \
        "${level}" \
        "${PID:-no_pid}" \
        "${msg}"
}

log_info() {
    log_msg "INFO" "$@"
}

log_warn() {
    log_msg "WARN" "$@"
}

log_err() {
    # Di default scrive su stdout. Per scrivere su stderr, aggiungi:
    #   log_err() { log_msg "ERROR" "$@" >&2; }
    log_msg "ERROR" "$@"
}
