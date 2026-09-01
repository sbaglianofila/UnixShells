#!/bin/bash

###############################################################################
# LIBRERIA PER INVIO MAIL DI NOTIFICA DA SHELL
#
# Funzioni principali:
# - send_mail_notification
# - send_error_mail
#
# Obiettivi:
# - inviare email a uno o più destinatari configurati
# - permettere allegati (es. file .err, .log, report, csv, ecc.)
# - poter essere richiamata sia in caso di errore sia in modo esplicito
# - essere riutilizzabile da più shell tramite `source ./lib/mail_util.sh`
#
# Requisiti:
# - disponibilità di `mailx` sul server
# - configurazione SMTP / MTA già funzionante a livello di sistema
#
# Configurazione destinatari:
# - se valorizzata, usa la variabile MAIL_RECIPIENTS dall'esterno
# - altrimenti usa DEFAULT_MAIL_RECIPIENTS definita qui sotto
#
# Esempi:
#   source ./lib/mail_util.sh
#
#   send_mail_notification \
#       "Oggetto" \
#       "Corpo mail" \
#       "/tmp/job.err;/tmp/job.log"
#
#   send_error_mail \
#       "Errore job ABC" \
#       "Si è verificato un errore in fase 2" \
#       "$ERR_FILE;$LOG_FILE"
#
# Formato allegati:
# - lista separata da `;`
# - esempio: "/tmp/a.err;/tmp/b.log;/tmp/report.csv"
#
###############################################################################

# Destinatari di default, sovrascrivibili dall'esterno con:
#   export MAIL_RECIPIENTS="am@azienda.it ops@azienda.it"
DEFAULT_MAIL_RECIPIENTS="am-group@example.com other@example.com"

_get_mail_recipients() {
    if [ -n "$MAIL_RECIPIENTS" ]; then
        echo "$MAIL_RECIPIENTS"
    else
        echo "$DEFAULT_MAIL_RECIPIENTS"
    fi
}

send_mail_notification() {
    # Parametri:
    #   $1 = subject
    #   $2 = body
    #   $3 = lista allegati separata da ';' (opzionale)
    #
    # Return code:
    #   0 = invio ok
    #   1 = mailx non disponibile
    #   2 = subject mancante
    #   3 = body mancante
    #   4 = nessun destinatario configurato
    #   n = errore restituito da mailx
    local subject="$1"
    local body="$2"
    local attachments="${3:-}"
    local recipients
    local mail_command="mailx"
    local -a attachment_params
    local old_ifs
    local file
    local rc

    recipients="$(_get_mail_recipients)"

    if ! command -v "$mail_command" >/dev/null 2>&1; then
        echo "Errore: '$mail_command' non trovato. Impossibile inviare mail." >&2
        return 1
    fi

    if [ -z "$subject" ]; then
        echo "Errore: subject mail non valorizzato." >&2
        return 2
    fi

    if [ -z "$body" ]; then
        echo "Errore: body mail non valorizzato." >&2
        return 3
    fi

    if [ -z "$recipients" ]; then
        echo "Errore: nessun destinatario mail configurato." >&2
        return 4
    fi

    # Parsing lista allegati separata da ';'
    # Nota: usare ';' evita ambiguità nel caso di path con spazi.
    attachment_params=()
    if [ -n "$attachments" ]; then
        old_ifs="$IFS"
        IFS=';'
        for file in $attachments; do
            # Trim basilare: rimuove eventuali spazi iniziali/finali più comuni.
            file="${file#"${file%%[![:space:]]*}"}"
            file="${file%"${file##*[![:space:]]}"}"

            if [ -z "$file" ]; then
                continue
            fi

            if [ -f "$file" ]; then
                attachment_params+=( -a "$file" )
            else
                echo "Attenzione: allegato non trovato, lo salto: $file" >&2
            fi
        done
        IFS="$old_ifs"
    fi

    printf '%s\n' "$body" | "$mail_command" -s "$subject" "${attachment_params[@]}" $recipients
    rc=$?

    if [ $rc -ne 0 ]; then
        echo "Invio mail fallito con codice $rc" >&2
        return $rc
    fi

    return 0
}

send_error_mail() {
    # Wrapper semantico per invio mail in caso di errore.
    #
    # Parametri:
    #   $1 = subject
    #   $2 = body
    #   $3 = lista allegati separata da ';' (opzionale)
    #
    # Esempio:
    #   send_error_mail \
    #       "[ERRORE] Job venduti gg" \
    #       "Errore durante l'elaborazione. Vedi allegati." \
    #       "$ERR_FILE;$LOG_FILE"
    send_mail_notification "$1" "$2" "${3:-}"
}
