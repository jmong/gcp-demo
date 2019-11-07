#!/bin/bash
##--
# Pull a Docker image from GCR.
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

LABEL="pull"
GCLOUD="gcloud"
CURL="curl"
DOCKER="docker"
GCR_HOSTNAME="gcr.io"
NOW=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="log/run-${LABEL}-${NOW}.log"
RES_DIR="res"
GOLANG_IMAGE="golang:1.12"
DOCKER_IMAGE="hellogcrtest-app"
DOCKER_IMAGE_TAG="0.1"
DOCKER_CONTAINER="${DOCKER_IMAGE}-run"
APP_PORT="80"
DOCKER_PORT="8080"

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
check_exists_fatal "$CURL"
check_exists_fatal "$DOCKER"

# We need to make sure we configure Docker to use gcloud as a credential helper.
# @see https://docs.docker.com/engine/reference/commandline/login/#credential-helpers
# @see https://cloud.google.com/container-registry/docs/advanced-authentication
run_cmd_fatal "$GCLOUD auth configure-docker" \
              "Configuring Docker to add GCR as a credential helper"
info_msg 1 "To authenticate to Container Registry, we must first configure gcloud as a Docker credential helper at least once."

# Build a new Docker image
run_cmd_fatal "$DOCKER build -t ${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG} ${RES_DIR}" \
              "Building a Docker image version"

# Tagging the Docker image
run_cmd_fatal "$DOCKER tag ${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG} ${GCR_HOSTNAME}/${PROJECT_ID}/${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG}" \
              "Tagging the Docker image on GCR"

# Pushing this Docker image to GCR
run_cmd_fatal "$GCLOUD $DOCKER -- push ${GCR_HOSTNAME}/${PROJECT_ID}/${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG}" \
              "Pushing Docker image to GCR"

# List Docker images from GCR
run_cmd "$GCLOUD container images list --repository=${GCR_HOSTNAME}/${PROJECT_ID}" \
        "Listing Docker images from GCR"

# Deleting local Docker images
run_cmd_fatal "$DOCKER rmi ${GOLANG_IMAGE} ${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG} ${GCR_HOSTNAME}/${PROJECT_ID}/${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG}" \
              "Deleting local Docker images"

# Confirming no local Docker images
run_cmd_fatal "$DOCKER images" \
              "Confirming no local Docker images"

# Pulling Docker image from GCR
run_cmd_fatal "$GCLOUD $DOCKER -- pull ${GCR_HOSTNAME}/${PROJECT_ID}/${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG}" \
              "Pulling Docker image from GCR"

# Confirming local Docker image exists
run_cmd_fatal "$DOCKER images" \
              "Confirming local Docker image exists"

# Running the Docker image in the background
run_cmd_fatal "$DOCKER run -p ${DOCKER_PORT}:${APP_PORT} --name ${DOCKER_CONTAINER} -d ${GCR_HOSTNAME}/${PROJECT_ID}/${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG}" \
              "Running the Docker image"

# Showing running Docker container
run_cmd "$DOCKER ps -a" \
        "Showing running Docker container"

# Viewing it online and awaiting continuation
continue "Pausing to view the running app by visiting http://localhost:${DOCKER_PORT}"

# Examining the logs of the Docker container
run_cmd "$DOCKER logs ${DOCKER_CONTAINER}" \
        "Examining the running logs of the Docker container"

# Examining the Docker container's metadata
run_cmd "$DOCKER inspect ${DOCKER_CONTAINER}" \
        "Examining the Docker container's metadata"

# Stopping the running Docker container
run_cmd_fatal "$DOCKER stop ${DOCKER_CONTAINER}" \
              "Stopping the running Docker container"

# Removing the running container
run_cmd_fatal "$DOCKER rm ${DOCKER_CONTAINER}" \
              "Removing the running Docker container"

# Deleting the local Docker image
run_cmd_fatal "$DOCKER rmi ${GCR_HOSTNAME}/${PROJECT_ID}/${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG}" \
              "Deleting the local Docker image"

# Deleting the Docker image from GCR
run_cmd_fatal "$GCLOUD container images delete ${GCR_HOSTNAME}/${PROJECT_ID}/${DOCKER_IMAGE}:${DOCKER_IMAGE_TAG} --force-delete-tags" \
              "Deleting the Docker image from GCR"

exit 0
