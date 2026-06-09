#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

failures=()

record_failure() {
  failures+=("$1")
}

check_required_files() {
  local required=(
    flake.nix
    README.md
    specs/001-platform-blueprints/spec.md
    specs/001-platform-blueprints/plan.md
    specs/001-platform-blueprints/tasks.md
    modules/nixos/base.nix
    modules/nixos/k3s.nix
    modules/nixos/roles/k3s-bootstrap.nix
    modules/nixos/roles/network-tailscale.nix
    modules/nixos/roles/raspberry-pi-image.nix
    lib/nixos/fleet-to-flake.nix
    scripts/bootstrap-k3s-agent-token.sh
    scripts/validate-flux.sh
    scripts/validate-platform-render.sh
    scripts/backup/backup-service-state.sh
    scripts/backup/backup-service-snapshots.sh
    scripts/backup/verify-backup-run.sh
    scripts/backup/audit-backup-scope.sh
    scripts/vault/compile-vault-bootstrap-policy.py
    specs/003-round3-platform-packs/spec.md
    specs/003-round3-platform-packs/plan.md
    specs/003-round3-platform-packs/tasks.md
    specs/004-round4-working-platform-packs/spec.md
    specs/004-round4-working-platform-packs/plan.md
    specs/004-round4-working-platform-packs/tasks.md
    packs/flux-core/README.md
    packs/edge/README.md
    packs/edge-middleware/README.md
    packs/rabbitmq-data-service/README.md
    packs/observability/README.md
    examples/backup/manifest.tsv
    tests/scripts/backup-tooling-smoke.sh
    docs/dns-zone-policy.md
    .github/workflows/ci.yml
    .github/workflows/release.yml
    release-please-config.json
    .release-please-manifest.json
  )

  local path
  for path in "${required[@]}"; do
    [[ -f "${path}" ]] || record_failure "Missing required file: ${path}"
  done
}

check_shell_syntax() {
  local path
  while IFS= read -r path; do
    bash -n "${path}" || record_failure "Invalid shell syntax: ${path}"
  done < <(find scripts -type f -name '*.sh' | sort)
}

check_python_syntax() {
  local path
  while IFS= read -r path; do
    python3 -m py_compile "${path}" || record_failure "Invalid Python syntax: ${path}"
  done < <(find scripts -type f -name '*.py' | sort)
}

check_json_yaml() {
  python3 - <<'PY'
import json
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(".")
failures = []

for path in root.rglob("*"):
    if ".git" in path.parts or not path.is_file():
        continue
    if path.suffix.lower() == ".json":
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            failures.append(f"{path}: invalid JSON: {exc}")

yaml_paths = [
    path for path in root.rglob("*")
    if ".git" not in path.parts and path.is_file() and path.suffix.lower() in {".yaml", ".yml"}
]
if yaml_paths:
    try:
        import yaml
    except ModuleNotFoundError:
        yaml = None

    if yaml is not None:
        for path in yaml_paths:
            try:
                list(yaml.safe_load_all(path.read_text(encoding="utf-8")))
            except Exception as exc:
                failures.append(f"{path}: invalid YAML: {exc}")
    elif shutil.which("ruby"):
        result = subprocess.run(
            ["ruby", "-e", "require 'yaml'; ARGV.each { |path| YAML.load_stream(File.read(path)) }", *map(str, yaml_paths)],
            text=True,
            capture_output=True,
        )
        if result.returncode != 0:
            failures.append(f"YAML parser failed: {result.stderr.strip()}")
    else:
        for path in yaml_paths:
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if line.startswith("\t"):
                    failures.append(f"{path}:{number}: YAML indentation uses a tab")

for failure in failures:
    print(failure)
sys.exit(1 if failures else 0)
PY
}

check_output_names() {
  if grep --line-number -E 'platform-blueprints-platform-blueprints|platformBlueprints\.platformBlueprints' flake.nix; then
    record_failure "Found doubled platform marker in public outputs or docs"
  fi
}

check_extraction_boundary() {
  local forbidden_paths=(
    "platform/inventory/fleet.yaml"
    "platform/cluster/flux/apps"
    "platform/cluster/flux/clusters"
    "platform/cluster/flux/rendered"
    "nomad"
    "consul"
  )
  local path
  for path in "${forbidden_paths[@]}"; do
    if [[ -e "${path}" ]]; then
      record_failure "Forbidden consumer-local path present: ${path}"
    fi
  done

  local scan_files=()
  while IFS= read -r path; do
    scan_files+=("${path}")
  done < <(find flake.nix lib modules scripts tests packs examples skeletons fixtures docs -type f ! -path 'scripts/validate-repository.sh' | sort)

  if grep --line-number -E 'personalStack|enschede|frankfurt|jorisjonkers|deploy\.pub|/Users/|/opt/personal-stack|BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|AGE-SECRET-KEY' "${scan_files[@]}"; then
    record_failure "Found reference-local or secret marker in shared implementation files"
  fi
}

check_vault_policy_compiler() {
  local tmpdir
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/platform-blueprints-vault.XXXXXX")"
  trap 'rm -rf "${tmpdir}"' RETURN

  python3 scripts/vault/compile-vault-bootstrap-policy.py \
    --input fixtures/vault-bootstrap-policy/minimal-policy.yaml \
    --output "${tmpdir}/minimal.yaml" || {
      record_failure "Vault compiler failed on minimal fixture"
      return
    }

  python3 scripts/vault/compile-vault-bootstrap-policy.py \
    --input fixtures/vault-bootstrap-policy/full-policy.yaml \
    --output "${tmpdir}/full.yaml" || {
      record_failure "Vault compiler failed on full fixture"
      return
    }

  grep -q 'kind: Job' "${tmpdir}/minimal.yaml" || record_failure "Vault compiler minimal fixture did not emit a Job"
  grep -q 'kind: VaultStaticSecret' "${tmpdir}/full.yaml" || record_failure "Vault compiler full fixture did not emit a VaultStaticSecret"
  grep -q 'kind: VaultDynamicSecret' "${tmpdir}/full.yaml" || record_failure "Vault compiler full fixture did not emit a VaultDynamicSecret"
  grep -q 'rabbitmq/roles/app-rabbitmq' "${tmpdir}/full.yaml" || record_failure "Vault compiler full fixture did not emit RabbitMQ role commands"
}

check_required_files
check_shell_syntax
check_python_syntax
check_json_yaml || record_failure "JSON/YAML validation failed"
check_output_names
check_extraction_boundary
check_vault_policy_compiler

if [[ "${#failures[@]}" -gt 0 ]]; then
  printf '%s\n' "${failures[@]}" >&2
  exit 1
fi

echo "Repository validation passed"
