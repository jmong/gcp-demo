#!/bin/bash
##--
# Runs creating a simple BigTable
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

NOW=$(date '+%Y%m%d-%H%M%S')
GCLOUD="gcloud"
CBT="cbt"
TMP_DIR="tmp/${NOW}"
LOG_FILE="log/run-${NOW}.log"
REGION="us-west1"
ZONE="${REGION}-a"
BT_INSTANCE="mybt-${NOW}"
BT_DISPLAY_NAME=${BT_INSTANCE}
BT_CLUSTER="cluster-${BT_INSTANCE}"
BT_TABLE="table-1"
BT_COLUMN_FAMILY="family-1"
NUM_NODES="1"  # for development cluster, limit up to 1 node
STORAGE_TYPE="SSD"

###############
## VARIABLES ##
###############

IS_VERBOSE=0
PROJECT_ID=""
CREDS_FILE=""

###############
## FUNCTIONS ##
###############

usage() {
  echo "Usage: $(basename $0) [-v] [-h] [gcp_project_id] [path_to_creds_file]"
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

CREDS_FILE=$2
check_nonempty_fatal "$CREDS_FILE" "credentials file"
verbose_msg "${IS_VERBOSE}" "CREDS_FILE = ${CREDS_FILE}"

verbose_msg "${IS_VERBOSE}" "Log file = ${LOG_FILE}"

check_exists_fatal "$GCLOUD"
check_exists_fatal "$CBT"

# Setting project id
run_cmd_fatal "$GCLOUD config set project $PROJECT_ID" \
              "Setting project id"

# Confirming project id set
run_cmd_fatal "test `$GCLOUD config get-value project` == $PROJECT_ID"  \
              "Confirming setting project id"

# Note about installing cbt command
info_msg 1 "Following instructions here to install the cbt tool, if not already ... https://cloud.google.com/bigtable/docs/cbt-overview"

# Note about cbt command
info_msg 1 "The cbt command needs project id and credentials to execute the BigTable operations. " \
"I created a new service account that has the correct BigTable privileges, and its credentials are passed into the cbt command via -creds argument. " \
"Alternatively, you can add project id and credentials information into ~/.cbtrc so you do not have to pass in the cbt command line."

# Creating BigTable instance and cluster
run_cmd_fatal "$CBT -project $PROJECT_ID -creds $CREDS_FILE createinstance $BT_INSTANCE $BT_DISPLAY_NAME $BT_CLUSTER $ZONE $NUM_NODES $STORAGE_TYPE" \
              "Creating BigTable instance."

# Listing all BigTable instances
run_cmd_fatal "$CBT -project $PROJECT_ID -creds $CREDS_FILE listinstances" \
              "Listing all BigTable instances."

# Creating a table.
run_cmd_fatal "$CBT -instance $BT_INSTANCE -project $PROJECT_ID -creds $CREDS_FILE createtable $BT_TABLE" \
              "Creating a table."

# Adding a column family.
run_cmd_fatal "$CBT -instance $BT_INSTANCE -project $PROJECT_ID -creds $CREDS_FILE createfamily $BT_TABLE $BT_COLUMN_FAMILY" \
              "Adding a column family."

# Listing all tables and column families.
run_cmd "$CBT -instance $BT_INSTANCE -project $PROJECT_ID -creds $CREDS_FILE ls" \
        "Listing all tables and column families."

# Adding a value test-value in the row r1, using the column family cf1 and the column qualifier c1.
run_cmd "$CBT -instance $BT_INSTANCE -project $PROJECT_ID -creds $CREDS_FILE set $BT_TABLE r1 ${BT_COLUMN_FAMILY}:c1=test-value" \
        "Adding a value test-value in the row r1, using the column family cf1 and the column qualifier c1."

# Reading the data that was added to the table.
run_cmd "$CBT -instance $BT_INSTANCE -project $PROJECT_ID -creds $CREDS_FILE read $BT_TABLE" \
        "Reading the data that was added to the table."

# Pausing before deletion
continue "Pausing before deleting the BigTable column, table, and instance."

# Deleting the table.
run_cmd_fatal "$CBT -instance $BT_INSTANCE -project $PROJECT_ID -creds $CREDS_FILE deletetable $BT_TABLE" \
              "Deleting the table."

# @TODO - Because the instance uses the default application profile that uses single-cluster routing,
#         you can not delete the last live cluster in the instance. Trying to delete it will error out.
#         Google Support case 19026409
# Deleting the cluster.
run_cmd_fatal "$CBT -instance $BT_INSTANCE -project $PROJECT_ID -creds $CREDS_FILE deletecluster $BT_CLUSTER" \
              "Deleting the cluster."

# Deleting the instance.
run_cmd_fatal "$CBT -project $PROJECT_ID -creds $CREDS_FILE deleteinstance $BT_INSTANCE" \
              "Deleting the instance."

exit 0
