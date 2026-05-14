# tmux-superclick

A tmux plugin that makes mouse clicks smarter.

## v1 feature: smart triple-click

Triple-click on a token of interest (URL, path, identifier with separators) and the **cleaned** token is copied to your clipboard. Triple-click on plain prose and the **entire line** is copied — matching native tmux behavior.

What gets stripped from a chunk before copying:

- Matched outer pairs: `()`, `[]`, `{}`, `<>`, `""`, `''`, `` `` ``
- Trailing `:line` or `:line:col` (e.g. `foo.py:42` → `foo.py`)
- Trailing `,.;:!?`
- Unmatched closing brackets (e.g. markdown `[txt](url)` clicked on the tail → `url`)

A token "looks interesting" — and therefore triggers chunk-copy — if, after cleaning, it contains any non-alphanumeric character. Plain words fall through to line-select.

### Examples

| You triple-click on | Clipboard gets |
| --- | --- |
| `(https://example.com),` | `https://example.com` |
| `"~/foo/bar.txt"` | `~/foo/bar.txt` |
| `foo.py:42` | `foo.py` |
| `select-entire-hyphen-string` | `select-entire-hyphen-string` |
| `/select/a/path:100` | `/select/a/path` |
| any word in `this is a normal sentence` | the whole line |

A brief `display-message` shows what was copied. (v1 does not flash an in-pane highlight; the confirmation message provides feedback. This may change later.)

## Install

### Tmux Plugin Manager (TPM)

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'YOUR-NAME/tmux-superclick'
```

Then `prefix + I` to install.

Mouse mode must be enabled:

```tmux
set -g mouse on
```

### Manual

```tmux
run-shell ~/path/to/tmux-superclick/superclick.tmux
```

## Requirements

- tmux 3.0+
- One of: `pbcopy` (macOS), `wl-copy` (Wayland), `xclip` / `xsel` (X11), or a terminal that supports OSC52
- Standard Unix tools (`awk`, `bash`)

## Manual smoke test

After installing, enable mouse mode and triple-click on each of the following lines in your terminal. The expected clipboard contents are listed.

```
(https://example.com),                 -> https://example.com
"~/foo/bar.txt"                        -> ~/foo/bar.txt
see foo.py:42 for details              -> foo.py    (when clicked on foo.py:42)
http://select-url.com                  -> http://select-url.com
select-entire-hyphen-string            -> select-entire-hyphen-string
/select/a/path:100                     -> /select/a/path
this selects the entire terminal line  -> the whole line (clicked anywhere)
```

## Tests

Unit tests for the cleaning function use plain bash — no extra deps:

```
./tests/test_clean.sh
```

## Known limitations (v1)

- Chunks wrapped across multiple display rows are not reassembled — only the clicked row is inspected.
- Multi-byte / wide characters (CJK, emoji) may shift column math by one cell.
- No in-pane highlight flash on copy (`display-message` confirmation only).
- No user-configurable options yet.

## License

MIT
