#!/usr/bin/env bash
# Tests for scripts/cells.sh (UTF-8 cell-aware string helper).
# Run: ./tests/test_cells.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CELLS="$SCRIPT_DIR/scripts/cells.sh"

pass=0
fail=0

check() {
  local desc="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass + 1))
    printf '  ok  %s\n' "$desc"
  else
    fail=$((fail + 1))
    printf 'FAIL  %s\n        expected: %q\n        actual:   %q\n' \
      "$desc" "$expected" "$actual"
  fi
}

# --- chunk ----------------------------------------------------------------

out=$(printf '%s\n' 'foo bar baz' | "$CELLS" chunk 4)
check "chunk: ascii middle word" "$out" $'4\tbar'

out=$(printf '%s\n' 'foo bar baz' | "$CELLS" chunk 0)
check "chunk: at start" "$out" $'0\tfoo'

out=$(printf '%s\n' 'foo bar baz' | "$CELLS" chunk 10)
check "chunk: at last char" "$out" $'8\tbaz'

# Multi-byte: `└─ echo https://example.com` — clicking on cell 12 ('s')
# should give the URL starting at cell 8.
out=$(printf '%s\n' '└─ echo https://example.com' | "$CELLS" chunk 12)
check "chunk: utf8 prefix, click inside URL" "$out" $'8\thttps://example.com'

# Click on the box-drawing char itself.
out=$(printf '%s\n' '└─ hi' | "$CELLS" chunk 0)
check "chunk: click on multi-byte char" "$out" $'0\t└─'

# Click on whitespace -> exit 1, no output.
out=$(printf '%s\n' 'foo bar' | "$CELLS" chunk 3 || echo "EMPTY")
check "chunk: click on space -> empty" "$out" "EMPTY"

# Click past end -> exit 1.
out=$(printf '%s\n' 'foo' | "$CELLS" chunk 99 || echo "EMPTY")
check "chunk: click past end -> empty" "$out" "EMPTY"

# --- find -----------------------------------------------------------------

out=$(printf '%s\n' 'foo bar baz' | "$CELLS" find 'bar')
check "find: ascii mid" "$out" "4"

out=$(printf '%s\n' 'foo bar baz' | "$CELLS" find 'foo')
check "find: ascii at start" "$out" "0"

out=$(printf '%s\n' '└─https://example.com' | "$CELLS" find 'https')
check "find: after utf8 prefix" "$out" "2"

out=$(printf '%s\n' 'no match here' | "$CELLS" find 'xyz' || echo "EMPTY")
check "find: missing -> empty" "$out" "EMPTY"

out=$(printf '%s\n' 'identical' | "$CELLS" find 'identical')
check "find: whole-string match -> 0" "$out" "0"

# --- len ------------------------------------------------------------------

out=$(printf '%s\n' 'hello' | "$CELLS" len)
check "len: ascii" "$out" "5"

out=$(printf '%s\n' '└─' | "$CELLS" len)
check "len: box-drawing chars" "$out" "2"

out=$(printf '%s\n' 'https://exámple.com' | "$CELLS" len)
check "len: mixed ascii + accented" "$out" "19"

out=$(printf '%s\n' '' | "$CELLS" len)
check "len: empty" "$out" "0"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
