#!/bin/bash
##--
# Runs creating and managing K8S Secrets.
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

LABEL="secrets"
NOW=$(date '+%Y%m%d-%H%M%S')
GCLOUD="gcloud"
KUBECTL="kubectl"
ZONE="us-west1-a"
CLUSTER="${LABEL}-${NOW}"
NETWORK="default"
RES_DIR="res"
TMP_DIR="tmp/${LABEL}-${NOW}"
LOG_FILE="log/run-${LABEL}-${NOW}.log"
KUBECONFIG="${TMP_DIR}/kube/config"
SECRETS1="my-secrets-1"
SECRETS2="my-secrets-2"
SECRETS_BASE_PATH="${RES_DIR}/secrets"
USERNAME_FILE="${SECRETS_BASE_PATH}/username1.txt"
PASSWORD_FILE="${SECRETS_BASE_PATH}/password1.txt"
SECRETS2_YAML="${TMP_DIR}/secrets2.yaml"
SECRETS2_TEMPLATE_YAML="${SECRETS_BASE_PATH}/secrets2_template.yaml"

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
check_exists_fatal "$KUBECTL"

# Create tmp directory
run_cmd_fatal "mkdir -p $TMP_DIR" \
              "Creating folder"

# Setting project id
run_cmd_fatal "$GCLOUD config set project $PROJECT_ID" \
              "Setting project id"

# Confirming project id set
run_cmd_fatal "test `$GCLOUD config get-value project` == $PROJECT_ID"  \
              "Confirming setting project id"

# @TODO
# We clean up project id only after it was successfully set
#trap cleanup_set_project_id 0 1 2 3 6

# Create K8S cluster
run_cmd_fatal "$GCLOUD container clusters create $CLUSTER --num-nodes 1 --machine-type n1-standard-1 --zone $ZONE --network $NETWORK" \
              "Creating GKE K8S cluster"

# Set cluster auth credentials in order to interact with the cluster
# @see https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials
run_cmd_fatal "export KUBECONFIG=${KUBECONFIG}" \
              "Setting KUBECONFIG env var for use by the following get-credentials action"
run_cmd_fatal "$GCLOUD container clusters get-credentials $CLUSTER --zone $ZONE" \
              "Retrieving and setting GKE K8S cluster auth credentials"
echo "${TEXT_COLOR_YELLOW}[INFO]${TEXT_RESET} get-credentials updates a kubeconfig file with appropriate credentials and endpoint information " \
  "to point kubectl at a specific cluster in Google Kubernetes Engine so that you can run kubectl to interact " \
  "with the GKE cluster you just set up. get-credentials writes to $HOME/.kube/config by default, or " \
  "alternatively to the path set by KUBECONFIG env variable."
echo "${TEXT_COLOR_YELLOW}[INFO]${TEXT_RESET} See https://cloud.google.com/sdk/gcloud/reference/container/clusters/get-credentials"

# Dumping contents of raw username and password file
echo "${TEXT_COLOR_YELLOW}[VERBOSE]${TEXT_RESET} Content of ${USERNAME_FILE}:"
echo "${TEXT_COLOR_YELLOW}[VERBOSE]${TEXT_RESET} `cat ${USERNAME_FILE}`"
echo "${TEXT_COLOR_YELLOW}[VERBOSE]${TEXT_RESET} Content of ${PASSWORD_FILE}:"
echo "${TEXT_COLOR_YELLOW}[VERBOSE]${TEXT_RESET} `cat ${PASSWORD_FILE}`"

# Manually packages these files into a Secret  and creates the object on the Apiserver.
run_cmd_fatal "$KUBECTL --kubeconfig=$KUBECONFIG create secret generic $SECRETS1 --from-file=${USERNAME_FILE} --from-file=${PASSWORD_FILE}" \
              "Manually packaging these files into a Secret and creates the object on the Apiserver."

# Configurationally packages these files into a Secret  and creates the object on the Apiserver.
sed "s#{{SECRETS}}#${SECRETS2}#" ${SECRETS2_TEMPLATE_YAML} > ${SECRETS2_YAML}
run_cmd_fatal "$KUBECTL --kubeconfig=$KUBECONFIG create -f ${SECRETS2_YAML}" \
              "Configurationally packaging these files into a Secret and creates the object on the Apiserver."

# Checking all Secrets
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get secrets" \
        "Checking all Secrets"

# Checking secrets1 Secrets
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get secrets ${SECRETS1}" \
        "Checking ${SECRETS1} Secrets"

# Checking secrets2 Secrets
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get secrets ${SECRETS2}" \
        "Checking ${SECRETS2} Secrets"

# Describing the secrets1 Secrets
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG describe secrets/${SECRETS1}" \
        "Describing ${SECRETS1} Secrets"

# Describing the secrets2 Secrets
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG describe secrets/${SECRETS2}" \
        "Describing ${SECRETS2} Secrets"

# Decoding secrets1 Secret, output in yaml format
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get secret ${SECRETS1} -o yaml" \
        "Decoding ${SECRETS1} Secret, output in yaml format"
echo "${TEXT_COLOR_YELLOW}[INFO]${TEXT_RESET} Pipe the encoded value to base64 --decode to get the actual value, eg- \"echo '<encoded_string>' | base 64 --decode\""

# Decoding secrets2 Secret, output in yaml format
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get secret ${SECRETS2} -o yaml" \
        "Decoding ${SECRETS2} Secret, output in yaml format"
echo "${TEXT_COLOR_YELLOW}[INFO]${TEXT_RESET} Pipe the encoded value to base64 --decode to get the actual value, eg- \"echo '<encoded_string>' | base 64 --decode\""

# Viewing it online and awaiting continuation
continue "Pausing."

# Deleting secrets1 Secret
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG delete secret ${SECRETS1}" \
        "Deleting ${SECRETS1} Secret"

# Checking all Secrets
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get secrets" \
        "Checking all Secrets"

# Deleting secrets2 Secret
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG delete secret ${SECRETS2}" \
        "Deleting ${SECRETS2} Secret"

# Checking all Secrets
run_cmd "$KUBECTL --kubeconfig=$KUBECONFIG get secrets" \
        "Checking all Secrets"

# Viewing it online and awaiting continuation
continue "Pausing before deleting cluster."

# Delete the cluster
run_cmd_fatal "$GCLOUD container clusters delete $CLUSTER --zone $ZONE" \
              "Deleting the GKE K8S cluster"

exit 0
