#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  backup-service-state --manifest <manifest.tsv> --output-dir <dir> [options]

Options:
  --host-group <group>       Include only one host group.
  --service <service>        Include one service. May be repeated.
  --list                     Print selected manifest rows and exit.
  --dry-run                  Validate/filter rows without connecting to hosts.

Manifest columns:
  host_group service_name source_path required description

Environment per host group:
  BACKUP_<GROUP>_SSH_TARGET
  or BACKUP_<GROUP>_SSH_HOST + BACKUP_<GROUP>_SSH_USER
  optional BACKUP_<GROUP>_SSH_PORT
  optional BACKUP_<GROUP>_SSH_IDENTITY_FILE
  optional BACKUP_<GROUP>_SSH_OPTS
  optional BACKUP_<GROUP>_SUDO (default: sudo -n)
EOF
  exit 64
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
  else
    echo "Missing sha256sum or shasum" >&2
    exit 69
  fi
}

shell_quote() {
  printf "'%s'" "${1//\'/\'\"\'\"\'}"
}

group_env_prefix() {
  printf 'BACKUP_%s' "$(printf '%s' "$1" | tr '[:lower:]-' '[:upper:]_')"
}

env_or_empty() {
  local name="$1"
  printf '%s' "${!name:-}"
}

group_target() {
  local group="$1" prefix target host user
  prefix="$(group_env_prefix "${group}")"
  target="$(env_or_empty "${prefix}_SSH_TARGET")"
  if [[ -n "${target}" ]]; then
    printf '%s\n' "${target}"
    return 0
  fi

  host="$(env_or_empty "${prefix}_SSH_HOST")"
  user="$(env_or_empty "${prefix}_SSH_USER")"
  [[ -n "${host}" && -n "${user}" ]] || {
    echo "Missing SSH target for ${group}. Set ${prefix}_SSH_TARGET or ${prefix}_SSH_HOST/${prefix}_SSH_USER." >&2
    exit 64
  }
  printf '%s@%s\n' "${user}" "${host}"
}

build_ssh_command() {
  local group="$1" prefix port identity extra_opts sudo_var
  local parsed_opts=()
  prefix="$(group_env_prefix "${group}")"
  SSH_TARGET="$(group_target "${group}")"
  SSH_CMD=(ssh)

  port="$(env_or_empty "${prefix}_SSH_PORT")"
  [[ -z "${port}" ]] || SSH_CMD+=(-p "${port}")

  identity="$(env_or_empty "${prefix}_SSH_IDENTITY_FILE")"
  if [[ -n "${identity}" ]]; then
    [[ -f "${identity}" ]] || { echo "SSH identity file not found: ${identity}" >&2; exit 66; }
    SSH_CMD+=(-i "${identity}")
  fi

  extra_opts="$(env_or_empty "${prefix}_SSH_OPTS")"
  if [[ -n "${extra_opts}" ]]; then
    # shellcheck disable=SC2206
    parsed_opts=(${extra_opts})
    SSH_CMD+=("${parsed_opts[@]}")
  fi

  sudo_var="${prefix}_SUDO"
  if [[ "${!sudo_var+x}" == x ]]; then
    REMOTE_SUDO="${!sudo_var}"
  else
    REMOTE_SUDO="sudo -n"
  fi
}

remote_exec() {
  local group="$1" remote_script="$2" remote_runner
  build_ssh_command "${group}"
  if [[ -n "${REMOTE_SUDO}" ]]; then
    remote_runner="${REMOTE_SUDO} bash -s"
  else
    remote_runner="bash -s"
  fi
  "${SSH_CMD[@]}" "${SSH_TARGET}" "${remote_runner}" <<< "${remote_script}"
}

matches_filters() {
  local group="$1" service="$2" filter
  [[ "${host_group_filter}" == "all" || "${group}" == "${host_group_filter}" ]] || return 1
  [[ "${#service_filters[@]}" -gt 0 ]] || return 0
  for filter in "${service_filters[@]}"; do
    [[ "${service}" == "${filter}" ]] && return 0
  done
  return 1
}

prepare_output_dir() {
  mkdir -p "${output_dir}"
  cp "${manifest_file}" "${output_dir}/manifest.tsv"
  printf 'generated_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${output_dir}/run-metadata.txt"
  printf 'host_group\tservice_name\tsource_path\tarchive_path\tstatus\tsize_bytes\tdescription\n' > "${output_dir}/archives.tsv"
  : > "${output_dir}/checksums.sha256"
}

record_archive() {
  local group="$1" service="$2" source_path="$3" archive_path="$4" status="$5" description="$6"
  local checksum="" size_bytes="" relative=""
  if [[ -f "${archive_path}" ]]; then
    checksum="$(sha256_file "${archive_path}")"
    size_bytes="$(wc -c < "${archive_path}" | tr -d ' ')"
    relative="${group}/$(basename "${archive_path}")"
    printf '%s  %s\n' "${checksum}" "${relative}" >> "${output_dir}/checksums.sha256"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${group}" "${service}" "${source_path}" "${archive_path}" "${status}" "${size_bytes}" "${description}" >> "${output_dir}/archives.tsv"
}

backup_entry() {
  local group="$1" service="$2" source_path="$3" required="$4" description="$5"
  local relative_path archive_dir archive_path remote_path_quoted relative_path_quoted exists_script archive_script
  matches_filters "${group}" "${service}" || return 0

  if [[ "${list_only}" == "true" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "${group}" "${service}" "${source_path}" "${required}" "${description}"
    return 0
  fi

  if [[ "${dry_run}" == "true" ]]; then
    echo "Would back up ${group}:${service} from ${source_path}"
    return 0
  fi

  archive_dir="${output_dir}/${group}"
  mkdir -p "${archive_dir}"
  archive_path="${archive_dir}/${service}.tar.gz"
  relative_path="${source_path#/}"
  remote_path_quoted="$(shell_quote "${source_path}")"
  relative_path_quoted="$(shell_quote "${relative_path}")"

  exists_script="set -euo pipefail
test -e ${remote_path_quoted}"
  archive_script="set -euo pipefail
tar --numeric-owner --acls --xattrs -C / -cpf - ${relative_path_quoted}"

  if ! remote_exec "${group}" "${exists_script}" >/dev/null 2>&1; then
    if [[ "${required}" == "true" ]]; then
      echo "Required path missing on ${group}: ${source_path} (${service})" >&2
      return 1
    fi
    record_archive "${group}" "${service}" "${source_path}" "" "missing-optional" "${description}"
    return 0
  fi

  echo "Backing up ${group}:${service} from ${source_path}"
  remote_exec "${group}" "${archive_script}" | gzip -1 > "${archive_path}"
  record_archive "${group}" "${service}" "${source_path}" "${archive_path}" "backed-up" "${description}"
}

manifest_file=""
output_dir=""
host_group_filter="all"
dry_run=false
list_only=false
service_filters=()
SSH_CMD=()
SSH_TARGET=""
REMOTE_SUDO=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --manifest) shift; [[ "$#" -gt 0 ]] || usage; manifest_file="$1" ;;
    --output-dir) shift; [[ "$#" -gt 0 ]] || usage; output_dir="$1" ;;
    --host-group|--host) shift; [[ "$#" -gt 0 ]] || usage; host_group_filter="$1" ;;
    --service) shift; [[ "$#" -gt 0 ]] || usage; service_filters+=("$1") ;;
    --dry-run) dry_run=true ;;
    --list) list_only=true ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
  shift
done

[[ -n "${manifest_file}" ]] || { echo "Missing --manifest" >&2; exit 64; }
[[ -f "${manifest_file}" ]] || { echo "Manifest not found: ${manifest_file}" >&2; exit 66; }
if [[ "${list_only}" == "false" && "${dry_run}" == "false" ]]; then
  [[ -n "${output_dir}" ]] || { echo "Missing --output-dir" >&2; exit 64; }
  prepare_output_dir
fi

while IFS=$'\t' read -r group service source_path required description; do
  [[ -z "${group}" || "${group}" == \#* || "${group}" == "host_group" ]] && continue
  backup_entry "${group}" "${service}" "${source_path}" "${required}" "${description:-}"
done < "${manifest_file}"

[[ "${list_only}" == "true" || "${dry_run}" == "true" ]] || echo "Backups written to ${output_dir}"
