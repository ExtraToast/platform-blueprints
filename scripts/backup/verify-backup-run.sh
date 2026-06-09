#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  verify-backup-run --run-dir <dir> --manifest <manifest.tsv> [options]

Options:
  --required-snapshot <name>    Required snapshot/export artifact. May be repeated.
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
    target="${run_dir}/${relative_path}"
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

run_dir=""
manifest_file=""
required_snapshots=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --run-dir) shift; [[ "$#" -gt 0 ]] || usage; run_dir="$1" ;;
    --manifest) shift; [[ "$#" -gt 0 ]] || usage; manifest_file="$1" ;;
    --required-snapshot) shift; [[ "$#" -gt 0 ]] || usage; required_snapshots+=("$1") ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
  shift
done

[[ -d "${run_dir}" ]] || { echo "Run directory not found: ${run_dir}" >&2; exit 66; }
[[ -f "${manifest_file}" ]] || { echo "Manifest not found: ${manifest_file}" >&2; exit 66; }
[[ -f "${run_dir}/archives.tsv" ]] || { echo "Missing archives.tsv in ${run_dir}" >&2; exit 66; }

failures=0

while IFS=$'\t' read -r group service source_path required description; do
  [[ -z "${group}" || "${group}" == \#* || "${group}" == "host_group" ]] && continue
  [[ "${required}" == "true" ]] || continue
  status="$(awk -F '\t' -v g="${group}" -v s="${service}" '$1 == g && $2 == s { print $5; exit }' "${run_dir}/archives.tsv")"
  if [[ "${status}" != "backed-up" ]]; then
    echo "Missing required archive: ${group}/${service} (${source_path})" >&2
    failures=$((failures + 1))
  fi
done < "${manifest_file}"

if [[ "${#required_snapshots[@]}" -gt 0 ]]; then
  [[ -f "${run_dir}/service-snapshots.tsv" ]] || { echo "Missing service-snapshots.tsv in ${run_dir}" >&2; exit 66; }
  for artifact in "${required_snapshots[@]}"; do
    status="$(awk -F '\t' -v a="${artifact}" '$1 == a { print $3; exit }' "${run_dir}/service-snapshots.tsv")"
    if [[ "${status}" != "captured" ]]; then
      echo "Missing required service snapshot/export: ${artifact}" >&2
      failures=$((failures + 1))
    fi
  done
fi

verify_checksums "${run_dir}/checksums.sha256"
verify_checksums "${run_dir}/service-snapshots.sha256"

if [[ "${failures}" -ne 0 ]]; then
  echo "Backup verification failed with ${failures} issue(s)." >&2
  exit 1
fi

echo "Backup verification passed for ${run_dir}"
