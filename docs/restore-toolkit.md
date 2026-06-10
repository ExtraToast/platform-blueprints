# Restore Toolkit

`scripts/restore` contains generic restore primitives that pair with the backup
toolkit in `scripts/backup`. The backup scripts create portable artifacts and
metadata; the restore scripts validate those artifacts and stream them into
caller-supplied destinations.

Consumer repositories should keep fixed wrappers, service names, namespaces, PVC
names, hostnames, image choices, paths, and credentials outside this repository.

## Backup to Restore Flow

1. Capture host-path archives with `scripts/backup/backup-service-state.sh`.
2. Capture service-native exports with `scripts/backup/backup-service-snapshots.sh`.
3. Verify the backup run with `scripts/backup/verify-backup-run.sh`.
4. Before restore, verify required inputs with `scripts/restore/verify-restore-run.sh`.
5. Restore host-path archives with `scripts/restore/restore-hostpath-archive.sh`.
6. Restore PVC archives with `scripts/restore/restore-pvc-archive.sh`.
7. Restore service-native snapshots with `scripts/restore/restore-service-snapshots.sh`.

## Primitive Inputs

### `restore-hostpath-archive.sh`

Required inputs:

- `--ssh-target <user@host>`
- `--target-path <dir>`
- `--archive <file.tar.gz>`

Optional inputs:

- `--ssh-port <port>`
- `--identity-file <path>`
- `--ssh-opts "<opts>"`
- `--sudo "<cmd>"`
- `--strip-components <n>`
- `--wipe-target`
- `--dry-run`

### `restore-pvc-archive.sh`

Required inputs:

- `--namespace <ns>`
- `--pvc <name>` or `--pvc-match <substring>`
- `--archive <file.tar.gz>`
- `--image <image>`

Optional inputs:

- `--strip-components <n>`
- `--pod-name <name>`
- `--kubectl <path>`
- `--wipe-target`
- `--keep-pod`
- `--dry-run`
- `--print-manifest`

Use `--pvc` for offline validation. `--pvc-match` performs a live `kubectl`
lookup and is intended for consumer wrappers.

### `restore-service-snapshots.sh`

Required inputs:

- `--plugins <plugins.tsv>`
- `--snapshot-dir <dir>` unless using `--list`

Plugin columns:

```text
artifact	input_file	required	command_path	description
```

Each `command_path` is a caller-owned executable invoked as:

```text
command_path <snapshot-dir>/<input_file>
```

The command owns service-specific details such as namespaces, ports, API paths,
credentials, and import flags.

### `verify-restore-run.sh`

Required inputs:

- `--backup-run-dir <dir>`

Optional inputs:

- `--required-archive <group/service>`
- `--required-snapshot <artifact>`

The verifier checks `archives.tsv`, optional `service-snapshots.tsv`, and
checksum files from the backup toolkit without contacting a cluster.

## Boundary

This repository only provides parameterized primitives. Fixed restore wrappers
belong in consumer repositories because they encode deployment-specific
namespaces, PVC names, host paths, image prefixes, service endpoints, and
credentials.
