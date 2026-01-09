#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CODEX_HOME="${repo_root}/.codex"

mkdir -p "${CODEX_HOME}/skills"

if [[ ! -e "${CODEX_HOME}/skills/gemini-cli-bridge" ]]; then
  "${repo_root}/scripts/install-skill.sh" --dest "${CODEX_HOME}"
fi

exec codex "$@"

