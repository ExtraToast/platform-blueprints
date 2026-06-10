#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  restore-hostpath-archive --ssh-target <user@host> --target-path <dir> --archive <file.tar.gz> [options]

Options:
  --ssh-port <port>          SSH port. Default: 22.
  --identity-file <path>     SSH identity file.
  --ssh-opts "<opts>"        Extra SSH options, shell-split.
  --sudo "<cmd>"             Remote privilege wrapper. Default: sudo -n.
  --strip-components <n>     Tar strip count before writing into target root. Default: 0.
  --wipe-target              Delete existing target contents before extraction.
  --dry-run                  Validate inputs and print the restore action.

Streams a local tar.gz archive into a caller-supplied remote host path. No host,
path, or privilege policy is embedded in this script.
EOF
  exit 64
}

shell_quote() {
  printf "'%s'" "${1//\'/\'\"\'\"\'}"
}

require_non_empty() {
  local name="$1" value="$2"
  [[ -n "${value}" ]] || { echo "Missing ${name}" >&2; exit 64; }
}

require_non_negative_int() {
  local name="$1" value="$2"
  [[ "${value}" =~ ^[0-9]+$ ]] || { echo "${name} must be a non-negative integer: ${value}" >&2; exit 64; }
}

SSH_TARGET=""
SSH_PORT=22
IDENTITY_FILE=""
SSH_OPTS=""
REMOTE_SUDO="sudo -n"
TARGET_PATH=""
ARCHIVE=""
STRIP_COMPONENTS=0
WIPE_TARGET=false
DRY_RUN=false

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --ssh-target) shift; [[ "$#" -gt 0 ]] || usage; SSH_TARGET="$1" ;;
    --ssh-port) shift; [[ "$#" -gt 0 ]] || usage; SSH_PORT="$1" ;;
    --identity-file) shift; [[ "$#" -gt 0 ]] || usage; IDENTITY_FILE="$1" ;;
    --ssh-opts) shift; [[ "$#" -gt 0 ]] || usage; SSH_OPTS="$1" ;;
    --sudo) shift; [[ "$#" -gt 0 ]] || usage; REMOTE_SUDO="$1" ;;
    --target-path) shift; [[ "$#" -gt 0 ]] || usage; TARGET_PATH="$1" ;;
    --archive) shift; [[ "$#" -gt 0 ]] || usage; ARCHIVE="$1" ;;
    --strip-components) shift; [[ "$#" -gt 0 ]] || usage; STRIP_COMPONENTS="$1" ;;
    --wipe-target) WIPE_TARGET=true ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
  shift
done

require_non_empty "--ssh-target" "${SSH_TARGET}"
require_non_empty "--target-path" "${TARGET_PATH}"
require_non_empty "--archive" "${ARCHIVE}"
require_non_negative_int "--ssh-port" "${SSH_PORT}"
require_non_negative_int "--strip-components" "${STRIP_COMPONENTS}"
[[ -f "${ARCHIVE}" ]] || { echo "Archive not found: ${ARCHIVE}" >&2; exit 66; }
if [[ -n "${IDENTITY_FILE}" ]]; then
  [[ -f "${IDENTITY_FILE}" ]] || { echo "SSH identity file not found: ${IDENTITY_FILE}" >&2; exit 66; }
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "Would restore $(basename "${ARCHIVE}") to ${SSH_TARGET}:${TARGET_PATH}"
  exit 0
fi

SSH_CMD=(ssh -p "${SSH_PORT}")
if [[ -n "${IDENTITY_FILE}" ]]; then
  SSH_CMD+=(-i "${IDENTITY_FILE}")
fi
if [[ -n "${SSH_OPTS}" ]]; then
  # shellcheck disable=SC2206
  EXTRA_SSH_OPTS=(${SSH_OPTS})
  SSH_CMD+=("${EXTRA_SSH_OPTS[@]}")
fi

remote_script="set -euo pipefail; mkdir -p $(shell_quote "${TARGET_PATH}")"
if [[ "${WIPE_TARGET}" == "true" ]]; then
  remote_script="${remote_script}; find $(shell_quote "${TARGET_PATH}") -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +"
fi
remote_script="${remote_script}; tar -xzpf - -C $(shell_quote "${TARGET_PATH}") --strip-components ${STRIP_COMPONENTS}"

if [[ -n "${REMOTE_SUDO}" ]]; then
  remote_command="${REMOTE_SUDO} bash -ec $(shell_quote "${remote_script}")"
else
  remote_command="bash -ec $(shell_quote "${remote_script}")"
fi

echo "Restoring $(basename "${ARCHIVE}") to ${SSH_TARGET}:${TARGET_PATH}"
"${SSH_CMD[@]}" "${SSH_TARGET}" "${remote_command}" < "${ARCHIVE}"
echo "Host-path restore finished: ${SSH_TARGET}:${TARGET_PATH}"
