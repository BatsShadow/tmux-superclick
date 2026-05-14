#!/usr/bin/env bash
# Read a raw non-space chunk on stdin, write the cleaned chunk on stdout.
#
# Cleaning rules (applied repeatedly until stable):
#   1. Strip a matched outer pair: () [] {} <> "" '' ``
#      - For brackets, the pair must be balanced across the whole string
#        (depth returns to zero only at the final character).
#      - For quotes/backticks, the middle must not contain the quote.
#   2. Strip a trailing :digits or :digits:digits group.
#   3. Strip trailing ,.;:!? punctuation.
#   4. Strip an unmatched closing ) ] } > when the matching opener is absent.
set -u

is_balanced_pair() {
  local s="$1" open="$2" close="$3"
  local len=${#s} depth=0 i
  for ((i = 0; i < len; i++)); do
    local c="${s:i:1}"
    [[ "$c" == "$open" ]] && depth=$((depth + 1))
    [[ "$c" == "$close" ]] && depth=$((depth - 1))
    if ((depth == 0)) && ((i < len - 1)); then
      return 1
    fi
  done
  ((depth == 0))
}

strip_outer_pair() {
  local s="$1"
  local len=${#s}
  ((len < 2)) && { printf '%s' "$s"; return; }
  local first="${s:0:1}" last="${s:len-1:1}"
  local middle="${s:1:len-2}"
  case "$first$last" in
    '""'|"''"|'``')
      if [[ "$middle" != *"$first"* ]]; then
        printf '%s' "$middle"; return
      fi
      ;;
    '()')
      if is_balanced_pair "$s" '(' ')'; then
        printf '%s' "$middle"; return
      fi
      ;;
    '[]')
      if is_balanced_pair "$s" '[' ']'; then
        printf '%s' "$middle"; return
      fi
      ;;
    '{}')
      if is_balanced_pair "$s" '{' '}'; then
        printf '%s' "$middle"; return
      fi
      ;;
    '<>')
      if is_balanced_pair "$s" '<' '>'; then
        printf '%s' "$middle"; return
      fi
      ;;
  esac
  printf '%s' "$s"
}

strip_trailing_line_suffix() {
  local s="$1"
  [[ "$s" =~ ^(.*[^:0-9])(:[0-9]+){1,2}$ ]] && s="${BASH_REMATCH[1]}"
  printf '%s' "$s"
}

strip_trailing_punct() {
  local s="$1"
  [[ "$s" =~ ^(.*[^,.\;:!?])[,.\;:!?]+$ ]] && s="${BASH_REMATCH[1]}"
  # Handle the case where the whole string is punctuation.
  [[ "$s" =~ ^[,.\;:!?]+$ ]] && s=""
  printf '%s' "$s"
}

strip_unmatched_closer() {
  local s="$1"
  local len=${#s}
  ((len == 0)) && { printf '%s'; return; }
  local last="${s:len-1:1}"
  local rest="${s:0:len-1}"
  case "$last" in
    ')') [[ "$rest" != *'('* ]] && s="$rest" ;;
    ']') [[ "$rest" != *'['* ]] && s="$rest" ;;
    '}') [[ "$rest" != *'{'* ]] && s="$rest" ;;
    '>') [[ "$rest" != *'<'* ]] && s="$rest" ;;
    '"') [[ "$rest" != *'"'* ]] && s="$rest" ;;
    "'") [[ "$rest" != *"'"* ]] && s="$rest" ;;
    '`') [[ "$rest" != *'`'* ]] && s="$rest" ;;
  esac
  printf '%s' "$s"
}

strip_unmatched_opener() {
  local s="$1"
  local len=${#s}
  ((len == 0)) && { printf '%s'; return; }
  local first="${s:0:1}"
  local rest="${s:1}"
  case "$first" in
    '(') [[ "$rest" != *')'* ]] && s="$rest" ;;
    '[') [[ "$rest" != *']'* ]] && s="$rest" ;;
    '{') [[ "$rest" != *'}'* ]] && s="$rest" ;;
    '<') [[ "$rest" != *'>'* ]] && s="$rest" ;;
    '"') [[ "$rest" != *'"'* ]] && s="$rest" ;;
    "'") [[ "$rest" != *"'"* ]] && s="$rest" ;;
    '`') [[ "$rest" != *'`'* ]] && s="$rest" ;;
  esac
  printf '%s' "$s"
}

clean() {
  local s="$1" prev=""
  while [[ "$s" != "$prev" ]]; do
    prev="$s"
    s=$(strip_outer_pair "$s")
    s=$(strip_trailing_line_suffix "$s")
    s=$(strip_trailing_punct "$s")
    s=$(strip_unmatched_closer "$s")
    s=$(strip_unmatched_opener "$s")
  done
  printf '%s' "$s"
}

input=$(cat)
clean "$input"
