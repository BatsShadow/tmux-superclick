#!/usr/bin/env bash
# Print a shell command that reads text on stdin and copies it to the
# system clipboard. Used by triple-click.sh as the command passed to
# tmux's `copy-pipe-and-cancel`.
#
# Detection order:
#   macOS                       -> pbcopy
#   Wayland (wl-copy present)   -> wl-copy
#   X11    (xclip   present)    -> xclip -selection clipboard
#   X11    (xsel    present)    -> xsel  --clipboard --input
#   fallback                    -> tmux load-buffer (also emits OSC52 to
#                                  the terminal so a local terminal can
#                                  pick it up over SSH)
set -u

case "$(uname -s)" in
  Darwin)
    printf 'pbcopy'
    exit 0
    ;;
esac

if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
  printf 'wl-copy'
  exit 0
fi

if [[ -n "${DISPLAY:-}" ]]; then
  if command -v xclip >/dev/null 2>&1; then
    printf 'xclip -selection clipboard -in'
    exit 0
  fi
  if command -v xsel >/dev/null 2>&1; then
    printf 'xsel --clipboard --input'
    exit 0
  fi
fi

# Fallback: stash in tmux's own buffer. tmux is configured (via
# `set -g set-clipboard on`) to emit OSC52 so the outer terminal copies
# it as well; if not, the user can still paste with prefix-].
printf 'tmux load-buffer -'
