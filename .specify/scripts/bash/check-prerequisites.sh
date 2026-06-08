#!/usr/bin/env bash
set -euo pipefail

json=false
require_tasks=false
include_tasks=false

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --json)
      json=true
      ;;
    --require-tasks)
      require_tasks=true
      ;;
    --include-tasks)
      include_tasks=true
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

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
spec_file="${feature_dir}/spec.md"
plan_file="${feature_dir}/plan.md"
tasks_file="${feature_dir}/tasks.md"

[[ -f "${spec_file}" ]] || { echo "Missing spec file: ${spec_file}" >&2; exit 1; }
[[ -f "${plan_file}" ]] || { echo "Missing plan file: ${plan_file}" >&2; exit 1; }
if [[ "${require_tasks}" == "true" && ! -f "${tasks_file}" ]]; then
  echo "Missing tasks file: ${tasks_file}" >&2
  exit 1
fi

if [[ "${json}" == "true" ]]; then
  python3 - "$feature_dir" "$spec_file" "$plan_file" "$tasks_file" "$include_tasks" <<'PY'
import json
import sys

payload = {
    "FEATURE_DIR": sys.argv[1],
    "SPEC_FILE": sys.argv[2],
    "PLAN_FILE": sys.argv[3],
}
if sys.argv[5] == "true":
    payload["TASKS_FILE"] = sys.argv[4]
print(json.dumps(payload))
PY
else
  printf 'FEATURE_DIR=%s\nSPEC_FILE=%s\nPLAN_FILE=%s\n' "${feature_dir}" "${spec_file}" "${plan_file}"
  if [[ "${include_tasks}" == "true" ]]; then
    printf 'TASKS_FILE=%s\n' "${tasks_file}"
  fi
fi
