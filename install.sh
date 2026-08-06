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

detect_provider_executables() {
  if command -v claude >/dev/null 2>&1; then
    CLAUDE_EXECUTABLE_FOUND=1
    if claude_has_required_commands; then
      CLAUDE_AVAILABLE=1
      if claude_has_auth_commands; then CLAUDE_AUTH_AVAILABLE=1; fi
    fi
  fi
  if command -v codex >/dev/null 2>&1; then
    CODEX_EXECUTABLE_FOUND=1
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

  if [ "$TARGET_ALL" -eq 1 ]; then
    CLAUDE_SELECTED=$CLAUDE_AVAILABLE
    CODEX_SELECTED=$CODEX_AVAILABLE
    # An installed provider whose CLI lacks the required commands is a
    # provider-specific failure, not a silent omission: --target all promised
    # every installed provider, so the run must end nonzero and say why.
    if [ "$CLAUDE_EXECUTABLE_FOUND" -eq 1 ] && [ "$CLAUDE_AVAILABLE" -eq 0 ]; then
      printf 'Error: Claude Code is installed but lacks required plugin commands; upgrade it or drop it from --target.\n' >&2
      CLAUDE_INSTALL_RESULT="failed (unsupported CLI)"
      PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
    fi
    if [ "$CODEX_EXECUTABLE_FOUND" -eq 1 ] && [ "$CODEX_AVAILABLE" -eq 0 ]; then
      printf 'Error: Codex is installed but lacks required plugin commands; upgrade it or drop it from --target.\n' >&2
      CODEX_INSTALL_RESULT="failed (unsupported CLI)"
      PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
    fi
  fi
  # Explicitly requested providers are failure-isolated like --target all:
  # one unavailable target must not prevent another requested, available
  # target from installing. The run still ends nonzero.
  if [ "$TARGET_CLAUDE" -eq 1 ]; then
    if [ "$CLAUDE_AVAILABLE" -eq 0 ]; then
      if [ "$CLAUDE_EXECUTABLE_FOUND" -eq 1 ]; then
        printf 'Error: Claude Code is installed but lacks required plugin commands; upgrade it.\n' >&2
        CLAUDE_INSTALL_RESULT="failed (unsupported CLI)"
      else
        printf 'Error: Claude Code was requested but its CLI is not on PATH.\n' >&2
        CLAUDE_INSTALL_RESULT="failed (not installed)"
      fi
      PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
    else
      CLAUDE_SELECTED=1
    fi
  fi
  if [ "$TARGET_CODEX" -eq 1 ]; then
    if [ "$CODEX_AVAILABLE" -eq 0 ]; then
      if [ "$CODEX_EXECUTABLE_FOUND" -eq 1 ]; then
        printf 'Error: Codex is installed but lacks required plugin commands; upgrade it.\n' >&2
        CODEX_INSTALL_RESULT="failed (unsupported CLI)"
      else
        printf 'Error: Codex was requested but its CLI is not on PATH.\n' >&2
        CODEX_INSTALL_RESULT="failed (not installed)"
      fi
      PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
    else
      CODEX_SELECTED=1
    fi
  fi
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
  CLAUDE_SELECTED=0
  CODEX_SELECTED=0
  menu_index=0
  while [ "$menu_index" -lt "${#MENU_IDS[@]}" ]; do
    if [ "${MENU_SELECTED[$menu_index]}" -eq 1 ]; then
      case ${MENU_IDS[$menu_index]} in
        claude) CLAUDE_SELECTED=1 ;;
        codex) CODEX_SELECTED=1 ;;
      esac
    fi
    menu_index=$((menu_index + 1))
  done
}

interactive_select_targets() {
  CLAUDE_SELECTED=$CLAUDE_AVAILABLE
  CODEX_SELECTED=$CODEX_AVAILABLE

  reset_menu "Select harnesses for Valency" "All detected harnesses" "Selected harnesses" 0 \
    "Install Valency for" "answer once for each detected harness."
  if [ "$CLAUDE_AVAILABLE" -eq 1 ]; then add_menu_item claude "Claude Code" 1; fi
  if [ "$CODEX_AVAILABLE" -eq 1 ]; then add_menu_item codex "Codex" 1; fi
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

inspect_provider_state() {
  # Inspection failures are provider-specific: one provider's unreadable state
  # must not block the other selected provider, so the failed provider is
  # reported, counted toward the exit status, and dropped before any mutation.
  if [ "$CLAUDE_SELECTED" -eq 1 ]; then
    if ! inspect_claude_state; then
      CLAUDE_SELECTED=0
      CLAUDE_INSTALL_RESULT="failed (state inspection)"
      PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
    elif [ "$CLAUDE_MARKETPLACE_CONFLICT" -eq 1 ]; then
      printf 'Error: an existing Claude Code marketplace named %s does not come from %s; Claude Code was not changed.\n' "$CLAUDE_MARKETPLACE" "$MARKETPLACE_SOURCE" >&2
      printf 'Review where it came from, then remove it and rerun this installer: claude plugin marketplace remove %s --scope user\n' "$CLAUDE_MARKETPLACE" >&2
      CLAUDE_SELECTED=0
      CLAUDE_INSTALL_RESULT="failed (marketplace conflict)"
      PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
    fi
  fi
  if [ "$CODEX_SELECTED" -eq 1 ] && ! inspect_codex_state; then
    CODEX_SELECTED=0
    CODEX_INSTALL_RESULT="failed (state inspection)"
    PREINSTALL_FAILURES=$((PREINSTALL_FAILURES + 1))
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

print_plan() {
  printf '\nValency installation plan\n'
  if [ "$CLAUDE_SELECTED" -eq 1 ]; then
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
  fi
  if [ "$CODEX_SELECTED" -eq 1 ]; then
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
  fi
  if [ "$AUTH_MODE" = "no" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '  Authentication: skipped; a real run prints the manual login commands.\n'
    else
      printf '  Authentication: skipped; manual login commands will be shown.\n'
    fi
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
  json_entry_contains "$compact_plugins" "\"pluginId\":\"$CODEX_PLUGIN\"" '"installed":true' '"enabled":true'
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
  reset_menu "Optional authentication" "All available providers" "Authentication" 1 \
    "Authenticate" "answer once for each available provider."
  if [ "$CLAUDE_SELECTED" -eq 1 ] && installation_succeeded "$CLAUDE_INSTALL_RESULT" && [ "$CLAUDE_AUTH_STATE" != "unavailable" ]; then
    add_menu_item claude "Claude Code ($CLAUDE_AUTH_STATE)" "$CLAUDE_AUTH_SELECTED"
  fi
  if [ "$CODEX_SELECTED" -eq 1 ] && installation_succeeded "$CODEX_INSTALL_RESULT" && [ "$CODEX_AUTH_STATE" != "unavailable" ]; then
    add_menu_item codex "Codex ($CODEX_AUTH_STATE)" "$CODEX_AUTH_SELECTED"
  fi

  run_multiselect
  menu_status=$?
  if [ "$menu_status" -ne 0 ]; then
    CLAUDE_AUTH_SELECTED=0
    CODEX_AUTH_SELECTED=0
    printf 'Authentication skipped.\n'
    return 0
  fi

  CLAUDE_AUTH_SELECTED=0
  CODEX_AUTH_SELECTED=0
  menu_index=0
  while [ "$menu_index" -lt "${#MENU_IDS[@]}" ]; do
    if [ "${MENU_SELECTED[$menu_index]}" -eq 1 ]; then
      case ${MENU_IDS[$menu_index]} in
        claude) CLAUDE_AUTH_SELECTED=1 ;;
        codex) CODEX_AUTH_SELECTED=1 ;;
      esac
    fi
    menu_index=$((menu_index + 1))
  done
}

run_authentication() {
  if [ "$DRY_RUN" -eq 1 ]; then
    if [ "$CLAUDE_AUTH_SELECTED" -eq 1 ]; then CLAUDE_AUTH_RESULT="planned"; fi
    if [ "$CODEX_AUTH_SELECTED" -eq 1 ]; then CODEX_AUTH_RESULT="planned"; fi
    finalize_unselected_auth_results
    return
  fi

  # Login output passes straight through to the user: device-code flows print
  # a URL the user must see, exactly as if they ran the login command by hand.
  # The installer never captures or re-prints that output itself.
  if [ "$CLAUDE_AUTH_SELECTED" -eq 1 ]; then
    if claude mcp login plugin:valency:valency <&3; then
      CLAUDE_AUTH_RESULT="authenticated"
    else
      CLAUDE_AUTH_RESULT="failed (plugin remains installed)"
      printf 'Warning: Claude Code authentication did not complete; the verified plugin remains installed.\n' >&2
    fi
  fi
  if [ "$CODEX_AUTH_SELECTED" -eq 1 ]; then
    if codex mcp login valency <&3; then
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
    if plugin_ready_for_login "$CLAUDE_INSTALL_RESULT" && [ "$CLAUDE_AUTH_RESULT" != "authenticated" ] && [ "$CLAUDE_AUTH_RESULT" != "already connected" ]; then
      if [ "$CLAUDE_AUTH_AVAILABLE" -eq 1 ]; then
        printf '  Manual Claude login: claude mcp login plugin:valency:valency\n'
      else
        printf '  This Claude Code version lacks mcp login; upgrade it, then run: claude mcp login plugin:valency:valency\n'
      fi
    fi
  fi
  if [ "$CODEX_SELECTED" -eq 1 ] || [ "$CODEX_INSTALL_RESULT" != "not selected" ]; then
    printf '  Codex installation: %s\n' "$CODEX_INSTALL_RESULT"
    printf '  Codex authentication: %s\n' "$CODEX_AUTH_RESULT"
    if plugin_ready_for_login "$CODEX_INSTALL_RESULT" && [ "$CODEX_AUTH_RESULT" != "authenticated" ] && [ "$CODEX_AUTH_RESULT" != "already connected" ]; then
      if [ "$CODEX_AUTH_AVAILABLE" -eq 1 ]; then
        printf '  Manual Codex login: codex mcp login valency\n'
      else
        printf '  This Codex version lacks mcp login; upgrade it, then run: codex mcp login valency\n'
      fi
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
    # Present-but-unsupported CLIs get a precise message; claiming nothing
    # was found on PATH would misdirect the user away from the real fix.
    if [ "$CLAUDE_EXECUTABLE_FOUND" -eq 1 ]; then
      printf 'Error: Claude Code is installed but lacks required plugin commands; upgrade it.\n' >&2
    fi
    if [ "$CODEX_EXECUTABLE_FOUND" -eq 1 ]; then
      printf 'Error: Codex is installed but lacks required plugin commands; upgrade it.\n' >&2
    fi
    if [ "$CLAUDE_EXECUTABLE_FOUND" -eq 0 ] && [ "$CODEX_EXECUTABLE_FOUND" -eq 0 ]; then
      printf 'No supported provider CLIs were found on PATH (expected claude or codex).\n' >&2
    fi
    return 1
  fi

  select_requested_targets || return $?
  inspect_provider_state
  if [ "$CLAUDE_SELECTED" -eq 0 ] && [ "$CODEX_SELECTED" -eq 0 ]; then
    # Every requested provider was unavailable or failed inspection; nothing
    # was changed.
    print_summary
    return 1
  fi
  inspect_auth_states
  print_plan
  authorize_migrations || return $?
  validate_migration_preflights
  if [ "$CLAUDE_SELECTED" -eq 0 ] && [ "$CODEX_SELECTED" -eq 0 ]; then
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
