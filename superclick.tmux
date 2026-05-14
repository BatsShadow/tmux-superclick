#!/usr/bin/env bash
# tmux-superclick entry script. Sourced by tmux on plugin load (TPM) or
# by `run-shell '/path/to/superclick.tmux'` in tmux.conf.
set -u

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HANDLER="$CURRENT_DIR/scripts/triple-click.sh"

tmux bind-key -n TripleClick1Pane \
  run-shell "$HANDLER '#{pane_id}' '#{mouse_x}' '#{mouse_y}'"
