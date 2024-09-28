#!/bin/sh

set -eu
#set -x

CONFIG_DIR=/usr/local/etc/resticbackup
REPOSITORIES_CONFIG_DIR=${CONFIG_DIR}/repositories
FILES_TO_BACKUP=${CONFIG_DIR}/files_to_backup
RESTIC_CMD=/usr/local/bin/restic

# Load global config
. ${CONFIG_DIR}/general.conf

# Define global variables
: "${DEBUG:=false}"
: "${ACTION:=}"
: "${RESTIC_GLOBAL_OPTIONS:=}"
: "${RESTIC_OPTIONS:=}"
: "${SKIP_FILES_FROM:=false}"
: "${SAVE_CONFIG_STDIN:=false}"
: "${INPUT_FILE:=/dev/null}"
: "${ONLY_REPOSITORY:=}"

export RESTIC_PASSWORD

echoe() {
    echo "$@" >&2
}

usage() {
    cat >&2 << EOF
Usage: $(basename $0) [-h] | -a <action> [-s] [-c] [-r <repository>] -- <restic options>"
Run a restic configuration backup.

Global options:
  -h              Show this help
  -a <action>     The action to run
  -s              Skip reading file to backup from "${FILES_TO_BACKUP}"
  -c              Read configuration file to backup via stdin
  -r <repository> Only backup to this specific repository

actions:
  init        Init a restic repository
  backup      Run a backup
  snapshots   List snapshots
  ls          List latest snapshot files
  prune       Remove unneeded data from the repository
EOF
}

[ $# -eq 0 ] && { usage; exit 1; }
echo -e "\$ $(basename "${0}") $*\n"
ARGS=$(getopt ha:sc:r: $*)
set -- $ARGS
while :; do
  case "$1" in
    -a)
      ACTION="${2}"
      shift; shift
      ;;
    -s)
      SKIP_FILES_FROM=true
      shift
      ;;
    -c)
      SKIP_FILES_FROM=true
      SAVE_CONFIG_STDIN=true
      INPUT_FILE="${2}"
      shift; shift
      ;;
    -r)
      ONLY_REPOSITORY="${2}"
      shift; shift
      ;;
    --)
      shift;
      break
      ;;
    h|*)
      usage
      exit 0
      ;;
  esac
done

{ # redirect everything to stderr else configctl will not show errors

if [ "${ACTION}" = "" ]; then
  echoe "E: an action must be specified"
  echoe
  usage
  exit 1
fi

! ${SKIP_FILES_FROM} && [ "${ACTION}" = "backup" ] && RESTIC_OPTIONS="${RESTIC_OPTIONS} --files-from ${FILES_TO_BACKUP}"
${SAVE_CONFIG_STDIN} && [ "${ACTION}" = "backup" ] && RESTIC_OPTIONS="${RESTIC_OPTIONS} --stdin --stdin-filename /config.xml"

WAS_TRIGGERED=false
HAS_ERROR=false

for repository in ${REPOSITORIES_CONFIG_DIR}/*.conf; do {
    repository="$(basename ${repository})"

    # filter repositories
    [ -n "${ONLY_REPOSITORY}" ] && { [ "${repository}" = "${ONLY_REPOSITORY}.conf" ] || continue; }

    # load repository config
    # shellcheck source=/dev/null
    . ${REPOSITORIES_CONFIG_DIR}/${repository}

    # Check if the repository is enabled
    ${REPOSITORY_ENABLED:-false} || { ! ${DEBUG} || echoe "Skipping '${repository}' as config is disabled"; continue; }
    [ -z "${ONLY_REPOSITORY}" ] && echoe "Restic repository: ${repository}"
    WAS_TRIGGERED=true

    echo "\$ ${RESTIC_CMD} ${RESTIC_GLOBAL_OPTIONS} "${ACTION}" ${RESTIC_OPTIONS} ${@}"
    if ! cat "${INPUT_FILE}" | ${RESTIC_CMD} ${RESTIC_GLOBAL_OPTIONS} "${ACTION}" ${RESTIC_OPTIONS} ${@} 2>&1; then
      HAS_ERROR=true
    fi

}; done


! ${WAS_TRIGGERED} && { echoe "No action were triggered"; exit 2; }
${HAS_ERROR} && [ "${ACTION}" = "backup" ] && { echoe "At least one of the backup failed"; exit 3; }

} 2>&1 | tee -a /tmp/restic.log # redirect everything to stdout else configctl will not show errors
