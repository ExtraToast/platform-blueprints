#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  validate-flux --flux-root <path> --cluster-path <path> [options]

Options:
  --apps-path <path>          Directory to search for in-repository Helm charts.
  --enable-helm              Render HelmRelease resources with flux-local and local charts with helm.
  --schema-location <value>   kubeconform schema location. May be repeated.
  --no-strict                Do not pass -strict to kubeconform.
EOF
  exit 64
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 69
  fi
}

require_dir() {
  local name="$1"
  local path="$2"
  if [[ -z "${path}" ]]; then
    echo "Missing required option: ${name}" >&2
    exit 64
  fi
  if [[ ! -d "${path}" ]]; then
    echo "Directory not found for ${name}: ${path}" >&2
    exit 66
  fi
}

flux_root=""
cluster_path=""
apps_path=""
enable_helm=false
strict=true
schema_locations=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --flux-root)
      shift
      [[ "$#" -gt 0 ]] || usage
      flux_root="$1"
      ;;
    --cluster-path)
      shift
      [[ "$#" -gt 0 ]] || usage
      cluster_path="$1"
      ;;
    --apps-path)
      shift
      [[ "$#" -gt 0 ]] || usage
      apps_path="$1"
      ;;
    --enable-helm)
      enable_helm=true
      ;;
    --schema-location)
      shift
      [[ "$#" -gt 0 ]] || usage
      schema_locations+=("$1")
      ;;
    --no-strict)
      strict=false
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
  shift
done

require_dir "--flux-root" "${flux_root}"
require_dir "--cluster-path" "${cluster_path}"

if [[ -z "${apps_path}" ]]; then
  apps_path="${flux_root}/apps"
fi

if [[ "${#schema_locations[@]}" -eq 0 ]]; then
  schema_locations=(
    "default"
    "https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"
    "https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/{{.ResourceKind}}-{{.ResourceAPIVersion}}.json"
  )
fi

require_command kustomize
require_command kubeconform
if [[ "${enable_helm}" == "true" ]]; then
  require_command find
  require_command flux-local
  require_command helm
fi

render_output="$(mktemp "${TMPDIR:-/tmp}/platform-blueprints-flux.XXXXXX.yaml")"
trap 'rm -f "${render_output}"' EXIT

echo "==> kustomize build ${cluster_path}"
kustomize build "${cluster_path}" > "${render_output}"

if [[ "${enable_helm}" == "true" ]]; then
  echo "==> flux-local build all --enable-helm ${flux_root}"
  flux-local build all --enable-helm "${flux_root}" >> "${render_output}"

  if [[ -d "${apps_path}" ]]; then
    while IFS= read -r chart_file; do
      chart_dir="$(dirname "${chart_file}")"
      release_name="$(basename "${chart_dir}")"
      echo "==> helm template ${release_name} ${chart_dir}"
      helm template "${release_name}" "${chart_dir}" >> "${render_output}"
    done < <(find "${apps_path}" -name Chart.yaml | sort)
  fi
fi

kubeconform_args=(-summary)
if [[ "${strict}" == "true" ]]; then
  kubeconform_args+=(-strict)
fi
for schema_location in "${schema_locations[@]}"; do
  kubeconform_args+=(-schema-location "${schema_location}")
done

echo "==> kubeconform ${render_output}"
kubeconform "${kubeconform_args[@]}" "${render_output}"
