#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_file="${repo_root}/tests/gemini-run.bats"

if ! command -v bats >/dev/null 2>&1; then
  echo "bats not found on PATH. Install bats-core first (e.g. 'brew install bats-core')." >&2
  exit 127
fi

exec bats "${test_file}" "$@"
