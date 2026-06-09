#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  backup-service-snapshots --plugins <plugins.tsv> --output-dir <dir> [options]

Options:
  --artifact <name>       Capture one artifact. May be repeated.
  --required <name>       Mark artifact required in metadata. May be repeated.
  --list                  Print selected plugins and exit.
  --dry-run               Validate/filter plugins without running commands.

Plugin columns:
  artifact output_file required command_path description

Each command_path is a caller-owned executable that writes the snapshot/export
payload to stdout. No service-specific commands are embedded in this script.
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

matches_filters() {
  local artifact="$1" filter
  [[ "${#artifact_filters[@]}" -gt 0 ]] || return 0
  for filter in "${artifact_filters[@]}"; do
    [[ "${artifact}" == "${filter}" ]] && return 0
  done
  return 1
}

prepare_output_dir() {
  mkdir -p "${output_dir}/snapshots"
  printf 'generated_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${output_dir}/snapshot-metadata.txt"
  printf 'artifact\toutput_path\tstatus\tsize_bytes\trequired\tdescription\n' > "${output_dir}/service-snapshots.tsv"
  : > "${output_dir}/service-snapshots.sha256"
}

record_artifact() {
  local artifact="$1" output_path="$2" status="$3" required="$4" description="$5"
  local checksum="" size_bytes="" relative=""
  if [[ -f "${output_path}" ]]; then
    checksum="$(sha256_file "${output_path}")"
    size_bytes="$(wc -c < "${output_path}" | tr -d ' ')"
    relative="snapshots/$(basename "${output_path}")"
    printf '%s  %s\n' "${checksum}" "${relative}" >> "${output_dir}/service-snapshots.sha256"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${artifact}" "${output_path}" "${status}" "${size_bytes}" "${required}" "${description}" >> "${output_dir}/service-snapshots.tsv"
}

capture_plugin() {
  local artifact="$1" output_file="$2" required="$3" command_path="$4" description="$5"
  local output_path
  matches_filters "${artifact}" || return 0

  if [[ "${list_only}" == "true" ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "${artifact}" "${output_file}" "${required}" "${command_path}" "${description}"
    return 0
  fi

  if [[ "${dry_run}" == "true" ]]; then
    echo "Would capture ${artifact} using ${command_path}"
    return 0
  fi

  [[ -x "${command_path}" ]] || {
    if [[ "${required}" == "true" ]]; then
      echo "Required snapshot command missing or not executable: ${command_path}" >&2
      return 1
    fi
    record_artifact "${artifact}" "" "missing-optional" "${required}" "${description}"
    return 0
  }

  output_path="${output_dir}/snapshots/${output_file}"
  echo "Capturing ${artifact}"
  "${command_path}" > "${output_path}"
  record_artifact "${artifact}" "${output_path}" "captured" "${required}" "${description}"
}

plugins_file=""
output_dir=""
dry_run=false
list_only=false
artifact_filters=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --plugins) shift; [[ "$#" -gt 0 ]] || usage; plugins_file="$1" ;;
    --output-dir) shift; [[ "$#" -gt 0 ]] || usage; output_dir="$1" ;;
    --artifact) shift; [[ "$#" -gt 0 ]] || usage; artifact_filters+=("$1") ;;
    --required) shift; [[ "$#" -gt 0 ]] || usage ;;
    --dry-run) dry_run=true ;;
    --list) list_only=true ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
  shift
done

[[ -n "${plugins_file}" ]] || { echo "Missing --plugins" >&2; exit 64; }
[[ -f "${plugins_file}" ]] || { echo "Plugin manifest not found: ${plugins_file}" >&2; exit 66; }
if [[ "${list_only}" == "false" && "${dry_run}" == "false" ]]; then
  [[ -n "${output_dir}" ]] || { echo "Missing --output-dir" >&2; exit 64; }
  prepare_output_dir
fi

while IFS=$'\t' read -r artifact output_file required command_path description; do
  [[ -z "${artifact}" || "${artifact}" == \#* || "${artifact}" == "artifact" ]] && continue
  capture_plugin "${artifact}" "${output_file}" "${required}" "${command_path}" "${description:-}"
done < "${plugins_file}"

[[ "${list_only}" == "true" || "${dry_run}" == "true" ]] || echo "Service-native snapshots written to ${output_dir}"
