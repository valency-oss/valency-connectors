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

exit_after_signal() {
  signal_status=$1
  trap - EXIT HUP INT TERM
  cleanup
  exit "$signal_status"
}

trap cleanup EXIT
trap 'exit_after_signal 129' HUP
trap 'exit_after_signal 130' INT
trap 'exit_after_signal 143' TERM

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
  if grep -E '(plugin (install|update|uninstall|add|remove)|plugin marketplace (add|update|upgrade|remove)|extensions (install|update|enable|disable|uninstall)|mcp login)' "$MOCK_LOG" | grep -v -- '--help' >/dev/null 2>&1; then
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
  env \
    HOME="$CASE_DIR/home" \
    CODEX_HOME="$CASE_DIR/codex-home" \
    PATH="$MOCK_BIN:$TEST_BASH_DIR:/usr/bin:/bin" \
    MOCK_STATE="$MOCK_STATE" \
    MOCK_LOG="$MOCK_LOG" \
    NO_COLOR=1 \
    VALENCY_INSTALLER_TEST_MODE=1 \
    VALENCY_INSTALLER_TTY="$CASE_DIR/no-terminal" \
    "$TEST_BASH" "$INSTALLER" "$@" >"$RUN_OUTPUT" 2>&1
  RUN_STATUS=$?
}

run_with_terminal() {
  env \
    HOME="$CASE_DIR/home" \
    CODEX_HOME="$CASE_DIR/codex-home" \
    PATH="$MOCK_BIN:$TEST_BASH_DIR:/usr/bin:/bin" \
    MOCK_STATE="$MOCK_STATE" \
    MOCK_LOG="$MOCK_LOG" \
    NO_COLOR=1 \
    TERM=xterm \
    VALENCY_INSTALLER_TEST_MODE=1 \
    VALENCY_INSTALLER_TTY="$TTY_INPUT" \
    "$TEST_BASH" "$INSTALLER" "$@" >"$RUN_OUTPUT" 2>&1
  RUN_STATUS=$?
}

run_with_limited_terminal() {
  env \
    HOME="$CASE_DIR/home" \
    CODEX_HOME="$CASE_DIR/codex-home" \
    PATH="$MOCK_BIN:$TEST_BASH_DIR:/usr/bin:/bin" \
    MOCK_STATE="$MOCK_STATE" \
    MOCK_LOG="$MOCK_LOG" \
    NO_COLOR=1 \
    TERM=dumb \
    VALENCY_INSTALLER_TEST_MODE=1 \
    VALENCY_INSTALLER_TTY="$TTY_INPUT" \
    "$TEST_BASH" "$INSTALLER" "$@" >"$RUN_OUTPUT" 2>&1
  RUN_STATUS=$?
}

enable_claude() {
  ln -s "$REPO_ROOT/tests/fixtures/mock-provider" "$MOCK_BIN/claude"
}

enable_codex() {
  ln -s "$REPO_ROOT/tests/fixtures/mock-provider" "$MOCK_BIN/codex"
}

enable_antigravity() {
  ln -s "$REPO_ROOT/tests/fixtures/mock-provider" "$MOCK_BIN/agy"
}

enable_copilot() {
  ln -s "$REPO_ROOT/tests/fixtures/mock-provider" "$MOCK_BIN/copilot"
}

enable_grok() {
  ln -s "$REPO_ROOT/tests/fixtures/mock-provider" "$MOCK_BIN/grok"
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

test_antigravity_fresh_install() {
  new_case antigravity-fresh-install
  enable_antigravity
  run_without_terminal --target antigravity --yes --no-auth
  assert_status 0 || return
  assert_log_contains "agy plugin install https://github.com/valency-oss/valency-bond" || return
  assert_output_contains "Antigravity CLI installation: installed" || return
  assert_output_contains "In Antigravity CLI: open /mcp, select valency, and complete browser authentication." || return
  pass "$TEST_NAME"
}

test_antigravity_capability_order_is_irrelevant() {
  new_case antigravity-capability-order
  enable_antigravity
  : > "$MOCK_STATE/agy-reversed-capabilities"
  run_without_terminal --target antigravity --yes --no-auth
  assert_status 0 || return
  assert_log_contains "agy plugin install https://github.com/valency-oss/valency-bond" || return
  assert_output_contains "Antigravity CLI installation: installed" || return
  pass "$TEST_NAME"
}

test_antigravity_capability_probe_requires_exact_commands() {
  new_case antigravity-capability-boundaries
  enable_antigravity
  : > "$MOCK_STATE/agy-similar-capabilities"
  run_without_terminal --target antigravity --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Antigravity CLI is installed but lacks required plugin commands; upgrade it." || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_antigravity_partial_import_fails_verification() {
  new_case antigravity-partial-import
  enable_antigravity
  : > "$MOCK_STATE/agy-partial-import"
  run_without_terminal --target antigravity --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Antigravity CLI installation: failed verification" || return
  assert_output_not_contains "In Antigravity CLI: open /mcp" || return
  pass "$TEST_NAME"
}

test_antigravity_unverifiable_import_requires_migration() {
  new_case antigravity-replacement-requires-flag
  enable_antigravity
  : > "$MOCK_STATE/agy-plugin-unverifiable"
  run_without_terminal --target antigravity --yes --no-auth
  assert_status 2 || return
  assert_output_contains "replacing the existing Antigravity CLI import named valency requires --migrate" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_antigravity_approved_replacement_updates() {
  new_case antigravity-replacement-approved
  enable_antigravity
  : > "$MOCK_STATE/agy-plugin-unverifiable"
  run_without_terminal --target antigravity --yes --migrate --no-auth
  assert_status 0 || return
  assert_output_contains "replace the existing import named valency whose repository Antigravity CLI does not expose" || return
  assert_log_contains "agy plugin install https://github.com/valency-oss/valency-bond" || return
  assert_output_contains "Antigravity CLI installation: updated" || return
  pass "$TEST_NAME"
}

test_interactive_declined_antigravity_replacement_skips_provider() {
  new_case antigravity-replacement-declined
  enable_antigravity
  : > "$MOCK_STATE/agy-plugin-unverifiable"
  printf 'n\n' > "$TTY_INPUT"
  run_with_terminal --target antigravity --no-auth
  assert_status 0 || return
  assert_output_contains "Antigravity CLI skipped; the existing import named valency was left unchanged." || return
  assert_output_contains "Antigravity CLI installation: skipped (replacement declined)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_copilot_fresh_install() {
  new_case copilot-fresh-install
  enable_copilot
  run_without_terminal --target copilot --yes --no-auth
  assert_status 0 || return
  assert_log_contains "copilot plugin marketplace add valency-oss/valency-bond" || return
  assert_log_contains "copilot plugin install valency@valency-copilot-plugin" || return
  assert_output_contains "GitHub Copilot CLI installation: installed" || return
  assert_output_contains "In GitHub Copilot CLI: run /mcp auth valency." || return
  pass "$TEST_NAME"
}

test_copilot_json_inventory_rejects_same_named_wrong_id() {
  new_case copilot-json-wrong-id
  enable_copilot
  : > "$MOCK_STATE/copilot-marketplace"
  : > "$MOCK_STATE/copilot-json-inventory"
  : > "$MOCK_STATE/copilot-plugin-wrong-id"
  run_without_terminal --target copilot --yes --no-auth
  assert_status 1 || return
  assert_output_contains "GitHub Copilot CLI installation: failed (plugin conflict)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_copilot_json_inventory_rejects_mixed_ids() {
  new_case copilot-json-mixed-ids
  enable_copilot
  : > "$MOCK_STATE/copilot-marketplace"
  : > "$MOCK_STATE/copilot-json-inventory"
  : > "$MOCK_STATE/copilot-plugin"
  : > "$MOCK_STATE/copilot-plugin-wrong-id"
  run_without_terminal --target copilot --yes --no-auth
  assert_status 1 || return
  assert_output_contains "GitHub Copilot CLI installation: failed (plugin conflict)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_copilot_text_inventory_rejects_mixed_ids() {
  new_case copilot-text-mixed-ids
  enable_copilot
  : > "$MOCK_STATE/copilot-marketplace"
  : > "$MOCK_STATE/copilot-plugin"
  : > "$MOCK_STATE/copilot-plugin-wrong-id"
  run_without_terminal --target copilot --yes --no-auth
  assert_status 1 || return
  assert_output_contains "GitHub Copilot CLI installation: failed (plugin conflict)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_copilot_text_inventory_rejects_mixed_marketplaces() {
  new_case copilot-text-mixed-marketplaces
  enable_copilot
  : > "$MOCK_STATE/copilot-marketplace-mixed"
  run_without_terminal --target copilot --yes --no-auth
  assert_status 1 || return
  assert_output_contains "GitHub Copilot CLI installation: failed (marketplace conflict)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_copilot_json_verification_rejects_disabled_plugin() {
  new_case copilot-json-disabled
  enable_copilot
  : > "$MOCK_STATE/copilot-marketplace"
  : > "$MOCK_STATE/copilot-plugin"
  : > "$MOCK_STATE/copilot-json-inventory"
  : > "$MOCK_STATE/copilot-plugin-disabled"
  run_without_terminal --target copilot --yes --no-auth
  assert_status 1 || return
  assert_log_contains "copilot plugin update valency" || return
  assert_output_contains "GitHub Copilot CLI installation: failed verification" || return
  assert_output_not_contains "In GitHub Copilot CLI: run /mcp auth valency." || return
  pass "$TEST_NAME"
}

test_copilot_text_verification_rejects_mixed_ids_after_update() {
  new_case copilot-text-post-update-mixed-ids
  enable_copilot
  : > "$MOCK_STATE/copilot-marketplace"
  : > "$MOCK_STATE/copilot-plugin"
  : > "$MOCK_STATE/copilot-plugin-mixed-after-update"
  run_without_terminal --target copilot --yes --no-auth
  assert_status 1 || return
  assert_log_contains "copilot plugin update valency" || return
  assert_output_contains "GitHub Copilot CLI installation: failed verification" || return
  assert_output_not_contains "In GitHub Copilot CLI: run /mcp auth valency." || return
  pass "$TEST_NAME"
}

test_grok_fresh_install() {
  new_case grok-fresh-install
  enable_grok
  run_without_terminal --target grok --yes --no-auth
  assert_status 0 || return
  assert_log_contains "grok plugin marketplace add valency-oss/valency-bond" || return
  assert_log_contains "grok plugin install valency --trust" || return
  assert_output_contains "Grok Build installation: installed" || return
  assert_output_contains "In Grok Build: open /mcps, select valency, and press i to authenticate." || return
  pass "$TEST_NAME"
}

test_copilot_foreign_marketplace_source_fails_closed() {
  new_case copilot-foreign-source
  enable_copilot
  : > "$MOCK_STATE/copilot-marketplace-foreign"
  run_without_terminal --target copilot --yes --no-auth
  assert_status 1 || return
  assert_output_contains "GitHub Copilot CLI installation: failed (marketplace conflict)" || return
  assert_output_contains "does not come from valency-oss/valency-bond" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_copilot_unrecognized_marketplace_output_fails_inspection() {
  new_case copilot-unrecognized-marketplace
  enable_copilot
  : > "$MOCK_STATE/copilot-marketplace-unrecognized"
  run_without_terminal --target copilot --yes --no-auth
  assert_status 1 || return
  assert_output_contains "GitHub Copilot CLI returned an unrecognized marketplace list" || return
  assert_output_contains "GitHub Copilot CLI installation: failed (state inspection)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_copilot_unrecognized_plugin_output_fails_inspection() {
  new_case copilot-unrecognized-plugin-list
  enable_copilot
  : > "$MOCK_STATE/copilot-plugin-list-unrecognized"
  run_without_terminal --target copilot --yes --no-auth
  assert_status 1 || return
  assert_output_contains "GitHub Copilot CLI returned an unrecognized plugin list" || return
  assert_output_contains "GitHub Copilot CLI installation: failed (state inspection)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_grok_foreign_source_fails_closed() {
  new_case grok-foreign-source
  enable_grok
  : > "$MOCK_STATE/grok-marketplace-foreign"
  : > "$MOCK_STATE/grok-plugin-foreign"
  run_without_terminal --target grok --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Grok Build installation: failed (source conflict)" || return
  assert_output_contains "does not come from valency-oss/valency-bond" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_grok_mixed_plugin_sources_fail_closed() {
  new_case grok-mixed-plugin-sources
  enable_grok
  : > "$MOCK_STATE/grok-marketplace"
  : > "$MOCK_STATE/grok-plugin-mixed"
  run_without_terminal --target grok --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Grok Build installation: failed (source conflict)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_grok_mixed_marketplace_sources_fail_closed() {
  new_case grok-mixed-marketplace-sources
  enable_grok
  : > "$MOCK_STATE/grok-marketplace-mixed"
  run_without_terminal --target grok --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Grok Build installation: failed (source conflict)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_new_provider_rerun_updates() {
  new_case new-provider-rerun-updates
  enable_antigravity
  enable_copilot
  enable_grok
  : > "$MOCK_STATE/agy-plugin"
  : > "$MOCK_STATE/copilot-marketplace"
  : > "$MOCK_STATE/copilot-plugin"
  : > "$MOCK_STATE/copilot-json-inventory"
  : > "$MOCK_STATE/grok-marketplace"
  : > "$MOCK_STATE/grok-plugin"
  run_without_terminal --target antigravity --target copilot --target grok --yes --migrate --no-auth
  assert_status 0 || return
  assert_log_contains "agy plugin install https://github.com/valency-oss/valency-bond" || return
  assert_log_contains "copilot plugin marketplace update valency-copilot-plugin" || return
  assert_log_contains "copilot plugin update valency" || return
  assert_log_contains "grok plugin marketplace update valency" || return
  assert_log_not_contains "grok plugin marketplace update valency-bond" || return
  assert_log_contains "grok plugin update valency" || return
  assert_output_contains "Antigravity CLI installation: updated" || return
  assert_output_contains "GitHub Copilot CLI installation: updated" || return
  assert_output_contains "Grok Build installation: updated" || return
  pass "$TEST_NAME"
}

test_new_provider_verification_failure_is_isolated() {
  new_case new-provider-verification-isolation
  enable_antigravity
  enable_copilot
  enable_grok
  : > "$MOCK_STATE/fail-copilot-verification"
  run_without_terminal --target antigravity --target copilot --target grok --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Antigravity CLI installation: installed" || return
  assert_output_contains "GitHub Copilot CLI installation: failed verification" || return
  assert_output_contains "Grok Build installation: installed" || return
  assert_log_contains "grok plugin install valency --trust" || return
  assert_output_not_contains "In GitHub Copilot CLI: run /mcp auth valency." || return
  pass "$TEST_NAME"
}

test_new_provider_capability_failure_is_isolated() {
  new_case new-provider-capability-isolation
  enable_antigravity
  enable_grok
  : > "$MOCK_STATE/agy-missing-capability"
  run_without_terminal --target antigravity --target grok --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Antigravity CLI installation: failed (unsupported CLI)" || return
  assert_output_contains "Grok Build installation: installed" || return
  assert_log_contains "grok plugin install valency --trust" || return
  pass "$TEST_NAME"
}

test_grok_required_options_are_capabilities() {
  new_case grok-required-options
  enable_grok
  : > "$MOCK_STATE/grok-missing-option"
  run_without_terminal --target grok --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Grok Build is installed but lacks required plugin commands; upgrade it." || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_all_providers_dry_run_is_non_destructive() {
  new_case all-provider-dry-run
  enable_claude
  enable_codex
  enable_antigravity
  enable_copilot
  enable_grok
  run_without_terminal --target all --yes --no-auth --dry-run
  assert_status 0 || return
  assert_no_mutations || return
  assert_output_contains "Claude Code installation: planned" || return
  assert_output_contains "Codex installation: planned" || return
  assert_output_contains "Antigravity CLI installation: planned" || return
  assert_output_contains "GitHub Copilot CLI installation: planned" || return
  assert_output_contains "Grok Build installation: planned" || return
  assert_output_contains "Antigravity CLI authentication: skipped" || return
  assert_output_contains "GitHub Copilot CLI authentication: skipped" || return
  assert_output_contains "Grok Build authentication: skipped" || return
  assert_output_not_contains "authentication: manual action required" || return
  pass "$TEST_NAME"
}

test_in_host_authentication_is_planned_during_dry_run() {
  new_case in-host-auth-dry-run
  enable_antigravity
  run_with_terminal --target antigravity --yes --auth --dry-run
  assert_status 0 || return
  assert_output_contains "Antigravity CLI installation: planned" || return
  assert_output_contains "Antigravity CLI authentication: planned" || return
  assert_output_not_contains "authentication: manual action required" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_standalone_dry_run_preserves_inspected_auth_states() {
  new_case standalone-auth-dry-run
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-auth-connected"
  : > "$MOCK_STATE/codex-auth-capability-missing"
  run_with_terminal --target claude --target codex --yes --auth --dry-run
  assert_status 0 || return
  assert_output_contains "Claude Code authentication: already connected" || return
  assert_output_contains "Codex authentication: unavailable" || return
  assert_output_not_contains "Claude Code authentication: planned" || return
  assert_output_not_contains "Codex authentication: planned" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_in_host_authentication_never_launches_new_hosts() {
  new_case in-host-authentication
  enable_antigravity
  enable_copilot
  enable_grok
  run_with_terminal --target antigravity --target copilot --target grok --yes --auth
  assert_status 0 || return
  assert_output_contains "Antigravity CLI authentication: manual action required" || return
  assert_output_contains "GitHub Copilot CLI authentication: manual action required" || return
  assert_output_contains "Grok Build authentication: manual action required" || return
  assert_log_not_contains "mcp auth valency" || return
  assert_log_not_contains "grok /mcps" || return
  pass "$TEST_NAME"
}

test_in_host_no_auth_reports_skipped_with_manual_guidance() {
  new_case in-host-no-auth
  enable_antigravity
  run_without_terminal --target antigravity --yes --no-auth
  assert_status 0 || return
  assert_output_contains "Antigravity CLI installation: installed" || return
  assert_output_contains "Antigravity CLI authentication: skipped" || return
  assert_output_contains "In Antigravity CLI: open /mcp, select valency, and complete browser authentication." || return
  assert_output_not_contains "authentication: manual action required" || return
  assert_log_not_contains "mcp auth valency" || return
  pass "$TEST_NAME"
}

test_interactive_selector_defaults_to_all_five_providers() {
  new_case interactive-all-five
  enable_claude
  enable_codex
  enable_antigravity
  enable_copilot
  enable_grok
  printf '\n\n' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 0 || return
  assert_output_contains "Selected harnesses: Claude Code, Codex, Antigravity CLI, GitHub Copilot CLI, Grok Build" || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_contains "codex plugin add valency@valency" || return
  assert_log_contains "agy plugin install https://github.com/valency-oss/valency-bond" || return
  assert_log_contains "copilot plugin install valency@valency-copilot-plugin" || return
  assert_log_contains "grok plugin install valency --trust" || return
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

test_installed_plugin_with_missing_marketplace_is_repaired() {
  # A plugin can outlive its marketplace registration. The update path must
  # re-add the trusted marketplace rather than update or upgrade a missing
  # one, for both providers.
  new_case plugin-present-marketplace-missing
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-plugin"
  : > "$MOCK_STATE/codex-plugin"
  run_without_terminal --target all --yes --no-auth
  assert_status 0 || return
  assert_output_contains "Claude Code: add the valency-oss/valency-bond marketplace, update valency@valency-claude-plugin" || return
  assert_output_contains "Codex: add the valency-oss/valency-bond marketplace, reinstall valency@valency" || return
  assert_log_contains "claude plugin marketplace add valency-oss/valency-bond --scope user" || return
  assert_log_not_contains "claude plugin marketplace update valency-claude-plugin" || return
  assert_log_contains "claude plugin update valency@valency-claude-plugin --scope user" || return
  assert_log_contains "codex plugin marketplace add valency-oss/valency-bond" || return
  assert_log_not_contains "codex plugin marketplace upgrade valency" || return
  assert_log_contains "codex plugin add valency@valency" || return
  assert_output_contains "Claude Code installation: updated" || return
  assert_output_contains "Codex installation: updated" || return
  pass "$TEST_NAME"
}

test_plan_shows_refresh_for_existing_marketplace_with_fresh_plugin() {
  # The opposite mismatch: marketplace present, plugin absent must plan a
  # refresh, not an add, for both providers.
  new_case plan-existing-marketplace-fresh-plugin
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-marketplace"
  : > "$MOCK_STATE/codex-marketplace"
  run_without_terminal --target all --yes --no-auth --dry-run
  assert_status 0 || return
  assert_output_contains "Claude Code: refresh the valency-claude-plugin marketplace, install valency@valency-claude-plugin at user scope" || return
  assert_output_contains "Codex: refresh the valency marketplace, install valency@valency" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_project_scoped_plugin_is_not_mistaken_for_user_install() {
  # The same plugin id installed at project scope must not satisfy detection
  # or verification: the installer manages user scope, installs there, and
  # verifies the user-scoped entry even with the project entry listed first.
  new_case claude-project-scope-duplicate
  enable_claude
  : > "$MOCK_STATE/claude-marketplace"
  : > "$MOCK_STATE/claude-plugin-project-scoped"
  run_without_terminal --target claude --yes --no-auth
  assert_status 0 || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_not_contains "claude plugin update valency@valency-claude-plugin --scope user" || return
  assert_output_contains "Claude Code installation: installed" || return
  pass "$TEST_NAME"
}

test_lookalike_claude_marketplace_is_not_trusted() {
  # A pre-existing marketplace with the expected name but a different
  # repository must not be updated or used to install: the plugin it serves
  # would carry the expected identity and pass verification.
  new_case claude-lookalike-marketplace
  enable_claude
  : > "$MOCK_STATE/claude-foreign-marketplace"
  run_without_terminal --target claude --yes --no-auth
  assert_status 1 || return
  assert_output_contains "does not come from valency-oss/valency-bond" || return
  assert_output_contains "Claude Code installation: failed (marketplace conflict)" || return
  assert_output_contains "claude plugin marketplace remove valency-claude-plugin --scope user" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_whitespace_in_marketplace_repo_is_not_trusted() {
  # " valency-oss/valency-bond" equals the trusted repo only if whitespace
  # inside the JSON string were stripped before comparison; it must stay a
  # conflict.
  new_case claude-whitespace-marketplace
  enable_claude
  : > "$MOCK_STATE/claude-whitespace-marketplace"
  run_without_terminal --target claude --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Claude Code installation: failed (marketplace conflict)" || return
  assert_no_mutations || return
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

test_foreign_legacy_marketplace_is_left_alone() {
  # An unrelated marketplace using the legacy name — and the legacy-id plugin
  # it serves — must survive a migration-approved install untouched.
  new_case claude-foreign-legacy-marketplace
  enable_claude
  : > "$MOCK_STATE/claude-foreign-legacy-marketplace"
  : > "$MOCK_STATE/claude-legacy-plugin"
  run_without_terminal --target claude --yes --migrate --no-auth
  assert_status 0 || return
  assert_output_contains "does not come from a Valency legacy repository" || return
  assert_log_not_contains "claude plugin marketplace remove valency-plugin --scope user" || return
  assert_log_not_contains "claude plugin uninstall valency@valency-plugin --scope user" || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_output_contains "Claude Code installation: installed" || return
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
  : > "$MOCK_STATE/codex-foreign-marketplace"
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
  : > "$MOCK_STATE/codex-foreign-marketplace"
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
  : > "$MOCK_STATE/codex-foreign-marketplace"
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
  : > "$MOCK_STATE/codex-foreign-marketplace"
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
  : > "$MOCK_STATE/codex-foreign-marketplace"
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
  : > "$MOCK_STATE/codex-foreign-marketplace"
  printf 'n\n' > "$TTY_INPUT"
  run_with_terminal --target codex --no-auth
  assert_status 0 || return
  assert_output_contains "Codex skipped; the existing marketplace named valency was left unchanged." || return
  assert_output_contains "Codex installation: skipped (replacement declined)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_trusted_codex_marketplace_reinstalls_without_migration() {
  # Our own marketplace surviving a partial earlier run is not a conflict:
  # the source matches, so reinstalling needs no replacement approval.
  new_case codex-trusted-marketplace-reinstall
  enable_codex
  : > "$MOCK_STATE/codex-marketplace"
  run_without_terminal --target codex --yes --no-auth
  assert_status 0 || return
  assert_log_contains "codex plugin marketplace upgrade valency" || return
  assert_log_contains "codex plugin add valency@valency" || return
  assert_log_not_contains "codex plugin marketplace remove valency" || return
  assert_output_contains "Codex installation: installed" || return
  pass "$TEST_NAME"
}

test_lookalike_codex_marketplace_with_installed_plugin_requires_migration() {
  # A look-alike marketplace must not take the refresh path just because a
  # plugin with the expected id is installed from it; replacement approval
  # is required before anything changes.
  new_case codex-lookalike-with-plugin
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/codex-foreign-marketplace"
  : > "$MOCK_STATE/codex-plugin"
  run_without_terminal --target codex --yes --no-auth
  assert_status 2 || return
  assert_output_contains "--migrate" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_lookalike_codex_marketplace_with_installed_plugin_is_replaced() {
  new_case codex-lookalike-with-plugin-replaced
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/codex-foreign-marketplace"
  : > "$MOCK_STATE/codex-plugin"
  run_without_terminal --target codex --yes --migrate --no-auth
  assert_status 0 || return
  assert_log_order "codex plugin marketplace remove valency" "codex plugin marketplace add valency-oss/valency-bond" || return
  assert_log_not_contains "codex plugin marketplace upgrade valency" || return
  assert_output_contains "Codex installation: installed (marketplace replaced)" || return
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
  assert_status 1 || return
  assert_output_contains "Claude Code is installed but lacks required plugin commands" || return
  assert_output_contains "Claude Code installation: failed (unsupported CLI)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_one_unavailable_explicit_target_does_not_block_the_other() {
  # Repeated explicit targets are failure-isolated like --target all: the
  # unavailable provider is reported, the available one still installs.
  new_case explicit-target-partial-availability
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-missing-capability"
  run_without_terminal --target claude --target codex --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Claude Code installation: failed (unsupported CLI)" || return
  assert_output_contains "Codex installation: installed" || return
  assert_log_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_requested_provider_missing_from_path_is_reported() {
  new_case explicit-target-not-installed
  enable_codex
  run_without_terminal --target claude --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Claude Code was requested but its CLI is not on PATH" || return
  assert_output_contains "Claude Code installation: failed (not installed)" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_only_missing_explicit_target_is_reported_precisely() {
  new_case only-explicit-target-not-installed
  run_without_terminal --target codex --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Codex was requested but its CLI is not on PATH" || return
  assert_output_contains "Codex installation: failed (not installed)" || return
  assert_output_not_contains "No supported provider CLIs were found" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_only_unsupported_provider_is_reported_precisely() {
  # When the only installed provider lacks capabilities, the error must name
  # that condition rather than claim no CLI was found on PATH.
  new_case only-unsupported-provider
  enable_claude
  : > "$MOCK_STATE/claude-missing-capability"
  run_without_terminal --target all --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Claude Code is installed but lacks required plugin commands" || return
  assert_output_not_contains "No supported provider CLIs were found" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_target_all_reports_unsupported_provider() {
  # --target all promised every installed provider: a present CLI without the
  # required commands must be reported and fail the run, while the capable
  # provider still installs.
  new_case target-all-unsupported-provider
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-missing-capability"
  run_without_terminal --target all --yes --no-auth
  assert_status 1 || return
  assert_output_contains "Claude Code is installed but lacks required plugin commands" || return
  assert_output_contains "Claude Code installation: failed (unsupported CLI)" || return
  assert_output_contains "Codex installation: installed" || return
  assert_log_contains "codex plugin add valency@valency" || return
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
  assert_output_contains "--target claude|codex|antigravity|copilot|grok|all" || return
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
  assert_output_not_contains "Manual Claude login:" || return
  assert_output_not_contains "Manual Codex login:" || return
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
  # Removing the closing brace leaves the guarded invocation open: nothing
  # may execute and the parse failure must surface as a nonzero status.
  new_case truncated-download
  enable_claude
  truncated="$CASE_DIR/install-truncated.sh"
  sed '$d' "$INSTALLER" > "$truncated"
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
  if [ "$RUN_STATUS" -eq 0 ]; then
    fail "$TEST_NAME (a truncated download must not succeed)"
    return
  fi
  if [ -s "$MOCK_LOG" ]; then
    fail "$TEST_NAME (a truncated download ran provider commands)"
    return
  fi
  pass "$TEST_NAME"
}

test_truncation_after_the_word_main_is_inert() {
  # A stream that ends directly after the word "main" would be a valid
  # argument-free invocation without the brace guard, silently dropping the
  # caller's flags. With the guard it must be a parse error that runs nothing.
  new_case truncated-after-main
  enable_claude
  truncated="$CASE_DIR/install-truncated.sh"
  # Drop the closing brace and the invocation line, then end the stream
  # directly after the word "main" with no newline.
  sed '$d' "$INSTALLER" | sed '$d' > "$truncated"
  printf '  main' >> "$truncated"
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
  if [ "$RUN_STATUS" -eq 0 ]; then
    fail "$TEST_NAME (a cut after the word main must not succeed)"
    return
  fi
  if [ -s "$MOCK_LOG" ]; then
    fail "$TEST_NAME (a cut after the word main ran provider commands)"
    return
  fi
  pass "$TEST_NAME"
}

test_midfile_truncated_download_is_inert() {
  # A download can be cut anywhere, not only before the final line. Whatever
  # the cut point, the truncated script must run no provider commands at all,
  # because only the final main invocation executes work.
  new_case midfile-truncated-download
  enable_claude
  truncated="$CASE_DIR/install-truncated.sh"
  total_lines=$(wc -l < "$INSTALLER")
  head -n "$((total_lines / 2))" "$INSTALLER" > "$truncated"
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
  if [ -s "$MOCK_LOG" ]; then
    fail "$TEST_NAME (a mid-file truncation ran provider commands)"
    return
  fi
  pass "$TEST_NAME"
}

test_codex_bearer_token_auth_counts_as_connected() {
  new_case codex-bearer-token-auth
  enable_codex
  : > "$MOCK_STATE/codex-auth-bearer"
  run_with_terminal --target codex --yes --auth
  assert_status 0 || return
  assert_log_not_contains "codex mcp login valency" || return
  assert_output_contains "Codex authentication: already connected" || return
  pass "$TEST_NAME"
}

test_dry_run_shows_migration_and_replacement_plan_without_mutation() {
  new_case dry-run-migration-plan
  enable_claude
  enable_codex
  enable_repository_check
  : > "$MOCK_STATE/claude-legacy-marketplace"
  : > "$MOCK_STATE/claude-legacy-plugin"
  : > "$MOCK_STATE/codex-foreign-marketplace"
  run_without_terminal --target all --yes --migrate --no-auth --dry-run
  assert_status 0 || return
  assert_output_contains "Conditional migration: after verification, remove valency@valency-plugin" || return
  assert_output_contains "Conditional replacement: remove the existing marketplace named valency" || return
  assert_output_contains "Claude Code installation: planned" || return
  assert_output_contains "Codex installation: planned" || return
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
  assert_output_contains "Select harnesses for Valency" || return
  assert_output_contains "[x] All detected harnesses" || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_interactive_selector_explains_an_unsupported_provider() {
  new_case interactive-unsupported-provider
  enable_claude
  enable_codex
  : > "$MOCK_STATE/claude-missing-capability"
  printf '\n\n' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 0 || return
  assert_output_contains "Claude Code is installed but lacks required plugin commands; upgrade it." || return
  assert_output_contains "Selected harnesses: Codex" || return
  assert_log_not_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_interactive_selector_can_deselect_a_provider() {
  new_case interactive-deselect-codex
  enable_claude
  enable_codex
  # Start on "All detected harnesses", move to Codex, toggle it with Space,
  # confirm the selection, then accept the installation plan.
  printf '\033[B\033[B \n\n' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 0 || return
  assert_output_contains "up/down move  space toggle  enter continue  esc cancel" || return
  assert_output_not_contains "Enter numbers to toggle" || return
  assert_output_contains "[-] All detected harnesses" || return
  assert_output_contains "Selected harnesses: Claude Code" || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_not_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_interactive_select_all_can_clear_and_restore_defaults() {
  new_case interactive-select-all
  enable_claude
  enable_codex
  # Space clears the initial all-selected state; Space again restores it.
  printf '  \n\n' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 0 || return
  assert_output_contains "[ ] All detected harnesses" || return
  assert_output_contains "[x] All detected harnesses" || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_interactive_selector_rejects_an_empty_required_selection() {
  new_case interactive-empty-selection
  enable_claude
  enable_codex
  # Clear all, try to submit, restore all, submit, then accept the plan.
  printf ' \n \n\n' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 0 || return
  assert_output_contains "Select at least one item to continue." || return
  assert_log_contains "claude plugin install valency@valency-claude-plugin --scope user" || return
  assert_log_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

test_limited_terminal_uses_yes_no_selection() {
  new_case limited-terminal-selection
  enable_claude
  enable_codex
  # Keep Claude selected, deselect Codex, then accept the plan.
  printf '\nn\n\n' > "$TTY_INPUT"
  run_with_limited_terminal --no-auth
  assert_status 0 || return
  assert_output_contains "Limited terminal: answer once for each detected harness." || return
  assert_output_contains "Install Valency for Claude Code? [Y/n]" || return
  assert_output_contains "Install Valency for Codex? [Y/n]" || return
  assert_output_not_contains "provider numbers" || return
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
  assert_output_contains "Selected harnesses cancelled" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_interactive_selector_escape_cancels() {
  new_case interactive-selection-escape
  enable_claude
  enable_codex
  printf '\033' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 1 || return
  assert_output_contains "Selected harnesses cancelled" || return
  assert_no_mutations || return
  pass "$TEST_NAME"
}

test_interactive_selector_interrupt_returns_130() {
  new_case interactive-selection-interrupt
  enable_claude
  enable_codex
  printf '\003' > "$TTY_INPUT"
  run_with_terminal --no-auth
  assert_status 130 || return
  assert_output_contains "Selected harnesses cancelled" || return
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

test_not_connected_status_is_not_misread_as_connected() {
  # "Not connected" contains the word "connected"; it must classify as
  # unknown so authentication stays selected by default.
  new_case claude-auth-not-connected
  enable_claude
  : > "$MOCK_STATE/claude-auth-not-connected"
  run_with_terminal --target claude --yes --auth
  assert_status 0 || return
  assert_output_contains "Claude Code status: unknown." || return
  assert_log_contains "claude mcp login plugin:valency:valency" || return
  pass "$TEST_NAME"
}

test_prefix_collision_server_is_not_misread_as_claude_auth() {
  # plugin:valency:valency-helper shares the prefix but is a different
  # server; its Connected status must not suppress the plugin's login.
  new_case claude-auth-prefix-collision
  enable_claude
  : > "$MOCK_STATE/claude-auth-prefix-collision"
  run_with_terminal --target claude --yes --auth
  assert_status 0 || return
  assert_output_contains "Claude Code status: missing." || return
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
  assert_output_not_contains "Manual Claude login:" || return
  assert_output_contains "This Claude Code version lacks mcp login; upgrade it" || return
  pass "$TEST_NAME"
}

test_optional_authentication_selector_can_skip_one_provider() {
  new_case optional-auth-selection
  enable_claude
  enable_codex
  # Start on All, move to Codex, toggle it, then confirm authentication.
  printf '\033[B\033[B \n' > "$TTY_INPUT"
  run_with_terminal --target all --yes
  assert_status 0 || return
  assert_output_contains "Optional authentication" || return
  assert_output_contains "[-] All available providers" || return
  assert_output_not_contains "Enter numbers to toggle" || return
  assert_log_contains "claude mcp login plugin:valency:valency" || return
  assert_log_not_contains "codex mcp login valency" || return
  assert_output_contains "Codex authentication: skipped" || return
  pass "$TEST_NAME"
}

test_optional_authentication_selector_can_skip_all_providers() {
  new_case optional-auth-skip-all
  enable_claude
  enable_codex
  # Space on All clears every default, and Enter confirms the empty optional
  # selection without affecting the verified installations.
  printf ' \n' > "$TTY_INPUT"
  run_with_terminal --target all --yes
  assert_status 0 || return
  assert_output_contains "Authentication: skipped" || return
  assert_log_not_contains "claude mcp login plugin:valency:valency" || return
  assert_log_not_contains "codex mcp login valency" || return
  assert_output_contains "Claude Code authentication: skipped" || return
  assert_output_contains "Codex authentication: skipped" || return
  pass "$TEST_NAME"
}

test_limited_terminal_authentication_uses_yes_no_selection() {
  new_case limited-terminal-auth-selection
  enable_claude
  enable_codex
  # Keep Claude selected and deselect Codex in the portable fallback.
  printf '\nn\n' > "$TTY_INPUT"
  run_with_limited_terminal --target all --yes
  assert_status 0 || return
  assert_output_contains "Limited terminal: answer once for each available provider." || return
  assert_output_contains "Authenticate Claude Code (missing)? [Y/n]" || return
  assert_output_contains "Authenticate Codex (missing)? [Y/n]" || return
  assert_log_contains "claude mcp login plugin:valency:valency" || return
  assert_log_not_contains "codex mcp login valency" || return
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
  : > "$MOCK_STATE/codex-foreign-marketplace"
  : > "$MOCK_STATE/fail-codex-plugin-add"
  run_without_terminal --target codex --yes --migrate --no-auth
  assert_status 1 || return
  assert_output_contains "Codex installation: failed marketplace replacement" || return
  assert_output_contains "codex plugin marketplace add valency-oss/valency-bond" || return
  assert_output_contains "codex plugin add valency@valency" || return
  pass "$TEST_NAME"
}

# Failing tests return nonzero without aborting the run, so every test
# executes and the final pass/fail summary reflects the whole suite.
test_no_harnesses
test_claude_fresh_install
test_codex_fresh_install
test_antigravity_fresh_install
test_antigravity_capability_order_is_irrelevant
test_antigravity_capability_probe_requires_exact_commands
test_antigravity_partial_import_fails_verification
test_antigravity_unverifiable_import_requires_migration
test_antigravity_approved_replacement_updates
test_interactive_declined_antigravity_replacement_skips_provider
test_copilot_fresh_install
test_copilot_json_inventory_rejects_same_named_wrong_id
test_copilot_json_inventory_rejects_mixed_ids
test_copilot_text_inventory_rejects_mixed_ids
test_copilot_text_inventory_rejects_mixed_marketplaces
test_copilot_json_verification_rejects_disabled_plugin
test_copilot_text_verification_rejects_mixed_ids_after_update
test_grok_fresh_install
test_copilot_foreign_marketplace_source_fails_closed
test_copilot_unrecognized_marketplace_output_fails_inspection
test_copilot_unrecognized_plugin_output_fails_inspection
test_grok_foreign_source_fails_closed
test_grok_mixed_plugin_sources_fail_closed
test_grok_mixed_marketplace_sources_fail_closed
test_new_provider_rerun_updates
test_new_provider_verification_failure_is_isolated
test_new_provider_capability_failure_is_isolated
test_grok_required_options_are_capabilities
test_all_providers_dry_run_is_non_destructive
test_in_host_authentication_is_planned_during_dry_run
test_standalone_dry_run_preserves_inspected_auth_states
test_in_host_authentication_never_launches_new_hosts
test_in_host_no_auth_reports_skipped_with_manual_guidance
test_interactive_selector_defaults_to_all_five_providers
test_rerun_updates_both_providers
test_installed_plugin_with_missing_marketplace_is_repaired
test_plan_shows_refresh_for_existing_marketplace_with_fresh_plugin
test_project_scoped_plugin_is_not_mistaken_for_user_install
test_lookalike_claude_marketplace_is_not_trusted
test_whitespace_in_marketplace_repo_is_not_trusted
test_unattended_claude_migration_requires_flag
test_claude_migration_verifies_before_cleanup
test_claude_verification_failure_preserves_legacy_install
test_disabled_claude_plugin_migration_preserves_legacy
test_failed_legacy_cleanup_still_prints_manual_login
test_foreign_legacy_marketplace_is_left_alone
test_interactive_declined_migration_skips_provider
test_unattended_codex_replacement_requires_flag
test_codex_replacement_preflight_failure_is_non_destructive
test_codex_preflight_failure_does_not_block_claude
test_claude_inspection_failure_does_not_block_codex
test_codex_replacement_failure_prints_recovery
test_codex_replacement_succeeds
test_interactive_declined_codex_replacement_skips_provider
test_trusted_codex_marketplace_reinstalls_without_migration
test_lookalike_codex_marketplace_with_installed_plugin_requires_migration
test_lookalike_codex_marketplace_with_installed_plugin_is_replaced
test_provider_failure_does_not_block_other_provider
test_selected_provider_requires_plugin_capabilities
test_one_unavailable_explicit_target_does_not_block_the_other
test_requested_provider_missing_from_path_is_reported
test_only_missing_explicit_target_is_reported_precisely
test_only_unsupported_provider_is_reported_precisely
test_target_all_reports_unsupported_provider
test_invalid_unattended_invocations_are_non_destructive
test_help_is_non_destructive
test_repeated_targets_are_combined
test_dry_run_never_mutates_provider_state
test_final_confirmation_can_cancel
test_truncated_download_is_inert
test_truncation_after_the_word_main_is_inert
test_midfile_truncated_download_is_inert
test_codex_bearer_token_auth_counts_as_connected
test_dry_run_shows_migration_and_replacement_plan_without_mutation
test_interactive_selector_preselects_detected_providers
test_interactive_selector_explains_an_unsupported_provider
test_interactive_selector_can_deselect_a_provider
test_interactive_select_all_can_clear_and_restore_defaults
test_interactive_selector_rejects_an_empty_required_selection
test_limited_terminal_uses_yes_no_selection
test_interactive_selector_can_cancel
test_interactive_selector_escape_cancels
test_interactive_selector_interrupt_returns_130
test_authentication_succeeds_for_missing_connections
test_connected_providers_are_not_reauthenticated_by_default
test_reauthenticate_includes_connected_providers
test_other_connected_server_is_not_misread_as_claude_auth
test_not_connected_status_is_not_misread_as_connected
test_prefix_collision_server_is_not_misread_as_claude_auth
test_unknown_auth_status_is_selected
test_authentication_failure_is_only_a_warning
test_unavailable_authentication_does_not_fail_installation
test_optional_authentication_selector_can_skip_one_provider
test_optional_authentication_selector_can_skip_all_providers
test_limited_terminal_authentication_uses_yes_no_selection
test_unattended_default_does_not_attempt_authentication
test_disabled_codex_plugin_is_not_misclassified_as_a_conflict
test_state_inspection_failure_prevents_mutation
test_codex_plugin_failure_after_replacement_prints_recovery

printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
if [ "$FAIL_COUNT" -ne 0 ]; then
  exit 1
fi
