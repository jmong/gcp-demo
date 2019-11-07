#!/bin/bash
##--
# Runs a simple create, delete, upload, download, and validation of a GCS bucket.
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
GSUTIL="gsutil"
REGION="us-west1"
ZONE="${REGION}-a"
RES_DIR="res"
BUCKET="my-gcs-test-bkt-${NOW}"
BUCKET_LOCATION="us"
STORAGE_CLASS="multi_regional"
SUBDIR_1="subdir1"
SUBDIR_2="subdir2"
RESOURCE_1="test_file1.txt"
RESOURCE_2="test_file2.txt"
RESOURCE_3="test_file3.txt"
LOG_FILE="log/run-${NOW}.log"

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
check_exists_fatal "$GSUTIL"

# Setting project id
run_cmd_fatal "$GCLOUD config set project $PROJECT_ID" \
              "Setting project id"

# Confirming project id set
run_cmd_fatal "test `$GCLOUD config get-value project` == $PROJECT_ID"  \
              "Confirming setting project id"

# Creating the $STORAGE_CLASS GCS bucket, available in the $BUCKET_LOCATION multi-region
run_cmd_fatal "$GSUTIL mb -c $STORAGE_CLASS -l $BUCKET_LOCATION -p $PROJECT_ID gs://${BUCKET}" \
              "Creating the $STORAGE_CLASS GCS bucket, available in the $BUCKET_LOCATION multi-region"
info_msg 1 "For bucket locations via \"-l\" option, see https://cloud.google.com/storage/docs/bucket-locations."
info_msg 1 "For storage class via \"-c\" option, see https://cloud.google.com/storage/docs/storage-classes."

# Uploading a resource into the bucket root
run_cmd_fatal "$GSUTIL cp ${RES_DIR}/${RESOURCE_3} gs://${BUCKET}/${RESOURCE_3}" \
              "Uploading a resource into the bucket root"

# Uploading a resource into newly-created subdirectory
run_cmd_fatal "$GSUTIL cp ${RES_DIR}/${RESOURCE_1} gs://${BUCKET}/${SUBDIR_1}/${RESOURCE_1}" \
              "Uploading a resource into newly-created subdirectory"
info_msg 1 "For GCS subdirectories, see https://cloud.google.com/storage/docs/gsutil/addlhelp/HowSubdirectoriesWork."

# Uploading a resource into another newly-created subdirectory
run_cmd_fatal "$GSUTIL cp ${RES_DIR}/${RESOURCE_2} gs://${BUCKET}/${SUBDIR_2}/${RESOURCE_2}" \
              "Uploading a resource into another newly-created subdirectory"

# Viewing IAM policy about the bucket
run_cmd_fatal "$GSUTIL iam get gs://${BUCKET}" \
              "Viewing IAM policy about the bucket"

# Viewing IAM policy about a resource
run_cmd_fatal "$GSUTIL iam get gs://${BUCKET}/${SUBDIR_1}/${RESOURCE_1}" \
              "Viewing IAM policy about a resource"

# Viewing metadata about the bucket
run_cmd_fatal "$GSUTIL ls -L  gs://${BUCKET}" \
              "Viewing metadata about the bucket"

# Viewing metadata about the root resource
run_cmd_fatal "$GSUTIL ls -L  gs://${BUCKET}/${RESOURCE_3}" \
              "Viewing metadata about the root resource"

# Viewing the metadata about the subdirectory resource 
run_cmd_fatal "$GSUTIL ls -L  gs://${BUCKET}/${SUBDIR_1}/${RESOURCE_1}" \
              "Viewing the metadata about the subdirectory resource"

# Viewing it online
continue "Pausing before deleting resources and subdirectories."

# Deleting the root resource
run_cmd_fatal "$GSUTIL rm gs://${BUCKET}/${RESOURCE_3}" \
              "Deleting the root resource"

# Deleting the subdirectory recursively
run_cmd_fatal "$GSUTIL rm -r gs://${BUCKET}/${SUBDIR_1}" \
              "Deleting the subdirectory recursively"

# Viewing it online
continue "Pausing before deleting the bucket."

# Deleting the bucket
run_cmd_fatal "$GSUTIL rm -r gs://${BUCKET}" \
              "Deleting the bucket"

exit 0
