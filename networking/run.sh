#!/bin/bash
##--
# Runs a simple tearing up, customizing, and tearing down of VPC networks, subnets, and firewall rules.
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
NETWORK_1="my-network1"
NETWORK_2="my-network2"
SUBNET_1="${NETWORK_1}-subnet1"
SUBNET_2="${NETWORK_2}-subnet2"
REGION_1="us-central1"
REGION_2="europe-west1"
FIREWALL_1="${NETWORK_1}-allow-icmp-ssh-rdp"
TMP_DIR="tmp/${NOW}"
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

# Setting project id
run_cmd_fatal "$GCLOUD config set project $PROJECT_ID" \
              "Setting project id"

# Confirming project id set
run_cmd_fatal "test `$GCLOUD config get-value project` == $PROJECT_ID"  \
              "Confirming setting project id"

# Creating first custom VPC network
run_cmd_fatal "$GCLOUD compute networks create ${NETWORK_1} --subnet-mode=custom" \
               "Creating first custom VPC network"

# Creating second custom VPC network
run_cmd_fatal "$GCLOUD compute networks create ${NETWORK_2} --subnet-mode=custom" \
               "Creating second custom VPC network"

# Creating US subnet in network ${NETWORK_1}
run_cmd_fatal "$GCLOUD compute networks subnets create $SUBNET_1 --network=${NETWORK_1} --region=$REGION_1 --range=172.16.0.0/24" \
               "Creating US subnet in network ${NETWORK_1}"

# Creating EU subnet in network ${NETWORK_2}
run_cmd_fatal "$GCLOUD compute networks subnets create $SUBNET_2 --network=${NETWORK_2} --region=$REGION_2 --range=172.20.0.0/20" \
               "Creating EU subnet in network ${NETWORK_2}"

# Viewing the available VPC networks sorted by networks.
run_cmd_fatal "$GCLOUD compute networks subnets list --sort-by=NETWORK" \
               "Viewing available VPC networks sorted by networks"

# Creating firewall rule that allows icmp,ssh,rdp ingress into $NETWORK_1
run_cmd_fatal "$GCLOUD compute firewall-rules create $FIREWALL_1 --direction=INGRESS --priority=1000 --network=${NETWORK_1} --action=ALLOW --rules=icmp,tcp:22,tcp:3389 --source-ranges=0.0.0.0/0" \
               "Creating firewall rule that allows icmp,ssh,rdp ingress into $NETWORK_1"

# Viewing firewall rules sorted by networks
run_cmd_fatal "$GCLOUD compute firewall-rules list --sort-by=NETWORK" \
               "Viewing firewall rules sorted by networks"

# Viewing it online
continue "Pause to view it online."

# Deleting the firewall rule
run_cmd_fatal "$GCLOUD compute firewall-rules delete $FIREWALL_1" \
              "Deleting the firewall rule"

# Deleting the US subnet in network ${NETWORK_1}
run_cmd_fatal "$GCLOUD compute networks subnets delete $SUBNET_1 --region=$REGION_1" \
              "Deleting the US subnet in network ${NETWORK_1}"

# Deleting the EU subnet in network ${NETWORK_2}
run_cmd_fatal "$GCLOUD compute networks subnets delete $SUBNET_2 --region=$REGION_2" \
              "Deleting the EU subnet in network ${NETWORK_2}"

# Deleting the first VPC network
run_cmd_fatal "$GCLOUD compute networks delete $NETWORK_1" \
               "Deleting the first VPC network"

# Deleting the second VPC network
run_cmd_fatal "$GCLOUD compute networks delete $NETWORK_2" \
               "Deleting the second VPC network"

exit 0
