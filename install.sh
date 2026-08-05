#!/usr/bin/env bash

set -u

MARKETPLACE_SOURCE="valency-oss/valency-bond"
CLAUDE_MARKETPLACE="valency-claude-plugin"
CLAUDE_PLUGIN="valency@valency-claude-plugin"
CODEX_MARKETPLACE="valency"
CODEX_PLUGIN="valency@valency"

TARGETS_SPECIFIED=0
TARGET_CLAUDE=0
TARGET_CODEX=0
TARGET_ALL=0
ASSUME_YES=0
ALLOW_MIGRATION=0
AUTH_MODE="prompt"
REAUTHENTICATE=0
DRY_RUN=0
TERMINAL_AVAILABLE=0

CLAUDE_AVAILABLE=0
CODEX_AVAILABLE=0
CLAUDE_SELECTED=0
CODEX_SELECTED=0
CLAUDE_MARKETPLACE_PRESENT=0
CLAUDE_PLUGIN_PRESENT=0
CLAUDE_LEGACY_MARKETPLACE_PRESENT=0
CLAUDE_LEGACY_PLUGIN_PRESENT=0
CLAUDE_INSTALL_RESULT="not selected"
CLAUDE_AUTH_RESULT="not offered"
CODEX_INSTALL_RESULT="not selected"
CODEX_AUTH_RESULT="not offered"
CODEX_MARKETPLACE_PRESENT=0
CODEX_PLUGIN_PRESENT=0
CODEX_REPLACEMENT_REQUIRED=0
CLAUDE_AUTH_AVAILABLE=0
CODEX_AUTH_AVAILABLE=0
CLAUDE_AUTH_STATE="unknown"
CODEX_AUTH_STATE="unknown"
CLAUDE_AUTH_SELECTED=0
CODEX_AUTH_SELECTED=0

print_help() {
  cat <<'EOF'
Valency plugin installer

Usage:
  install.sh [options]

Options:
  --target claude|codex|all  Select a provider; may be repeated.
  --yes                      Confirm the displayed plan.
  --migrate                  Approve legacy marketplace migration.
  --auth                     Offer authentication after installation.
  --no-auth                  Skip authentication.
  --reauthenticate           Include apparently connected providers in authentication.
  --dry-run                  Show the plan without changing provider state.
  --help                     Show this help.
EOF
}

parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case $1 in
      --target)
        if [ "$#" -lt 2 ]; then
          printf 'Error: --target requires a value.\n' >&2
          return 2
        fi
        add_target "$2" || return $?
        shift 2
        ;;
      --target=*)
        add_target "${1#--target=}" || return $?
        shift
        ;;
      --yes)
        ASSUME_YES=1
        shift
        ;;
      --migrate)
        ALLOW_MIGRATION=1
        shift
        ;;
      --auth)
        if [ "$AUTH_MODE" = "no" ]; then
          printf 'Error: --auth conflicts with --no-auth.\n' >&2
          return 2
        fi
        AUTH_MODE="yes"
        shift
        ;;
      --no-auth)
        if [ "$AUTH_MODE" = "yes" ] || [ "$REAUTHENTICATE" -eq 1 ]; then
          printf 'Error: --no-auth conflicts with --auth and --reauthenticate.\n' >&2
          return 2
        fi
        AUTH_MODE="no"
        shift
        ;;
      --reauthenticate)
        if [ "$AUTH_MODE" = "no" ]; then
          printf 'Error: --reauthenticate conflicts with --no-auth.\n' >&2
          return 2
        fi
        REAUTHENTICATE=1
        AUTH_MODE="yes"
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --help|-h)
        print_help
        return 64
        ;;
      *)
        printf 'Error: unknown option: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done
}

add_target() {
  TARGETS_SPECIFIED=1
  case $1 in
    claude) TARGET_CLAUDE=1 ;;
    codex) TARGET_CODEX=1 ;;
    all) TARGET_ALL=1 ;;
    '')
      printf 'Error: --target requires a value.\n' >&2
      return 2
      ;;
    *)
      printf 'Error: unknown target: %s\n' "$1" >&2
      return 2
      ;;
  esac
}

initialize_terminal() {
  # The installer is normally piped on standard input, so prompts must use the
  # controlling terminal instead. The override is only a test seam: production
  # behavior remains /dev/tty and never falls back to the downloaded script.
  if [ -n "${VALENCY_INSTALLER_TTY-}" ]; then
    if [ -r "$VALENCY_INSTALLER_TTY" ] && exec 3<"$VALENCY_INSTALLER_TTY"; then
      TERMINAL_AVAILABLE=1
    fi
    return
  fi

  if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    if exec 3<>/dev/tty 2>/dev/null; then
      TERMINAL_AVAILABLE=1
    fi
  fi
}

claude_has_required_commands() {
  claude plugin marketplace add --help >/dev/null 2>&1 &&
    claude plugin marketplace list --help >/dev/null 2>&1 &&
    claude plugin marketplace update --help >/dev/null 2>&1 &&
    claude plugin marketplace remove --help >/dev/null 2>&1 &&
    claude plugin install --help >/dev/null 2>&1 &&
    claude plugin update --help >/dev/null 2>&1 &&
    claude plugin list --help >/dev/null 2>&1 &&
    claude plugin uninstall --help >/dev/null 2>&1
}

claude_has_auth_commands() {
  claude mcp list --help >/dev/null 2>&1 &&
    claude mcp login --help >/dev/null 2>&1
}

codex_has_required_commands() {
  codex plugin marketplace add --help >/dev/null 2>&1 &&
    codex plugin marketplace list --help >/dev/null 2>&1 &&
    codex plugin marketplace upgrade --help >/dev/null 2>&1 &&
    codex plugin marketplace remove --help >/dev/null 2>&1 &&
    codex plugin add --help >/dev/null 2>&1 &&
    codex plugin list --help >/dev/null 2>&1
}

codex_has_auth_commands() {
  codex mcp list --help >/dev/null 2>&1 &&
    codex mcp login --help >/dev/null 2>&1
}

detect_provider_executables() {
  if command -v claude >/dev/null 2>&1; then
    if claude_has_required_commands; then
      CLAUDE_AVAILABLE=1
      if claude_has_auth_commands; then CLAUDE_AUTH_AVAILABLE=1; fi
    fi
  fi
  if command -v codex >/dev/null 2>&1; then
    if codex_has_required_commands; then
      CODEX_AVAILABLE=1
      if codex_has_auth_commands; then CODEX_AUTH_AVAILABLE=1; fi
    fi
  fi
}

select_requested_targets() {
  if [ "$TARGETS_SPECIFIED" -eq 0 ]; then
    if [ "$TERMINAL_AVAILABLE" -eq 0 ]; then
      printf 'Error: without a terminal, --target is required.\n' >&2
      return 2
    fi
    interactive_select_targets || return 1
  fi

  if [ "$TERMINAL_AVAILABLE" -eq 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    printf 'Error: without a terminal, --yes is required.\n' >&2
    return 2
  fi
  if [ "$TERMINAL_AVAILABLE" -eq 0 ] && [ "$AUTH_MODE" = "yes" ]; then
    printf 'Error: authentication requires a terminal; use --no-auth for unattended installation.\n' >&2
    return 2
  fi
  if [ "$TERMINAL_AVAILABLE" -eq 0 ] && [ "$AUTH_MODE" = "prompt" ]; then
    AUTH_MODE="no"
  fi

  if [ "$TARGET_ALL" -eq 1 ]; then
    CLAUDE_SELECTED=$CLAUDE_AVAILABLE
    CODEX_SELECTED=$CODEX_AVAILABLE
  fi
  if [ "$TARGET_CLAUDE" -eq 1 ]; then
    if [ "$CLAUDE_AVAILABLE" -eq 0 ]; then
      printf 'Error: Claude Code is unavailable or lacks required plugin commands.\n' >&2
      return 2
    fi
    CLAUDE_SELECTED=1
  fi
  if [ "$TARGET_CODEX" -eq 1 ]; then
    if [ "$CODEX_AVAILABLE" -eq 0 ]; then
      printf 'Error: Codex is unavailable or lacks required plugin commands.\n' >&2
      return 2
    fi
    CODEX_SELECTED=1
  fi
}

interactive_select_targets() {
  CLAUDE_SELECTED=$CLAUDE_AVAILABLE
  CODEX_SELECTED=$CODEX_AVAILABLE
  option_number=0
  CLAUDE_OPTION=0
  CODEX_OPTION=0

  printf '\nChoose where to install Valency. Detected providers are selected by default.\n'
  if [ "$CLAUDE_AVAILABLE" -eq 1 ]; then
    option_number=$((option_number + 1))
    CLAUDE_OPTION=$option_number
  fi
  if [ "$CODEX_AVAILABLE" -eq 1 ]; then
    option_number=$((option_number + 1))
    CODEX_OPTION=$option_number
  fi

  if [ "${TERM-}" = "dumb" ] || [ -z "${TERM-}" ]; then
    printf 'Limited terminal selection (enter provider numbers separated by commas; Enter selects all):\n'
    if [ "$CLAUDE_OPTION" -gt 0 ]; then printf '  %s) Claude Code\n' "$CLAUDE_OPTION"; fi
    if [ "$CODEX_OPTION" -gt 0 ]; then printf '  %s) Codex\n' "$CODEX_OPTION"; fi
    printf 'Selection [all]: '
    selection=""
    IFS= read -r selection <&3 || return 1
    case $selection in
      q|Q|quit|cancel) printf 'Installation cancelled.\n'; return 1 ;;
      '') return 0 ;;
    esac
    CLAUDE_SELECTED=0
    CODEX_SELECTED=0
    apply_numbered_selection "$selection" select || return 1
  else
    if [ "$CLAUDE_OPTION" -gt 0 ]; then printf '  [x] %s) Claude Code\n' "$CLAUDE_OPTION"; fi
    if [ "$CODEX_OPTION" -gt 0 ]; then printf '  [x] %s) Codex\n' "$CODEX_OPTION"; fi
    printf 'Enter numbers to toggle, Enter to keep defaults, or q to cancel: '
    selection=""
    IFS= read -r selection <&3 || return 1
    case $selection in
      q|Q|quit|cancel) printf 'Installation cancelled.\n'; return 1 ;;
      '') return 0 ;;
    esac
    apply_numbered_selection "$selection" toggle || return 1
  fi

  if [ "$CLAUDE_SELECTED" -eq 0 ] && [ "$CODEX_SELECTED" -eq 0 ]; then
    printf 'Installation cancelled: no providers selected.\n'
    return 1
  fi
}

apply_numbered_selection() {
  selection=$1
  behavior=$2
  normalized=${selection//,/ }
  for item in $normalized; do
    if [ "$item" = "$CLAUDE_OPTION" ] && [ "$CLAUDE_OPTION" -gt 0 ]; then
      if [ "$behavior" = "toggle" ] && [ "$CLAUDE_SELECTED" -eq 1 ]; then
        CLAUDE_SELECTED=0
      else
        CLAUDE_SELECTED=1
      fi
    elif [ "$item" = "$CODEX_OPTION" ] && [ "$CODEX_OPTION" -gt 0 ]; then
      if [ "$behavior" = "toggle" ] && [ "$CODEX_SELECTED" -eq 1 ]; then
        CODEX_SELECTED=0
      else
        CODEX_SELECTED=1
      fi
    else
      printf 'Invalid provider selection: %s\n' "$item" >&2
      return 1
    fi
  done
}

compact_json() {
  tr -d '[:space:]'
}

inspect_claude_state() {
  if ! marketplace_json=$(claude plugin marketplace list --json 2>/dev/null); then
    printf 'Error: could not inspect Claude Code marketplace state; no changes were made.\n' >&2
    return 1
  fi
  if ! plugin_json=$(claude plugin list --json 2>/dev/null); then
    printf 'Error: could not inspect Claude Code plugin state; no changes were made.\n' >&2
    return 1
  fi
  compact_marketplaces=$(printf '%s' "$marketplace_json" | compact_json)
  compact_plugins=$(printf '%s' "$plugin_json" | compact_json)
  case $compact_marketplaces in
    \[*\]) ;;
    *) printf 'Error: Claude Code returned an unrecognized marketplace list; no changes were made.\n' >&2; return 1 ;;
  esac
  case $compact_plugins in
    \[*\]) ;;
    *) printf 'Error: Claude Code returned an unrecognized plugin list; no changes were made.\n' >&2; return 1 ;;
  esac

  case $compact_marketplaces in
    *\"name\":\"$CLAUDE_MARKETPLACE\"*) CLAUDE_MARKETPLACE_PRESENT=1 ;;
  esac
  case $compact_marketplaces in
    *\"name\":\"valency-plugin\"*) CLAUDE_LEGACY_MARKETPLACE_PRESENT=1 ;;
  esac
  case $compact_plugins in
    *\"id\":\"$CLAUDE_PLUGIN\"*) CLAUDE_PLUGIN_PRESENT=1 ;;
  esac
  case $compact_plugins in
    *\"id\":\"valency@valency-plugin\"*) CLAUDE_LEGACY_PLUGIN_PRESENT=1 ;;
  esac
}

inspect_provider_state() {
  if [ "$CLAUDE_SELECTED" -eq 1 ]; then
    inspect_claude_state || return 1
  fi
  if [ "$CODEX_SELECTED" -eq 1 ]; then
    inspect_codex_state || return 1
  fi
}

inspect_auth_states() {
  if [ "$AUTH_MODE" = "no" ]; then
    return
  fi
  if [ "$CLAUDE_SELECTED" -eq 1 ]; then
    inspect_claude_auth_state
  fi
  if [ "$CODEX_SELECTED" -eq 1 ]; then
    inspect_codex_auth_state
  fi
}

inspect_claude_auth_state() {
  if [ "$CLAUDE_AUTH_AVAILABLE" -eq 0 ]; then
    CLAUDE_AUTH_STATE="unavailable"
    return
  fi
  if ! auth_output=$(claude mcp list 2>/dev/null); then
    CLAUDE_AUTH_STATE="unknown"
    return
  fi
  case $auth_output in
    *plugin:valency:valency*Connected*|*plugin:valency:valency*connected*) CLAUDE_AUTH_STATE="connected" ;;
    *plugin:valency:valency*) CLAUDE_AUTH_STATE="unknown" ;;
    *) CLAUDE_AUTH_STATE="missing" ;;
  esac
}

inspect_codex_auth_state() {
  if [ "$CODEX_AUTH_AVAILABLE" -eq 0 ]; then
    CODEX_AUTH_STATE="unavailable"
    return
  fi
  if ! auth_output=$(codex mcp list --json 2>/dev/null); then
    CODEX_AUTH_STATE="unknown"
    return
  fi
  compact_auth=$(printf '%s' "$auth_output" | compact_json)
  case $compact_auth in
    \[*\]) ;;
    *) CODEX_AUTH_STATE="unknown"; return ;;
  esac
  case $compact_auth in
    *\"name\":\"valency\"*\"auth_status\":\"oauth\"*|*\"name\":\"valency\"*\"auth_status\":\"bearer_token\"*) CODEX_AUTH_STATE="connected" ;;
    *\"name\":\"valency\"*) CODEX_AUTH_STATE="unknown" ;;
    *) CODEX_AUTH_STATE="missing" ;;
  esac
}

inspect_codex_state() {
  if ! marketplace_json=$(codex plugin marketplace list --json 2>/dev/null); then
    printf 'Error: could not inspect Codex marketplace state; no changes were made.\n' >&2
    return 1
  fi
  if ! plugin_json=$(codex plugin list --json 2>/dev/null); then
    printf 'Error: could not inspect Codex plugin state; no changes were made.\n' >&2
    return 1
  fi
  compact_marketplaces=$(printf '%s' "$marketplace_json" | compact_json)
  compact_plugins=$(printf '%s' "$plugin_json" | compact_json)
  case $compact_marketplaces in
    *\"marketplaces\":\[*\]*) ;;
    *) printf 'Error: Codex returned an unrecognized marketplace list; no changes were made.\n' >&2; return 1 ;;
  esac
  case $compact_plugins in
    *\"installed\":\[*\]*) ;;
    *) printf 'Error: Codex returned an unrecognized plugin list; no changes were made.\n' >&2; return 1 ;;
  esac

  case $compact_marketplaces in
    *\"name\":\"$CODEX_MARKETPLACE\"*) CODEX_MARKETPLACE_PRESENT=1 ;;
  esac
  case $compact_plugins in
    *\"pluginId\":\"$CODEX_PLUGIN\"*\"installed\":true*) CODEX_PLUGIN_PRESENT=1 ;;
  esac
  if [ "$CODEX_MARKETPLACE_PRESENT" -eq 1 ] && [ "$CODEX_PLUGIN_PRESENT" -eq 0 ]; then
    CODEX_REPLACEMENT_REQUIRED=1
  fi
}

print_plan() {
  printf '\nValency installation plan\n'
  if [ "$CLAUDE_SELECTED" -eq 1 ]; then
    if [ "$CLAUDE_PLUGIN_PRESENT" -eq 1 ]; then
      printf '  Claude Code: refresh marketplace, update %s, and verify it is enabled.\n' "$CLAUDE_PLUGIN"
    else
      printf '  Claude Code: add the %s marketplace, install %s at user scope, and verify it is enabled.\n' "$MARKETPLACE_SOURCE" "$CLAUDE_PLUGIN"
    fi
    if [ "$CLAUDE_LEGACY_PLUGIN_PRESENT" -eq 1 ] || [ "$CLAUDE_LEGACY_MARKETPLACE_PRESENT" -eq 1 ]; then
      printf '    Conditional migration: after verification, remove valency@valency-plugin and the valency-plugin marketplace.\n'
    fi
  fi
  if [ "$CODEX_SELECTED" -eq 1 ]; then
    if [ "$CODEX_PLUGIN_PRESENT" -eq 1 ]; then
      printf '  Codex: refresh the %s marketplace, reinstall %s, and verify it is enabled.\n' "$CODEX_MARKETPLACE" "$CODEX_PLUGIN"
    else
      printf '  Codex: add the %s marketplace, install %s, and verify it is enabled.\n' "$MARKETPLACE_SOURCE" "$CODEX_PLUGIN"
    fi
    if [ "$CODEX_REPLACEMENT_REQUIRED" -eq 1 ]; then
      printf '    Conditional replacement: remove the existing marketplace named valency, add %s, then install and verify %s.\n' "$MARKETPLACE_SOURCE" "$CODEX_PLUGIN"
      printf '    The existing marketplace source will not be inspected and cannot be restored automatically.\n'
    fi
  fi
  if [ "$AUTH_MODE" = "no" ]; then
    printf '  Authentication: skipped; manual login commands will be shown.\n'
  else
    printf '  Authentication: offered after verified installation.\n'
    if [ "$CLAUDE_SELECTED" -eq 1 ]; then printf '    Claude Code status: %s.\n' "$CLAUDE_AUTH_STATE"; fi
    if [ "$CODEX_SELECTED" -eq 1 ]; then printf '    Codex status: %s.\n' "$CODEX_AUTH_STATE"; fi
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  Mode: dry run; no provider state will change.\n'
  fi
}

read_yes_no() {
  prompt=$1
  default_yes=$2
  printf '%s' "$prompt"
  answer=""
  IFS= read -r answer <&3 || return 1
  case $answer in
    y|Y|yes|YES|Yes) return 0 ;;
    n|N|no|NO|No) return 1 ;;
    '') [ "$default_yes" -eq 1 ] && return 0 || return 1 ;;
  esac
  return 1
}

authorize_migrations() {
  if [ "$CLAUDE_SELECTED" -eq 1 ] &&
    { [ "$CLAUDE_LEGACY_PLUGIN_PRESENT" -eq 1 ] || [ "$CLAUDE_LEGACY_MARKETPLACE_PRESENT" -eq 1 ]; }; then
    if [ "$ALLOW_MIGRATION" -eq 0 ]; then
      if [ "$TERMINAL_AVAILABLE" -eq 0 ]; then
        printf 'Error: Claude Code legacy cleanup requires --migrate for unattended installation.\n' >&2
        return 2
      fi
      if ! read_yes_no 'Allow the disclosed Claude Code legacy cleanup? [y/N] ' 0; then
        CLAUDE_SELECTED=0
        CLAUDE_INSTALL_RESULT="skipped (migration declined)"
        printf 'Claude Code skipped; legacy configuration was left unchanged.\n'
      fi
    fi
  fi
  if [ "$CODEX_SELECTED" -eq 1 ] && [ "$CODEX_REPLACEMENT_REQUIRED" -eq 1 ]; then
    if [ "$ALLOW_MIGRATION" -eq 0 ]; then
      if [ "$TERMINAL_AVAILABLE" -eq 0 ]; then
        printf 'Error: replacing the existing Codex marketplace named valency requires --migrate for unattended installation.\n' >&2
        return 2
      fi
      if ! read_yes_no 'Allow the disclosed Codex marketplace replacement? [y/N] ' 0; then
        CODEX_SELECTED=0
        CODEX_INSTALL_RESULT="skipped (replacement declined)"
        printf 'Codex skipped; the existing marketplace named valency was left unchanged.\n'
      fi
    fi
  fi
}

validate_migration_preflights() {
  if [ "$CODEX_SELECTED" -eq 1 ] && [ "$CODEX_REPLACEMENT_REQUIRED" -eq 1 ]; then
    if ! command -v curl >/dev/null 2>&1; then
      printf 'Error: Codex replacement preflight requires curl to verify the public marketplace repository.\n' >&2
      return 1
    fi
    if ! curl -fsSIL --max-time 10 "https://github.com/$MARKETPLACE_SOURCE" >/dev/null 2>&1; then
      printf 'Error: cannot publicly reach https://github.com/%s; the existing Codex marketplace was not changed.\n' "$MARKETPLACE_SOURCE" >&2
      return 1
    fi
  fi
}

confirm_plan() {
  if [ "$ASSUME_YES" -eq 1 ]; then
    return 0
  fi
  if read_yes_no 'Continue? [Y/n] ' 1; then
    return 0
  fi
  printf 'Installation cancelled.\n'
  return 1
}

run_quietly() {
  "$@" >/dev/null 2>&1
}

verify_claude_plugin() {
  plugin_json=$(claude plugin list --json 2>/dev/null) || return 1
  compact_plugins=$(printf '%s' "$plugin_json" | compact_json)
  case $compact_plugins in
    *\"id\":\"$CLAUDE_PLUGIN\"*\"enabled\":true*) return 0 ;;
  esac
  return 1
}

install_claude() {
  if [ "$DRY_RUN" -eq 1 ]; then
    CLAUDE_INSTALL_RESULT="planned"
    return 0
  fi

  if [ "$CLAUDE_PLUGIN_PRESENT" -eq 1 ]; then
    # Claude's manifest version is authoritative. The native updater decides
    # whether content changed; this installer never force-reinstalls around it.
    if ! run_quietly claude plugin marketplace update "$CLAUDE_MARKETPLACE"; then
      CLAUDE_INSTALL_RESULT="failed"
      return 1
    fi
    if ! run_quietly claude plugin update "$CLAUDE_PLUGIN" --scope user; then
      CLAUDE_INSTALL_RESULT="failed"
      return 1
    fi
    success_result="updated"
  else
    if [ "$CLAUDE_MARKETPLACE_PRESENT" -eq 0 ]; then
      if ! run_quietly claude plugin marketplace add "$MARKETPLACE_SOURCE" --scope user; then
        CLAUDE_INSTALL_RESULT="failed"
        return 1
      fi
    else
      if ! run_quietly claude plugin marketplace update "$CLAUDE_MARKETPLACE"; then
        CLAUDE_INSTALL_RESULT="failed"
        return 1
      fi
    fi
    if ! run_quietly claude plugin install "$CLAUDE_PLUGIN" --scope user; then
      CLAUDE_INSTALL_RESULT="failed"
      return 1
    fi
    success_result="installed"
  fi

  if ! verify_claude_plugin; then
    CLAUDE_INSTALL_RESULT="failed verification"
    return 1
  fi

  # Migration is deliberately ordered after exact identity verification. A
  # failed new install therefore never destroys the working legacy plugin.
  if [ "$CLAUDE_LEGACY_PLUGIN_PRESENT" -eq 1 ]; then
    if ! run_quietly claude plugin uninstall valency@valency-plugin --scope user; then
      CLAUDE_INSTALL_RESULT="failed legacy cleanup (new plugin verified)"
      printf 'Claude Code legacy plugin removal failed. Retry: claude plugin uninstall valency@valency-plugin --scope user\n' >&2
      return 1
    fi
  fi
  if [ "$CLAUDE_LEGACY_MARKETPLACE_PRESENT" -eq 1 ]; then
    if ! run_quietly claude plugin marketplace remove valency-plugin --scope user; then
      CLAUDE_INSTALL_RESULT="failed legacy cleanup (new plugin verified)"
      printf 'Claude Code legacy marketplace removal failed. Retry: claude plugin marketplace remove valency-plugin --scope user\n' >&2
      return 1
    fi
  fi
  CLAUDE_INSTALL_RESULT=$success_result
}

verify_codex_plugin() {
  plugin_json=$(codex plugin list --json 2>/dev/null) || return 1
  compact_plugins=$(printf '%s' "$plugin_json" | compact_json)
  case $compact_plugins in
    *\"pluginId\":\"$CODEX_PLUGIN\"*\"installed\":true*\"enabled\":true*) return 0 ;;
  esac
  return 1
}

install_codex() {
  if [ "$DRY_RUN" -eq 1 ]; then
    CODEX_INSTALL_RESULT="planned"
    return 0
  fi

  codex_replacement_started=0
  if [ "$CODEX_PLUGIN_PRESENT" -eq 1 ]; then
    if ! run_quietly codex plugin marketplace upgrade "$CODEX_MARKETPLACE"; then
      CODEX_INSTALL_RESULT="failed"
      return 1
    fi
    success_result="updated"
  elif [ "$CODEX_REPLACEMENT_REQUIRED" -eq 1 ]; then
    # Codex identifies marketplaces by name. We intentionally do not inspect or
    # retain the previous source, so replacement is disclosed and preflighted;
    # failure guidance can retry Valency but cannot promise automatic rollback.
    if ! run_quietly codex plugin marketplace remove "$CODEX_MARKETPLACE"; then
      CODEX_INSTALL_RESULT="failed marketplace replacement"
      printf 'Codex could not remove the existing marketplace named valency; it was left in place.\n' >&2
      return 1
    fi
    codex_replacement_started=1
    if ! run_quietly codex plugin marketplace add "$MARKETPLACE_SOURCE"; then
      CODEX_INSTALL_RESULT="failed marketplace replacement"
      print_codex_recovery
      return 1
    fi
    success_result="installed (marketplace replaced)"
  else
    if [ "$CODEX_MARKETPLACE_PRESENT" -eq 0 ]; then
      if ! run_quietly codex plugin marketplace add "$MARKETPLACE_SOURCE"; then
        CODEX_INSTALL_RESULT="failed"
        return 1
      fi
    fi
    success_result="installed"
  fi

  if ! run_quietly codex plugin add "$CODEX_PLUGIN"; then
    if [ "$codex_replacement_started" -eq 1 ]; then
      CODEX_INSTALL_RESULT="failed marketplace replacement"
      print_codex_recovery
    else
      CODEX_INSTALL_RESULT="failed"
    fi
    return 1
  fi
  if ! verify_codex_plugin; then
    if [ "$codex_replacement_started" -eq 1 ]; then
      CODEX_INSTALL_RESULT="failed marketplace replacement"
      print_codex_recovery
    else
      CODEX_INSTALL_RESULT="failed verification"
    fi
    return 1
  fi
  CODEX_INSTALL_RESULT=$success_result
}

print_codex_recovery() {
  printf 'Codex marketplace replacement did not complete. The previous source was intentionally not inspected and cannot be restored automatically.\n' >&2
  printf 'Retry these commands after the repository is reachable:\n' >&2
  printf '  codex plugin marketplace remove valency\n' >&2
  printf '  codex plugin marketplace add valency-oss/valency-bond\n' >&2
  printf '  codex plugin add valency@valency\n' >&2
}

install_selected_providers() {
  # Provider failures are isolated: a broken Claude install must not prevent a
  # selected Codex install (or vice versa), and verified work is never rolled back.
  install_failures=0
  if [ "$CLAUDE_SELECTED" -eq 1 ]; then
    install_claude || install_failures=$((install_failures + 1))
  fi
  if [ "$CODEX_SELECTED" -eq 1 ]; then
    install_codex || install_failures=$((install_failures + 1))
  fi
  return "$install_failures"
}

installation_succeeded() {
  case $1 in
    installed*|updated*|planned) return 0 ;;
  esac
  return 1
}

prepare_authentication() {
  if [ "$CLAUDE_SELECTED" -eq 1 ] && installation_succeeded "$CLAUDE_INSTALL_RESULT"; then
    prepare_provider_auth claude "$CLAUDE_AUTH_STATE"
  fi
  if [ "$CODEX_SELECTED" -eq 1 ] && installation_succeeded "$CODEX_INSTALL_RESULT"; then
    prepare_provider_auth codex "$CODEX_AUTH_STATE"
  fi

  if [ "$AUTH_MODE" = "prompt" ] &&
    { [ "$CLAUDE_AUTH_SELECTED" -eq 1 ] || [ "$CODEX_AUTH_SELECTED" -eq 1 ]; }; then
    prompt_for_authentication_selection
  fi
}

prepare_provider_auth() {
  provider=$1
  state=$2
  if [ "$AUTH_MODE" = "no" ]; then
    set_auth_result "$provider" "skipped"
    return
  fi
  if [ "$state" = "unavailable" ]; then
    set_auth_result "$provider" "unavailable"
    return
  fi
  if [ "$state" = "connected" ] && [ "$REAUTHENTICATE" -eq 0 ]; then
    set_auth_result "$provider" "already connected"
    return
  fi
  if [ "$provider" = claude ]; then CLAUDE_AUTH_SELECTED=1; else CODEX_AUTH_SELECTED=1; fi
}

set_auth_result() {
  if [ "$1" = claude ]; then CLAUDE_AUTH_RESULT=$2; else CODEX_AUTH_RESULT=$2; fi
}

prompt_for_authentication_selection() {
  printf '\nOptional authentication\n'
  printf 'Providers with missing or unknown status are selected by default.\n'
  auth_option=0
  CLAUDE_AUTH_OPTION=0
  CODEX_AUTH_OPTION=0
  if [ "$CLAUDE_SELECTED" -eq 1 ] && installation_succeeded "$CLAUDE_INSTALL_RESULT" && [ "$CLAUDE_AUTH_STATE" != "unavailable" ]; then
    auth_option=$((auth_option + 1))
    CLAUDE_AUTH_OPTION=$auth_option
    if [ "$CLAUDE_AUTH_SELECTED" -eq 1 ]; then mark=x; else mark=' '; fi
    printf '  [%s] %s) Claude Code (%s)\n' "$mark" "$CLAUDE_AUTH_OPTION" "$CLAUDE_AUTH_STATE"
  fi
  if [ "$CODEX_SELECTED" -eq 1 ] && installation_succeeded "$CODEX_INSTALL_RESULT" && [ "$CODEX_AUTH_STATE" != "unavailable" ]; then
    auth_option=$((auth_option + 1))
    CODEX_AUTH_OPTION=$auth_option
    if [ "$CODEX_AUTH_SELECTED" -eq 1 ]; then mark=x; else mark=' '; fi
    printf '  [%s] %s) Codex (%s)\n' "$mark" "$CODEX_AUTH_OPTION" "$CODEX_AUTH_STATE"
  fi
  printf 'Enter numbers to toggle, Enter to keep defaults, or q to skip: '
  selection=""
  IFS= read -r selection <&3 || selection=q
  case $selection in
    '') return ;;
    q|Q|quit|skip)
      CLAUDE_AUTH_SELECTED=0
      CODEX_AUTH_SELECTED=0
      return
      ;;
  esac
  normalized=${selection//,/ }
  for item in $normalized; do
    if [ "$item" = "$CLAUDE_AUTH_OPTION" ] && [ "$CLAUDE_AUTH_OPTION" -gt 0 ]; then
      if [ "$CLAUDE_AUTH_SELECTED" -eq 1 ]; then CLAUDE_AUTH_SELECTED=0; else CLAUDE_AUTH_SELECTED=1; fi
    elif [ "$item" = "$CODEX_AUTH_OPTION" ] && [ "$CODEX_AUTH_OPTION" -gt 0 ]; then
      if [ "$CODEX_AUTH_SELECTED" -eq 1 ]; then CODEX_AUTH_SELECTED=0; else CODEX_AUTH_SELECTED=1; fi
    else
      printf 'Ignoring invalid authentication selection: %s\n' "$item" >&2
    fi
  done
}

run_authentication() {
  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$CLAUDE_AUTH_SELECTED" -eq 1 ]; then CLAUDE_AUTH_RESULT="planned"; fi
    if [ "$CODEX_AUTH_SELECTED" -eq 1 ]; then CODEX_AUTH_RESULT="planned"; fi
    finalize_unselected_auth_results
    return
  fi

  if [ "$CLAUDE_AUTH_SELECTED" -eq 1 ]; then
    if claude mcp login plugin:valency:valency <&3 >/dev/null 2>&1; then
      CLAUDE_AUTH_RESULT="authenticated"
    else
      CLAUDE_AUTH_RESULT="failed (plugin remains installed)"
      printf 'Warning: Claude Code authentication did not complete; the verified plugin remains installed.\n' >&2
    fi
  fi
  if [ "$CODEX_AUTH_SELECTED" -eq 1 ]; then
    if codex mcp login valency <&3 >/dev/null 2>&1; then
      CODEX_AUTH_RESULT="authenticated"
    else
      CODEX_AUTH_RESULT="failed (plugin remains installed)"
      printf 'Warning: Codex authentication did not complete; the verified plugin remains installed.\n' >&2
    fi
  fi
  finalize_unselected_auth_results
}

finalize_unselected_auth_results() {
  if [ "$CLAUDE_SELECTED" -eq 1 ] && installation_succeeded "$CLAUDE_INSTALL_RESULT" && [ "$CLAUDE_AUTH_RESULT" = "not offered" ]; then
    CLAUDE_AUTH_RESULT="skipped"
  fi
  if [ "$CODEX_SELECTED" -eq 1 ] && installation_succeeded "$CODEX_INSTALL_RESULT" && [ "$CODEX_AUTH_RESULT" = "not offered" ]; then
    CODEX_AUTH_RESULT="skipped"
  fi
}

print_summary() {
  printf '\nSummary\n'
  if [ "$CLAUDE_SELECTED" -eq 1 ] || [ "$CLAUDE_INSTALL_RESULT" != "not selected" ]; then
    printf '  Claude Code installation: %s\n' "$CLAUDE_INSTALL_RESULT"
    printf '  Claude Code authentication: %s\n' "$CLAUDE_AUTH_RESULT"
    if installation_succeeded "$CLAUDE_INSTALL_RESULT" && [ "$CLAUDE_AUTH_RESULT" != "authenticated" ] && [ "$CLAUDE_AUTH_RESULT" != "already connected" ]; then
      printf '  Manual Claude login: claude mcp login plugin:valency:valency\n'
    fi
  fi
  if [ "$CODEX_SELECTED" -eq 1 ] || [ "$CODEX_INSTALL_RESULT" != "not selected" ]; then
    printf '  Codex installation: %s\n' "$CODEX_INSTALL_RESULT"
    printf '  Codex authentication: %s\n' "$CODEX_AUTH_RESULT"
    if installation_succeeded "$CODEX_INSTALL_RESULT" && [ "$CODEX_AUTH_RESULT" != "authenticated" ] && [ "$CODEX_AUTH_RESULT" != "already connected" ]; then
      printf '  Manual Codex login: codex mcp login valency\n'
    fi
  fi
}

main() {
  parse_arguments "$@"
  parse_status=$?
  if [ "$parse_status" -eq 64 ]; then
    return 0
  fi
  if [ "$parse_status" -ne 0 ]; then
    return "$parse_status"
  fi

  initialize_terminal
  detect_provider_executables
  if [ "$CLAUDE_AVAILABLE" -eq 0 ] && [ "$CODEX_AVAILABLE" -eq 0 ]; then
    printf 'No supported provider CLIs were found on PATH (expected claude or codex).\n' >&2
    return 1
  fi

  select_requested_targets || return $?
  inspect_provider_state || return 1
  inspect_auth_states
  print_plan
  authorize_migrations || return $?
  if [ "$CLAUDE_SELECTED" -eq 0 ] && [ "$CODEX_SELECTED" -eq 0 ]; then
    print_summary
    return 0
  fi
  validate_migration_preflights || return 1
  confirm_plan || return 1

  if install_selected_providers; then
    install_status=0
  else
    install_status=$?
  fi
  prepare_authentication
  run_authentication
  print_summary
  if [ "$install_status" -ne 0 ]; then
    return 1
  fi
}

# Keeping executable work behind the final main call makes a partial download
# inert: a truncated script can define helpers, but cannot mutate provider state.
main "$@"
