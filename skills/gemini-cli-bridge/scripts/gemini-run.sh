#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  gemini-run.sh --prompt-file PROMPT.txt [--context-file CONTEXT.txt] [--out OUT.txt] [--output-format text|json|stream-json] [--model MODEL] [-- EXTRA_GEMINI_ARGS...]
  cat PROMPT.txt | gemini-run.sh --prompt-file - [--context-file CONTEXT.txt ...]
  git diff | gemini-run.sh --prompt-file PROMPT.txt --context-file -

Notes:
  - Requires `gemini` on PATH.
  - If --context-file is provided, the script will pipe context to stdin and use `--prompt` to append the prompt.
    (`--prompt` is deprecated in gemini CLI help, but available in current versions.)
EOF
}

prompt_file=""
context_file=""
out_file=""
output_format="text"
model=""
extra_args=()

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
  echo "`gemini` not found on PATH." >&2
  exit 127
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

if [[ -z "${prompt:-}" ]]; then
  prompt="$(cat "${prompt_file}")"
fi

cmd=(gemini --output-format "${output_format}")
if [[ -n "${model}" ]]; then
  cmd+=(--model "${model}")
fi
cmd+=("${extra_args[@]}")

if [[ -n "${context_file}" ]]; then
  # Explicitly use --prompt so the stdin behavior is well-defined for current gemini CLI.
  cmd+=(--prompt "${prompt}")
  if [[ -n "${out_file}" ]]; then
    cat "${context_file}" | "${cmd[@]}" | tee "${out_file}"
  else
    cat "${context_file}" | "${cmd[@]}"
  fi
else
  # Use positional prompt (preferred by gemini CLI help).
  if [[ -n "${out_file}" ]]; then
    "${cmd[@]}" "${prompt}" | tee "${out_file}"
  else
    "${cmd[@]}" "${prompt}"
  fi
fi
