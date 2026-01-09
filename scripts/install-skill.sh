#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_src="${repo_root}/skills/gemini-cli-bridge"

requested_dest=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)
      requested_dest="${2:-}"; shift 2 ;;
    --help|-h)
      echo "Usage: install-skill.sh [--dest CODEX_HOME_DIR]" >&2
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2 ;;
  esac
done

default_codex_home="${CODEX_HOME:-$HOME/.codex}"
codex_home="${requested_dest:-$default_codex_home}"
skills_dir="${codex_home}/skills"
skill_dest="${skills_dir}/gemini-cli-bridge"

if [[ ! -d "${skill_src}" ]]; then
  echo "Skill source not found: ${skill_src}" >&2
  exit 1
fi

mkdir -p "${skills_dir}"

if [[ -e "${skill_dest}" && ! -L "${skill_dest}" ]]; then
  echo "Destination already exists and is not a symlink: ${skill_dest}" >&2
  echo "Remove it manually if you want to reinstall." >&2
  exit 1
fi

if [[ -L "${skill_dest}" ]]; then
  current_target="$(readlink "${skill_dest}")"
  if [[ "${current_target}" == "${skill_src}" ]]; then
    echo "Already installed: ${skill_dest} -> ${skill_src}"
    echo "Restart Codex to pick up new skills."
    exit 0
  fi
  rm -f "${skill_dest}"
fi

if ! ln -s "${skill_src}" "${skill_dest}"; then
  echo "Failed to create symlink: ${skill_dest} -> ${skill_src}" >&2
  echo "If your environment blocks writes outside the repo, use a repo-local CODEX_HOME:" >&2
  echo "  CODEX_HOME=\"${repo_root}/.codex\" ./scripts/install-skill.sh --dest \"${repo_root}/.codex\"" >&2
  exit 1
fi

echo "Installed: ${skill_dest} -> ${skill_src}"
echo "Restart Codex to pick up new skills."

echo "Tip: repo-local CODEX_HOME (clone-and-use, no global writes):"
echo "  ./scripts/codex-local.sh"
