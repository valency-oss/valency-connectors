#!/usr/bin/env bash

set -u

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
INSTALLER="$REPO_ROOT/install.sh"
TEST_BASH=${BASH:-bash}
TEST_BASH_DIR=$(dirname "$TEST_BASH")
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/valency-installer-tests.XXXXXX")
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
  printf 'PASS: %s\n' "$1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

assert_status() {
  expected=$1
  if [ "$RUN_STATUS" -ne "$expected" ]; then
    fail "$TEST_NAME (expected status $expected, got $RUN_STATUS)"
    return 1
  fi
}

assert_output_contains() {
  expected=$1
  if ! grep -F -- "$expected" "$RUN_OUTPUT" >/dev/null 2>&1; then
    fail "$TEST_NAME (missing output: $expected)"
    return 1
  fi
}

assert_output_not_contains() {
  unexpected=$1
  if grep -F -- "$unexpected" "$RUN_OUTPUT" >/dev/null 2>&1; then
    fail "$TEST_NAME (unexpected output: $unexpected)"
    return 1
  fi
}

assert_log_contains() {
  expected=$1
  if ! grep -F -- "$expected" "$MOCK_LOG" >/dev/null 2>&1; then
    fail "$TEST_NAME (missing command: $expected)"
    return 1
  fi
}

assert_log_not_contains() {
  unexpected=$1
  if grep -F -- "$unexpected" "$MOCK_LOG" >/dev/null 2>&1; then
    fail "$TEST_NAME (unexpected command: $unexpected)"
    return 1
  fi
}

assert_no_mutations() {
  if grep -E '(plugin (install|update|uninstall|add|remove)|plugin marketplace (add|update|upgrade|remove)|mcp login)' "$MOCK_LOG" | grep -v -- '--help' >/dev/null 2>&1; then
    fail "$TEST_NAME (provider state was mutated)"
    return 1
  fi
}

assert_log_order() {
  first=$1
  second=$2
  first_line=$(grep -nF -- "$first" "$MOCK_LOG" | tail -1 | cut -d: -f1)
  second_line=$(grep -nF -- "$second" "$MOCK_LOG" | head -1 | cut -d: -f1)
  if [ -z "$first_line" ] || [ -z "$second_line" ] || [ "$first_line" -ge "$second_line" ]; then
    fail "$TEST_NAME (expected '$first' before '$second')"
    return 1
  fi
}

new_case() {
  TEST_NAME=$1
  CASE_DIR="$TEST_ROOT/$TEST_NAME"
  MOCK_BIN="$CASE_DIR/bin"
  MOCK_STATE="$CASE_DIR/state"
  MOCK_LOG="$CASE_DIR/commands.log"
  RUN_OUTPUT="$CASE_DIR/output.log"
  TTY_INPUT="$CASE_DIR/tty-input"
  mkdir -p "$MOCK_BIN" "$MOCK_STATE" "$CASE_DIR/home" "$CASE_DIR/codex-home"
  : > "$MOCK_LOG"
  : > "$TTY_INPUT"
}

run_without_terminal() {
  set +e
  env \
    HOME="$CASE_DIR/home" \
    CODEX_HOME="$CASE_DIR/codex-home" \
    PATH="$MOCK_BIN:$TEST_BASH_DIR:/usr/bin:/bin" \
    MOCK_STATE="$MOCK_STATE" \
    MOCK_LOG="$MOCK_LOG" \
    NO_COLOR=1 \
    VALENCY_INSTALLER_TTY="$CASE_DIR/no-terminal" \
    "$TEST_BASH" "$INSTALLER" "$@" >"$RUN_OUTPUT" 2>&1
  RUN_STATUS=$?
  set -e
}

run_with_terminal() {
  set +e
  env \
    HOME="$CASE_DIR/home" \
    CODEX_HOME="$CASE_DIR/codex-home" \
    PATH="$MOCK_BIN:$TEST_BASH_DIR:/usr/bin:/bin" \
    MOCK_STATE="$MOCK_STATE" \
    MOCK_LOG="$MOCK_LOG" \
    NO_COLOR=1 \
    TERM=xterm \
    VALENCY_INSTALLER_TTY="$TTY_INPUT" \
    "$TEST_BASH" "$INSTALLER" "$@" >"$RUN_OUTPUT" 2>&1
  RUN_STATUS=$?
  set -e
}

run_with_limited_terminal() {
  set +e
  env \
    HOME="$CASE_DIR/home" \
    CODEX_HOME="$CASE_DIR/codex-home" \
    PATH="$MOCK_BIN:$TEST_BASH_DIR:/usr/bin:/bin" \
    MOCK_STATE="$MOCK_STATE" \
    MOCK_LOG="$MOCK_LOG" \
    NO_COLOR=1 \
    TERM=dumb \
    VALENCY_INSTALLER_TTY="$TTY_INPUT" \
    "$TEST_BASH" "$INSTALLER" "$@" >"$RUN_OUTPUT" 2>&1
  RUN_STATUS=$?
  set -e
}

enable_claude() {
  ln -s "$REPO_ROOT/tests/fixtures/mock-provider" "$MOCK_BIN/claude"
}

enable_codex() {
  ln -s "$REPO_ROOT/tests/fixtures/mock-provider" "$MOCK_BIN/codex"
}

enable_repository_check() {
  ln -s "$REPO_ROOT/tests/fixtures/mock-provider" "$MOCK_BIN/curl"
}

test_no_harnesses() {
  new_case no-harnesses
  run_without_terminal --target all --yes --no-auth
  assert_status 1 || return
  assert_output_contains "No supported provider CLIs were found" || return
  pass "$TEST_NAME"
}

test_claude_fresh_install() {
  new_case claude-fresh-install
  enable_claude
  run_without_terminal --target claude --yes --no-auth
  assert_status 0 || return
  assert_log_contains "claude plugin marketplace add valency-oss/valency-bond --scope user" || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_output_contains "Claude Code installation: installed" || return
  pass "$TEST_NAME"
}

test_codex_fresh_install() {
  new_case codex-fresh-install
  enable_codex
  run_without_terminal --target codex --yes --no-auth
  assert_status 0 || return
  assert_log_contains "codex plugin marketplace add valency-oss/valency-bond" || return
  assert_log_contains "codex plugin add valency@valency" || return
  assert_output_contains "Codex installation: installed" || return
  pass "$TEST_NAME"
}

test_rerun_updates_both_providers() {
  new_case rerun-updates-both
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-marketplace"
  : > "$MOCK_STATE/claude-plugin"
  : > "$MOCK_STATE/codex-marketplace"
  : > "$MOCK_STATE/codex-plugin"
  run_without_terminal --target all --yes --no-auth
  assert_status 0 || return
  assert_log_contains "claude plugin marketplace update valency-claude-plugin" || return
  assert_log_contains "claude plugin update valency@valency-claude-plugin --scope user" || return
  assert_log_contains "codex plugin marketplace upgrade valency" || return
  assert_log_contains "codex plugin add valency@valency" || return
  assert_output_contains "Claude Code installation: updated" || return
  assert_output_contains "Codex installation: updated" || return
  pass "$TEST_NAME"
}

test_unattended_claude_migration_requires_flag() {
  new_case claude-migration-requires-flag
  enable_claude
  : > "$MOCK_STATE/claude-legacy-marketplace"
  : > "$MOCK_STATE/claude-legacy-plugin"
  run_without_terminal --target claude --yes --no-auth
  assert_status 2 || return
  assert_output_contains "--migrate" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_claude_migration_verifies_before_cleanup() {
  new_case claude-migration-succeeds
  enable_claude
  : > "$MOCK_STATE/claude-legacy-marketplace"
  : > "$MOCK_STATE/claude-legacy-plugin"
  run_without_terminal --target claude --yes --migrate --no-auth
  assert_status 0 || return
  assert_log_order "claude plugin install valency@valency-claude-plugin --scope user" "claude plugin uninstall valency@valency-plugin --scope user" || return
  assert_log_order "claude plugin uninstall valency@valency-plugin --scope user" "claude plugin marketplace remove valency-plugin --scope user" || return
  assert_output_contains "Claude Code installation: installed" || return
  pass "$TEST_NAME"
}

test_claude_verification_failure_preserves_legacy_install() {
  new_case claude-verification-preserves-legacy
  enable_claude
  : > "$MOCK_STATE/claude-legacy-marketplace"
  : > "$MOCK_STATE/claude-legacy-plugin"
  : > "$MOCK_STATE/fail-claude-verification"
  run_without_terminal --target claude --yes --migrate --no-auth
  assert_status 1 || return
  assert_log_not_contains "claude plugin uninstall valency@valency-plugin --scope user" || return
  assert_log_not_contains "claude plugin marketplace remove valency-plugin --scope user" || return
  assert_output_contains "Claude Code installation: failed verification" || return
  pass "$TEST_NAME"
}

test_disabled_claude_plugin_migration_preserves_legacy() {
  # A disabled new plugin next to an enabled legacy plugin is the exact shape
  # where whole-document matching falsely verified and destroyed the legacy
  # install; verification must fail and leave the legacy plugin alone.
  new_case claude-disabled-plugin-migration
  enable_claude
  : > "$MOCK_STATE/claude-marketplace"
  : > "$MOCK_STATE/claude-plugin"
  : > "$MOCK_STATE/claude-plugin-disabled"
  : > "$MOCK_STATE/claude-legacy-marketplace"
  : > "$MOCK_STATE/claude-legacy-plugin"
  run_without_terminal --target claude --yes --migrate --no-auth
  assert_status 1 || return
  assert_output_contains "Claude Code installation: failed verification" || return
  assert_log_not_contains "claude plugin uninstall valency@valency-plugin --scope user" || return
  assert_log_not_contains "claude plugin marketplace remove valency-plugin --scope user" || return
  pass "$TEST_NAME"
}

test_failed_legacy_cleanup_still_prints_manual_login() {
  # Legacy cleanup failing after verification is an installation failure, but
  # the new plugin is verified and enabled, so the login hint must survive.
  new_case claude-legacy-cleanup-fails
  enable_claude
  : > "$MOCK_STATE/claude-legacy-marketplace"
  : > "$MOCK_STATE/claude-legacy-plugin"
  : > "$MOCK_STATE/fail-claude-legacy-uninstall"
  run_without_terminal --target claude --yes --migrate --no-auth
  assert_status 1 || return
  assert_output_contains "Claude Code installation: failed legacy cleanup (new plugin verified)" || return
  assert_output_contains "Manual Claude login: claude mcp login plugin:valency:valency" || return
  pass "$TEST_NAME"
}

test_interactive_declined_migration_skips_provider() {
  new_case declined-claude-migration
  enable_claude
  : > "$MOCK_STATE/claude-legacy-marketplace"
  : > "$MOCK_STATE/claude-legacy-plugin"
  printf 'n\n' > "$TTY_INPUT"
  run_with_terminal --target claude --no-auth
  assert_status 0 || return
  assert_output_contains "Claude Code skipped; legacy configuration was left unchanged." || return
  assert_output_contains "Claude Code installation: skipped (migration declined)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_unattended_codex_replacement_requires_flag() {
  new_case codex-replacement-requires-flag
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/codex-marketplace"
  run_without_terminal --target codex --yes --no-auth
  assert_status 2 || return
  assert_output_contains "--migrate" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_codex_replacement_preflight_failure_is_non_destructive() {
  new_case codex-replacement-preflight-fails
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/codex-marketplace"
  : > "$MOCK_STATE/repository-unreachable"
  run_without_terminal --target codex --yes --migrate --no-auth
  assert_status 1 || return
  assert_output_contains "the existing Codex marketplace was not changed" || return
  assert_output_contains "Codex installation: failed (replacement preflight)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_codex_preflight_failure_does_not_block_claude() {
  new_case codex-preflight-claude-continues
  enable_claude
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/codex-marketplace"
  : > "$MOCK_STATE/repository-unreachable"
  run_without_terminal --target all --yes --migrate --no-auth
  assert_status 1 || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_not_contains "codex plugin marketplace remove valency" || return
  assert_output_contains "Claude Code installation: installed" || return
  assert_output_contains "Codex installation: failed (replacement preflight)" || return
  pass "$TEST_NAME"
}

test_claude_inspection_failure_does_not_block_codex() {
  new_case claude-inspection-codex-continues
  enable_claude
  enable_codex
  : > "$MOCK_STATE/fail-claude-plugin-list"
  run_without_terminal --target all --yes --no-auth
  assert_status 1 || return
  assert_log_contains "codex plugin add valency@valency" || return
  assert_log_not_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_output_contains "Claude Code installation: failed (state inspection)" || return
  assert_output_contains "Codex installation: installed" || return
  pass "$TEST_NAME"
}

test_codex_replacement_failure_prints_recovery() {
  new_case codex-replacement-add-fails
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/codex-marketplace"
  : > "$MOCK_STATE/fail-codex-marketplace-add"
  run_without_terminal --target codex --yes --migrate --no-auth
  assert_status 1 || return
  assert_log_contains "codex plugin marketplace remove valency" || return
  assert_output_contains "cannot be restored automatically" || return
  assert_output_contains "codex plugin marketplace add valency-oss/valency-bond" || return
  assert_output_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_codex_replacement_succeeds() {
  new_case codex-replacement-succeeds
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/codex-marketplace"
  run_without_terminal --target codex --yes --migrate --no-auth
  assert_status 0 || return
  assert_log_order "codex plugin marketplace remove valency" "codex plugin marketplace add valency-oss/valency-bond" || return
  assert_log_order "codex plugin marketplace add valency-oss/valency-bond" "codex plugin add valency@valency" || return
  assert_output_contains "Codex installation: installed (marketplace replaced)" || return
  pass "$TEST_NAME"
}

test_interactive_declined_codex_replacement_skips_provider() {
  new_case declined-codex-replacement
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/codex-marketplace"
  printf 'n\n' > "$TTY_INPUT"
  run_with_terminal --target codex --no-auth
  assert_status 0 || return
  assert_output_contains "Codex skipped; the existing marketplace named valency was left unchanged." || return
  assert_output_contains "Codex installation: skipped (replacement declined)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_provider_failure_does_not_block_other_provider() {
  new_case partial-provider-failure
  enable_claude
  enable_codex
  : > "$MOCK_STATE/fail-claude-plugin-install"
  run_without_terminal --target all --yes --no-auth
  assert_status 1 || return
  assert_log_contains "codex plugin add valency@valency" || return
  assert_output_contains "Claude Code installation: failed" || return
  assert_output_contains "Codex installation: installed" || return
  assert_output_not_contains "Manual Claude login" || return
  pass "$TEST_NAME"
}

test_selected_provider_requires_plugin_capabilities() {
  new_case missing-provider-capability
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-missing-capability"
  run_without_terminal --target claude --yes --no-auth
  assert_status 2 || return
  assert_output_contains "Claude Code is unavailable or lacks required plugin commands" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_invalid_unattended_invocations_are_non_destructive() {
  case_index=0
  for arguments in \
    "--target unknown --yes --no-auth" \
    "--target" \
    "--wat" \
    "--target claude --yes --auth --no-auth" \
    "--target claude --yes --no-auth --reauthenticate" \
    "--yes --no-auth" \
    "--target claude --no-auth" \
    "--target claude --yes --auth"
  do
    case_index=$((case_index + 1))
    new_case "invalid-invocation-$case_index"
    enable_claude
    IFS=' ' read -r -a argument_vector <<< "$arguments"
    run_without_terminal "${argument_vector[@]}"
    if [ "$RUN_STATUS" -eq 0 ]; then
      fail "$TEST_NAME (unexpected success for: $arguments)"
      return
    fi
    assert_no_mutations || return
  done
  pass "invalid-unattended-invocations"
}

test_help_is_non_destructive() {
  new_case help
  enable_claude
  run_without_terminal --help
  assert_status 0 || return
  assert_output_contains "--target claude|codex|all" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_repeated_targets_are_combined() {
  new_case repeated-targets
  enable_claude
  enable_codex
  run_without_terminal --target claude --target codex --target claude --yes --no-auth
  assert_status 0 || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_dry_run_never_mutates_provider_state() {
  new_case dry-run
  enable_claude
  enable_codex
  run_without_terminal --target all --yes --no-auth --dry-run
  assert_status 0 || return
  assert_no_mutations || return
  assert_output_contains "Claude Code installation: planned" || return
  assert_output_contains "Codex installation: planned" || return
  pass "$TEST_NAME"
}

test_final_confirmation_can_cancel() {
  new_case final-confirmation-cancelled
  enable_claude
  printf 'n\n' > "$TTY_INPUT"
  run_with_terminal --target claude --no-auth
  assert_status 1 || return
  assert_output_contains "Installation cancelled" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_truncated_download_is_inert() {
  new_case truncated-download
  enable_claude
  truncated="$CASE_DIR/install-truncated.sh"
  sed '$d' "$INSTALLER" > "$truncated"
  set +e
  env \
    HOME="$CASE_DIR/home" \
    CODEX_HOME="$CASE_DIR/codex-home" \
    PATH="$MOCK_BIN:$TEST_BASH_DIR:/usr/bin:/bin" \
    MOCK_STATE="$MOCK_STATE" \
    MOCK_LOG="$MOCK_LOG" \
    NO_COLOR=1 \
    VALENCY_INSTALLER_TTY="$CASE_DIR/no-terminal" \
    "$TEST_BASH" "$truncated" --target claude --yes --no-auth >"$RUN_OUTPUT" 2>&1
  RUN_STATUS=$?
  set -e
  assert_status 0 || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_interactive_selector_preselects_detected_providers() {
  new_case interactive-default-selection
  enable_claude
  enable_codex
  printf '\n\n' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 0 || return
  assert_output_contains "Choose where to install Valency" || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_interactive_selector_can_deselect_a_provider() {
  new_case interactive-deselect-codex
  enable_claude
  enable_codex
  printf '2\n\n' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 0 || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_not_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_limited_terminal_uses_numbered_selection() {
  new_case limited-terminal-selection
  enable_claude
  enable_codex
  printf '1\n\n' > "$TTY_INPUT"
  run_with_limited_terminal --no-auth
  assert_status 0 || return
  assert_output_contains "Limited terminal selection" || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_not_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_interactive_selector_can_cancel() {
  new_case interactive-selection-cancelled
  enable_claude
  enable_codex
  printf 'q\n' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 1 || return
  assert_output_contains "Installation cancelled" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_authentication_succeeds_for_missing_connections() {
  new_case authentication-succeeds
  enable_claude
  enable_codex
  run_with_terminal --target all --yes --auth
  assert_status 0 || return
  assert_log_contains "claude mcp login plugin:valency:valency" || return
  assert_log_contains "codex mcp login valency" || return
  assert_output_contains "Open https://auth.example/claude-device to finish signing in." || return
  assert_output_contains "Open https://auth.example/codex-device to finish signing in." || return
  assert_output_contains "Claude Code authentication: authenticated" || return
  assert_output_contains "Codex authentication: authenticated" || return
  pass "$TEST_NAME"
}

test_connected_providers_are_not_reauthenticated_by_default() {
  new_case connected-auth-default
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-auth-connected"
  : > "$MOCK_STATE/codex-auth-connected"
  run_with_terminal --target all --yes --auth
  assert_status 0 || return
  assert_log_not_contains "claude mcp login plugin:valency:valency" || return
  assert_log_not_contains "codex mcp login valency" || return
  assert_output_contains "Claude Code authentication: already connected" || return
  assert_output_contains "Codex authentication: already connected" || return
  pass "$TEST_NAME"
}

test_reauthenticate_includes_connected_providers() {
  new_case explicit-reauthentication
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-auth-connected"
  : > "$MOCK_STATE/codex-auth-connected"
  run_with_terminal --target all --yes --reauthenticate
  assert_status 0 || return
  assert_log_contains "claude mcp login plugin:valency:valency" || return
  assert_log_contains "codex mcp login valency" || return
  pass "$TEST_NAME"
}

test_other_connected_server_is_not_misread_as_claude_auth() {
  # Another MCP server's "Connected" line must not mark the plugin connected;
  # the plugin's own line is unrecognized, so the state stays unknown and the
  # provider remains selected for authentication.
  new_case claude-auth-other-connected
  enable_claude
  : > "$MOCK_STATE/claude-auth-other-connected"
  run_with_terminal --target claude --yes --auth
  assert_status 0 || return
  assert_output_contains "Claude Code status: unknown." || return
  assert_log_contains "claude mcp login plugin:valency:valency" || return
  pass "$TEST_NAME"
}

test_unknown_auth_status_is_selected() {
  new_case unknown-auth-status
  enable_claude
  : > "$MOCK_STATE/claude-auth-unknown"
  run_with_terminal --target claude --yes --auth
  assert_status 0 || return
  assert_log_contains "claude mcp login plugin:valency:valency" || return
  pass "$TEST_NAME"
}

test_authentication_failure_is_only_a_warning() {
  new_case authentication-failure-warning
  enable_claude
  : > "$MOCK_STATE/fail-claude-auth"
  run_with_terminal --target claude --yes --auth
  assert_status 0 || return
  assert_output_contains "Claude Code installation: installed" || return
  assert_output_contains "Claude Code authentication: failed (plugin remains installed)" || return
  assert_output_contains "Manual Claude login: claude mcp login plugin:valency:valency" || return
  pass "$TEST_NAME"
}

test_unavailable_authentication_does_not_fail_installation() {
  new_case authentication-unavailable
  enable_claude
  : > "$MOCK_STATE/claude-auth-capability-missing"
  run_with_terminal --target claude --yes --auth
  assert_status 0 || return
  assert_log_not_contains "claude mcp login plugin:valency:valency" || return
  assert_output_contains "Claude Code installation: installed" || return
  assert_output_contains "Claude Code authentication: unavailable" || return
  pass "$TEST_NAME"
}

test_optional_authentication_selector_can_skip_one_provider() {
  new_case optional-auth-selection
  enable_claude
  enable_codex
  printf '2\n' > "$TTY_INPUT"
  run_with_terminal --target all --yes
  assert_status 0 || return
  assert_output_contains "Optional authentication" || return
  assert_log_contains "claude mcp login plugin:valency:valency" || return
  assert_log_not_contains "codex mcp login valency" || return
  assert_output_contains "Codex authentication: skipped" || return
  pass "$TEST_NAME"
}

test_unattended_default_does_not_attempt_authentication() {
  new_case unattended-default-auth
  enable_claude
  run_without_terminal --target claude --yes
  assert_status 0 || return
  assert_log_not_contains "claude mcp login plugin:valency:valency" || return
  if grep -F -- "Optional authentication" "$RUN_OUTPUT" >/dev/null 2>&1; then
    fail "$TEST_NAME (printed an interactive authentication prompt without a terminal)"
    return
  fi
  assert_output_contains "Claude Code authentication: skipped" || return
  pass "$TEST_NAME"
}

test_disabled_codex_plugin_is_not_misclassified_as_a_conflict() {
  new_case disabled-codex-plugin
  enable_codex
  : > "$MOCK_STATE/codex-marketplace"
  : > "$MOCK_STATE/codex-plugin"
  : > "$MOCK_STATE/codex-plugin-disabled"
  run_without_terminal --target codex --yes --no-auth
  assert_status 1 || return
  assert_log_contains "codex plugin marketplace upgrade valency" || return
  assert_log_not_contains "codex plugin marketplace remove valency" || return
  assert_output_contains "Codex installation: failed verification" || return
  pass "$TEST_NAME"
}

test_state_inspection_failure_prevents_mutation() {
  new_case state-inspection-failure
  enable_claude
  : > "$MOCK_STATE/fail-claude-plugin-list"
  run_without_terminal --target claude --yes --no-auth
  assert_status 1 || return
  assert_output_contains "could not inspect Claude Code plugin state" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_codex_plugin_failure_after_replacement_prints_recovery() {
  new_case codex-replacement-plugin-fails
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/codex-marketplace"
  : > "$MOCK_STATE/fail-codex-plugin-add"
  run_without_terminal --target codex --yes --migrate --no-auth
  assert_status 1 || return
  assert_output_contains "Codex installation: failed marketplace replacement" || return
  assert_output_contains "codex plugin marketplace add valency-oss/valency-bond" || return
  assert_output_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

set -e
test_no_harnesses
test_claude_fresh_install
test_codex_fresh_install
test_rerun_updates_both_providers
test_unattended_claude_migration_requires_flag
test_claude_migration_verifies_before_cleanup
test_claude_verification_failure_preserves_legacy_install
test_disabled_claude_plugin_migration_preserves_legacy
test_failed_legacy_cleanup_still_prints_manual_login
test_interactive_declined_migration_skips_provider
test_unattended_codex_replacement_requires_flag
test_codex_replacement_preflight_failure_is_non_destructive
test_codex_preflight_failure_does_not_block_claude
test_claude_inspection_failure_does_not_block_codex
test_codex_replacement_failure_prints_recovery
test_codex_replacement_succeeds
test_interactive_declined_codex_replacement_skips_provider
test_provider_failure_does_not_block_other_provider
test_selected_provider_requires_plugin_capabilities
test_invalid_unattended_invocations_are_non_destructive
test_help_is_non_destructive
test_repeated_targets_are_combined
test_dry_run_never_mutates_provider_state
test_final_confirmation_can_cancel
test_truncated_download_is_inert
test_interactive_selector_preselects_detected_providers
test_interactive_selector_can_deselect_a_provider
test_limited_terminal_uses_numbered_selection
test_interactive_selector_can_cancel
test_authentication_succeeds_for_missing_connections
test_connected_providers_are_not_reauthenticated_by_default
test_reauthenticate_includes_connected_providers
test_other_connected_server_is_not_misread_as_claude_auth
test_unknown_auth_status_is_selected
test_authentication_failure_is_only_a_warning
test_unavailable_authentication_does_not_fail_installation
test_optional_authentication_selector_can_skip_one_provider
test_unattended_default_does_not_attempt_authentication
test_disabled_codex_plugin_is_not_misclassified_as_a_conflict
test_state_inspection_failure_prevents_mutation
test_codex_plugin_failure_after_replacement_prints_recovery

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
if [ "$FAIL_COUNT" -ne 0 ]; then
  exit 1
fi
