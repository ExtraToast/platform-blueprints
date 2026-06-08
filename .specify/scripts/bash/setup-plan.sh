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
spec_file="${feature_dir}/spec.md"
plan_file="${feature_dir}/plan.md"
template="${repo_root}/.specify/templates/plan-template.md"

if [[ ! -f "${plan_file}" ]]; then
  cp "${template}" "${plan_file}"
fi

if [[ "${json}" == "true" ]]; then
  python3 - "$feature_dir" "$spec_file" "$plan_file" <<'PY'
import json
import sys

print(json.dumps({
    "FEATURE_DIR": sys.argv[1],
    "SPEC_FILE": sys.argv[2],
    "PLAN_FILE": sys.argv[3],
}))
PY
else
  printf 'FEATURE_DIR=%s\nSPEC_FILE=%s\nPLAN_FILE=%s\n' "${feature_dir}" "${spec_file}" "${plan_file}"
fi
