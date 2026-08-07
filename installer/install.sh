#!/usr/bin/env bash

# Provider state is read and written through controlled Bash-3.2-compatible
# accessors. ShellCheck cannot follow the dynamic variable names.
# shellcheck disable=SC2034

set -u

MARKETPLACE_SOURCE="valency-oss/valency-bond"
CLAUDE_MARKETPLACE="valency-claude-plugin"
CLAUDE_PLUGIN="valency@valency-claude-plugin"
CODEX_MARKETPLACE="valency"
CODEX_PLUGIN="valency@valency"

TARGETS_SPECIFIED=0
TARGET_CLAUDE=0
TARGET_CODEX=0
TARGET_ANTIGRAVITY=0
TARGET_GEMINI=0
TARGET_COPILOT=0
TARGET_GROK=0
TARGET_ALL=0
ASSUME_YES=0
ALLOW_MIGRATION=0
AUTH_MODE="prompt"
REAUTHENTICATE=0
DRY_RUN=0
TERMINAL_AVAILABLE=0

PREINSTALL_FAILURES=0
CLAUDE_EXECUTABLE_FOUND=0
CODEX_EXECUTABLE_FOUND=0
CLAUDE_AVAILABLE=0
CODEX_AVAILABLE=0
CLAUDE_SELECTED=0
CODEX_SELECTED=0
CLAUDE_MARKETPLACE_PRESENT=0
CLAUDE_MARKETPLACE_CONFLICT=0
CLAUDE_PLUGIN_PRESENT=0
CLAUDE_LEGACY_MARKETPLACE_PRESENT=0
CLAUDE_LEGACY_MARKETPLACE_FOREIGN=0
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
ANTIGRAVITY_EXECUTABLE_FOUND=0
ANTIGRAVITY_AVAILABLE=0
ANTIGRAVITY_SELECTED=0
ANTIGRAVITY_PLUGIN_PRESENT=0
ANTIGRAVITY_INSTALL_RESULT="not selected"
ANTIGRAVITY_AUTH_RESULT="not offered"
ANTIGRAVITY_AUTH_AVAILABLE=0
ANTIGRAVITY_AUTH_STATE="in-host"
ANTIGRAVITY_AUTH_SELECTED=0
GEMINI_EXECUTABLE_FOUND=0
GEMINI_AVAILABLE=0
GEMINI_SELECTED=0
GEMINI_EXTENSION_PRESENT=0
GEMINI_EXTENSION_CONFLICT=0
GEMINI_INSTALL_RESULT="not selected"
GEMINI_AUTH_RESULT="not offered"
GEMINI_AUTH_AVAILABLE=0
GEMINI_AUTH_STATE="in-host"
GEMINI_AUTH_SELECTED=0
COPILOT_EXECUTABLE_FOUND=0
COPILOT_AVAILABLE=0
COPILOT_SELECTED=0
COPILOT_MARKETPLACE_PRESENT=0
COPILOT_MARKETPLACE_CONFLICT=0
COPILOT_PLUGIN_PRESENT=0
COPILOT_PLUGIN_ENABLED=0
COPILOT_INSTALL_RESULT="not selected"
COPILOT_AUTH_RESULT="not offered"
COPILOT_AUTH_AVAILABLE=0
COPILOT_AUTH_STATE="in-host"
COPILOT_AUTH_SELECTED=0
GROK_EXECUTABLE_FOUND=0
GROK_AVAILABLE=0
GROK_SELECTED=0
GROK_MARKETPLACE_PRESENT=0
GROK_MARKETPLACE_CONFLICT=0
GROK_PLUGIN_PRESENT=0
GROK_PLUGIN_CONFLICT=0
GROK_INSTALL_RESULT="not selected"
GROK_AUTH_RESULT="not offered"
GROK_AUTH_AVAILABLE=0
GROK_AUTH_STATE="in-host"
GROK_AUTH_SELECTED=0

# Provider order is user-visible in the checklist, plan, execution, and
# summary. Indexed arrays are supported by Bash 3.2; provider-specific state
# remains named so each adapter is easy to inspect in this single-file script.
PROVIDER_IDS=(claude codex antigravity gemini copilot grok)

# The interactive checklist is deliberately generic so harness installation
# and optional authentication share one keyboard model. Parallel indexed
# arrays keep it compatible with the Bash 3.2 shipped by macOS.
MENU_IDS=()
MENU_LABELS=()
MENU_SELECTED=()
MENU_CURSOR=0
MENU_TITLE=""
MENU_ALL_LABEL=""
MENU_RESULT_LABEL=""
MENU_PLAIN_ACTION=""
MENU_PLAIN_HELP=""
MENU_ALLOW_EMPTY=0
MENU_RENDERED_LINES=0
MENU_MESSAGE=""
MENU_KEY=""
MENU_SIGNAL_STATUS=0

load_provider_metadata() {
  case $1 in
    claude)
      PROVIDER_LABEL="Claude Code"
      PROVIDER_EXECUTABLE=claude
      PROVIDER_COMPONENT=plugin
      PROVIDER_AUTH_METHOD=standalone
      ;;
    codex)
      PROVIDER_LABEL="Codex"
      PROVIDER_EXECUTABLE=codex
      PROVIDER_COMPONENT=plugin
      PROVIDER_AUTH_METHOD=standalone
      ;;
    antigravity)
      PROVIDER_LABEL="Antigravity CLI"
      PROVIDER_EXECUTABLE=agy
      PROVIDER_COMPONENT=plugin
      PROVIDER_AUTH_METHOD=in-host
      ;;
    gemini)
      PROVIDER_LABEL="Gemini CLI"
      PROVIDER_EXECUTABLE=gemini
      PROVIDER_COMPONENT=extension
      PROVIDER_AUTH_METHOD=in-host
      ;;
    copilot)
      PROVIDER_LABEL="GitHub Copilot CLI"
      PROVIDER_EXECUTABLE=copilot
      PROVIDER_COMPONENT=plugin
      PROVIDER_AUTH_METHOD=in-host
      ;;
    grok)
      PROVIDER_LABEL="Grok Build"
      PROVIDER_EXECUTABLE=grok
      PROVIDER_COMPONENT=plugin
      PROVIDER_AUTH_METHOD=in-host
      ;;
    *) return 1 ;;
  esac
}

load_provider_prefix() {
  case $1 in
    claude) PROVIDER_PREFIX=CLAUDE ;;
    codex) PROVIDER_PREFIX=CODEX ;;
    antigravity) PROVIDER_PREFIX=ANTIGRAVITY ;;
    gemini) PROVIDER_PREFIX=GEMINI ;;
    copilot) PROVIDER_PREFIX=COPILOT ;;
    grok) PROVIDER_PREFIX=GROK ;;
    *) return 1 ;;
  esac
}

read_provider_state() {
  load_provider_prefix "$1" || return 1
  case $2 in
    EXECUTABLE_FOUND|AVAILABLE|SELECTED|INSTALL_RESULT|AUTH_AVAILABLE|AUTH_STATE|AUTH_SELECTED|AUTH_RESULT) ;;
    *) return 1 ;;
  esac
  eval "PROVIDER_STATE_VALUE=\${${PROVIDER_PREFIX}_$2}"
}

write_provider_state() {
  load_provider_prefix "$1" || return 1
  case $2 in
    EXECUTABLE_FOUND|AVAILABLE|SELECTED|INSTALL_RESULT|AUTH_AVAILABLE|AUTH_STATE|AUTH_SELECTED|AUTH_RESULT) ;;
    *) return 1 ;;
  esac
  printf -v "${PROVIDER_PREFIX}_$2" '%s' "$3"
}

read_provider_target() {
  case $1 in
    claude) PROVIDER_STATE_VALUE=$TARGET_CLAUDE ;;
    codex) PROVIDER_STATE_VALUE=$TARGET_CODEX ;;
    antigravity) PROVIDER_STATE_VALUE=$TARGET_ANTIGRAVITY ;;
    gemini) PROVIDER_STATE_VALUE=$TARGET_GEMINI ;;
    copilot) PROVIDER_STATE_VALUE=$TARGET_COPILOT ;;
    grok) PROVIDER_STATE_VALUE=$TARGET_GROK ;;
    *) return 1 ;;
  esac
}

print_help() {
  cat <<'EOF'
Valency plugin installer

Usage:
  install.sh [options]

Options:
  --target claude|codex|antigravity|gemini|copilot|grok|all
                             Select a provider; may be repeated.
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
    antigravity) TARGET_ANTIGRAVITY=1 ;;
    gemini) TARGET_GEMINI=1 ;;
    copilot) TARGET_COPILOT=1 ;;
    grok) TARGET_GROK=1 ;;
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
  # controlling terminal instead. The override is restricted to the test
  # harness so production confirmations cannot be redirected by environment.
  if [ "${VALENCY_INSTALLER_TEST_MODE-}" = "1" ] &&
    [ -n "${MOCK_STATE-}" ] && [ -n "${VALENCY_INSTALLER_TTY-}" ]; then
    if [ -r "$VALENCY_INSTALLER_TTY" ] && exec 3<"$VALENCY_INSTALLER_TTY" && exec 4>&1; then
      TERMINAL_AVAILABLE=1
    fi
    return
  fi

  if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    if exec 3<>/dev/tty 2>/dev/null && exec 4>&3; then
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

antigravity_has_required_commands() {
  # Antigravity's plugin subcommands do not accept --help individually. Its
  # side-effect-free `plugin help` output is therefore the capability probe.
  plugin_help=$(agy plugin help 2>/dev/null) || return 1
  case $plugin_help in
    *"list"*) ;;
    *) return 1 ;;
  esac
  case $plugin_help in
    *"install <target>"*) return 0 ;;
  esac
  return 1
}

gemini_has_required_commands() {
  gemini extensions install --help >/dev/null 2>&1 &&
    gemini extensions list --help >/dev/null 2>&1 &&
    gemini extensions update --help >/dev/null 2>&1 &&
    gemini extensions enable --help >/dev/null 2>&1
}

copilot_has_required_commands() {
  copilot plugin marketplace add --help >/dev/null 2>&1 &&
    copilot plugin marketplace list --help >/dev/null 2>&1 &&
    copilot plugin marketplace update --help >/dev/null 2>&1 &&
    copilot plugin install --help >/dev/null 2>&1 &&
    copilot plugin update --help >/dev/null 2>&1 &&
    copilot plugin list --help >/dev/null 2>&1
}

grok_has_required_commands() {
  grok plugin marketplace add --help >/dev/null 2>&1 &&
    grok plugin marketplace list --help >/dev/null 2>&1 &&
    grok plugin marketplace update --help >/dev/null 2>&1 &&
    grok plugin install --help >/dev/null 2>&1 &&
    grok plugin update --help >/dev/null 2>&1 &&
    grok plugin list --help >/dev/null 2>&1
}

provider_has_required_commands() {
  case $1 in
    claude) claude_has_required_commands ;;
    codex) codex_has_required_commands ;;
    antigravity) antigravity_has_required_commands ;;
    gemini) gemini_has_required_commands ;;
    copilot) copilot_has_required_commands ;;
    grok) grok_has_required_commands ;;
    *) return 1 ;;
  esac
}

provider_has_auth_commands() {
  case $1 in
    claude) claude_has_auth_commands ;;
    codex) codex_has_auth_commands ;;
    *) return 1 ;;
  esac
}

detect_provider_executables() {
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    load_provider_metadata "$provider"
    if command -v "$PROVIDER_EXECUTABLE" >/dev/null 2>&1; then
      write_provider_state "$provider" EXECUTABLE_FOUND 1
      if provider_has_required_commands "$provider"; then
        write_provider_state "$provider" AVAILABLE 1
        if provider_has_auth_commands "$provider"; then
          write_provider_state "$provider" AUTH_AVAILABLE 1
        fi
      fi
    fi
    provider_index=$((provider_index + 1))
  done
}

report_unsupported_provider() {
  provider=$1
  target_all=$2
  load_provider_metadata "$provider"
  if [ "$target_all" -eq 1 ]; then
    printf 'Error: %s is installed but lacks required %s commands; upgrade it or drop it from --target.\n' "$PROVIDER_LABEL" "$PROVIDER_COMPONENT" >&2
  else
    printf 'Error: %s is installed but lacks required %s commands; upgrade it.\n' "$PROVIDER_LABEL" "$PROVIDER_COMPONENT" >&2
  fi
  write_provider_state "$provider" INSTALL_RESULT "failed (unsupported CLI)"
  PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
}

report_missing_provider() {
  provider=$1
  load_provider_metadata "$provider"
  case $provider in
    claude|codex|gemini)
      printf 'Error: %s was requested but its CLI is not on PATH.\n' "$PROVIDER_LABEL" >&2
      ;;
    *)
      printf 'Error: %s was requested but %s is not on PATH.\n' "$PROVIDER_LABEL" "$PROVIDER_EXECUTABLE" >&2
      ;;
  esac
  write_provider_state "$provider" INSTALL_RESULT "failed (not installed)"
  PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
}

select_requested_targets() {
  if [ "$TARGETS_SPECIFIED" -eq 0 ]; then
    if [ "$TERMINAL_AVAILABLE" -eq 0 ]; then
      printf 'Error: without a terminal, --target is required.\n' >&2
      return 2
    fi
    interactive_select_targets || return $?
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

  # Every provider follows the same selection contract. Failures are recorded
  # per provider so one missing or outdated CLI never blocks another target.
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    read_provider_target "$provider"
    provider_requested=$PROVIDER_STATE_VALUE
    if [ "$TARGET_ALL" -eq 1 ]; then provider_requested=1; fi
    if [ "$provider_requested" -eq 1 ]; then
      read_provider_state "$provider" AVAILABLE
      provider_available=$PROVIDER_STATE_VALUE
      if [ "$provider_available" -eq 1 ]; then
        write_provider_state "$provider" SELECTED 1
      else
        read_provider_state "$provider" EXECUTABLE_FOUND
        if [ "$PROVIDER_STATE_VALUE" -eq 1 ]; then
          report_unsupported_provider "$provider" "$TARGET_ALL"
        elif [ "$TARGET_ALL" -eq 0 ]; then
          report_missing_provider "$provider"
        fi
      fi
    fi
    provider_index=$((provider_index + 1))
  done
}

reset_menu() {
  MENU_IDS=()
  MENU_LABELS=()
  MENU_SELECTED=()
  MENU_CURSOR=0
  MENU_TITLE=$1
  MENU_ALL_LABEL=$2
  MENU_RESULT_LABEL=$3
  MENU_ALLOW_EMPTY=$4
  MENU_PLAIN_ACTION=$5
  MENU_PLAIN_HELP=$6
  MENU_RENDERED_LINES=0
  MENU_MESSAGE=""
  MENU_KEY=""
  MENU_SIGNAL_STATUS=0
}

add_menu_item() {
  menu_index=${#MENU_IDS[@]}
  MENU_IDS[menu_index]=$1
  MENU_LABELS[menu_index]=$2
  MENU_SELECTED[menu_index]=$3
}

calculate_menu_state() {
  MENU_ITEM_COUNT=${#MENU_IDS[@]}
  MENU_SELECTED_COUNT=0
  MENU_SELECTION_SUMMARY=""
  menu_index=0
  while [ "$menu_index" -lt "$MENU_ITEM_COUNT" ]; do
    if [ "${MENU_SELECTED[$menu_index]}" -eq 1 ]; then
      MENU_SELECTED_COUNT=$((MENU_SELECTED_COUNT + 1))
      if [ -n "$MENU_SELECTION_SUMMARY" ]; then
        MENU_SELECTION_SUMMARY="$MENU_SELECTION_SUMMARY, ${MENU_LABELS[$menu_index]}"
      else
        MENU_SELECTION_SUMMARY=${MENU_LABELS[$menu_index]}
      fi
    fi
    menu_index=$((menu_index + 1))
  done

  if [ "$MENU_SELECTED_COUNT" -eq 0 ]; then
    MENU_ALL_STATE="none"
    MENU_SELECTION_SUMMARY="none"
  elif [ "$MENU_SELECTED_COUNT" -eq "$MENU_ITEM_COUNT" ]; then
    MENU_ALL_STATE="all"
  else
    MENU_ALL_STATE="partial"
  fi
}

menu_marker() {
  case $1 in
    all|selected) MENU_MARKER=x ;;
    partial) MENU_MARKER=- ;;
    *) MENU_MARKER=' ' ;;
  esac
}

render_menu_row() {
  menu_row=$1
  menu_state=$2
  menu_label=$3
  if [ "$MENU_CURSOR" -eq "$menu_row" ]; then
    menu_pointer='>'
  else
    menu_pointer=' '
  fi
  menu_marker "$menu_state"
  printf '  %s [%s] %s\n' "$menu_pointer" "$MENU_MARKER" "$menu_label" >&4
}

clear_rendered_menu() {
  if [ "$MENU_RENDERED_LINES" -gt 0 ]; then
    # Redraw only the checklist region. Normal installer logs remain durable in
    # the transcript instead of using a full-screen alternate terminal buffer.
    printf '\033[%dA\r\033[J' "$MENU_RENDERED_LINES" >&4
  fi
}

render_menu() {
  calculate_menu_state
  clear_rendered_menu
  printf '%s\n' "$MENU_TITLE" >&4
  printf '  up/down move  space toggle  enter continue  esc cancel\n' >&4
  printf '\n' >&4
  render_menu_row 0 "$MENU_ALL_STATE" "$MENU_ALL_LABEL"

  menu_index=0
  while [ "$menu_index" -lt "$MENU_ITEM_COUNT" ]; do
    if [ "${MENU_SELECTED[$menu_index]}" -eq 1 ]; then
      menu_item_state=selected
    else
      menu_item_state=none
    fi
    render_menu_row $((menu_index + 1)) "$menu_item_state" "${MENU_LABELS[$menu_index]}"
    menu_index=$((menu_index + 1))
  done

  printf '\n' >&4
  if [ -n "$MENU_MESSAGE" ]; then
    printf '  %s\n' "$MENU_MESSAGE" >&4
  else
    printf '  Selected: %s\n' "$MENU_SELECTION_SUMMARY" >&4
  fi
  MENU_RENDERED_LINES=$((MENU_ITEM_COUNT + 6))
}

read_menu_key() {
  MENU_KEY=""
  menu_character=""
  if ! IFS= read -r -s -n 1 menu_character <&3; then
    return 1
  fi

  case $menu_character in
    '') MENU_KEY=enter ;;
    ' ') MENU_KEY=toggle ;;
    j|J) MENU_KEY=down ;;
    k|K) MENU_KEY=up ;;
    a|A) MENU_KEY=all ;;
    q|Q) MENU_KEY=cancel ;;
    $'\t') MENU_KEY=toggle ;;
    $'\003') MENU_KEY=interrupt ;;
    $'\033')
      # Bash 3.2 accepts only whole seconds for read -t. Arrow-key bytes are
      # already buffered and return immediately; only a standalone Escape
      # waits for this compatibility timeout before being treated as cancel.
      menu_escape_timeout=0.1
      if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then menu_escape_timeout=1; fi
      menu_escape_part=""
      if ! IFS= read -r -s -n 1 -t "$menu_escape_timeout" menu_escape_part <&3; then
        MENU_KEY=cancel
        return 0
      fi
      case $menu_escape_part in
        '['|'O')
          menu_escape_end=""
          if ! IFS= read -r -s -n 1 -t "$menu_escape_timeout" menu_escape_end <&3; then
            MENU_KEY=cancel
            return 0
          fi
          case $menu_escape_end in
            A) MENU_KEY=up ;;
            B) MENU_KEY=down ;;
          esac
          ;;
        *) MENU_KEY=cancel ;;
      esac
      ;;
  esac
}

toggle_all_menu_items() {
  calculate_menu_state
  if [ "$MENU_ALL_STATE" = "all" ]; then
    menu_new_state=0
  else
    menu_new_state=1
  fi
  menu_index=0
  while [ "$menu_index" -lt "$MENU_ITEM_COUNT" ]; do
    MENU_SELECTED[menu_index]=$menu_new_state
    menu_index=$((menu_index + 1))
  done
}

toggle_current_menu_item() {
  if [ "$MENU_CURSOR" -eq 0 ]; then
    toggle_all_menu_items
    return
  fi
  menu_index=$((MENU_CURSOR - 1))
  if [ "${MENU_SELECTED[$menu_index]}" -eq 1 ]; then
    MENU_SELECTED[menu_index]=0
  else
    MENU_SELECTED[menu_index]=1
  fi
}

restore_menu_signal_handlers() {
  trap - INT TERM HUP
}

finish_menu() {
  calculate_menu_state
  clear_rendered_menu
  if [ "$MENU_SELECTED_COUNT" -eq 0 ]; then
    printf '%s: skipped\n' "$MENU_RESULT_LABEL" >&4
  else
    printf '%s: %s\n' "$MENU_RESULT_LABEL" "$MENU_SELECTION_SUMMARY" >&4
  fi
  MENU_RENDERED_LINES=0
}

cancel_menu() {
  clear_rendered_menu
  printf '%s cancelled.\n' "$MENU_RESULT_LABEL" >&4
  MENU_RENDERED_LINES=0
}

run_dynamic_multiselect() {
  if [ "${#MENU_IDS[@]}" -eq 0 ]; then
    return 1
  fi

  # Bash's single-character read supplies the raw key behavior without a
  # downloaded UI helper. Signal traps ensure an interrupted checklist leaves
  # a clean line and returns a conventional shell status.
  MENU_SIGNAL_STATUS=0
  trap 'MENU_SIGNAL_STATUS=130' INT
  trap 'MENU_SIGNAL_STATUS=143' TERM
  trap 'MENU_SIGNAL_STATUS=129' HUP
  printf '\n' >&4

  while :; do
    render_menu
    if ! read_menu_key; then
      if [ "$MENU_SIGNAL_STATUS" -eq 0 ]; then MENU_SIGNAL_STATUS=1; fi
    fi
    if [ "$MENU_SIGNAL_STATUS" -ne 0 ]; then
      menu_status=$MENU_SIGNAL_STATUS
      cancel_menu
      restore_menu_signal_handlers
      return "$menu_status"
    fi

    MENU_MESSAGE=""
    case $MENU_KEY in
      up)
        if [ "$MENU_CURSOR" -gt 0 ]; then MENU_CURSOR=$((MENU_CURSOR - 1)); fi
        ;;
      down)
        if [ "$MENU_CURSOR" -lt "${#MENU_IDS[@]}" ]; then MENU_CURSOR=$((MENU_CURSOR + 1)); fi
        ;;
      toggle) toggle_current_menu_item ;;
      all) toggle_all_menu_items ;;
      enter)
        calculate_menu_state
        if [ "$MENU_ALLOW_EMPTY" -eq 0 ] && [ "$MENU_SELECTED_COUNT" -eq 0 ]; then
          MENU_MESSAGE="Select at least one item to continue."
        else
          finish_menu
          restore_menu_signal_handlers
          return 0
        fi
        ;;
      interrupt)
        cancel_menu
        restore_menu_signal_handlers
        return 130
        ;;
      cancel)
        cancel_menu
        restore_menu_signal_handlers
        return 1
        ;;
    esac
  done
}

read_plain_menu_choice() {
  menu_plain_label=$1
  menu_plain_default=$2
  while :; do
    if [ "$menu_plain_default" -eq 1 ]; then
      menu_plain_suffix='[Y/n]'
    else
      menu_plain_suffix='[y/N]'
    fi
    printf '%s %s? %s ' "$MENU_PLAIN_ACTION" "$menu_plain_label" "$menu_plain_suffix" >&4
    menu_plain_answer=""
    IFS= read -r menu_plain_answer <&3 || return 1
    case $menu_plain_answer in
      y|Y|yes|YES|Yes) MENU_PLAIN_SELECTED=1; return 0 ;;
      n|N|no|NO|No) MENU_PLAIN_SELECTED=0; return 0 ;;
      '') MENU_PLAIN_SELECTED=$menu_plain_default; return 0 ;;
      q|Q|quit|cancel) return 2 ;;
      *) printf '  Please answer yes, no, or q to cancel.\n' >&4 ;;
    esac
  done
}

run_plain_multiselect() {
  printf '\n%s\n' "$MENU_TITLE" >&4
  printf 'Limited terminal: %s\n' "$MENU_PLAIN_HELP" >&4
  menu_index=0
  while [ "$menu_index" -lt "${#MENU_IDS[@]}" ]; do
    read_plain_menu_choice "${MENU_LABELS[$menu_index]}" "${MENU_SELECTED[$menu_index]}"
    menu_status=$?
    if [ "$menu_status" -eq 2 ]; then
      printf '%s cancelled.\n' "$MENU_RESULT_LABEL" >&4
      return 1
    fi
    if [ "$menu_status" -ne 0 ]; then return "$menu_status"; fi
    MENU_SELECTED[menu_index]=$MENU_PLAIN_SELECTED
    menu_index=$((menu_index + 1))
  done

  calculate_menu_state
  if [ "$MENU_ALLOW_EMPTY" -eq 0 ] && [ "$MENU_SELECTED_COUNT" -eq 0 ]; then
    printf 'Select at least one item to continue.\n' >&4
    return 1
  fi
  finish_menu
}

run_multiselect() {
  if [ "${TERM-}" = "dumb" ] || [ -z "${TERM-}" ]; then
    run_plain_multiselect
  else
    run_dynamic_multiselect
  fi
}

apply_target_menu_selection() {
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    write_provider_state "${PROVIDER_IDS[$provider_index]}" SELECTED 0
    provider_index=$((provider_index + 1))
  done
  menu_index=0
  while [ "$menu_index" -lt "${#MENU_IDS[@]}" ]; do
    if [ "${MENU_SELECTED[$menu_index]}" -eq 1 ]; then
      write_provider_state "${MENU_IDS[$menu_index]}" SELECTED 1
    fi
    menu_index=$((menu_index + 1))
  done
}

interactive_select_targets() {
  reset_menu "Select harnesses for Valency" "All detected harnesses" "Selected harnesses" 0 \
    "Install Valency for" "answer once for each detected harness."
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    load_provider_metadata "$provider"
    read_provider_state "$provider" AVAILABLE
    provider_available=$PROVIDER_STATE_VALUE
    read_provider_state "$provider" EXECUTABLE_FOUND
    if [ "$PROVIDER_STATE_VALUE" -eq 1 ] && [ "$provider_available" -eq 0 ]; then
      printf '%s is installed but lacks required %s commands; upgrade it.\n' "$PROVIDER_LABEL" "$PROVIDER_COMPONENT" >&2
    fi
    if [ "$provider_available" -eq 1 ]; then
      write_provider_state "$provider" SELECTED 1
      add_menu_item "$provider" "$PROVIDER_LABEL" 1
    fi
    provider_index=$((provider_index + 1))
  done
  run_multiselect
  menu_status=$?
  if [ "$menu_status" -ne 0 ]; then return "$menu_status"; fi
  apply_target_menu_selection
}

# Collapses JSON formatting whitespace while leaving string values intact.
# Stripping blanks inside quoted strings could make an attacker-controlled
# value compact into a trusted one, so only structural whitespace is removed.
# awk is a base utility on every supported platform; this is a character
# scanner, not a JSON parser dependency.
compact_json() {
  awk '
    BEGIN { in_string = 0; escaped = 0 }
    {
      line = $0
      for (i = 1; i <= length(line); i++) {
        ch = substr(line, i, 1)
        if (escaped) { printf "%s", ch; escaped = 0; continue }
        if (in_string && ch == "\\") { printf "%s", ch; escaped = 1; continue }
        if (ch == "\"") { in_string = !in_string }
        if (in_string || (ch != " " && ch != "\t" && ch != "\r")) printf "%s", ch
      }
    }
  '
}

# Substring checks over a whole JSON document can match a key from a different
# list entry (for example another plugin's "enabled":true), so conjunction
# checks are scoped to one entry: the segment around the identity pair,
# bounded on both sides by object boundaries ("},{" between siblings, "[{"
# opening and "}]" closing an array of objects). JSON keys are unordered, so
# required fields are accepted anywhere within the bounded segment — but all
# of them must sit in the same entry. The identity may appear in several
# entries (for example one plugin id installed at multiple scopes); each
# occurrence is examined in turn. A boundary sequence appearing inside a
# string value can only shrink a segment, which fails closed instead of
# falsely verifying.
json_entry_contains() {
  document=$1
  identity=$2
  shift 2
  remainder=$document
  while :; do
    case $remainder in
      *"$identity"*) ;;
      *) return 1 ;;
    esac
    entry_before=${remainder%%"$identity"*}
    entry_after=${remainder#*"$identity"}
    remainder=$entry_after
    entry_before=${entry_before##*"},{"}
    entry_before=${entry_before##*"[{"}
    entry_after=${entry_after%%"},{"*}
    entry_after=${entry_after%%"}]"*}
    segment=$entry_before$identity$entry_after
    segment_matches=1
    for required in "$@"; do
      case $segment in
        *"$required"*) ;;
        *) segment_matches=0; break ;;
      esac
    done
    if [ "$segment_matches" -eq 1 ]; then
      return 0
    fi
  done
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
    *\"name\":\"$CLAUDE_MARKETPLACE\"*)
      # The name alone is never trusted: a look-alike marketplace with this
      # name but a different repository could serve a plugin that passes
      # identity verification. The entry must also name the expected repo.
      if json_entry_contains "$compact_marketplaces" "\"name\":\"$CLAUDE_MARKETPLACE\"" "\"repo\":\"$MARKETPLACE_SOURCE\""; then
        CLAUDE_MARKETPLACE_PRESENT=1
      else
        CLAUDE_MARKETPLACE_CONFLICT=1
      fi
      ;;
  esac
  case $compact_marketplaces in
    *\"name\":\"valency-plugin\"*)
      # The legacy cleanup follows the same trust rule as everything else:
      # only Valency's own legacy marketplace is removed. A different
      # marketplace that happens to use the name is disclosed and left alone,
      # together with any plugin it serves under the legacy id.
      if json_entry_contains "$compact_marketplaces" '"name":"valency-plugin"' '"repo":"valency-oss/valency-plugin"' ||
        json_entry_contains "$compact_marketplaces" '"name":"valency-plugin"' '"repo":"valencyio/valency-plugin"'; then
        CLAUDE_LEGACY_MARKETPLACE_PRESENT=1
      else
        CLAUDE_LEGACY_MARKETPLACE_FOREIGN=1
        printf 'Note: a marketplace named valency-plugin does not come from a Valency legacy repository; it and its plugins were left unchanged.\n' >&2
      fi
      ;;
  esac
  # Detection is scope-aware: the installer manages the user scope only, so a
  # project- or local-scoped copy of the same plugin id must not be mistaken
  # for the user-scoped installation (or trigger user-scoped legacy cleanup).
  if json_entry_contains "$compact_plugins" "\"id\":\"$CLAUDE_PLUGIN\"" '"scope":"user"'; then
    CLAUDE_PLUGIN_PRESENT=1
  fi
  if json_entry_contains "$compact_plugins" '"id":"valency@valency-plugin"' '"scope":"user"'; then
    if [ "$CLAUDE_LEGACY_MARKETPLACE_FOREIGN" -eq 1 ]; then
      # The legacy plugin id is bound to the marketplace name; when that name
      # belongs to a foreign marketplace, the plugin is theirs, not ours.
      CLAUDE_LEGACY_PLUGIN_PRESENT=0
    else
      CLAUDE_LEGACY_PLUGIN_PRESENT=1
    fi
  fi
}

provider_inspect_state() {
  case $1 in
    claude) inspect_claude_state ;;
    codex) inspect_codex_state ;;
    antigravity) inspect_antigravity_state ;;
    gemini) inspect_gemini_state ;;
    copilot) inspect_copilot_state ;;
    grok) inspect_grok_state ;;
    *) return 1 ;;
  esac
}

provider_inspection_is_acceptable() {
  PROVIDER_INSPECTION_RESULT=""
  case $1 in
    claude)
      if [ "$CLAUDE_MARKETPLACE_CONFLICT" -eq 1 ]; then
        printf 'Error: an existing Claude Code marketplace named %s does not come from %s; Claude Code was not changed.\n' "$CLAUDE_MARKETPLACE" "$MARKETPLACE_SOURCE" >&2
        printf 'Review where it came from, then remove it and rerun this installer: claude plugin marketplace remove %s --scope user\n' "$CLAUDE_MARKETPLACE" >&2
        PROVIDER_INSPECTION_RESULT="failed (marketplace conflict)"
        return 1
      fi
      ;;
    gemini)
      if [ "$GEMINI_EXTENSION_CONFLICT" -eq 1 ]; then
        printf 'Error: the installed Gemini extension named valency does not come from %s; Gemini CLI was not changed.\n' "$MARKETPLACE_SOURCE" >&2
        PROVIDER_INSPECTION_RESULT="failed (extension conflict)"
        return 1
      fi
      ;;
    copilot)
      if [ "$COPILOT_MARKETPLACE_CONFLICT" -eq 1 ]; then
        printf 'Error: the Copilot marketplace named valency-copilot-plugin does not come from %s; Copilot was not changed.\n' "$MARKETPLACE_SOURCE" >&2
        PROVIDER_INSPECTION_RESULT="failed (marketplace conflict)"
        return 1
      fi
      ;;
    grok)
      if [ "$GROK_MARKETPLACE_CONFLICT" -eq 1 ] || [ "$GROK_PLUGIN_CONFLICT" -eq 1 ]; then
        printf 'Error: an existing Grok marketplace or plugin named valency does not come from %s; Grok Build was not changed.\n' "$MARKETPLACE_SOURCE" >&2
        PROVIDER_INSPECTION_RESULT="failed (source conflict)"
        return 1
      fi
      ;;
  esac
}

inspect_provider_state() {
  # Inspection failures stay isolated: the dispatch drops only the affected
  # provider before any mutation while the remaining selected providers run.
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    read_provider_state "$provider" SELECTED
    if [ "$PROVIDER_STATE_VALUE" -eq 1 ]; then
      if ! provider_inspect_state "$provider"; then
        write_provider_state "$provider" SELECTED 0
        write_provider_state "$provider" INSTALL_RESULT "failed (state inspection)"
        PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
      elif ! provider_inspection_is_acceptable "$provider"; then
        write_provider_state "$provider" SELECTED 0
        write_provider_state "$provider" INSTALL_RESULT "$PROVIDER_INSPECTION_RESULT"
        PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
      fi
    fi
    provider_index=$((provider_index + 1))
  done
}

inspect_antigravity_state() {
  if ! plugin_output=$(agy plugin list 2>/dev/null); then
    printf 'Error: could not inspect Antigravity CLI plugin state; no changes were made.\n' >&2
    return 1
  fi
  case $plugin_output in
    "No imported plugins."*) return 0 ;;
  esac
  compact_plugins=$(printf '%s' "$plugin_output" | compact_json)
  case $compact_plugins in
    *'"imports":['*) ;;
    *) printf 'Error: Antigravity CLI returned an unrecognized plugin list; no changes were made.\n' >&2; return 1 ;;
  esac
  # Antigravity 1.1.11 normalizes every native install to source
  # "antigravity" and exposes no repository URL. The adapter therefore never
  # removes an existing import: it refreshes through the fixed Valency GitHub
  # URL and verifies the resulting component inventory after installation.
  if json_entry_contains "$compact_plugins" '"name":"valency"' '"source":"antigravity"'; then
    ANTIGRAVITY_PLUGIN_PRESENT=1
  fi
}

gemini_extension_source_trusted() {
  json_entry_contains "$1" '"name":"valency"' "\"source\":\"https://github.com/$MARKETPLACE_SOURCE\"" ||
    json_entry_contains "$1" '"name":"valency"' "\"source\":\"https://github.com/$MARKETPLACE_SOURCE.git\""
}

inspect_gemini_state() {
  if ! extension_json=$(gemini extensions list --output-format json 2>/dev/null); then
    printf 'Error: could not inspect Gemini CLI extension state; no changes were made.\n' >&2
    return 1
  fi
  compact_extensions=$(printf '%s' "$extension_json" | compact_json)
  case $compact_extensions in
    \[*\]) ;;
    *) printf 'Error: Gemini CLI returned an unrecognized extension list; no changes were made.\n' >&2; return 1 ;;
  esac
  case $compact_extensions in
    *'"name":"valency"'*)
      if gemini_extension_source_trusted "$compact_extensions"; then
        GEMINI_EXTENSION_PRESENT=1
      else
        GEMINI_EXTENSION_CONFLICT=1
      fi
      ;;
  esac
}

inspect_copilot_plugin_state() {
  COPILOT_PLUGIN_PRESENT=0
  COPILOT_PLUGIN_ENABLED=0
  # Current Copilot docs define a JSON inventory command, but stable 1.0.78
  # still reports it unavailable. Prefer it when present and otherwise parse
  # only the exact installed-plugin token from the stable text command.
  if plugin_output=$(copilot plugins list --kind plugin --scope user --json 2>/dev/null); then
    compact_plugins=$(printf '%s' "$plugin_output" | compact_json)
    case $compact_plugins in
      \[*\]) ;;
      *) printf 'Error: GitHub Copilot CLI returned an unrecognized JSON plugin list; no changes were made.\n' >&2; return 1 ;;
    esac
    if json_entry_contains "$compact_plugins" '"id":"valency@valency-copilot-plugin"' '"name":"valency"' '"kind":"plugin"' '"scope":"user"'; then
      COPILOT_PLUGIN_PRESENT=1
      if json_entry_contains "$compact_plugins" '"id":"valency@valency-copilot-plugin"' '"name":"valency"' '"kind":"plugin"' '"scope":"user"' '"enabled":true'; then
        COPILOT_PLUGIN_ENABLED=1
      fi
    fi
    return 0
  fi

  if ! plugin_output=$(copilot plugin list 2>/dev/null); then
    printf 'Error: could not inspect GitHub Copilot CLI plugin state; no changes were made.\n' >&2
    return 1
  fi
  case $plugin_output in
    *"valency@valency-copilot-plugin ("*)
      # Stable Copilot 1.0.78 has no enable/disable command and exposes no
      # enabled field in this fallback. Its exact installed-plugin token is
      # the strongest activation evidence that version provides.
      COPILOT_PLUGIN_PRESENT=1
      COPILOT_PLUGIN_ENABLED=1
      ;;
  esac
}

inspect_copilot_state() {
  if ! marketplace_output=$(copilot plugin marketplace list 2>/dev/null); then
    printf 'Error: could not inspect GitHub Copilot CLI marketplace state; no changes were made.\n' >&2
    return 1
  fi
  case $marketplace_output in
    *"valency-copilot-plugin (GitHub: $MARKETPLACE_SOURCE)"*) COPILOT_MARKETPLACE_PRESENT=1 ;;
    *"valency-copilot-plugin"*) COPILOT_MARKETPLACE_CONFLICT=1 ;;
  esac
  inspect_copilot_plugin_state
}

grok_source_url() {
  printf 'https://github.com/%s.git' "$MARKETPLACE_SOURCE"
}

inspect_grok_state() {
  if ! marketplace_json=$(grok plugin marketplace list --json 2>/dev/null); then
    printf 'Error: could not inspect Grok Build marketplace state; no changes were made.\n' >&2
    return 1
  fi
  if ! plugin_json=$(grok plugin list --json 2>/dev/null); then
    printf 'Error: could not inspect Grok Build plugin state; no changes were made.\n' >&2
    return 1
  fi
  compact_marketplaces=$(printf '%s' "$marketplace_json" | compact_json)
  compact_plugins=$(printf '%s' "$plugin_json" | compact_json)
  case $compact_marketplaces in
    \[*\]) ;;
    *) printf 'Error: Grok Build returned an unrecognized marketplace list; no changes were made.\n' >&2; return 1 ;;
  esac
  case $compact_plugins in
    \[*\]) ;;
    *) printf 'Error: Grok Build returned an unrecognized plugin list; no changes were made.\n' >&2; return 1 ;;
  esac

  expected_grok_source=$(grok_source_url)
  case $compact_marketplaces in
    *'"name":"valency-bond"'*)
      if json_entry_contains "$compact_marketplaces" '"name":"valency-bond"' "\"url\":\"$expected_grok_source\""; then
        GROK_MARKETPLACE_PRESENT=1
      else
        GROK_MARKETPLACE_CONFLICT=1
      fi
      ;;
  esac
  case $compact_plugins in
    *'"name":"valency"'*)
      if json_entry_contains "$compact_plugins" '"name":"valency"' '"status":"installed"' "\"source\":\"$expected_grok_source\""; then
        GROK_PLUGIN_PRESENT=1
      else
        GROK_PLUGIN_CONFLICT=1
      fi
      ;;
  esac
}

inspect_auth_states() {
  if [ "$AUTH_MODE" = "no" ]; then
    return
  fi
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    load_provider_metadata "$provider"
    read_provider_state "$provider" SELECTED
    if [ "$PROVIDER_STATE_VALUE" -eq 1 ] && [ "$PROVIDER_AUTH_METHOD" = standalone ]; then
      provider_inspect_auth_state "$provider"
    fi
    provider_index=$((provider_index + 1))
  done
}

provider_inspect_auth_state() {
  case $1 in
    claude) inspect_claude_auth_state ;;
    codex) inspect_codex_auth_state ;;
    *) return 0 ;;
  esac
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
  # Status is read from the single line naming this plugin so another server's
  # "Connected" cannot bleed in. The identifier must end at a delimiter — a
  # longer name such as plugin:valency:valency-helper is a different server.
  # "Disconnected" contains "connected" and must not count; anything
  # unrecognized on the line stays "unknown".
  CLAUDE_AUTH_STATE="missing"
  while IFS= read -r auth_line; do
    case $auth_line in
      *plugin:valency:valency*) ;;
      *) continue ;;
    esac
    auth_line_rest=${auth_line#*plugin:valency:valency}
    case $auth_line_rest in
      [A-Za-z0-9._-]*) continue ;;
    esac
    case $auth_line in
      # Negative and diagnostic statuses contain the word "connected" and
      # must be recognized before the positive match.
      *[Dd]isconnected*|*[Nn]ot\ [Cc]onnected*|*[Ff]ail*|*[Ee]rror*) CLAUDE_AUTH_STATE="unknown" ;;
      *[Cc]onnected*) CLAUDE_AUTH_STATE="connected" ;;
      *) CLAUDE_AUTH_STATE="unknown" ;;
    esac
    break
  done <<EOF
$auth_output
EOF
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
  if json_entry_contains "$compact_auth" '"name":"valency"' '"auth_status":"oauth"' ||
    json_entry_contains "$compact_auth" '"name":"valency"' '"auth_status":"bearer_token"'; then
    CODEX_AUTH_STATE="connected"
    return
  fi
  case $compact_auth in
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
    *\"name\":\"$CODEX_MARKETPLACE\"*)
      CODEX_MARKETPLACE_PRESENT=1
      # Same trust rule as Claude: the marketplace name alone is never
      # trusted. A marketplace named valency from another source requires the
      # disclosed replacement even when a plugin with the expected id is
      # already installed from it — otherwise a look-alike source would be
      # refreshed and pass verification. Several source spellings are
      # accepted; anything else fails closed into the replacement flow.
      if ! codex_marketplace_source_trusted "$compact_marketplaces"; then
        CODEX_REPLACEMENT_REQUIRED=1
      fi
      ;;
  esac
  if json_entry_contains "$compact_plugins" "\"pluginId\":\"$CODEX_PLUGIN\"" '"installed":true'; then
    CODEX_PLUGIN_PRESENT=1
  fi
}

codex_marketplace_source_trusted() {
  json_entry_contains "$1" "\"name\":\"$CODEX_MARKETPLACE\"" "\"source\":\"https://github.com/$MARKETPLACE_SOURCE.git\"" ||
    json_entry_contains "$1" "\"name\":\"$CODEX_MARKETPLACE\"" "\"source\":\"https://github.com/$MARKETPLACE_SOURCE\"" ||
    json_entry_contains "$1" "\"name\":\"$CODEX_MARKETPLACE\"" "\"source\":\"$MARKETPLACE_SOURCE\""
}

print_provider_plan() {
  case $1 in
    claude)
    # The marketplace verb comes from the marketplace state, not the plugin
    # state: a plugin can outlive its marketplace and vice versa, and the
    # displayed plan must match the commands that will actually run.
    if [ "$CLAUDE_MARKETPLACE_PRESENT" -eq 1 ]; then
      claude_marketplace_step="refresh the $CLAUDE_MARKETPLACE marketplace"
    else
      claude_marketplace_step="add the $MARKETPLACE_SOURCE marketplace"
    fi
    if [ "$CLAUDE_PLUGIN_PRESENT" -eq 1 ]; then
      printf '  Claude Code: %s, update %s, and verify it is enabled.\n' "$claude_marketplace_step" "$CLAUDE_PLUGIN"
    else
      printf '  Claude Code: %s, install %s at user scope, and verify it is enabled.\n' "$claude_marketplace_step" "$CLAUDE_PLUGIN"
    fi
    if [ "$CLAUDE_LEGACY_PLUGIN_PRESENT" -eq 1 ] || [ "$CLAUDE_LEGACY_MARKETPLACE_PRESENT" -eq 1 ]; then
      printf '    Conditional migration: after verification, remove valency@valency-plugin and the valency-plugin marketplace.\n'
    fi
      ;;
    codex)
    if [ "$CODEX_MARKETPLACE_PRESENT" -eq 1 ] && [ "$CODEX_REPLACEMENT_REQUIRED" -eq 0 ]; then
      codex_marketplace_step="refresh the $CODEX_MARKETPLACE marketplace"
    else
      codex_marketplace_step="add the $MARKETPLACE_SOURCE marketplace"
    fi
    if [ "$CODEX_PLUGIN_PRESENT" -eq 1 ] && [ "$CODEX_REPLACEMENT_REQUIRED" -eq 0 ]; then
      printf '  Codex: %s, reinstall %s, and verify it is enabled.\n' "$codex_marketplace_step" "$CODEX_PLUGIN"
    else
      printf '  Codex: %s, install %s, and verify it is enabled.\n' "$codex_marketplace_step" "$CODEX_PLUGIN"
    fi
    if [ "$CODEX_REPLACEMENT_REQUIRED" -eq 1 ]; then
      printf '    Conditional replacement: remove the existing marketplace named valency, add %s, then install and verify %s.\n' "$MARKETPLACE_SOURCE" "$CODEX_PLUGIN"
      printf '    The existing marketplace source will not be inspected and cannot be restored automatically.\n'
    fi
      ;;
    antigravity)
    if [ "$ANTIGRAVITY_PLUGIN_PRESENT" -eq 1 ]; then
      printf '  Antigravity CLI: reinstall Valency from %s to refresh it, then verify the import.\n' "$MARKETPLACE_SOURCE"
    else
      printf '  Antigravity CLI: install Valency from %s, then verify the import.\n' "$MARKETPLACE_SOURCE"
    fi
      ;;
    gemini)
    if [ "$GEMINI_EXTENSION_PRESENT" -eq 1 ]; then
      printf '  Gemini CLI: update and enable the valency extension, then verify it is active.\n'
    else
      printf '  Gemini CLI: install valency from %s with automatic updates, then verify it is active.\n' "$MARKETPLACE_SOURCE"
    fi
      ;;
    copilot)
    if [ "$COPILOT_MARKETPLACE_PRESENT" -eq 1 ]; then
      copilot_marketplace_step="refresh the valency-copilot-plugin marketplace"
    else
      copilot_marketplace_step="add the $MARKETPLACE_SOURCE marketplace"
    fi
    if [ "$COPILOT_PLUGIN_PRESENT" -eq 1 ]; then
      printf '  GitHub Copilot CLI: %s, update valency, then verify the installed plugin.\n' "$copilot_marketplace_step"
    else
      printf '  GitHub Copilot CLI: %s, install valency@valency-copilot-plugin, then verify it.\n' "$copilot_marketplace_step"
    fi
      ;;
    grok)
    if [ "$GROK_MARKETPLACE_PRESENT" -eq 1 ]; then
      grok_marketplace_step="refresh the valency-bond marketplace"
    else
      grok_marketplace_step="add the $MARKETPLACE_SOURCE marketplace"
    fi
    if [ "$GROK_PLUGIN_PRESENT" -eq 1 ]; then
      printf '  Grok Build: %s, update valency, then verify its installed record.\n' "$grok_marketplace_step"
    else
      printf '  Grok Build: %s, install and trust valency, then verify its installed record.\n' "$grok_marketplace_step"
    fi
      ;;
  esac
}

print_plan() {
  printf '\nValency installation plan\n'
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    read_provider_state "$provider" SELECTED
    if [ "$PROVIDER_STATE_VALUE" -eq 1 ]; then
      print_provider_plan "$provider"
    fi
    provider_index=$((provider_index + 1))
  done
  if [ "$AUTH_MODE" = "no" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '  Authentication: skipped; a real run prints the manual login commands.\n'
    else
      printf '  Authentication: skipped; manual login commands will be shown.\n'
    fi
  else
    printf '  Authentication: offered after verified installation.\n'
    provider_index=0
    while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
      provider=${PROVIDER_IDS[$provider_index]}
      load_provider_metadata "$provider"
      read_provider_state "$provider" SELECTED
      if [ "$PROVIDER_STATE_VALUE" -eq 1 ] && [ "$PROVIDER_AUTH_METHOD" = standalone ]; then
        read_provider_state "$provider" AUTH_STATE
        printf '    %s status: %s.\n' "$PROVIDER_LABEL" "$PROVIDER_STATE_VALUE"
      fi
      provider_index=$((provider_index + 1))
    done
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
  # Preflight failures are provider-specific like inspection failures: Codex is
  # reported as failed and dropped while a selected Claude install proceeds.
  if [ "$CODEX_SELECTED" -eq 1 ] && [ "$CODEX_REPLACEMENT_REQUIRED" -eq 1 ]; then
    if ! command -v curl >/dev/null 2>&1; then
      printf 'Error: Codex replacement preflight requires curl to verify the public marketplace repository.\n' >&2
      fail_codex_preflight
      return
    fi
    if ! curl -fsSIL --max-time 10 "https://github.com/$MARKETPLACE_SOURCE" >/dev/null 2>&1; then
      printf 'Error: cannot publicly reach https://github.com/%s; the existing Codex marketplace was not changed.\n' "$MARKETPLACE_SOURCE" >&2
      fail_codex_preflight
    fi
  fi
}

fail_codex_preflight() {
  CODEX_SELECTED=0
  CODEX_INSTALL_RESULT="failed (replacement preflight)"
  PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
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
  json_entry_contains "$compact_plugins" "\"id\":\"$CLAUDE_PLUGIN\"" '"enabled":true' '"scope":"user"'
}

install_claude() {
  if [ "$DRY_RUN" -eq 1 ]; then
    CLAUDE_INSTALL_RESULT="planned"
    return 0
  fi

  if [ "$CLAUDE_PLUGIN_PRESENT" -eq 1 ]; then
    # Claude's manifest version is authoritative. The native updater decides
    # whether content changed; this installer never force-reinstalls around it.
    if [ "$CLAUDE_MARKETPLACE_PRESENT" -eq 1 ]; then
      if ! run_quietly claude plugin marketplace update "$CLAUDE_MARKETPLACE"; then
        CLAUDE_INSTALL_RESULT="failed"
        return 1
      fi
    else
      # The plugin can outlive its marketplace registration; repair the state
      # by re-adding the trusted marketplace instead of updating a missing one.
      if ! run_quietly claude plugin marketplace add "$MARKETPLACE_SOURCE" --scope user; then
        CLAUDE_INSTALL_RESULT="failed"
        return 1
      fi
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

  if ! verify_provider claude; then
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
  json_entry_contains "$compact_plugins" "\"pluginId\":\"$CODEX_PLUGIN\"" '"installed":true' '"enabled":true'
}

verify_antigravity_plugin() {
  plugin_output=$(agy plugin list 2>/dev/null) || return 1
  compact_plugins=$(printf '%s' "$plugin_output" | compact_json)
  json_entry_contains "$compact_plugins" '"name":"valency"' '"source":"antigravity"' '"mcpServers"'
}

install_antigravity() {
  if [ "$DRY_RUN" -eq 1 ]; then
    ANTIGRAVITY_INSTALL_RESULT="planned"
    return 0
  fi

  if [ "$ANTIGRAVITY_PLUGIN_PRESENT" -eq 1 ]; then
    success_result="updated"
  else
    success_result="installed"
  fi
  # Antigravity has no separate update verb. Reinstalling the same source is
  # its supported idempotent refresh path and does not prompt for confirmation.
  if ! run_quietly agy plugin install "https://github.com/$MARKETPLACE_SOURCE"; then
    ANTIGRAVITY_INSTALL_RESULT="failed"
    return 1
  fi
  if ! verify_provider antigravity; then
    ANTIGRAVITY_INSTALL_RESULT="failed verification"
    return 1
  fi
  ANTIGRAVITY_INSTALL_RESULT=$success_result
}

verify_gemini_extension() {
  extension_json=$(gemini extensions list --output-format json 2>/dev/null) || return 1
  compact_extensions=$(printf '%s' "$extension_json" | compact_json)
  gemini_extension_source_trusted "$compact_extensions" &&
    json_entry_contains "$compact_extensions" '"name":"valency"' '"isActive":true'
}

install_gemini() {
  if [ "$DRY_RUN" -eq 1 ]; then
    GEMINI_INSTALL_RESULT="planned"
    return 0
  fi

  if [ "$GEMINI_EXTENSION_PRESENT" -eq 1 ]; then
    if ! run_quietly gemini extensions update valency; then
      GEMINI_INSTALL_RESULT="failed"
      return 1
    fi
    if ! run_quietly gemini extensions enable valency --scope user; then
      GEMINI_INSTALL_RESULT="failed"
      return 1
    fi
    success_result="updated"
  else
    if ! run_quietly gemini extensions install "https://github.com/$MARKETPLACE_SOURCE" --auto-update --consent; then
      GEMINI_INSTALL_RESULT="failed"
      return 1
    fi
    success_result="installed"
  fi
  if ! verify_provider gemini; then
    GEMINI_INSTALL_RESULT="failed verification"
    return 1
  fi
  GEMINI_INSTALL_RESULT=$success_result
}

verify_copilot_plugin() {
  inspect_copilot_plugin_state || return 1
  [ "$COPILOT_PLUGIN_PRESENT" -eq 1 ] && [ "$COPILOT_PLUGIN_ENABLED" -eq 1 ]
}

install_copilot() {
  if [ "$DRY_RUN" -eq 1 ]; then
    COPILOT_INSTALL_RESULT="planned"
    return 0
  fi

  if [ "$COPILOT_MARKETPLACE_PRESENT" -eq 1 ]; then
    if ! run_quietly copilot plugin marketplace update valency-copilot-plugin; then
      COPILOT_INSTALL_RESULT="failed"
      return 1
    fi
  else
    if ! run_quietly copilot plugin marketplace add "$MARKETPLACE_SOURCE"; then
      COPILOT_INSTALL_RESULT="failed"
      return 1
    fi
  fi
  if [ "$COPILOT_PLUGIN_PRESENT" -eq 1 ]; then
    if ! run_quietly copilot plugin update valency; then
      COPILOT_INSTALL_RESULT="failed"
      return 1
    fi
    success_result="updated"
  else
    if ! run_quietly copilot plugin install valency@valency-copilot-plugin; then
      COPILOT_INSTALL_RESULT="failed"
      return 1
    fi
    success_result="installed"
  fi
  if ! verify_provider copilot; then
    COPILOT_INSTALL_RESULT="failed verification"
    return 1
  fi
  COPILOT_INSTALL_RESULT=$success_result
}

verify_grok_plugin() {
  plugin_json=$(grok plugin list --json 2>/dev/null) || return 1
  compact_plugins=$(printf '%s' "$plugin_json" | compact_json)
  expected_grok_source=$(grok_source_url)
  json_entry_contains "$compact_plugins" '"name":"valency"' '"status":"installed"' "\"source\":\"$expected_grok_source\""
}

verify_provider() {
  case $1 in
    claude) verify_claude_plugin ;;
    codex) verify_codex_plugin ;;
    antigravity) verify_antigravity_plugin ;;
    gemini) verify_gemini_extension ;;
    copilot) verify_copilot_plugin ;;
    grok) verify_grok_plugin ;;
    *) return 1 ;;
  esac
}

install_grok() {
  if [ "$DRY_RUN" -eq 1 ]; then
    GROK_INSTALL_RESULT="planned"
    return 0
  fi

  if [ "$GROK_MARKETPLACE_PRESENT" -eq 1 ]; then
    if ! run_quietly grok plugin marketplace update valency-bond; then
      GROK_INSTALL_RESULT="failed"
      return 1
    fi
  else
    if ! run_quietly grok plugin marketplace add "$MARKETPLACE_SOURCE"; then
      GROK_INSTALL_RESULT="failed"
      return 1
    fi
  fi
  if [ "$GROK_PLUGIN_PRESENT" -eq 1 ]; then
    if ! run_quietly grok plugin update valency; then
      GROK_INSTALL_RESULT="failed"
      return 1
    fi
    success_result="updated"
  else
    # --trust is the host's noninteractive acknowledgement for activating the
    # plugin's remote MCP server and avoids a surprise second confirmation.
    if ! run_quietly grok plugin install valency --trust; then
      GROK_INSTALL_RESULT="failed"
      return 1
    fi
    success_result="installed"
  fi
  if ! verify_provider grok; then
    GROK_INSTALL_RESULT="failed verification"
    return 1
  fi
  GROK_INSTALL_RESULT=$success_result
}

install_codex() {
  if [ "$DRY_RUN" -eq 1 ]; then
    CODEX_INSTALL_RESULT="planned"
    return 0
  fi

  codex_replacement_started=0
  if [ "$CODEX_REPLACEMENT_REQUIRED" -eq 1 ]; then
    # Codex identifies marketplaces by name. We intentionally do not inspect or
    # retain the previous source, so replacement is disclosed and preflighted;
    # failure guidance can retry Valency but cannot promise automatic rollback.
    # Replacement is checked before plugin presence: a plugin installed from an
    # untrusted look-alike marketplace must not take the refresh path.
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
  elif [ "$CODEX_PLUGIN_PRESENT" -eq 1 ]; then
    if [ "$CODEX_MARKETPLACE_PRESENT" -eq 1 ]; then
      if ! run_quietly codex plugin marketplace upgrade "$CODEX_MARKETPLACE"; then
        CODEX_INSTALL_RESULT="failed"
        return 1
      fi
    else
      # The plugin can outlive its marketplace registration; repair the state
      # by re-adding the trusted marketplace instead of upgrading a missing one.
      if ! run_quietly codex plugin marketplace add "$MARKETPLACE_SOURCE"; then
        CODEX_INSTALL_RESULT="failed"
        return 1
      fi
    fi
    success_result="updated"
  else
    if [ "$CODEX_MARKETPLACE_PRESENT" -eq 0 ]; then
      if ! run_quietly codex plugin marketplace add "$MARKETPLACE_SOURCE"; then
        CODEX_INSTALL_RESULT="failed"
        return 1
      fi
    else
      # The trusted marketplace survived a partial earlier run; refresh it and
      # reinstall the plugin without any replacement ceremony.
      if ! run_quietly codex plugin marketplace upgrade "$CODEX_MARKETPLACE"; then
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
  if ! verify_provider codex; then
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

install_provider() {
  case $1 in
    claude) install_claude ;;
    codex) install_codex ;;
    antigravity) install_antigravity ;;
    gemini) install_gemini ;;
    copilot) install_copilot ;;
    grok) install_grok ;;
    *) return 1 ;;
  esac
}

install_selected_providers() {
  # Provider failures are isolated and verified work is never rolled back.
  install_failures=0
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    read_provider_state "$provider" SELECTED
    if [ "$PROVIDER_STATE_VALUE" -eq 1 ]; then
      install_provider "$provider" || install_failures=$((install_failures + 1))
    fi
    provider_index=$((provider_index + 1))
  done
  return "$install_failures"
}

installation_succeeded() {
  case $1 in
    installed*|updated*|planned) return 0 ;;
  esac
  return 1
}

# A failed legacy cleanup still leaves the new plugin installed, verified, and
# enabled, so the manual login command must still be shown for it. A dry run
# installs nothing, so login hints would point at a plugin that is not there.
plugin_ready_for_login() {
  case $1 in
    planned) return 1 ;;
    "failed legacy cleanup"*) return 0 ;;
  esac
  installation_succeeded "$1"
}

prepare_authentication() {
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    load_provider_metadata "$provider"
    read_provider_state "$provider" SELECTED
    provider_selected=$PROVIDER_STATE_VALUE
    read_provider_state "$provider" INSTALL_RESULT
    if [ "$provider_selected" -eq 1 ] && installation_succeeded "$PROVIDER_STATE_VALUE"; then
      if [ "$PROVIDER_AUTH_METHOD" = in-host ]; then
        # These providers own OAuth inside their TUI. The installer reports the
        # exact action instead of launching a full interactive agent.
        write_provider_state "$provider" AUTH_RESULT "manual action required"
      else
        read_provider_state "$provider" AUTH_STATE
        prepare_provider_auth "$provider" "$PROVIDER_STATE_VALUE"
      fi
    fi
    provider_index=$((provider_index + 1))
  done

  if [ "$AUTH_MODE" = "prompt" ] && any_provider_auth_selected; then
    prompt_for_authentication_selection
  fi
}

any_provider_auth_selected() {
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    read_provider_state "${PROVIDER_IDS[$provider_index]}" AUTH_SELECTED
    if [ "$PROVIDER_STATE_VALUE" -eq 1 ]; then return 0; fi
    provider_index=$((provider_index + 1))
  done
  return 1
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
  write_provider_state "$provider" AUTH_SELECTED 1
}

set_auth_result() {
  write_provider_state "$1" AUTH_RESULT "$2"
}

prompt_for_authentication_selection() {
  reset_menu "Optional authentication" "All available providers" "Authentication" 1 \
    "Authenticate" "answer once for each available provider."
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    load_provider_metadata "$provider"
    read_provider_state "$provider" SELECTED
    provider_selected=$PROVIDER_STATE_VALUE
    read_provider_state "$provider" INSTALL_RESULT
    provider_install_result=$PROVIDER_STATE_VALUE
    read_provider_state "$provider" AUTH_STATE
    provider_auth_state=$PROVIDER_STATE_VALUE
    read_provider_state "$provider" AUTH_SELECTED
    if [ "$PROVIDER_AUTH_METHOD" = standalone ] && [ "$provider_selected" -eq 1 ] &&
      installation_succeeded "$provider_install_result" && [ "$provider_auth_state" != "unavailable" ]; then
      add_menu_item "$provider" "$PROVIDER_LABEL ($provider_auth_state)" "$PROVIDER_STATE_VALUE"
    fi
    provider_index=$((provider_index + 1))
  done

  run_multiselect
  menu_status=$?
  if [ "$menu_status" -ne 0 ]; then
    provider_index=0
    while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
      write_provider_state "${PROVIDER_IDS[$provider_index]}" AUTH_SELECTED 0
      provider_index=$((provider_index + 1))
    done
    printf 'Authentication skipped.\n'
    return 0
  fi

  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    write_provider_state "${PROVIDER_IDS[$provider_index]}" AUTH_SELECTED 0
    provider_index=$((provider_index + 1))
  done
  menu_index=0
  while [ "$menu_index" -lt "${#MENU_IDS[@]}" ]; do
    if [ "${MENU_SELECTED[$menu_index]}" -eq 1 ]; then
      write_provider_state "${MENU_IDS[$menu_index]}" AUTH_SELECTED 1
    fi
    menu_index=$((menu_index + 1))
  done
}

run_provider_auth() {
  provider=$1
  load_provider_metadata "$provider"
  case $provider in
    claude) claude mcp login plugin:valency:valency <&3 ;;
    codex) codex mcp login valency <&3 ;;
    *) return 1 ;;
  esac
  auth_status=$?
  if [ "$auth_status" -eq 0 ]; then
    write_provider_state "$provider" AUTH_RESULT "authenticated"
  else
    write_provider_state "$provider" AUTH_RESULT "failed (plugin remains installed)"
    printf 'Warning: %s authentication did not complete; the verified plugin remains installed.\n' "$PROVIDER_LABEL" >&2
  fi
  return 0
}

run_authentication() {
  if [ "$DRY_RUN" -eq 1 ]; then
    provider_index=0
    while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
      provider=${PROVIDER_IDS[$provider_index]}
      read_provider_state "$provider" AUTH_SELECTED
      if [ "$PROVIDER_STATE_VALUE" -eq 1 ]; then
        write_provider_state "$provider" AUTH_RESULT "planned"
      fi
      provider_index=$((provider_index + 1))
    done
    finalize_unselected_auth_results
    return
  fi

  # Login output passes straight through to the user: device-code flows print
  # a URL the user must see, exactly as if they ran the login command by hand.
  # The installer never captures or re-prints that output itself.
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    read_provider_state "$provider" AUTH_SELECTED
    if [ "$PROVIDER_STATE_VALUE" -eq 1 ]; then
      run_provider_auth "$provider"
    fi
    provider_index=$((provider_index + 1))
  done
  finalize_unselected_auth_results
}

finalize_unselected_auth_results() {
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    read_provider_state "$provider" SELECTED
    provider_selected=$PROVIDER_STATE_VALUE
    read_provider_state "$provider" INSTALL_RESULT
    provider_install_result=$PROVIDER_STATE_VALUE
    read_provider_state "$provider" AUTH_RESULT
    if [ "$provider_selected" -eq 1 ] && installation_succeeded "$provider_install_result" && [ "$PROVIDER_STATE_VALUE" = "not offered" ]; then
      write_provider_state "$provider" AUTH_RESULT "skipped"
    fi
    provider_index=$((provider_index + 1))
  done
}

print_provider_auth_guidance() {
  provider=$1
  read_provider_state "$provider" AUTH_AVAILABLE
  provider_auth_available=$PROVIDER_STATE_VALUE
  case $provider in
    claude)
      if [ "$provider_auth_available" -eq 1 ]; then
        printf '  Manual Claude login: claude mcp login plugin:valency:valency\n'
      else
        printf '  This Claude Code version lacks mcp login; upgrade it, then run: claude mcp login plugin:valency:valency\n'
      fi
      ;;
    codex)
      if [ "$provider_auth_available" -eq 1 ]; then
        printf '  Manual Codex login: codex mcp login valency\n'
      else
        printf '  This Codex version lacks mcp login; upgrade it, then run: codex mcp login valency\n'
      fi
      ;;
    antigravity) printf '  In Antigravity CLI: open /mcp, select valency, and complete browser authentication.\n' ;;
    gemini) printf '  In Gemini CLI: run /mcp auth valency.\n' ;;
    copilot) printf '  In GitHub Copilot CLI: run /mcp auth valency.\n' ;;
    grok) printf '  In Grok Build: open /mcps, select valency, and press i to authenticate.\n' ;;
  esac
}

print_summary() {
  printf '\nSummary\n'
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    load_provider_metadata "$provider"
    read_provider_state "$provider" SELECTED
    provider_selected=$PROVIDER_STATE_VALUE
    read_provider_state "$provider" INSTALL_RESULT
    provider_install_result=$PROVIDER_STATE_VALUE
    read_provider_state "$provider" AUTH_RESULT
    provider_auth_result=$PROVIDER_STATE_VALUE
    if [ "$provider_selected" -eq 1 ] || [ "$provider_install_result" != "not selected" ]; then
      printf '  %s installation: %s\n' "$PROVIDER_LABEL" "$provider_install_result"
      printf '  %s authentication: %s\n' "$PROVIDER_LABEL" "$provider_auth_result"
      if plugin_ready_for_login "$provider_install_result" && [ "$provider_auth_result" != "authenticated" ] && [ "$provider_auth_result" != "already connected" ]; then
        print_provider_auth_guidance "$provider"
      fi
    fi
    provider_index=$((provider_index + 1))
  done
}

any_provider_state_equals() {
  field=$1
  expected=$2
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    read_provider_state "${PROVIDER_IDS[$provider_index]}" "$field"
    if [ "$PROVIDER_STATE_VALUE" = "$expected" ]; then return 0; fi
    provider_index=$((provider_index + 1))
  done
  return 1
}

report_no_supported_providers() {
  found_any=0
  provider_index=0
  while [ "$provider_index" -lt "${#PROVIDER_IDS[@]}" ]; do
    provider=${PROVIDER_IDS[$provider_index]}
    load_provider_metadata "$provider"
    read_provider_state "$provider" EXECUTABLE_FOUND
    if [ "$PROVIDER_STATE_VALUE" -eq 1 ]; then
      found_any=1
      printf 'Error: %s is installed but lacks required %s commands; upgrade it.\n' "$PROVIDER_LABEL" "$PROVIDER_COMPONENT" >&2
    fi
    provider_index=$((provider_index + 1))
  done
  if [ "$found_any" -eq 0 ]; then
    printf 'No supported provider CLIs were found on PATH (expected claude, codex, agy, gemini, copilot, or grok).\n' >&2
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
  if ! any_provider_state_equals AVAILABLE 1; then
    # Present-but-unsupported CLIs get a precise message; claiming nothing
    # was found on PATH would misdirect the user away from the real fix.
    report_no_supported_providers
    return 1
  fi

  select_requested_targets || return $?
  inspect_provider_state
  if ! any_provider_state_equals SELECTED 1; then
    # Every requested provider was unavailable or failed inspection; nothing
    # was changed.
    print_summary
    return 1
  fi
  inspect_auth_states
  print_plan
  authorize_migrations || return $?
  validate_migration_preflights
  if ! any_provider_state_equals SELECTED 1; then
    print_summary
    if [ "$PREINSTALL_FAILURES" -ne 0 ]; then
      return 1
    fi
    return 0
  fi
  confirm_plan || return 1

  if install_selected_providers; then
    install_status=0
  else
    install_status=$?
  fi
  prepare_authentication
  run_authentication
  print_summary
  if [ "$install_status" -ne 0 ] || [ "$PREINSTALL_FAILURES" -ne 0 ]; then
    return 1
  fi
}

# Keeping executable work behind the final main call makes a partial download
# inert: a truncated script can define helpers, but cannot mutate provider
# state. The braces make the invocation atomic: Bash only executes the block
# once the closing brace arrives, so a stream cut anywhere inside it — even
# directly after the word "main" — is a parse error rather than an
# argument-dropping invocation.
{
  main "$@"
}
