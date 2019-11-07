#!/bin/bash
##--
# Runs a simple tearing up and down of a custom VPC network and subnet.
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
REGION="us-west1"
ZONE="${REGION}-a"
CLUSTER="my-vpc"
IP_RANGE="10.0.0.0/16"
TMP_DIR="tmp/${NOW}"
LOG_FILE="log/run-${NOW}.log"
NETWORK="my-network-${NOW}"
SUBNET="my-subnet-${NOW}"
VM="my-vm-${NOW}"
NETWORK_FIREWALL="my-network-fw"
SUBNET_FIREWALL="my-subnet-fw"

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

# Creating custom VPC network
run_cmd_fatal "$GCLOUD compute networks create $NETWORK --subnet-mode custom" \
               "Creating custom VPC network"

# Adding a firewall rule to this VPC network
run_cmd_fatal "$GCLOUD compute firewall-rules create $NETWORK_FIREWALL --network $NETWORK --allow tcp:22,icmp" \
              "Adding a firewall rule to this VPC network"

# Creating subnet within this VPC network and specifying region and ip range
run_cmd_fatal "$GCLOUD compute networks subnets create $SUBNET --network $NETWORK --range $IP_RANGE --region $REGION" \
              "Creating subnet within this VPC network and specifying region and ip range"

# Creating a VM inside this VPC network and subnet
run_cmd_fatal "$GCLOUD compute instances create $VM --zone $ZONE --network $NETWORK --subnet $SUBNET" \
              "Creating a VM inside this VPC network and subnet"

# Adding a firewall rule in this subnet
run_cmd_fatal "$GCLOUD compute firewall-rules create $SUBNET_FIREWALL --network $NETWORK --allow tcp:5001,udp:5001" \
              "Adding a firewall rule in this subnet"

# Listing all routes in this project
run_cmd_fatal "$GCLOUD compute routes list --project $PROJECT_ID" \
              "Listing all routes in this project"

# Listing all firewall rules
run_cmd_fatal "$GCLOUD compute firewall-rules list" \
              "Listing all firewall rules"

# Viewing it online
continue "Pausing before deleting the subnet and network."

# Deleting the VM
run_cmd_fatal "$GCLOUD compute instances delete $VM" \
              "Deleting the VM"

# Deleting the subnet firewall rule
run_cmd_fatal "$GCLOUD compute firewall-rules delete $SUBNET_FIREWALL" \
              "Deleting the subnet firewall rule"

# Deleting the network firewall rule
run_cmd_fatal "$GCLOUD compute firewall-rules delete $NETWORK_FIREWALL" \
              "Deleting the network firewall rule"

# Deleting the subnet 
run_cmd_fatal "$GCLOUD compute networks subnets delete $SUBNET --region $REGION" \
              "Deleting the subnet" 

# Deleting the VPC network
run_cmd_fatal "$GCLOUD compute networks delete $NETWORK" \
              "Deleting the VPC network"

exit 0
