#!/usr/bin/env bash
# Tests for scripts/clean.sh
# Run: ./tests/test_clean.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLEAN="$SCRIPT_DIR/scripts/clean.sh"

pass=0
fail=0

check() {
  local desc="$1" input="$2" expected="$3"
  local actual
  actual=$(printf '%s' "$input" | "$CLEAN")
  if [[ "$actual" == "$expected" ]]; then
    pass=$((pass + 1))
    printf '  ok  %s\n' "$desc"
  else
    fail=$((fail + 1))
    printf 'FAIL  %s\n        input:    %q\n        expected: %q\n        actual:   %q\n' \
      "$desc" "$input" "$expected" "$actual"
  fi
}

check "url wrapped in parens with trailing comma" '(https://example.com),' 'https://example.com'
check "quoted home path" '"~/foo/bar.txt"' '~/foo/bar.txt'
check "backtick-wrapped command" '`git`' 'git'
check "path with :line suffix" 'foo.py:42' 'foo.py'
check "path with :line:col suffix" 'foo.py:42:10' 'foo.py'
check "plain url unchanged" 'http://select-url.com' 'http://select-url.com'
check "hyphen-string unchanged" 'select-entire-hyphen-string' 'select-entire-hyphen-string'
check "absolute path with :line" '/select/a/path:100' '/select/a/path'
check "plain word unchanged" 'hello' 'hello'
check "word with trailing dot" 'hello.' 'hello'
check "snake_case unchanged" 'foo_bar' 'foo_bar'
check "dotted version unchanged" '1.2.3' '1.2.3'
check "markdown link tail" 'url)' 'url'
check "matched parens around content" '(inside)' 'inside'
check "matched brackets" '[inside]' 'inside'
check "matched braces" '{inside}' 'inside'
check "matched angle brackets" '<inside>' 'inside'
check "single-quoted" "'inside'" 'inside'
check "nested parens" '((x))' 'x'
check "two separate paren groups not stripped" '(a)(b)' '(a)(b)'
check "trailing exclamation" 'wow!' 'wow'
check "trailing semicolon and bang" 'wow!;' 'wow'
check "url with markdown-style trailing paren" 'https://x.com)' 'https://x.com'
check "ipv6-ish no strip" '[::1]' '::1'
check "empty input" '' ''
check "all punctuation" '...' ''
check "unmatched leading single-quote" "'TEST:" 'TEST'
check "unmatched leading double-quote" '"hello' 'hello'
check "unmatched leading backtick" '`cmd' 'cmd'
check "unmatched leading paren" '(hello' 'hello'
check "balanced inline quote not stripped" "'hello'world" "'hello'world"
check "trailing unmatched single-quote then digits" "/tmp/foo.py:42'" "/tmp/foo.py"
check "trailing unmatched double-quote" 'hello"' 'hello'
check "trailing unmatched backtick" 'cmd`' 'cmd'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
