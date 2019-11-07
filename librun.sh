#!/bin/bash

# TOP_PID must be exported from the caller script
if [ -z ${TOP_PID} ]; then
  exit 1
fi

# Text decoration

export TEXT_COLOR_RED=$(tput setaf 1)
export TEXT_COLOR_GREEN=$(tput setaf 2)
export TEXT_COLOR_YELLOW=$(tput setaf 3)
export TEXT_DEC_BOLD=$(tput bold)
export TEXT_RESET=$(tput sgr0)

##--
# Checks if a command exists or dies.
# @param $1 name of command
##--
check_exists_fatal() {
  echo -n "${TEXT_COLOR_YELLOW}[CHECK]${TEXT_RESET} Checking if $1 exists ..... "
  ([[ ! -z `which $1` ]] && echo "${TEXT_COLOR_GREEN}DONE${TEXT_RESET}") \
    || (echo "${TEXT_COLOR_RED}FAIL${TEXT_RESET}" && echo "${TEXT_DEC_BOLD}${TEXT_COLOR_RED}ERROR, exiting.${TEXT_RESET}" && kill -s TERM $TOP_PID)
}

##--
# Checks if a variable has a non-empty value.
# @param $1 variable to check
# @param $2 description of the variable
##--
check_nonempty_fatal() {
  echo -n "${TEXT_COLOR_YELLOW}[CHECK]${TEXT_RESET} Checking if $2 is not empty ..... "
  ([[ ! -z $1 ]] && echo "${TEXT_COLOR_GREEN}DONE${TEXT_RESET}") \
    || (echo "${TEXT_COLOR_RED}FAIL${TEXT_RESET}" && echo "${TEXT_DEC_BOLD}${TEXT_COLOR_RED}ERROR, exiting.${TEXT_RESET}" && kill -s TERM $TOP_PID)
}

##--
# Clean up setting the project id.
##--
cleanup_set_project_id() {
  local cmd="$GCLOUD config unset project"
  echo "${TEXT_COLOR_YELLOW}[RUN]${TEXT_RESET} Cleanup: Unsetting project id ($cmd) ..... "
  $cmd
  ([[ $? -eq 0 ]] && echo "${TEXT_COLOR_GREEN}DONE${TEXT_RESET}") || echo "${TEXT_COLOR_RED}FAIL${TEXT_RESET}"
}

##--
# Clean up.
##--
cleanup() {
  cleanup_set_project_id
}

##--
# Runs shell command.
# It checks that exit code value is 0 to determine if the shell command ran successfully.
# @param $1 shell command to run
# @param $2 informative message to display
# @param $3 (optional) message to display in case of error
##--
run_cmd() {
  local cmd=$1
  local msg=$2
  local errmsg=${3:-}

  echo "${TEXT_COLOR_YELLOW}[RUN]${TEXT_RESET} $msg"
  echo "# $cmd #"
  $cmd
  local ret=$?
  wait
  echo -n "..... " && ([[ $ret -ne 0 ]] && echo "${TEXT_COLOR_RED}FAIL${TEXT_RESET}" && echo "${TEXT_COLOR_RED}ERROR:${TEXT_RESET} $errmsg") \
    || echo "${TEXT_COLOR_GREEN}DONE${TEXT_RESET}"
}

##--
# Runs shell command or dies.
# It checks that exit code value is 0 to determine if the shell command ran successfully.
# @param $1 shell command to run
# @param $2 informative message to display
# @param $3 (optional) message to display in case of error
##--
run_cmd_fatal() {
  local cmd=$1
  local msg=$2
  local errmsg=${3:-"<none>"}

  echo "${TEXT_COLOR_YELLOW}[RUN]${TEXT_RESET} $msg"
  echo "# $cmd #"
  $cmd
  local ret=$?
  wait
  echo -n "..... " && ([[ $ret -ne 0 ]] && echo "${TEXT_COLOR_RED}FAIL${TEXT_RESET}" && echo "${TEXT_COLOR_RED}ERROR:${TEXT_RESET} $errmsg" && echo "${TEXT_DEC_BOLD}${TEXT_COLOR_RED}EXITING.${TEXT_RESET}" && kill -s TERM $TOP_PID) \
    || echo "${TEXT_COLOR_GREEN}DONE${TEXT_RESET}"
}

##--
# Pretend running shell command.
# Always display DONE message.
# @param $1 shell command to run
# @param $2 informative message to display
# @param $3 (optional) message to display in case of error
##--
run_cmd_dryrun() {
  local cmd=$1
  local msg=$2
  local errmsg=${3:-}

  echo "${TEXT_COLOR_YELLOW}[DRYRUN]${TEXT_RESET} $msg"
  echo "# $cmd #"
  echo "  ${TEXT_COLOR_GREEN}DONE${TEXT_RESET}"
}

##-
# Display verbose message.
# @param $1 is verbose flag on
# @param $2 message to display
##-
verbose_msg() {
  local isverbose=$1
  local message=$2

  [[ $isverbose -eq 1 ]] && echo "${TEXT_COLOR_YELLOW}[VERBOSE]${TEXT_RESET} ${message}" 
}

##-
# Display info message.
# @param $1 is info flag on
# @param $2 message to display
##-
info_msg() {
  local isinfo=$1
  local message=$2

  [[ $isinfo -eq 1 ]] && echo "${TEXT_COLOR_YELLOW}[INFO]${TEXT_RESET} ${message}"
}

##-
# Prompt to continue.
# @param $1 message to display
##-
continue() {
  local message=$1

  echo "##"
  echo "# $message"
  echo -n "# Press <enter> to continue: "
  read
  echo "##"
}
