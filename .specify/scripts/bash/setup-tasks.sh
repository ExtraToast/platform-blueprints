#!/usr/bin/env bash
set -euo pipefail

json=false
if [[ "${1:-}" == "--json" ]]; then
  json=true
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
feature_dirs=()
while IFS= read -r spec_file; do
  feature_dirs+=("$(dirname "${spec_file}")")
done < <(find "${repo_root}/specs" -maxdepth 2 -mindepth 2 -name spec.md | sort)

if [[ "${#feature_dirs[@]}" -eq 0 ]]; then
  echo "No active spec found under specs/*/spec.md" >&2
  exit 1
fi

feature_dir="${feature_dirs[0]}"
plan_file="${feature_dir}/plan.md"
tasks_file="${feature_dir}/tasks.md"
template="${repo_root}/.specify/templates/tasks-template.md"

if [[ ! -f "${plan_file}" ]]; then
  echo "Missing plan file: ${plan_file}" >&2
  exit 1
fi

if [[ ! -f "${tasks_file}" ]]; then
  cp "${template}" "${tasks_file}"
fi

if [[ "${json}" == "true" ]]; then
  python3 - "$feature_dir" "$plan_file" "$tasks_file" <<'PY'
import json
import sys

print(json.dumps({
    "FEATURE_DIR": sys.argv[1],
    "PLAN_FILE": sys.argv[2],
    "TASKS_FILE": sys.argv[3],
}))
PY
else
  printf 'FEATURE_DIR=%s\nPLAN_FILE=%s\nTASKS_FILE=%s\n' "${feature_dir}" "${plan_file}" "${tasks_file}"
fi
