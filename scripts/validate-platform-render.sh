#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  validate-platform-render --repo-root <path> [options]

Options:
  --render-command <command>       Command to run from repo root. May be repeated.
  --render-command-file <path>     File with one render command per non-comment line.
  --generated-path <path>          Generated file or directory to require clean in git diff. May be repeated.
  --generated-path-file <path>     File with one generated path per non-comment line.
  --skip-git-diff                  Do not check generated paths with git diff.

This wrapper intentionally knows nothing about a consumer repository layout.
Consumers pass their own render commands and generated output paths.
EOF
  exit 64
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 69
  fi
}

read_lines() {
  local file="$1"
  [[ -f "${file}" ]] || { echo "File not found: ${file}" >&2; exit 66; }
  awk 'NF && $1 !~ /^#/ { print }' "${file}"
}

repo_root=""
skip_git_diff=false
render_commands=()
generated_paths=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --repo-root)
      shift
      [[ "$#" -gt 0 ]] || usage
      repo_root="$1"
      ;;
    --render-command)
      shift
      [[ "$#" -gt 0 ]] || usage
      render_commands+=("$1")
      ;;
    --render-command-file)
      shift
      [[ "$#" -gt 0 ]] || usage
      while IFS= read -r line; do
        render_commands+=("${line}")
      done < <(read_lines "$1")
      ;;
    --generated-path)
      shift
      [[ "$#" -gt 0 ]] || usage
      generated_paths+=("$1")
      ;;
    --generated-path-file)
      shift
      [[ "$#" -gt 0 ]] || usage
      while IFS= read -r line; do
        generated_paths+=("${line}")
      done < <(read_lines "$1")
      ;;
    --skip-git-diff)
      skip_git_diff=true
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

[[ -n "${repo_root}" ]] || { echo "Missing required option: --repo-root" >&2; exit 64; }
[[ -d "${repo_root}" ]] || { echo "Repository root not found: ${repo_root}" >&2; exit 66; }

for command_line in "${render_commands[@]}"; do
  echo "==> ${command_line}"
  (cd "${repo_root}" && bash -euo pipefail -c "${command_line}")
done

if [[ "${skip_git_diff}" == "false" && "${#generated_paths[@]}" -gt 0 ]]; then
  require_command git
  echo "==> git diff --exit-code generated paths"
  (cd "${repo_root}" && git diff --exit-code -- "${generated_paths[@]}")
fi

echo "Platform render validation passed"
