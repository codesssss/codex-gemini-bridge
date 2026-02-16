#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  gemini-run.sh --prompt-file PROMPT.txt [--context-file CONTEXT.txt] [--out OUT.txt] [--output-format text|json|stream-json] [--model MODEL] [-- EXTRA_GEMINI_ARGS...]
  cat PROMPT.txt | gemini-run.sh --prompt-file - [--context-file CONTEXT.txt ...]
  git diff | gemini-run.sh --prompt-file PROMPT.txt --context-file -

Notes:
  - Requires `gemini` on PATH.
  - If --context-file is provided, the script sends a combined stdin payload:
      TASK:\n<prompt>\n\nCONTEXT:\n<context>
    and uses a short positional instruction to avoid long prompt args.
  - `--prompt-file -` and `--context-file -` cannot be used together because both consume stdin.
USAGE
}

print_known_error_hints() {
  local stderr_path="$1"

  if grep -q "listen EPERM: operation not permitted 0.0.0.0" "${stderr_path}"; then
    cat >&2 <<'HINT'
Hint: Gemini CLI attempted browser-based OAuth callback but the current environment blocked opening a local listen socket.
Action: run outside sandbox / with elevated permissions, or complete `gemini` login in a non-restricted terminal first.
HINT
  fi

  if grep -q "oauth2.googleapis.com" "${stderr_path}" && grep -q "ENOTFOUND" "${stderr_path}"; then
    cat >&2 <<'HINT'
Hint: Network/DNS cannot reach oauth2.googleapis.com.
Action: check outbound network policy, proxy, or DNS configuration before retrying.
HINT
  fi

  if grep -q "Cached credentials are not valid" "${stderr_path}"; then
    cat >&2 <<'HINT'
Hint: Cached Gemini credentials are invalid.
Action: re-run `gemini` login flow in an environment with browser/network access.
HINT
  fi
}

emit_context_payload() {
  local context_path="$1"
  local prompt_text="$2"

  printf 'TASK:\n%s\n\nCONTEXT:\n' "${prompt_text}"
  if [[ "${context_path}" == "-" ]]; then
    cat -
  else
    cat "${context_path}"
  fi
  printf '\n'
}

prompt_file=""
context_file=""
out_file=""
output_format="text"
model=""
extra_args=()
prompt=""
stderr_tmp=""
stdin_instruction="Use the task and context provided in stdin. Return only the final answer."

cleanup() {
  if [[ -n "${stderr_tmp}" && -f "${stderr_tmp}" ]]; then
    rm -f "${stderr_tmp}"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt-file)
      prompt_file="${2:-}"; shift 2 ;;
    --context-file)
      context_file="${2:-}"; shift 2 ;;
    --out)
      out_file="${2:-}"; shift 2 ;;
    --output-format)
      output_format="${2:-}"; shift 2 ;;
    --model)
      model="${2:-}"; shift 2 ;;
    --help|-h)
      usage; exit 0 ;;
    --)
      shift
      extra_args+=("$@")
      break ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2 ;;
  esac
done

if ! command -v gemini >/dev/null 2>&1; then
  echo "'gemini' not found on PATH." >&2
  exit 127
fi

case "${output_format}" in
  text|json|stream-json)
    ;;
  *)
    echo "Invalid --output-format: ${output_format}. Expected one of: text|json|stream-json" >&2
    exit 2
    ;;
esac

if [[ "${prompt_file}" == "-" && "${context_file}" == "-" ]]; then
  echo "Invalid args: --prompt-file - and --context-file - cannot both read stdin." >&2
  exit 2
fi

if [[ -z "${prompt_file}" || ! -f "${prompt_file}" ]]; then
  if [[ "${prompt_file}" == "-" ]]; then
    prompt="$(cat -)"
  else
    echo "Missing or invalid --prompt-file: ${prompt_file}" >&2
    exit 2
  fi
fi

if [[ -n "${context_file}" && "${context_file}" != "-" && ! -f "${context_file}" ]]; then
  echo "Invalid --context-file: ${context_file}" >&2
  exit 2
fi

if [[ -z "${prompt}" ]]; then
  prompt="$(cat "${prompt_file}")"
fi

cmd=(gemini --output-format "${output_format}")
if [[ -n "${model}" ]]; then
  cmd+=(--model "${model}")
fi
if (( ${#extra_args[@]} > 0 )); then
  cmd+=("${extra_args[@]}")
fi

stderr_tmp="$(mktemp -t gemini-run-stderr.XXXXXX)"

set +e
if [[ -n "${context_file}" ]]; then
  cmd_with_instruction=("${cmd[@]}" "${stdin_instruction}")
  if [[ -n "${out_file}" ]]; then
    emit_context_payload "${context_file}" "${prompt}" | "${cmd_with_instruction[@]}" 2>"${stderr_tmp}" | tee "${out_file}"
    rc=${PIPESTATUS[1]}
  else
    emit_context_payload "${context_file}" "${prompt}" | "${cmd_with_instruction[@]}" 2>"${stderr_tmp}"
    rc=${PIPESTATUS[1]}
  fi
else
  if [[ -n "${out_file}" ]]; then
    "${cmd[@]}" "${prompt}" 2>"${stderr_tmp}" | tee "${out_file}"
    rc=${PIPESTATUS[0]}
  else
    "${cmd[@]}" "${prompt}" 2>"${stderr_tmp}"
    rc=$?
  fi
fi
set -e

if [[ -s "${stderr_tmp}" ]]; then
  cat "${stderr_tmp}" >&2
fi

if [[ ${rc} -ne 0 ]]; then
  print_known_error_hints "${stderr_tmp}"
  echo "gemini command failed with exit code: ${rc}" >&2
  exit "${rc}"
fi
