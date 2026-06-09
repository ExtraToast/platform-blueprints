#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

cd "${repo_root}"

scripts/backup/backup-service-state.sh --manifest examples/backup/manifest.tsv --list >/dev/null
scripts/backup/backup-service-state.sh --manifest examples/backup/manifest.tsv --dry-run >/dev/null

run_dir="${tmpdir}/run"
mkdir -p "${run_dir}/primary"
cp examples/backup/manifest.tsv "${run_dir}/manifest.tsv"
printf 'generated_at_utc=fixture\n' > "${run_dir}/run-metadata.txt"
printf 'host_group\tservice_name\tsource_path\tarchive_path\tstatus\tsize_bytes\tdescription\n' > "${run_dir}/archives.tsv"
printf 'fixture payload\n' > "${run_dir}/primary/example-data.tar.gz"
size="$(wc -c < "${run_dir}/primary/example-data.tar.gz" | tr -d ' ')"
printf 'primary\texample-data\t/var/lib/example\t%s\tbacked-up\t%s\tExample required service data\n' "${run_dir}/primary/example-data.tar.gz" "${size}" >> "${run_dir}/archives.tsv"
checksum="$(sha256sum "${run_dir}/primary/example-data.tar.gz" | awk '{print $1}')"
printf '%s  primary/example-data.tar.gz\n' "${checksum}" > "${run_dir}/checksums.sha256"

scripts/backup/backup-service-snapshots.sh --plugins examples/backup/snapshot-plugins.tsv --output-dir "${run_dir}" >/dev/null
scripts/backup/verify-backup-run.sh --run-dir "${run_dir}" --manifest examples/backup/manifest.tsv --required-snapshot example-snapshot >/dev/null
scripts/backup/audit-backup-scope.sh --manifest examples/backup/manifest.tsv --expected-paths examples/backup/expected-paths.tsv >/dev/null

printf 'tamper\n' >> "${run_dir}/primary/example-data.tar.gz"
if scripts/backup/verify-backup-run.sh --run-dir "${run_dir}" --manifest examples/backup/manifest.tsv --required-snapshot example-snapshot >/dev/null 2>&1; then
  echo "Expected checksum verification to fail after tampering" >&2
  exit 1
fi

echo "Backup tooling smoke test passed"
