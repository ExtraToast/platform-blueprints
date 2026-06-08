#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bootstrap-k3s-agent-token \
    --control-plane <user@host> \
    --agent <user@host> \
    --source-token-path <path> \
    --target-token-path <path> \
    [--control-plane-port <port>] \
    [--agent-port <port>] \
    [--identity-file <path>]
EOF
  exit 64
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 69
  fi
}

require_value() {
  local name="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    echo "Missing required option: ${name}" >&2
    exit 64
  fi
}

validate_target() {
  local name="$1"
  local value="$2"
  if [[ "${value}" =~ [[:space:]] ]]; then
    echo "${name} must not contain whitespace: ${value}" >&2
    exit 65
  fi
}

validate_remote_path() {
  local name="$1"
  local value="$2"
  if [[ "${value}" == *"'"* || "${value}" == *$'\n'* ]]; then
    echo "${name} must not contain quotes or newlines: ${value}" >&2
    exit 65
  fi
}

control_plane=""
agent=""
source_token_path=""
target_token_path=""
control_plane_port=""
agent_port=""
identity_file=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --control-plane)
      shift
      [[ "$#" -gt 0 ]] || usage
      control_plane="$1"
      ;;
    --agent)
      shift
      [[ "$#" -gt 0 ]] || usage
      agent="$1"
      ;;
    --source-token-path)
      shift
      [[ "$#" -gt 0 ]] || usage
      source_token_path="$1"
      ;;
    --target-token-path)
      shift
      [[ "$#" -gt 0 ]] || usage
      target_token_path="$1"
      ;;
    --control-plane-port)
      shift
      [[ "$#" -gt 0 ]] || usage
      control_plane_port="$1"
      ;;
    --agent-port)
      shift
      [[ "$#" -gt 0 ]] || usage
      agent_port="$1"
      ;;
    --identity-file)
      shift
      [[ "$#" -gt 0 ]] || usage
      identity_file="$1"
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
  shift
done

require_command dirname
require_command ssh

require_value "--control-plane" "${control_plane}"
require_value "--agent" "${agent}"
require_value "--source-token-path" "${source_token_path}"
require_value "--target-token-path" "${target_token_path}"

validate_target "--control-plane" "${control_plane}"
validate_target "--agent" "${agent}"
validate_remote_path "--source-token-path" "${source_token_path}"
validate_remote_path "--target-token-path" "${target_token_path}"

if [[ -n "${identity_file}" && ! -f "${identity_file}" ]]; then
  echo "SSH identity file not found: ${identity_file}" >&2
  exit 66
fi

control_plane_ssh=(ssh)
agent_ssh=(ssh)

if [[ -n "${control_plane_port}" ]]; then
  control_plane_ssh+=(-p "${control_plane_port}")
fi

if [[ -n "${agent_port}" ]]; then
  agent_ssh+=(-p "${agent_port}")
fi

if [[ -n "${identity_file}" ]]; then
  control_plane_ssh+=(-o IdentitiesOnly=yes -i "${identity_file}")
  agent_ssh+=(-o IdentitiesOnly=yes -i "${identity_file}")
fi

control_plane_ssh+=("${control_plane}")
agent_ssh+=("${agent}")

target_token_dir="$(dirname "${target_token_path}")"
token="$("${control_plane_ssh[@]}" "sudo cat '${source_token_path}'")"
if [[ -z "${token}" ]]; then
  echo "Control plane returned an empty k3s token" >&2
  exit 70
fi

"${agent_ssh[@]}" "sudo install -d -m 0700 -o root -g root '${target_token_dir}'"
printf '%s\n' "${token}" |
  "${agent_ssh[@]}" "sudo tee '${target_token_path}' >/dev/null && sudo chown root:root '${target_token_path}' && sudo chmod 600 '${target_token_path}'"

echo "Copied k3s agent join token to ${agent}:${target_token_path}"
