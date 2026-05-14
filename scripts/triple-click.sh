#!/usr/bin/env bash
# tmux-superclick triple-click handler.
#
# Args: <pane_id> <mouse_x> <mouse_y>
#   mouse_x / mouse_y are pane-relative, 0-indexed (from tmux's
#   #{mouse_x} / #{mouse_y} format strings).
#
# Flow:
#   1. Capture the clicked row.
#   2. Extract the maximal non-space chunk under the cursor.
#   3. Clean it; decide chunk-copy vs line-select.
#   4. Copy directly to the system clipboard.
#   5. Briefly highlight the matching range by entering copy-mode,
#      navigating to (cx, cy), making the selection, sleeping, cancelling.
#
# Debug: set SUPERCLICK_DEBUG=1 to log to /tmp/tmux-superclick.log.
set -u

LOG=/tmp/tmux-superclick.log
log() {
  [[ "${SUPERCLICK_DEBUG:-0}" == "1" ]] || return 0
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG"
}

pane="${1:-}"
cx="${2:-0}"
cy="${3:-0}"

[[ -z "$pane" ]] && { log "no pane id; aborting"; exit 0; }

# Blank line in the log between clicks for readability.
[[ "${SUPERCLICK_DEBUG:-0}" == "1" ]] && printf '\n' >>"$LOG"

script_dir="$(cd "$(dirname "$0")" && pwd)"
clipboard=$("$script_dir/clipboard.sh")
CELLS="$script_dir/cells.sh"

log "click pane=$pane cx=$cx cy=$cy"

row=$(tmux capture-pane -p -t "$pane" -S "$cy" -E "$cy" 2>/dev/null || true)
log "row=$(printf '%q' "$row")"

# Cell-aware chunk extraction. `cells.sh chunk` prints "<start>\t<chunk>"
# or exits 1 when there's nothing under the cursor.
extracted=$(printf '%s\n' "$row" | "$CELLS" chunk "$cx" || true)
log "extracted=$(printf '%q' "$extracted")"

trimmed_row="${row#"${row%%[![:space:]]*}"}"
trimmed_row="${trimmed_row%"${trimmed_row##*[![:space:]]}"}"

do_copy() {
  local text="$1" kind="$2"
  if [[ -z "$text" ]]; then
    log "nothing to copy ($kind)"
    return
  fi
  printf '%s' "$text" | eval "$clipboard"
  log "copied ($kind, ${#text} chars): $(printf '%q' "$text")"
}

# Enter copy-mode and move the cursor to (target_x, target_y). Done in
# two phases:
#   1. Move row via cursor-up/cursor-down — works on screen rows
#      (cursor-up/down just adjust data->cy).
#   2. Re-query the cursor position. tmux's copy-mode tracks a "preferred
#      column" that gets adjusted across rows of differing widths, so the
#      cx after a row move is *not* generally what it was before. Recompute
#      the column delta from the new position, then move cx.
navigate_to() {
  local target_x="$1" target_y="$2"
  tmux copy-mode -t "$pane"
  tmux send-keys -t "$pane" -X clear-selection

  local init pos_x pos_y
  init=$(tmux display-message -t "$pane" -p '#{copy_cursor_x},#{copy_cursor_y}' 2>/dev/null || echo "0,0")
  pos_x=${init%%,*}
  pos_y=${init##*,}
  log "navigate: init=($pos_x,$pos_y) target=($target_x,$target_y)"

  local dy=$(( target_y - pos_y ))
  if (( dy > 0 )); then
    tmux send-keys -t "$pane" -X -N "$dy" cursor-down
  elif (( dy < 0 )); then
    tmux send-keys -t "$pane" -X -N "$(( -dy ))" cursor-up
  fi

  # Re-query: tmux may have shifted cx during the vertical move.
  local after_row
  after_row=$(tmux display-message -t "$pane" -p '#{copy_cursor_x},#{copy_cursor_y}' 2>/dev/null || echo "0,0")
  pos_x=${after_row%%,*}
  pos_y=${after_row##*,}
  log "navigate: after_row=($pos_x,$pos_y)"

  local dx=$(( target_x - pos_x ))
  if (( dx > 0 )); then
    tmux send-keys -t "$pane" -X -N "$dx" cursor-right
  elif (( dx < 0 )); then
    tmux send-keys -t "$pane" -X -N "$(( -dx ))" cursor-left
  fi

  local final
  final=$(tmux display-message -t "$pane" -p '#{copy_cursor_x},#{copy_cursor_y}' 2>/dev/null || echo "n/a")
  log "navigate: final=$final"
}

schedule_cancel() {
  ( sleep 0.25; tmux send-keys -t "$pane" -X cancel 2>/dev/null; log "cancelled copy-mode" ) &
  disown 2>/dev/null || true
}

flash_chunk() {
  local start_col="$1" len="$2"
  log "flash chunk: start_col=$start_col len=$len"
  navigate_to "$start_col" "$cy"
  tmux send-keys -t "$pane" -X begin-selection
  if (( len > 1 )); then
    tmux send-keys -t "$pane" -X -N "$((len - 1))" cursor-right
  fi
  schedule_cancel
}

flash_line() {
  log "flash line"
  navigate_to "$cx" "$cy"
  tmux send-keys -t "$pane" -X select-line
  schedule_cancel
}

if [[ -z "$extracted" ]]; then
  log "no chunk under cursor -> line-select"
  do_copy "$trimmed_row" "line"
  flash_line
  exit 0
fi

IFS=$'\t' read -r raw_start_cell raw <<<"$extracted"
cleaned=$(printf '%s' "$raw" | "$script_dir/clean.sh")
log "raw_start_cell=$raw_start_cell raw=$(printf '%q' "$raw") cleaned=$(printf '%q' "$cleaned")"

if [[ -z "$cleaned" ]] || ! [[ "$cleaned" =~ [^A-Za-z0-9] ]]; then
  log "plain word -> line-select"
  do_copy "$trimmed_row" "line"
  flash_line
  exit 0
fi

offset_in_raw_cell=$(printf '%s\n' "$raw" | "$CELLS" find "$cleaned" || echo -1)
if (( offset_in_raw_cell < 0 )); then
  log "cleaned not in raw; falling back to line-select"
  do_copy "$trimmed_row" "line"
  flash_line
  exit 0
fi

cleaned_start_cell=$(( raw_start_cell + offset_in_raw_cell ))
cleaned_cell_len=$(printf '%s\n' "$cleaned" | "$CELLS" len)
log "offset=$offset_in_raw_cell cleaned_start_cell=$cleaned_start_cell cleaned_cell_len=$cleaned_cell_len"

do_copy "$cleaned" "chunk"
flash_chunk "$cleaned_start_cell" "$cleaned_cell_len"
