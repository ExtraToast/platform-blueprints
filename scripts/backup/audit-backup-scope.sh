#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  audit-backup-scope --manifest <manifest.tsv> --expected-paths <paths.tsv> [options]

Options:
  --exclude-paths <file>     One source path per line to ignore.

Expected path columns:
  host_group source_path description
EOF
  exit 64
}

manifest_file=""
expected_paths_file=""
exclude_paths_file=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --manifest) shift; [[ "$#" -gt 0 ]] || usage; manifest_file="$1" ;;
    --expected-paths) shift; [[ "$#" -gt 0 ]] || usage; expected_paths_file="$1" ;;
    --exclude-paths) shift; [[ "$#" -gt 0 ]] || usage; exclude_paths_file="$1" ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
  shift
done

[[ -f "${manifest_file}" ]] || { echo "Manifest not found: ${manifest_file}" >&2; exit 66; }
[[ -f "${expected_paths_file}" ]] || { echo "Expected paths file not found: ${expected_paths_file}" >&2; exit 66; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

expected="${tmpdir}/expected"
manifest="${tmpdir}/manifest"
excluded="${tmpdir}/excluded"

awk -F '\t' 'NF && $1 !~ /^#/ && $1 != "host_group" { print $1 "\t" $2 }' "${expected_paths_file}" | sort -u > "${expected}"
awk -F '\t' 'NF && $1 !~ /^#/ && $1 != "host_group" { print $1 "\t" $3 }' "${manifest_file}" | sort -u > "${manifest}"

if [[ -n "${exclude_paths_file}" && -f "${exclude_paths_file}" ]]; then
  awk 'NF && $1 !~ /^#/ { print }' "${exclude_paths_file}" | sort -u > "${excluded}"
  awk -F '\t' 'NR == FNR { e[$1]=1; next } !($2 in e)' "${excluded}" "${expected}" > "${expected}.filtered"
  mv "${expected}.filtered" "${expected}"
fi

echo "Expected paths missing from backup manifest:"
comm -23 "${expected}" "${manifest}" || true
echo
echo "Manifest paths not present in expected path list:"
comm -13 "${expected}" "${manifest}" || true

missing_count="$(comm -23 "${expected}" "${manifest}" | awk 'NF { count += 1 } END { print count + 0 }')"
[[ "${missing_count}" -eq 0 ]]
