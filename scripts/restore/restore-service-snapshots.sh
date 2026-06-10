#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  restore-service-snapshots --plugins <plugins.tsv> --snapshot-dir <dir> [options]

Options:
  --artifact <name>       Restore one artifact. May be repeated.
  --list                  Print selected plugins and exit.
  --dry-run               Validate/filter plugins without running commands.

Plugin columns:
  artifact input_file required command_path description

Each command_path is a caller-owned executable. The toolkit invokes it as:
  command_path <snapshot-dir>/<input_file>

No service-specific import command, namespace, host, or credential is embedded.
EOF
  exit 64
}

matches_filters() {
  local artifact="$1" filter
  [[ "${#artifact_filters[@]}" -gt 0 ]] || return 0
  for filter in "${artifact_filters[@]}"; do
    [[ "${artifact}" == "${filter}" ]] && return 0
  done
  return 1
}

restore_plugin() {
  local artifact="$1" input_file="$2" required="$3" command_path="$4" description="$5"
  local input_path
  matches_filters "${artifact}" || return 0

  if [[ "${list_only}" == "true" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "${artifact}" "${input_file}" "${required}" "${command_path}" "${description}"
    return 0
  fi

  input_path="${snapshot_dir}/${input_file}"
  if [[ "${dry_run}" == "true" ]]; then
    [[ -f "${input_path}" ]] || {
      [[ "${required}" == "true" ]] && { echo "Required snapshot not found: ${input_path}" >&2; return 1; }
      return 0
    }
    echo "Would restore ${artifact} using ${command_path} ${input_path}"
    return 0
  fi

  if [[ ! -f "${input_path}" ]]; then
    if [[ "${required}" == "true" ]]; then
      echo "Required snapshot not found: ${input_path}" >&2
      return 1
    fi
    echo "Skipping optional missing snapshot: ${artifact}"
    return 0
  fi
  [[ -x "${command_path}" ]] || { echo "Restore command missing or not executable: ${command_path}" >&2; return 1; }

  echo "Restoring ${artifact}"
  "${command_path}" "${input_path}"
}

plugins_file=""
snapshot_dir=""
dry_run=false
list_only=false
artifact_filters=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --plugins) shift; [[ "$#" -gt 0 ]] || usage; plugins_file="$1" ;;
    --snapshot-dir) shift; [[ "$#" -gt 0 ]] || usage; snapshot_dir="$1" ;;
    --artifact) shift; [[ "$#" -gt 0 ]] || usage; artifact_filters+=("$1") ;;
    --dry-run) dry_run=true ;;
    --list) list_only=true ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
  shift
done

[[ -n "${plugins_file}" ]] || { echo "Missing --plugins" >&2; exit 64; }
[[ -f "${plugins_file}" ]] || { echo "Plugin manifest not found: ${plugins_file}" >&2; exit 66; }
if [[ "${list_only}" == "false" ]]; then
  [[ -n "${snapshot_dir}" ]] || { echo "Missing --snapshot-dir" >&2; exit 64; }
  [[ -d "${snapshot_dir}" ]] || { echo "Snapshot directory not found: ${snapshot_dir}" >&2; exit 66; }
fi

while IFS=$'\t' read -r artifact input_file required command_path description; do
  [[ -z "${artifact}" || "${artifact}" == \#* || "${artifact}" == "artifact" ]] && continue
  restore_plugin "${artifact}" "${input_file}" "${required}" "${command_path}" "${description:-}"
done < "${plugins_file}"
