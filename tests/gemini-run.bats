#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${REPO_ROOT}/skills/gemini-cli-bridge/scripts/gemini-run.sh"

  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
  export FAKE_GEMINI_LOG="${TEST_TMPDIR}/gemini.log"

  mkdir -p "${TEST_TMPDIR}/bin"
  cat > "${TEST_TMPDIR}/bin/gemini" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

log_file="${FAKE_GEMINI_LOG}"
{
  printf 'ARGS:%s\n' "$*"
  stdin_data="$(cat || true)"
  printf 'STDIN:%s\n' "${stdin_data}"
} >> "${log_file}"

case "${FAKE_GEMINI_MODE:-ok}" in
  ok)
    echo "stub-ok"
    exit 0
    ;;
  error_eperm)
    echo "Error authenticating: Error: listen EPERM: operation not permitted 0.0.0.0" >&2
    exit 1
    ;;
  *)
    echo "unknown mode" >&2
    exit 2
    ;;
esac
STUB
  chmod +x "${TEST_TMPDIR}/bin/gemini"

  export PATH="${TEST_TMPDIR}/bin:${PATH}"

  PROMPT_FILE="${TEST_TMPDIR}/prompt.txt"
  CONTEXT_FILE="${TEST_TMPDIR}/context.txt"
  printf 'prompt-text' > "${PROMPT_FILE}"
  printf 'context-body' > "${CONTEXT_FILE}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

@test "rejects prompt/context dual-stdin conflict" {
  run bash -c "printf 'prompt' | '${SCRIPT}' --prompt-file - --context-file -"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"cannot both read stdin"* ]]
}

@test "handles empty extra_args without nounset crash" {
  run "${SCRIPT}" --prompt-file "${PROMPT_FILE}" --output-format text
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"stub-ok"* ]]
}

@test "validates output format" {
  run "${SCRIPT}" --prompt-file "${PROMPT_FILE}" --output-format invalid
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"Invalid --output-format"* ]]
}

@test "pipes context to stdin and prompt via --prompt" {
  run "${SCRIPT}" --prompt-file "${PROMPT_FILE}" --context-file "${CONTEXT_FILE}" --output-format text
  [ "${status}" -eq 0 ]

  gemini_log="$(cat "${FAKE_GEMINI_LOG}")"
  [[ "${gemini_log}" == *"--prompt prompt-text"* ]]
  [[ "${gemini_log}" == *"STDIN:context-body"* ]]
}

@test "prints actionable hint for EPERM auth failure" {
  export FAKE_GEMINI_MODE="error_eperm"
  run "${SCRIPT}" --prompt-file "${PROMPT_FILE}" --output-format text

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Hint: Gemini CLI attempted browser-based OAuth callback"* ]]
  [[ "${output}" == *"gemini command failed with exit code: 1"* ]]
}
