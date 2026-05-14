#!/usr/bin/env bash
# tmux-superclick triple-click handler.
#
# Args: <pane_id> <mouse_x> <mouse_y>
#   mouse_x / mouse_y are pane-relative, 0-indexed, supplied by tmux's
#   #{mouse_x} and #{mouse_y} format strings.
#
# Behavior:
#   - Extracts the maximal non-space chunk on the clicked row.
#   - Cleans it (see scripts/clean.sh).
#   - If the cleaned chunk contains any non-alphanumeric character, copies
#     the cleaned chunk to the system clipboard ("chunk-copy").
#   - Otherwise copies the entire clicked line ("line-select"), matching
#     native triple-click semantics.
#   - In both cases, shows a tmux display-message confirming what was copied.
set -u

pane_id="${1:-}"
mouse_x="${2:-0}"
mouse_y="${3:-0}"

if [[ -z "$pane_id" ]]; then
  exit 0
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"

row=$(tmux capture-pane -p -t "$pane_id" -S "$mouse_y" -E "$mouse_y" 2>/dev/null) || exit 0

chunk=$(awk -v col="$mouse_x" '
  {
    n = length($0)
    if (col >= n) exit
    if (substr($0, col + 1, 1) ~ /[[:space:]]/) exit
    start = col
    while (start > 0 && substr($0, start, 1) !~ /[[:space:]]/) start--
    if (substr($0, start + 1, 1) ~ /[[:space:]]/) start++
    end = col
    while (end < n - 1 && substr($0, end + 2, 1) !~ /[[:space:]]/) end++
    print substr($0, start + 1, end - start + 1)
  }
' <<<"$row")

clipboard_cmd=$("$script_dir/clipboard.sh")

copy_and_announce() {
  local text="$1" kind="$2"
  printf '%s' "$text" | eval "$clipboard_cmd"
  # Truncate for the status message so long URLs don't blow out the line.
  local preview="$text"
  if ((${#preview} > 60)); then
    preview="${preview:0:57}..."
  fi
  tmux display-message -t "$pane_id" "superclick: copied $kind: $preview"
}

if [[ -z "$chunk" ]]; then
  # Clicked on whitespace or past EOL — fall back to the whole row, trimmed.
  trimmed="${row#"${row%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  [[ -z "$trimmed" ]] && exit 0
  copy_and_announce "$trimmed" "line"
  exit 0
fi

cleaned=$(printf '%s' "$chunk" | "$script_dir/clean.sh")

if [[ -n "$cleaned" && "$cleaned" =~ [^A-Za-z0-9] ]]; then
  copy_and_announce "$cleaned" "chunk"
else
  trimmed="${row#"${row%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  [[ -z "$trimmed" ]] && exit 0
  copy_and_announce "$trimmed" "line"
fi
