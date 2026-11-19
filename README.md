# Personal X11 desktop configuration

Shared configuration for my Linux devices running i3 on X11. The configs were
seeded from the current host; only i3 has a separate section for host-specific
settings.

| Repo file | Host destination |
| --- | --- |
| `.vimrc` | `~/.vimrc` |
| `.config/i3/config` | `~/.config/i3/config` |
| `.config/i3status/config` | `~/.config/i3status/config` |
| `.config/kitty/kitty.conf` | `~/.config/kitty/kitty.conf` |
| `.config/dunst/dunstrc` | `~/.config/dunst/dunstrc` |

The `.config` destinations respect `XDG_CONFIG_HOME` when set. Vim, i3status,
Kitty, and Dunst are synced as whole files.

Run these commands from the repo:

```bash
./sync.sh              # Repo → host
./sync.sh --from-host  # Host → repo; does not stage or commit anything
```

The script also works when invoked by its absolute path from another directory.
It processes files in the table's order and shows a coloured unified diff for
each change: red lines are removed and green lines are added. Enter `y` to
apply, `n` or Enter to skip, or `q` to stop. EOF also stops; unchanged files need
no confirmation. Changes accepted earlier remain applied if you quit or a later
file fails.

No destination changes before confirmation. Missing destinations and their
parent directories are created only after approval. Existing symlinks and file
permissions are preserved, replacements are atomic, and edits made to a target
while its diff is open cause the script to stop rather than overwrite them.
Missing or non-regular source files cause an error.

Put host-specific i3 settings below this line in the host's config.

```text
# === local overrides ===
```

For repo → host, `sync.sh` writes the shared config followed by the marker
and any existing host overrides. It adds an empty line on each side of the
marker and reuses an existing empty line immediately after it.
For host → repo, the marker, the empty line immediately before it, and
everything below it are excluded. The repo's source config must contain only
shared settings.
Without a host marker, host → repo copies the entire i3 file.
Duplicate host markers are rejected. Repo → host also rejects a marker in the
repo config and validates the merged i3 config with `i3 -C` before prompting.

Keep monitor scripts, machine-specific startup tasks, optional Playerctl
bindings, and the systemd graphical-session helper below the marker. When
promoting settings to the shared config, remove their local copies before the
next sync to avoid duplicate bindings. The old plain dashed divider is not
recognized.

The shared settings provide:

- **Vim:** four-column indentation, line numbers, an 80-column guide, visible
  whitespace, mouse input disabled, Insert-mode Ctrl+D to change the current
  word, and `<leader>[` / `<leader>]` to comment or uncomment lines/selections.
  Escape in Normal mode clears search matches, with a guard for mappings lost
  during Kitty keyboard negotiation. i3 syntax highlighting tracks context from
  the start of the file to avoid false errors after scrolling into nested blocks.
- **i3:** a dark blue palette, tabbed workspaces, Kitty as the terminal, dmenu as
  the launcher, US keyboard layout, and directional workspace movement between
  monitors. Startup includes dex, xss-lock/i3lock, nm-applet, Dunst, and Flameshot.
- **i3status:** network connections, volume, root filesystem space, load, memory,
  and local date/time.
- **Kitty:** Fira Code 12 and copy-on-select to the system clipboard.
- **Dunst:** Fira Code 10 body text, larger regular-weight pale-blue titles,
  600-pixel width, and increased padding. Normal notifications use dark blue,
  low-priority ones use navy, and critical alerts retain red styling.

| Shared shortcut | Action |
| --- | --- |
| Volume keys / Alt+G / Alt+H | Adjust default output volume in 4% steps |
| Speaker / microphone mute keys | Toggle the default output / input mute |
| Print | Copy a fullscreen screenshot |
| Alt+S | Open the Flameshot screenshot selector |
| Alt+A | Copy and save a fullscreen screenshot, then play the capture sound |

Alt+A uses `~/Pictures/screenshots` and
`/usr/share/sounds/freedesktop/stereo/screen-capture.oga`; provide that directory
and the freedesktop sound theme on each device. Audio controls use `pactl`, so
they need PulseAudio or PipeWire's PulseAudio compatibility server. Fira Code
must be installed for the configured font to render as intended.

The script requires Bash and GNU coreutils/diffutils, plus `awk`. Before syncing
to a host, it checks for all desktop commands used by the shared configuration:
`vim`, `i3`, `i3bar`, `i3-msg`, `i3-nagbar`, `i3status`, `kitty`, `dmenu_run`,
`dex`, `xss-lock`, `i3lock`, `nm-applet`, `setxkbmap`, `pactl`, `killall`,
`dunst`, `dmenu`, `xdg-open`, `flameshot`, and `paplay`. Missing commands are
listed together and stop the script before any prompts. Importing with
`--from-host` checks only the script's file-handling tools. It does not install
packages or check dependencies used only by local overrides. Keep the explicit
command list in `sync.sh` updated when changing shared configs.

After accepting changes, reload the relevant application yourself:

```bash
i3-msg reload
dunstctl reload
```

Normal i3 startup commands run on the next session start, not on config reload.
Dunst finds `${XDG_CONFIG_HOME:-$HOME/.config}/dunst/dunstrc` automatically, so
its startup command needs no explicit path. Reload Kitty's configuration or
restart it; in Vim, use `:source ~/.vimrc`. For an already-open i3 buffer, use
`:syntax sync fromstart` and Ctrl+L to resynchronize and redraw highlighting.
`:noh` and `:nohlsearch` are the same command and clear only search matches.

Run the checks from the repo (requires ShellCheck, Python 3, and a recent Vim):

```bash
bash -n sync.sh tests/sync.sh
shellcheck sync.sh tests/sync.sh
./tests/sync.sh
python3 tests/vim-escape.py
vim -Nu "$PWD/.vimrc" -i NONE -n -es -S tests/vim-syntax.vim
i3 -C -c .config/i3/config
```

The sync checks use temporary host/repo fixtures. The Vim checks cover plain
terminal and Kitty-protocol Escape input, and highlighting inside long nested
i3 blocks. They do not change the host's config files.
