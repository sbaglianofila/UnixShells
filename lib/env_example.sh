#!/bin/bash
###############################################################################
# ESEMPIO DI FILE DI ENVIRONMENT DA USARE CON "source"
#
# Inserisci qui la configurazione specifica per ambiente, cluster, job, ecc.
# Ogni variabile sarà visibile agli script che fanno:
#   source ./lib/env_example.sh
#
# NOTE:
# - Puoi/dovresti copiare e rinominare questo esempio come "env.sh" o simili.
# - NON committare in repo variabili con credenziali reali!
# - I valori qui sono solo di esempio!
###############################################################################

# Configurazione Oracle
export ORACLE_CONNECT_STRING="utente/password@SID"

# Percorsi directory dati
export BASE_DATA_DIR="/dati/elaborazioni"
export ARCHIVE_DIR="/dati/archive"

# Email gruppo AM per notifiche (override rispetto a default in mail_util.sh)
export MAIL_RECIPIENTS="group_am@example.com,altro_dest@example.com"

# Ambiente/logica custom per job
export JOB_CUSTOM_PARAM="ELAB_MENSILE"

# Timeout/max attempt (valore esempio, personalizza)
export JOB_TIMEOUT_SEC=5400
export JOB_MAX_ATTEMPTS=3

# Ogni variabile qui definita potrà essere richiamata negli shell come $VAR_NAME
