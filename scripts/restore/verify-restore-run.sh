#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  verify-restore-run --backup-run-dir <dir> [options]

Options:
  --required-archive <group/service>   Required archive from archives.tsv. May be repeated.
  --required-snapshot <artifact>       Required service snapshot/export. May be repeated.

Verifies backup artifacts before a restore by checking backup metadata,
required archive/snapshot presence, and checksums. This complements
scripts/backup/verify-backup-run.sh but does not contact a cluster.
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

verify_checksums() {
  local checksum_file="$1" checksum relative_path target actual
  [[ -f "${checksum_file}" ]] || return 0
  while read -r checksum relative_path; do
    [[ -n "${checksum}" ]] || continue
    target="${backup_run_dir}/${relative_path}"
    if [[ ! -f "${target}" ]]; then
      echo "Missing checksummed file: ${target}" >&2
      failures=$((failures + 1))
      continue
    fi
    actual="$(sha256_file "${target}")"
    if [[ "${actual}" != "${checksum}" ]]; then
      echo "Checksum mismatch: ${target}" >&2
      failures=$((failures + 1))
    fi
  done < "${checksum_file}"
}

backup_run_dir=""
required_archives=()
required_snapshots=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --backup-run-dir) shift; [[ "$#" -gt 0 ]] || usage; backup_run_dir="$1" ;;
    --required-archive) shift; [[ "$#" -gt 0 ]] || usage; required_archives+=("$1") ;;
    --required-snapshot) shift; [[ "$#" -gt 0 ]] || usage; required_snapshots+=("$1") ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
  shift
done

[[ -n "${backup_run_dir}" ]] || { echo "Missing --backup-run-dir" >&2; exit 64; }
[[ -d "${backup_run_dir}" ]] || { echo "Backup run directory not found: ${backup_run_dir}" >&2; exit 66; }
[[ -f "${backup_run_dir}/archives.tsv" ]] || { echo "Missing archives.tsv in ${backup_run_dir}" >&2; exit 66; }

failures=0

for required_archive in "${required_archives[@]}"; do
  group="${required_archive%%/*}"
  service="${required_archive#*/}"
  if [[ "${group}" == "${required_archive}" || -z "${group}" || -z "${service}" ]]; then
    echo "--required-archive must use group/service: ${required_archive}" >&2
    exit 64
  fi
  status="$(awk -F '\t' -v g="${group}" -v s="${service}" '$1 == g && $2 == s { print $5; exit }' "${backup_run_dir}/archives.tsv")"
  if [[ "${status}" != "backed-up" ]]; then
    echo "Missing required archive: ${required_archive}" >&2
    failures=$((failures + 1))
  fi
done

if [[ "${#required_snapshots[@]}" -gt 0 ]]; then
  [[ -f "${backup_run_dir}/service-snapshots.tsv" ]] || { echo "Missing service-snapshots.tsv in ${backup_run_dir}" >&2; exit 66; }
  for artifact in "${required_snapshots[@]}"; do
    status="$(awk -F '\t' -v a="${artifact}" '$1 == a { print $3; exit }' "${backup_run_dir}/service-snapshots.tsv")"
    if [[ "${status}" != "captured" ]]; then
      echo "Missing required service snapshot/export: ${artifact}" >&2
      failures=$((failures + 1))
    fi
  done
fi

verify_checksums "${backup_run_dir}/checksums.sha256"
verify_checksums "${backup_run_dir}/service-snapshots.sha256"

if [[ "${failures}" -ne 0 ]]; then
  echo "Restore input verification failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "Restore input verification passed for ${backup_run_dir}"
