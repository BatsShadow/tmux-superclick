#!/usr/bin/env bash
# UTF-8 cell-aware string helper for tmux-superclick.
#
# macOS's default awk counts bytes, which throws off column math when the
# row contains multi-byte UTF-8 (e.g. `└─` from a powerline prompt: 3
# bytes per char but 1 display cell each). Bash itself is char-aware for
# ${#var} and ${var:i:n} when the locale is UTF-8, so we just need a
# locale guard plus a tiny CLI wrapper.
#
# Assumes 1 cell per character. East Asian Wide / Fullwidth chars (CJK,
# some emoji) take 2 cells each and would shift positions; not handled
# in v1.
#
# Subcommands:
#   chunk <col>     Read one line of text on stdin. Locate the maximal
#                   non-space run containing display cell <col>. Print
#                   "<start_cell><TAB><chunk>". Exit 1 if no chunk.
#   find <needle>   Read text on stdin; print the cell offset where
#                   <needle> first appears. Exit 1 if absent.
#   len             Read text on stdin; print its cell width.

# Ensure char-aware string operators. Most macOS / Linux setups already
# have a UTF-8 LANG; this is a belt-and-braces fallback.
if [[ "${LANG:-}" != *UTF-8* && "${LC_ALL:-}" != *UTF-8* ]]; then
  export LC_ALL=en_US.UTF-8
fi

_is_space() {
  case "$1" in
    " "|$'\t'|$'\n'|$'\r') return 0 ;;
  esac
  return 1
}

cmd="${1:-}"
case "$cmd" in
  chunk)
    col="${2:?usage: cells.sh chunk <col>}"
    # read returns non-zero on EOF without trailing newline, but it still
    # populates $row with whatever it got — don't reset it.
    IFS= read -r row || :
    n=${#row}
    if (( col >= n )); then exit 1; fi
    if _is_space "${row:col:1}"; then exit 1; fi
    s=$col; e=$col
    while (( s > 0 )) && ! _is_space "${row:s-1:1}"; do s=$((s - 1)); done
    while (( e < n - 1 )) && ! _is_space "${row:e+1:1}"; do e=$((e + 1)); done
    printf '%d\t%s\n' "$s" "${row:s:e-s+1}"
    ;;
  find)
    needle="${2:?usage: cells.sh find <needle>}"
    haystack=$(cat)
    prefix="${haystack%%"$needle"*}"
    if [[ "$prefix" == "$haystack" && "$haystack" != "$needle" ]]; then
      exit 1
    fi
    printf '%d\n' "${#prefix}"
    ;;
  len)
    text=$(cat)
    printf '%d\n' "${#text}"
    ;;
  *)
    printf 'usage: %s {chunk <col> | find <needle> | len}\n' "$0" >&2
    exit 2
    ;;
esac
