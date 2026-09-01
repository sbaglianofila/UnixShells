#!/bin/bash

###############################################################################
# LIBRERIA UTILITY SHELL RIUTILIZZABILE
#
# Include:
# - single_instance_check: impedisce più istanze della stessa shell
# - check_oracle_connection: verifica connessione Oracle via sqlplus
#
# Da usare con:
#    source ./lib/utility.sh
#
###############################################################################

single_instance_check() {
    # Previene la doppia esecuzione della stessa shell (stesso nome file), anche da cron.
    #
    # Come funziona:
    # - crea un lockfile in /tmp che contiene il PID del processo corrente
    # - se il lockfile esiste e il PID contenuto è ancora vivo -> blocca l'avvio
    # - se il lockfile esiste ma il PID non è più vivo -> lockfile "orfano", lo sovrascrive
    #
    # Uso tipico (all'inizio dello script chiamante):
    #   single_instance_check || exit 1
    #
    # Nota:
    # - il lock viene rimosso automaticamente a fine esecuzione tramite `trap ... EXIT`
    # - in ambienti con filesystem /tmp non condiviso tra host/container, la semantica è locale
    # - `basename "$0"` usa il nome dello script chiamante (non questa libreria), quindi
    #   evita collisioni tra script diversi.
    #
    # Dettagli comandi usati:
    # - `basename "$0"`: estrae solo il nome file dello script chiamante (senza path)
    # - `$$`          : PID del processo corrente (shell che sta eseguendo lo script)
    # - `[ -f FILE ]` : true se il file esiste ed è un file regolare
    # - `cat FILE`    : legge il PID memorizzato
    # - `kill -0 PID` : non invia segnali; verifica solo se il PID esiste e siamo autorizzati
    #                  (exit code 0 se il processo è vivo/accessibile, !=0 altrimenti)
    # - `trap '...' EXIT`: esegue il comando quando la shell termina (successo o errore)
    #
    local lockfile="/tmp/$(basename "$0").lock"
    local mypid=$$

    if [ -f "$lockfile" ]; then
        local otherpid
        otherpid=$(cat "$lockfile")

        # Se il PID è non vuoto e il processo è vivo, abortisco: un'altra istanza è attiva.
        if [ -n "$otherpid" ] && kill -0 "$otherpid" 2>/dev/null; then
            echo "Script già in esecuzione con PID $otherpid" >&2
            return 1
        fi

        # Se arrivo qui: lockfile presente ma PID non valido o processo non più vivo.
        echo "Lockfile orfano rilevato. Sovrascrivo." >&2
    fi

    # Registro il mio PID nel lockfile.
    echo "$mypid" > "$lockfile"

    # Rimuovo il lockfile all'uscita (qualunque sia il motivo di termine dello script).
    trap 'rm -f "$lockfile"' EXIT
    return 0
}

check_oracle_connection() {
    # Verifica una connessione Oracle tramite `sqlplus` eseguendo una query minimale.
    #
    # Requisito:
    # - la variabile d'ambiente ORACLE_CONNECT_STRING deve essere impostata, ad esempio:
    #     export ORACLE_CONNECT_STRING="user/pass@TNSSTRING"
    #   oppure:
    #     export ORACLE_CONNECT_STRING="user/pass@//host:1521/service"
    #
    # Uso tipico:
    #   check_oracle_connection || exit 2
    #
    # Cosa fa:
    # - apre una sessione SQL*Plus in modalità "silent" (-s)
    # - imposta direttive per far fallire l'exit code su errori SQL/OS
    # - imposta opzioni per ridurre output accessorio (header, feedback, ecc.)
    # - esegue `SELECT 1 FROM dual;` e si aspetta che l'output "pulito" sia esattamente "1"
    #
    # Perché è robusto:
    # - `WHENEVER SQLERROR/OSERROR EXIT` rende significativo il codice di ritorno di sqlplus
    # - il confronto `output == 1` evita falsi positivi tipici di un `grep "1"` sull'output
    #
    # Dettagli comandi usati:
    # - `sqlplus -s`:
    #     * -s = silent: riduce banner e prompt (ma non garantisce output nullo)
    # - Here-document `<<EOF ... EOF`:
    #     * passa un blocco di comandi SQL/SQL*Plus a sqlplus via stdin
    # - `2>&1`:
    #     * unifica stderr su stdout per catturare messaggi di errore in `output`
    # - `local rc=$?`:
    #     * salva l'exit code del comando precedente (sqlplus)
    # - `tr -d '[:space:]'`:
    #     * elimina spazi, tab e newline per rendere confrontabile l'output
    #
    # Exit code funzione:
    # - 0: ok
    # - 2: ORACLE_CONNECT_STRING mancante
    # - 3: connessione/query fallita oppure output inatteso
    #
    if [ -z "$ORACLE_CONNECT_STRING" ]; then
        echo "Variabile ORACLE_CONNECT_STRING non valorizzata" >&2
        return 2
    fi

    # Eseguo una query minimale. Se c'è un errore di login o SQL, sqlplus uscirà con rc != 0.
    local output
    output=$(
        sqlplus -s "$ORACLE_CONNECT_STRING" <<EOF 2>&1
WHENEVER OSERROR EXIT 10
WHENEVER SQLERROR EXIT 11
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET VERIFY OFF
SET ECHO OFF
SELECT 1 FROM dual;
EXIT
EOF
    )
    local rc=$?

    # Normalizzo l'output rimuovendo spazi/newline; mi aspetto esattamente "1".
    output=$(echo "$output" | tr -d '[:space:]')

    if [ $rc -ne 0 ] || [ "$output" != "1" ]; then
        echo "Connessione Oracle fallita: $output" >&2
        return 3
    fi

    return 0
}
