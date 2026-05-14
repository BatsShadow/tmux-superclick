# tmux-superclick: Triple-Click Smart Select — Design

## Overview

A tmux plugin that intercepts mouse events to make common terminal selections faster. The first feature: a triple-click selects and copies the "interesting token" under the cursor (URL, path, identifier) instead of the entire line, falling back to native line-select for plain prose.

The plugin is pure shell + tmux config, installable via TPM, with no external dependencies beyond standard Unix tools and a platform clipboard utility (`pbcopy` / `xclip` / `wl-copy`).

## Repository Layout

```
tmux-superclick/
├── superclick.tmux          # entry script tmux sources; binds mouse events
├── scripts/
│   ├── triple-click.sh      # handles a triple-click event
│   └── clipboard.sh         # detects and invokes the platform clipboard tool
├── tests/
│   └── clean.bats           # unit tests for the cleaning function
└── README.md
```

`superclick.tmux` binds `TripleClick1Pane` (root key table) to invoke `scripts/triple-click.sh` with the pane id and mouse coordinates. The plugin does **not** modify `word-separators` or other global options, so native double-click behavior is preserved.

## Triple-Click Flow

1. **Read click position** from tmux: `#{mouse_x}`, `#{mouse_y}`, target pane id.
2. **Capture the clicked row** of the pane (`tmux capture-pane -p -t <pane>`), then extract the maximal non-space run containing the clicked column. Record its raw start/end columns.
3. **Clean** the raw chunk (see Cleaning Rules). Because all cleaning rules strip from the edges only, the cleaned chunk remains a contiguous sub-range of the raw run; track adjusted start/end columns.
4. **Decide behavior** by inspecting the cleaned chunk:
   - If it contains **any non-alphanumeric character** → chunk-copy
   - Otherwise → fall back to native line-select
5. **Execute** the chosen behavior (see below). Both paths end in copy-mode being cancelled, leaving the user back at the shell prompt with the clipboard populated.

### Chunk-copy path

Enter copy-mode, position the cursor at the cleaned chunk's start column, begin selection, move to its end column, and issue `copy-pipe-and-cancel` piping the selection through the clipboard helper. tmux briefly highlights the cleaned range, copies it, and exits copy-mode — matching the visual feel of native double-click.

### Line-select fallback path

Enter copy-mode and issue the native sequence: `select-line` followed by `copy-pipe-and-cancel` through the clipboard helper. Visually and behaviorally indistinguishable from default tmux triple-click.

## Cleaning Rules

Applied in order to the raw non-space chunk:

1. **Strip matched outer pairs**, repeatedly until stable: `(…)`, `[…]`, `{…}`, `<…>`, `"…"`, `'…'`, `` `…` ``
2. **Strip trailing `:digits`** (one or two `:N` groups): `foo.py:42` → `foo.py`, `foo.py:42:10` → `foo.py`
3. **Strip trailing punctuation**: one or more of `,.;:!?`
4. **Strip unmatched closers**: if the chunk ends in `)`, `]`, `}`, or `>` and the matching opener does not appear inside, drop the closer (handles markdown-link case `[txt](url)` where the click landed inside `url)`)

### Example transforms

| Raw chunk | Cleaned | Behavior |
|-----------|---------|----------|
| `(https://example.com),` | `https://example.com` | chunk-copy |
| `"~/foo/bar.txt"` | `~/foo/bar.txt` | chunk-copy |
| `` `git` `` | `git` | line-select (plain word) |
| `foo.py:42` | `foo.py` | chunk-copy |
| `http://select-url.com` | `http://select-url.com` | chunk-copy |
| `select-entire-hyphen-string` | `select-entire-hyphen-string` | chunk-copy |
| `/select/a/path:100` | `/select/a/path` | chunk-copy |
| `hello` | `hello` | line-select |
| `hello.` | `hello` | line-select |
| `foo_bar` | `foo_bar` | chunk-copy (`_` is non-alphanumeric) |

## Trigger Heuristic

After cleaning, the chunk triggers chunk-copy iff it contains at least one character outside `[A-Za-z0-9]`. This ensures:

- URLs, paths, emails, hyphenated/underscored identifiers, and similar tokens are captured as chunks.
- Plain prose words fall back to line-select, matching the user's prior triple-click expectation.

## Clipboard Helper

`scripts/clipboard.sh` detects the platform at runtime and outputs the appropriate command:

- macOS: `pbcopy`
- Linux + Wayland: `wl-copy` (if `WAYLAND_DISPLAY` set and binary present)
- Linux + X11: `xclip -selection clipboard` (if `DISPLAY` set and binary present)
- Fallback: OSC52 escape sequence via tmux (`tmux load-buffer` + `tmux show-buffer` piped, or direct OSC52 emit) so remote sessions still work

This matches the approach used by tmux-yank.

## Non-Goals (v1)

- **Soft-wrapped chunks** spanning multiple display rows — only the clicked row is inspected.
- **Wide / multi-byte chars** (CJK, emoji) — column math may be off by a cell; documented limitation.
- **Type-aware actions** (open URL in browser vs. open path in editor) — copy only.
- **Configuration options** (`@superclick-*` user settings) — opinionated defaults; revisit when a real need appears.
- **Behavior in copy-mode** — binding is on the root table only; copy-mode triple-click is untouched.

## Testing

- **Unit tests (bats)** for the cleaning function: feed raw strings, assert cleaned output and chunk-vs-line decision. Covers every row of the example table plus edge cases (empty after cleaning, all-punctuation, nested pairs).
- **Manual smoke tests** in tmux: a fixture script that prints a known set of strings; a README checklist of what each triple-click should produce.

## Future Extensions

No immediate plans. Possibilities if interest arises:

- Type detection and per-type actions (open URL, open `path:line` in `$EDITOR`).
- Configurable trigger rules and cleaning behavior.
- Multi-row chunk reassembly for soft-wrapped URLs.
- Double-click overrides for richer word selection.
