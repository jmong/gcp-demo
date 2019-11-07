#!/bin/bash
##--
# Runs installing MongoDB in a StatefulSet and creating a headless Service.
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

LABEL="statefulsets"
NOW=$(date '+%Y%m%d-%H%M%S')
GCLOUD="gcloud"
KUBECTL="kubectl"
GIT="git"
ZONE="us-west1-a"
CLUSTER="${LABEL}-${NOW}"
NETWORK="default"
PORT=8080
TMP_DIR="tmp/${LABEL}-${NOW}"
LOG_FILE="log/run-${LABEL}-${NOW}.log"
KUBECONFIG="${TMP_DIR}/kube/config"
GIT_REPO="https://github.com/thesandlord/mongo-k8s-sidecar.git"
GIT_CLONE_LOCATION="${TMP_DIR}/git"
GIT_PROJECT_BASE_PATH="${GIT_CLONE_LOCATION}/mongo-k8s-sidecar"
STATEFULSET="mongo"
SERVICE="mongo"
STORAGECLASS="fast"

###############
## VARIABLES ##
###############

IS_VERBOSE=0
PROJECT_ID=""
GCLOUD_USER=""

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
check_exists_fatal "$KUBECTL"
check_exists_fatal "$GIT"

# Create the directory for cloning the git repo
run_cmd_fatal "mkdir -p $GIT_CLONE_LOCATION" \
              "Creating folder"

# Setting project id
run_cmd_fatal "$GCLOUD config set project $PROJECT_ID" \
              "Setting project id"

# Confirming project id set
run_cmd_fatal "test `$GCLOUD config get-value project` == $PROJECT_ID"  \
              "Confirming setting project id"

# Clone MongoDB sidecar
cd $GIT_CLONE_LOCATION
run_cmd_fatal "$GIT clone $GIT_REPO" \
              "Cloning MongoDB sidecar project into $GIT_CLONE_LOCATION and go back to previous directory"
cd -

# Create K8S cluster
run_cmd_fatal "$GCLOUD container clusters create $CLUSTER --num-nodes 3 --machine-type n1-standard-1 --zone $ZONE --network $NETWORK" \
              "Creating GKE K8S cluster"

# Set cluster auth credentials in order to interact with the cluster
# @see https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials
run_cmd_fatal "export KUBECONFIG=${KUBECONFIG}" \
              "Setting KUBECONFIG env var for use by the following get-credentials action"
run_cmd_fatal "$GCLOUD container clusters get-credentials $CLUSTER --zone $ZONE" \
              "Retrieving and setting GKE K8S cluster auth credentials"
info_msg 1 "get-credentials updates a kubeconfig file with appropriate credentials and endpoint information " \
  "to point kubectl at a specific cluster in Google Kubernetes Engine so that you can run kubectl to interact " \
  "with the GKE cluster you just set up. get-credentials writes to $HOME/.kube/config by default, or " \
  "alternatively to the path set by KUBECONFIG env variable."
info_msg 1 "See https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials"

# Creating StorageClass backed by SSD volumes
run_cmd_fatal "$KUBECTL --kubeconfig=$KUBECONFIG apply -f ${GIT_PROJECT_BASE_PATH}/example/StatefulSet/googlecloud_ssd.yaml" \
              "Creating StorageClass backed by SSD volumes"
info_msg 1 "Dump of googlecloud_ssd.yaml:"
info_msg 1 "`cat ${GIT_PROJECT_BASE_PATH}/example/StatefulSet/googlecloud_ssd.yaml`"

# Showing the MongoDB storageclass backed by ssd volumes
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get storageclasses -l name=${STORAGECLASS}" \
        "Showing the MongoDB storageclass named '${STORAGECLASS}' backed by ssd volumes"

# Creating MongoDB StatefulSet as a sidecar and Headless Service
run_cmd_fatal "$KUBECTL --kubeconfig=$KUBECONFIG apply -f ${GIT_PROJECT_BASE_PATH}/example/StatefulSet/mongo-statefulset.yaml" \
              "Creating MongoDB StatefulSet as a sidecar and Headless Service"
info_msg 1 "Dump of mongo-statefulset.yaml:"
info_msg 1 "`cat ${GIT_PROJECT_BASE_PATH}/example/StatefulSet/mongo-statefulset.yaml`"
info_msg 1 "A Headless Service is one that doesn't prescribe load balancing. " \
     "When combined with StatefulSets, this will give us individual DNSs to access our pods, and in turn a way to connect to all of our MongoDB nodes individually. " \
     "In the yaml file, you can make sure that the service is headless by verifying that the \"clusterIP\" field is set to \"None\"."
info_msg 1 "Sidecar is a helper container that helps the main container run its jobs and tasks."

# Showing the MongoDB StatefulSet named 'mongo'
info_msg 1 "Sleeping for 180 secs ..."
sleep 180
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get statefulsets" \
        "Showing the MongoDB StatefulSet named '${STATEFULSET}'"

# Showing all the Pods'
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get pods" \
        "Showing all the Pods"

# Showing the MongoDB Service named 'mongo'
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get services -l name=${SERVICE}" \
        "Showing the MongoDB StatefulSet named '${SERVICE}'"

# Pause
continue "Pausing"

# Scaling up Replicasets
run_cmd_fatal "$KUBECTL --kubeconfig=$KUBECONFIG scale --replicas=5 statefulset ${STATEFULSET}" \
              "Scaling up ReplicaSets to 5"

# Showing all the Pods'
info_msg 1 "Sleeping for 180 secs ..."
sleep 180
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get pods" \
        "Showing all the Pods"

# Scaling down Replicasets
run_cmd_fatal "$KUBECTL --kubeconfig=$KUBECONFIG scale --replicas=3 statefulset ${STATEFULSET}" \
              "Scaling down ReplicaSets to 3"

# Showing all the Pods'
info_msg 1 "Sleeping for 180 secs ..."
sleep 180
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get pods" \
        "Showing all the Pods"

#
info_msg 1 "Each pod in a StatefulSet backed by a Headless Service will have a stable DNS name."
info_msg 1 "You can connect directly to each Pod like this: mongodb://mongo-0.mongo,mongo-1.mongo,mongo-2.mongo:27017/dbname_?"

# Pause
continue "Pausing before deletion."

# Deleting the StatefulSet
run_cmd_fatal "$KUBECTL --kubeconfig=$KUBECONFIG delete statefulset ${STATEFULSET}" \
              "Deleting the StatefulSet"

# Deleting the Service
run_cmd_fatal "$KUBECTL --kubeconfig=$KUBECONFIG delete service ${SERVICE}" \
              "Deleting the Service"

# Deleting the volumes backed by the StorageClass
run_cmd_fatal "$KUBECTL --kubeconfig=$KUBECONFIG delete pvc -l role=${STATEFULSET}" \
              "Deleting the volumes backed by the StorageClass"

# Delete the cluster
run_cmd_fatal "$GCLOUD container clusters delete $CLUSTER --zone $ZONE" \
              "Deleting the GKE K8S cluster"

exit 0
