#!/bin/bash

set -o pipefail

# Allow exiting the script within functions
trap "exit 1" TERM
export TOP_PID=$$

# "Import"
source ../librun.sh

###############
## CONSTANTS ##
###############

GCLOUD="gcloud"
CURL="curl"
GCP_ACCESS_TOKEN_INFO_URL="https://www.googleapis.com/oauth2/v1/tokeninfo?access_token"
NOW=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="log/run-${NOW}.log"

###############
## VARIABLES ##
###############

IS_VERBOSE=0
PROJECT_ID=""
ACCESS_TOKEN=""

###############
## FUNCTIONS ##
###############

usage() {
  echo "Usage: $(basename $0) [-v] [-h] [gcp_project_id]"
  echo -e "\t-v"
  echo -e "\t\tEnable verbose mode"
  echo -e "\t-h"
  echo -e "\t\tThis usage"
  exit 0
}

##########
## MAIN ##
##########

# Dump everything into a log file.
exec > >(tee -i $LOG_FILE)
exec 2>&1

while getopts ":vh" opt; do
  case ${opt} in
    v )
      IS_VERBOSE=1
      ;;
    h ) usage
      ;;
    \? ) usage
      ;;
  esac
done
shift $((OPTIND -1))

# Checks

PROJECT_ID=$1
check_nonempty_fatal "$PROJECT_ID" "project_id"

verbose_msg "$IS_VERBOSE" "PROJECT_ID = ${PROJECT_ID}"
verbose_msg "$IS_VERBOSE" "Log file = ${LOG_FILE}"

check_exists_fatal "$GCLOUD"
check_exists_fatal "$CURL"

# Retrieving temporary access token
run_cmd_fatal "export ACCESS_TOKEN=$($GCLOUD auth print-access-token)" \
              "Retrieving a temporary access token"
info_msg 1 "GCloud Command: $GCLOUD auth print-access-token"
info_msg 1 "ACCESS_TOKEN=$ACCESS_TOKEN"

# Fetching access token details
run_cmd "$CURL ${GCP_ACCESS_TOKEN_INFO_URL}=${ACCESS_TOKEN}" \
        "Fetching details of the access token"

exit 0
