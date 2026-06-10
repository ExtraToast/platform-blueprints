#!/usr/bin/env bash
set -euo pipefail

EX_USAGE=64
EX_NOINPUT=66
EX_UNAVAILABLE=69

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_crd_catalog="$(cd "${script_dir}/.." && pwd)/schemas/crds"

usage() {
  local code="${1:-${EX_USAGE}}"
  cat >&2 <<'EOF'
Usage:
  validate-flux-render --overlay <path> [options]

Options:
  --overlay <path>                  Kustomize overlay to build. May be repeated.
  --crd-schema-location <location>  kubeconform schema location. May be repeated.
  --crd-catalog <dir>               Local CRD schema catalog. May be repeated.
  --mode strict|lenient             strict passes kubeconform -strict. Default: strict.
  -h, --help                        Show this help.

Schema resolution:
  When no CRD schema input is provided, the bundled pinned catalog under
  schemas/crds is used. The Kubernetes built-in schema location is always
  included through kubeconform's "default" location.
EOF
  exit "${code}"
}

require_command() {
  local command_name="$1"
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    echo "Install kustomize, flux, and kubeconform before running strict Flux render validation." >&2
    exit "${EX_UNAVAILABLE}"
  fi
}

require_dir() {
  local label="$1"
  local path="$2"
  if [[ ! -d "${path}" ]]; then
    echo "${label} is not a directory: ${path}" >&2
    exit "${EX_NOINPUT}"
  fi
}

append_render() {
  local source="$1"
  local output="$2"

  if [[ -s "${output}" ]]; then
    printf '\n---\n' >> "${output}"
  fi
  cat "${source}" >> "${output}"
}

render_flux_overlay() {
  local overlay="$1"
  local rendered="$2"
  local kustomize_output
  local flux_output
  local flux_kustomization

  kustomize_output="$(mktemp "${TMPDIR:-/tmp}/flux-render-kustomize.XXXXXX.yaml")"
  flux_output="$(mktemp "${TMPDIR:-/tmp}/flux-render-flux.XXXXXX.yaml")"
  flux_kustomization="$(mktemp "${TMPDIR:-/tmp}/flux-render-kustomization.XXXXXX.yaml")"
  cat > "${flux_kustomization}" <<'EOF'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: render-validation
spec:
  interval: 1m
  path: ./
  prune: false
  sourceRef:
    kind: GitRepository
    name: render-validation
EOF

  echo "==> kustomize build ${overlay}"
  if ! kustomize build "${overlay}" > "${kustomize_output}"; then
    echo "kustomize build failed for overlay: ${overlay}" >&2
    rm -f "${kustomize_output}" "${flux_output}" "${flux_kustomization}"
    return 1
  fi
  append_render "${kustomize_output}" "${rendered}"

  echo "==> flux build kustomization ${overlay}"
  if flux build kustomization "render-validation" \
      --path "${overlay}" \
      --kustomization-file "${flux_kustomization}" \
      > "${flux_output}"; then
    append_render "${flux_output}" "${rendered}"
  else
    echo "flux build kustomization failed for overlay: ${overlay}" >&2
    rm -f "${kustomize_output}" "${flux_output}" "${flux_kustomization}"
    return 1
  fi

  rm -f "${kustomize_output}" "${flux_output}" "${flux_kustomization}"
}

mode="strict"
overlays=()
schema_locations=()
crd_catalogs=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --overlay)
      shift
      [[ "$#" -gt 0 ]] || usage
      overlays+=("$1")
      ;;
    --crd-schema-location)
      shift
      [[ "$#" -gt 0 ]] || usage
      schema_locations+=("$1")
      ;;
    --crd-catalog)
      shift
      [[ "$#" -gt 0 ]] || usage
      crd_catalogs+=("$1")
      ;;
    --mode)
      shift
      [[ "$#" -gt 0 ]] || usage
      mode="$1"
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
  shift
done

if [[ "${#overlays[@]}" -eq 0 ]]; then
  echo "Missing required option: --overlay" >&2
  usage
fi

case "${mode}" in
  strict|lenient)
    ;;
  *)
    echo "Unsupported mode: ${mode}. Use strict or lenient." >&2
    exit "${EX_USAGE}"
    ;;
esac

for overlay in "${overlays[@]}"; do
  require_dir "Overlay" "${overlay}"
  if [[ ! -f "${overlay}/kustomization.yaml" && ! -f "${overlay}/kustomization.yml" && ! -f "${overlay}/Kustomization" ]]; then
    echo "Overlay does not contain a kustomization file: ${overlay}" >&2
    exit "${EX_NOINPUT}"
  fi
done

if [[ "${#schema_locations[@]}" -eq 0 && "${#crd_catalogs[@]}" -eq 0 ]]; then
  crd_catalogs+=("${default_crd_catalog}")
fi

for crd_catalog in "${crd_catalogs[@]}"; do
  require_dir "CRD catalog" "${crd_catalog}"
  schema_locations+=("${crd_catalog}/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json")
done

require_command kustomize
require_command flux
require_command kubeconform

render_output="$(mktemp "${TMPDIR:-/tmp}/flux-render-validation.XXXXXX.yaml")"
trap 'rm -f "${render_output}"' EXIT

for overlay in "${overlays[@]}"; do
  render_flux_overlay "${overlay}" "${render_output}"
done

kubeconform_args=(-summary -schema-location default)
if [[ "${mode}" == "strict" ]]; then
  kubeconform_args+=(-strict)
fi
for schema_location in "${schema_locations[@]}"; do
  kubeconform_args+=(-schema-location "${schema_location}")
done

echo "==> kubeconform (${mode})"
if ! kubeconform "${kubeconform_args[@]}" "${render_output}"; then
  echo "kubeconform reported schema-conformance errors" >&2
  exit 1
fi

echo "Strict Flux render validation passed"
