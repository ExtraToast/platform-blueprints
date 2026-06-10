#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

cd "${repo_root}"

archive="${tmpdir}/example-data.tar.gz"
printf 'fixture payload\n' > "${archive}"

scripts/restore/restore-hostpath-archive.sh \
  --ssh-target restore@example.invalid \
  --target-path /srv/example \
  --archive "${archive}" \
  --strip-components 0 \
  --wipe-target \
  --dry-run >/dev/null

if scripts/restore/restore-hostpath-archive.sh --ssh-target restore@example.invalid --target-path /srv/example --archive "${tmpdir}/missing.tar.gz" --dry-run >/dev/null 2>&1; then
  echo "Expected host-path restore to reject a missing archive" >&2
  exit 1
fi

scripts/restore/restore-pvc-archive.sh \
  --namespace example-system \
  --pvc example-data \
  --archive "${archive}" \
  --image example.invalid/restore-tool:latest \
  --pod-name restore-example \
  --dry-run >/dev/null

manifest_output="${tmpdir}/restore-pod.yaml"
scripts/restore/restore-pvc-archive.sh \
  --namespace example-system \
  --pvc example-data \
  --archive "${archive}" \
  --image example.invalid/restore-tool:latest \
  --pod-name restore-example \
  --print-manifest > "${manifest_output}"
grep -q 'claimName: example-data' "${manifest_output}"
grep -q 'image: example.invalid/restore-tool:latest' "${manifest_output}"

if scripts/restore/restore-pvc-archive.sh --namespace example-system --archive "${archive}" --image example.invalid/restore-tool:latest --dry-run >/dev/null 2>&1; then
  echo "Expected PVC restore to require --pvc or --pvc-match" >&2
  exit 1
fi

snapshot_dir="${tmpdir}/snapshots"
mkdir -p "${snapshot_dir}"
printf 'snapshot payload\n' > "${snapshot_dir}/example.snapshot"
chmod +x tests/fixtures/restore/example-snapshot-restore.sh

scripts/restore/restore-service-snapshots.sh \
  --plugins examples/restore/snapshot-restore-plugins.tsv \
  --list >/dev/null
scripts/restore/restore-service-snapshots.sh \
  --plugins examples/restore/snapshot-restore-plugins.tsv \
  --snapshot-dir "${snapshot_dir}" \
  --dry-run >/dev/null
scripts/restore/restore-service-snapshots.sh \
  --plugins examples/restore/snapshot-restore-plugins.tsv \
  --snapshot-dir "${snapshot_dir}" >/dev/null

run_dir="${tmpdir}/run"
mkdir -p "${run_dir}/primary" "${run_dir}/snapshots"
printf 'archive payload\n' > "${run_dir}/primary/example-data.tar.gz"
printf 'snapshot payload\n' > "${run_dir}/snapshots/example.snapshot"
archive_size="$(wc -c < "${run_dir}/primary/example-data.tar.gz" | tr -d ' ')"
snapshot_size="$(wc -c < "${run_dir}/snapshots/example.snapshot" | tr -d ' ')"
printf 'host_group\tservice_name\tsource_path\tarchive_path\tstatus\tsize_bytes\tdescription\n' > "${run_dir}/archives.tsv"
printf 'primary\texample-data\t/var/lib/example\t%s\tbacked-up\t%s\tExample required service data\n' "${run_dir}/primary/example-data.tar.gz" "${archive_size}" >> "${run_dir}/archives.tsv"
printf 'artifact\toutput_path\tstatus\tsize_bytes\trequired\tdescription\n' > "${run_dir}/service-snapshots.tsv"
printf 'example-snapshot\t%s\tcaptured\t%s\ttrue\tExample service-native snapshot fixture\n' "${run_dir}/snapshots/example.snapshot" "${snapshot_size}" >> "${run_dir}/service-snapshots.tsv"
archive_checksum="$(sha256sum "${run_dir}/primary/example-data.tar.gz" | awk '{print $1}')"
snapshot_checksum="$(sha256sum "${run_dir}/snapshots/example.snapshot" | awk '{print $1}')"
printf '%s  primary/example-data.tar.gz\n' "${archive_checksum}" > "${run_dir}/checksums.sha256"
printf '%s  snapshots/example.snapshot\n' "${snapshot_checksum}" > "${run_dir}/service-snapshots.sha256"

scripts/restore/verify-restore-run.sh \
  --backup-run-dir "${run_dir}" \
  --required-archive primary/example-data \
  --required-snapshot example-snapshot >/dev/null

printf 'tamper\n' >> "${run_dir}/snapshots/example.snapshot"
if scripts/restore/verify-restore-run.sh --backup-run-dir "${run_dir}" --required-snapshot example-snapshot >/dev/null 2>&1; then
  echo "Expected restore input verification to fail after tampering" >&2
  exit 1
fi

echo "Restore tooling smoke test passed"
