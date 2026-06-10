#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

script="scripts/validate-flux-render.sh"
good_fixture="tests/fixtures/flux-render-good"
broken_fixture="tests/fixtures/flux-render-broken"

bash -n "${script}"

missing_output="$(mktemp "${TMPDIR:-/tmp}/flux-render-missing.XXXXXX.log")"
trap 'rm -f "${missing_output}"' EXIT

if "${script}" --overlay "${good_fixture}" --mode strict >"${missing_output}" 2>&1; then
  echo "Flux render validation smoke test used full binary path: good fixture passed"
  if "${script}" --overlay "${broken_fixture}" --mode strict >/dev/null 2>&1; then
    echo "Expected broken fixture to fail strict render validation" >&2
    exit 1
  fi
  echo "Flux render validation smoke test passed: broken fixture failed as expected"
else
  status="$?"
  if [[ "${status}" -ne 69 ]]; then
    cat "${missing_output}" >&2
    echo "Expected missing-binary path to exit 69, got ${status}" >&2
    exit 1
  fi
  if ! grep -Eq 'Missing required command: (kustomize|flux|kubeconform)' "${missing_output}"; then
    cat "${missing_output}" >&2
    echo "Missing-binary output did not identify a required command" >&2
    exit 1
  fi
  if "${script}" --mode strict >/dev/null 2>&1; then
    echo "Expected argument validation to reject missing --overlay" >&2
    exit 1
  fi
  echo "Flux render validation smoke test used offline missing-binary path"
fi
