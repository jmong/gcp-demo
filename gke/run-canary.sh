#!/bin/bash
##--
# Runs canary and blue-green managed deployments through configuration files.
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

LABEL="canary"
NOW=$(date '+%Y%m%d-%H%M%S')
GCLOUD="gcloud"
DOCKER="docker"
KUBECTL="kubectl"
GIT="git"
ZONE="us-central1-a"
CLUSTER="${LABEL}-${NOW}"
NETWORK="default"
DEPLOYMENT="${LABEL}-deployment"
PORT=8080
LOG_FILE="log/run-${LABEL}-${NOW}.log"
TMP_DIR="tmp/${LABEL}-${NOW}"
KUBECONFIG="${TMP_DIR}/kube/config"
GIT_REPO="https://github.com/googlecodelabs/orchestrate-with-kubernetes.git"
GIT_CLONE_LOCATION="${TMP_DIR}/git"
GIT_PROJECT_BASE_PATH="${GIT_CLONE_LOCATION}/orchestrate-with-kubernetes"
GIT_PROJECT_KUBERNETES_PATH="${GIT_PROJECT_BASE_PATH}/kubernetes"
HELLO_DEPLOYMENT_PATH="deployments/hello.yaml"
HELLO_SERVICE_PATH="services/hello.yaml"
HELLO_CANARY_DEPLOYMENT_PATH="deployments/hello-canary.yaml"
HELLO_CANARY_SERVICE_PATH="services/hello-canary.yaml"
HELLO_BLUE_DEPLOYMENT_PATH="deployments/hello-blue.yaml"
HELLO_BLUE_SERVICE_PATH="services/hello-blue.yaml"
HELLO_GREEN_DEPLOYMENT_PATH="deployments/hello-green.yaml"
HELLO_GREEN_SERVICE_PATH="services/hello-green.yaml"

###############
## VARIABLES ##
###############

IS_VERBOSE=0
PROJECT_ID=""
CLUSTER_AUTH_CREDS=""

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
check_exists_fatal "$DOCKER"
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

# Create K8S cluster
run_cmd_fatal "$GCLOUD container clusters create $CLUSTER --num-nodes 5 --machine-type n1-standard-1 --zone $ZONE --network $NETWORK --issue-client-certificate" \
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

verbose_msg ${IS_VERBOSE} "Dumping contents of ${KUBECONFIG}:\n `cat ${KUBECONFIG}`"

# Clone the deployment configuration files
cd $GIT_CLONE_LOCATION
run_cmd_fatal "$GIT clone $GIT_REPO" \
              "Cloning deployment configuration files into $GIT_CLONE_LOCATION and go back to previous directory"
cd -

# Deploying hello
run_cmd_fatal "$KUBECTL create -f ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_DEPLOYMENT_PATH} --kubeconfig=$KUBECONFIG" \
              "Creating the hello Deployment"

# Exposing hello as a Service
run_cmd_fatal "$KUBECTL create -f ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_SERVICE_PATH} --kubeconfig=$KUBECONFIG" \
              "Exposing the hello Deployment as a Service"

# Deploying hello-canary
sed -i'' -e "s#version: 2.0.0#version: 1.0.0#" ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_CANARY_DEPLOYMENT_PATH}
verbose_msg "${IS_VERBOSE}" "Deploying 1 replica of this image as specified in ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_CANARY_DEPLOYMENT_PATH} (egrep 'replicas|image' ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_CANARY_DEPLOYMENT_PATH} :" && \
  egrep 'replicas|image' ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_CANARY_DEPLOYMENT_PATH}
run_cmd_fatal "$KUBECTL create -f ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_CANARY_DEPLOYMENT_PATH} --kubeconfig=$KUBECONFIG" \
              "Creating the hello-canary Deployment"

# Showing all the deployments
sleep 30
run_cmd "$KUBECTL get deployments --kubeconfig=$KUBECONFIG" \
        "Showing all the Deployments"
info_msg 1 "You should see 1 hello-canary and 3 hello Deployments."

# Viewing it and awaiting continuation
continue "Pause for viewing."

# Now lets do a blue-green deployment

info_msg 1 "Now lets do a blue-green deployment."
echo

# Point the Service to "blue" (hello version 1.0.0)
run_cmd_fatal "$KUBECTL apply -f ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_BLUE_SERVICE_PATH} --kubeconfig=$KUBECONFIG" \
              "Point Service to blue Deployment"
info_msg 1 "In ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_BLUE_SERVICE_PATH}, you can see that the selectors app is hello and version is 1.0.0: "
egrep "app|version" ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_BLUE_SERVICE_PATH}

# Viewing it and awaiting continuation
continue "Pausing to view in GCP Console that hello Service has a hello Deployment that has label version=1.0.0"

# Deploying "green" (hello version 2.0.0)
run_cmd_fatal "$KUBECTL create -f ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_GREEN_DEPLOYMENT_PATH} --kubeconfig=$KUBECONFIG" \
              "Creating the green Deployment"
info_msg 1 "green Deployment is running version 2.0.0: "
egrep "app|version" ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_GREEN_SERVICE_PATH}

# Point the Service to "green" (hello version 2.0.0)
run_cmd_fatal "$KUBECTL apply -f ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_GREEN_SERVICE_PATH} --kubeconfig=$KUBECONFIG" \
              "Point Service to green Deployment"
info_msg 1 "In ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_GREEN_SERVICE_PATH}, you can see that the selectors app is hello and version is 2.0.0: "
egrep "app|version" ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_GREEN_SERVICE_PATH}

# Viewing it and awaiting continuation
continue "Pausing to view in GCP Console that hello Service has a hello Deployment that has label version=2.0.0"

# "Rollback" to "blue" is just simply pointing the Service to "blue" (hello version 1.0.0)
run_cmd_fatal "$KUBECTL apply -f ${GIT_PROJECT_KUBERNETES_PATH}/${HELLO_BLUE_SERVICE_PATH} --kubeconfig=$KUBECONFIG" \
              "Rolling back to blue is simply pointing Service back to blue Deployment"

# Viewing it and awaiting continuation
continue "Pausing to view in GCP Console that hello Service has a hello Deployment that has label version=1.0.0"

# Delete the hello Service
run_cmd_fatal "$KUBECTL delete service hello" \
              "Deleting the hello Service"

# Delete the cluster
run_cmd_fatal "$GCLOUD container clusters delete $CLUSTER --zone $ZONE" \
              "Deleting the GKE K8S cluster"

exit 0
