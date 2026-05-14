# tmux-superclick

[![tests](https://github.com/BatsShadow/tmux-superclick/actions/workflows/test.yml/badge.svg)](https://github.com/BatsShadow/tmux-superclick/actions/workflows/test.yml)

A tmux plugin that makes mouse clicks smarter.

## v1 feature: smart triple-click

Triple-click on a token of interest (URL, path, identifier with separators) and the **cleaned** token is copied to your clipboard. Triple-click on plain prose and the **entire line** is copied — matching native tmux behavior.

What gets stripped from a chunk before copying:

- Matched outer pairs: `()`, `[]`, `{}`, `<>`, `""`, `''`, `` `` ``
- Trailing `:line` or `:line:col` (e.g. `foo.py:42` → `foo.py`)
- Trailing `,.;:!?`
- Unmatched leading or trailing brackets / quotes / backticks (e.g. `'TEST:` → `TEST`, `url)` → `url`)

A token "looks interesting" — and therefore triggers chunk-copy — if, after cleaning, it contains any non-alphanumeric character. Plain words fall through to line-select.

### Examples

| You triple-click on                     | Clipboard gets                |
| --------------------------------------- | ----------------------------- |
| `(https://example.com),`                | `https://example.com`         |
| `"~/foo/bar.txt"`                       | `~/foo/bar.txt`               |
| `foo.py:42`                             | `foo.py`                      |
| `select-entire-hyphen-string`           | `select-entire-hyphen-string` |
| `/select/a/path:100`                    | `/select/a/path`              |
| any word in `this is a normal sentence` | the whole line                |

The cleaned range flashes briefly in the pane as it's copied — same visual feel as native double-click.

## Install

### Tmux Plugin Manager (TPM)

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'BatsShadow/tmux-superclick'
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
- `bash` 3.2+ (the default on macOS works)
- A UTF-8 locale (default on modern macOS / Linux). Falls back to `en_US.UTF-8` if `$LANG`/`$LC_ALL` aren't UTF-8.
- One of: `pbcopy` (macOS), `wl-copy` (Wayland), `xclip` / `xsel` (X11), or a terminal that supports OSC52

## Configuration

The plugin has one user-configurable option:

| Variable            | Default | Effect                                                            |
| ------------------- | ------- | ----------------------------------------------------------------- |
| `SUPERCLICK_DEBUG`  | `0`     | When `1`, every click writes a trace to `/tmp/tmux-superclick.log` |

Enable from inside tmux:

```tmux
tmux setenv -g SUPERCLICK_DEBUG 1
```

Then `tail -f /tmp/tmux-superclick.log` while clicking to see what the handler saw, what got cleaned, and where the selection landed. Lines are separated by a blank line between clicks. Unset with `tmux setenv -gu SUPERCLICK_DEBUG`.

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

Pure-bash unit tests, no extra deps:

```
./tests/test_clean.sh    # cleaning rules
./tests/test_cells.sh    # UTF-8 cell-aware string helper
```

CI runs both on every push and pull request — see the badge at the top.

## Known limitations (v1)

- Chunks wrapped across multiple display rows are not reassembled — only the clicked row is inspected.
- East Asian Wide / Fullwidth characters (CJK, some emoji) take 2 display cells but are counted as 1 by the cell helper, so they shift the highlight by one cell each.

## License

MIT
