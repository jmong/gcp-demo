#!/bin/bash
##--
# Runs simple cloud function creation, testing, and deletion.
##--

set -o pipefail

# Allow exiting the script within functions
trap "exit 1" TERM
export TOP_PID=$$

# "Import"
source ../librun.sh

###############
## CONSTANTS ##
###############

LABEL="http"
NOW=$(date '+%Y%m%d-%H%M%S')
GCLOUD="gcloud"
GSUTIL="gsutil"
RES_DIR="res/hellohttp"
LOG_FILE="log/run-${LABEL}-${NOW}.log"
REGION="us-central1"
ZONE="${REGION}-a"
FUNCTION="HelloHttp"
RUNTIME="go111"

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

# Setting project id
run_cmd_fatal "$GCLOUD config set project $PROJECT_ID" \
              "Setting project id"

# Confirming project id set
run_cmd_fatal "test `$GCLOUD config get-value project` == $PROJECT_ID"  \
              "Confirming setting project id"

# @TODO
# We clean up project id only after it was successfully set
#trap cleanup_set_project_id 0 1 2 3 6

# Creating the function using the GCS bucket name for the source code and triggering it in the Pub/Sub topic named hello_world
run_cmd_fatal "$GCLOUD beta functions deploy $FUNCTION --region=$REGION --source=$RES_DIR --trigger-http --runtime $RUNTIME" \
              "Creating the function to be triggered with a HTTP request "
info_msg 1 "This command creates Cloud Function calling the function $FUNCTION from the source file mycftest.go located in the directory specified by --source. The event will be triggered with a HTTP request."
info_msg 1 "Cloud Functions are only available in the regions listed here ... https://cloud.google.com/functions/docs/locations"

# Verifying the status of the function
run_cmd "$GCLOUD beta functions describe $FUNCTION" \
        "Verifying the status of the function"

# @FIXME - run_cmd* unable to handle escaped quotes
# Creating a message test of the function
run_cmd "$GCLOUD beta functions call $FUNCTION --data '{\"name\":\"Hello World!\"}'" \
        "Creating a message test of the function"

# Checking the logs to see your messages in the log history
run_cmd "$GCLOUD beta functions logs read $FUNCTION" \
        "Checking the logs to see your messages in the log history"

# Viewing it online
continue "Pausing before deleting the cloud function."

# Deleting the cloud function
run_cmd_fatal "$GCLOUD beta functions delete $FUNCTION" \
              "Deleting the cloud function"

exit 0
