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

NOW=$(date '+%Y%m%d-%H%M%S')
GCLOUD="gcloud"
LOG_FILE="log/run-${NOW}.log"
ACCESS_TOKEN=""
SERVICE_ACCOUNT="my-servacct-${NOW}"
ROLE_EDITOR="roles/editor"

###############
## VARIABLES ##
###############

IS_VERBOSE=0
PROJECT_ID=""

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

verbose_msg "${IS_VERBOSE}" "PROJECT_ID = ${PROJECT_ID}"
verbose_msg "${IS_VERBOSE}" "Log file = ${LOG_FILE}"

check_exists_fatal "$GCLOUD"

# Creating a Service Account
run_cmd_fatal "${GCLOUD} iam service-accounts create ${SERVICE_ACCOUNT} --display-name \"${SERVICE_ACCOUNT}\"" \
              "Creating a Service Account"

# Granting roles to the Service Account for specific resources
run_cmd "${GCLOUD} projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com --role ${ROLE_EDITOR}" \
        "Granting roles to a Service Account for specific resources"

# Retrieving metadata about the Service Account
run_cmd_fatal "${GCLOUD} iam service-accounts get-iam-policy ${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" \
              "Retrieving metadata about the Service Account"
              
# Pause
#echo && echo "Pausing before deleting the Service Account" && echo
#echo -n "Press <enter> to continue: "
#read
continue "Pause before deleting the Service Account."

# Deleting the Service Account
run_cmd_fatal "${GCLOUD} iam service-accounts delete ${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" \
              "Deleting the Service Account"

exit 0
