#!/bin/bash
##--
# Runs creating a simple Dataproc cluster and job.
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
LOG_FILE="log/run-${NOW}.log"
ZONE="us-west1-a"
DATAPROC_CLUSTER="mydataproc-${NOW}"
SPARK_CLASS="org.apache.spark.examples.SparkPi"
SPARK_JARS="file:///usr/lib/spark/examples/jars/spark-examples.jar"

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

verbose_msg "$IS_VERBOSE" "PROJECT_ID = ${PROJECT_ID}"
verbose_msg "$IS_VERBOSE" "Log file = ${LOG_FILE}"

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

# Creating Dataproc cluster.
run_cmd_fatal "$GCLOUD dataproc clusters create $DATAPROC_CLUSTER --zone $ZONE" \
              "Creating Dataproc cluster"

# Submitting a Spark job.
run_cmd_fatal "$GCLOUD dataproc jobs submit spark --cluster $DATAPROC_CLUSTER --class $SPARK_CLASS --jars $SPARK_JARS -- 1000" \
        "Submitting a Spark job in the $DATAPROC_CLUSTER cluster, running the $SPARK_CLASS class."
echo "${TEXT_COLOR_YELLOW}[INFO]${TEXT_RESET} Parameters passed to the job must follow a double dash (--). Here the parameters you want to pass to the job—in this case, the number of tasks, which is 1000."

# Listing all the Dataproc clusters.
run_cmd "$GCLOUD dataproc clusters list" \
        "Listing all the Dataproc clusters."

# Viewing details of the Dataproc cluster.
run_cmd "$GCLOUD dataproc clusters describe $DATAPROC_CLUSTER" \
        "Viewing details of the Dataproc cluster."

# Pausing
continue "Pausing before scaling up the cluster."

# Scaling up Dataproc cluster.
run_cmd_fatal "$GCLOUD dataproc clusters update $DATAPROC_CLUSTER --num-workers 4" \
              "Scaling up Dataproc cluster"

# Pausing
continue "Pausing before scaling down the cluster."

# Scaling down Dataproc cluster.
run_cmd_fatal "$GCLOUD dataproc clusters update $DATAPROC_CLUSTER --num-workers 2" \
              "Scaling down Dataproc cluster"

# Pausing
continue "Pausing before deleting the cluster."

# Deleting the Dataproc cluster
run_cmd_fatal "$GCLOUD dataproc clusters delete $DATAPROC_CLUSTER" \
              "Deleting the Dataproc cluster"

exit 0
