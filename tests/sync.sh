#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
marker='# === local overrides ==='
fixture=$test_dir/repo\ with\ spaces
mkdir -p "$fixture/.config/i3" "$fixture/.config/i3status" "$fixture/.config/kitty" "$fixture/.config/dunst"
cp "$repo_dir/sync.sh" "$fixture/sync.sh"
printf 'new vim\n' > "$fixture/.vimrc"
printf 'new shared\n' > "$fixture/.config/i3/config"
printf 'new status\n' > "$fixture/.config/i3status/config"
printf 'font_size 12.0\n' > "$fixture/.config/kitty/kitty.conf"
printf '[global]\nfont = "Fira Code 10"\n' > "$fixture/.config/dunst/dunstrc"

# Only the sync subprocess uses this PATH; desktop programs must not be run.
bash_bin=$(command -v bash)
mkdir -p "$test_dir/bin"
for dependency in 'awk' 'cat' 'chmod' 'cmp' 'cp' 'diff' 'dirname' 'head' 'mkdir' 'mktemp' 'mv' 'realpath' 'rm' 'tail'; do
    ln -s "$(command -v "$dependency")" "$test_dir/bin/$dependency"
done
for dependency in 'vim' 'i3' 'i3bar' 'i3-msg' 'i3-nagbar' 'i3status' 'kitty' 'dmenu_run' 'dex' 'xss-lock' 'i3lock' 'nm-applet' 'setxkbmap' 'pactl' 'killall' 'dunst' 'dmenu' 'xdg-open' 'flameshot' 'paplay'; do
    printf '#!/bin/sh\nexit 99\n' > "$test_dir/bin/$dependency"
    chmod +x "$test_dir/bin/$dependency"
done
printf '#!/bin/sh\nexit 0\n' > "$test_dir/bin/i3"

reset_host() {
    HOME=$test_dir/host
    XDG_CONFIG_HOME=$HOME/custom\ config
    export HOME XDG_CONFIG_HOME
    mkdir -p "$XDG_CONFIG_HOME/i3" "$XDG_CONFIG_HOME/i3status" "$XDG_CONFIG_HOME/kitty" "$XDG_CONFIG_HOME/dunst"
    printf 'old vim\n' > "$HOME/.vimrc"
    printf 'old shared\n%s\nexec local-startup\nbindsym Mod4+x exec local' "$marker" > "$XDG_CONFIG_HOME/i3/config"
    printf 'old status\n' > "$XDG_CONFIG_HOME/i3status/config"
    printf 'font_size 10.0\n' > "$XDG_CONFIG_HOME/kitty/kitty.conf"
    printf '[global]\nfont = Monospace 8\n' > "$XDG_CONFIG_HOME/dunst/dunstrc"
    cp "$HOME/.vimrc" "$test_dir/vim-before"
    cp "$XDG_CONFIG_HOME/i3/config" "$test_dir/i3-before"
    cp "$XDG_CONFIG_HOME/i3status/config" "$test_dir/status-before"
    cp "$XDG_CONFIG_HOME/kitty/kitty.conf" "$test_dir/kitty-before"
    cp "$XDG_CONFIG_HOME/dunst/dunstrc" "$test_dir/dunst-before"
}

run_sync() {
    local input="$1"
    shift
    printf '%s' "$input" | PATH="$test_dir/bin" "$bash_bin" "$fixture/sync.sh" "$@" > "$test_dir/output" 2>&1
}

assert_unchanged() {
    cmp "$test_dir/vim-before" "$HOME/.vimrc"
    cmp "$test_dir/i3-before" "$XDG_CONFIG_HOME/i3/config"
    cmp "$test_dir/status-before" "$XDG_CONFIG_HOME/i3status/config"
    cmp "$test_dir/kitty-before" "$XDG_CONFIG_HOME/kitty/kitty.conf"
    cmp "$test_dir/dunst-before" "$XDG_CONFIG_HOME/dunst/dunstrc"
}

reset_host
# Report every missing command before using tools or prompting for changes.
for dependency in 'kitty' 'i3status' 'dirname' 'mktemp' 'setxkbmap' 'pactl' 'killall' 'dunst' 'dmenu' 'xdg-open' 'flameshot' 'paplay'; do
    mv "$test_dir/bin/$dependency" "$test_dir/bin/$dependency.unavailable"
done
if run_sync $'y\ny\ny\n'; then
    printf 'Expected missing dependencies to fail.\n' >&2
    exit 1
fi
assert_unchanged
for dependency in 'kitty' 'i3status' 'dirname' 'mktemp' 'setxkbmap' 'pactl' 'killall' 'dunst' 'dmenu' 'xdg-open' 'flameshot' 'paplay'; do
    grep -Fxq "  $dependency" "$test_dir/output"
    mv "$test_dir/bin/$dependency.unavailable" "$test_dir/bin/$dependency"
done
if grep -q 'Apply to' "$test_dir/output"; then
    printf 'Unexpected prompt with missing dependencies.\n' >&2
    exit 1
fi

# Reject invalid merged i3 configs before offering to install them.
printf '#!/bin/sh\nexit 1\n' > "$test_dir/bin/i3"
if run_sync $'n\ny\ny\n'; then
    printf 'Expected i3 validation failure to abort.\n' >&2
    exit 1
fi
assert_unchanged
grep -q 'Merged i3 config is invalid' "$test_dir/output"
if grep -Fq "Apply to $XDG_CONFIG_HOME/i3/config?" "$test_dir/output"; then exit 1; fi
printf '#!/bin/sh\nexit 0\n' > "$test_dir/bin/i3"

run_sync $'n\n\nno\nn\nn\n'
assert_unchanged
grep -q $'\033\[' "$test_dir/output"

for input in $'q\n' ''; do
    run_sync "$input"
    assert_unchanged
done

chmod 640 "$HOME/.vimrc"
run_sync $'invalid\ny\ny\ny\ny\ny\n'
cmp "$fixture/.vimrc" "$HOME/.vimrc"
[[ $(stat -c '%a' "$HOME/.vimrc") == 640 ]]
cmp "$fixture/.config/i3status/config" "$XDG_CONFIG_HOME/i3status/config"
cmp "$fixture/.config/kitty/kitty.conf" "$XDG_CONFIG_HOME/kitty/kitty.conf"
cmp "$fixture/.config/dunst/dunstrc" "$XDG_CONFIG_HOME/dunst/dunstrc"
{
    cat "$fixture/.config/i3/config"
    printf '%s\n' "$marker"
    printf 'exec local-startup\nbindsym Mod4+x exec local'
} > "$test_dir/expected-i3"
cmp "$test_dir/expected-i3" "$XDG_CONFIG_HOME/i3/config"
run_sync ''
[[ $(grep -c 'Already up to date:' "$test_dir/output") == 5 ]]

reset_host
run_sync $'y\nq\n'
cmp "$fixture/.vimrc" "$HOME/.vimrc"
cmp "$test_dir/i3-before" "$XDG_CONFIG_HOME/i3/config"
cmp "$test_dir/status-before" "$XDG_CONFIG_HOME/i3status/config"

# A missing exact marker is added during whole-file replacement.
{
    cat "$fixture/.config/i3/config"
    printf '%s\n' "$marker"
} > "$test_dir/expected-i3"
for content in $'unmarked config\n' $'# -------------------------------------------------------------\nold settings\n' "$marker"$' \nold settings\n'; do
    reset_host
    printf '%s' "$content" > "$XDG_CONFIG_HOME/i3/config"
    cp "$XDG_CONFIG_HOME/i3/config" "$test_dir/i3-before"
    run_sync $'n\nn\nn\n'
    assert_unchanged
    run_sync $'n\ny\nn\n'
    cmp "$test_dir/expected-i3" "$XDG_CONFIG_HOME/i3/config"
    cmp "$test_dir/vim-before" "$HOME/.vimrc"
    cmp "$test_dir/status-before" "$XDG_CONFIG_HOME/i3status/config"
done

# Duplicate host markers and markers in the repo are rejected before writing.
reset_host
printf '%s\nlocal\n%s\n' "$marker" "$marker" > "$XDG_CONFIG_HOME/i3/config"
cp "$XDG_CONFIG_HOME/i3/config" "$test_dir/i3-before"
if run_sync $'n\ny\ny\n'; then
    printf 'Expected duplicate host markers to fail.\n' >&2
    exit 1
fi
assert_unchanged
grep -q 'Expected at most one host-local marker' "$test_dir/output"

for content in "$marker" "$marker"$'\nrepo override\n'; do
    reset_host
    printf '%s\n' "$content" > "$fixture/.config/i3/config"
    if run_sync $'n\ny\ny\n'; then
        printf 'Expected a marker in the repo to fail.\n' >&2
        exit 1
    fi
    assert_unchanged
    grep -q 'Repo i3 config must not contain the host-local marker' "$test_dir/output"
done
printf 'new shared\n' > "$fixture/.config/i3/config"

# A fresh HOME uses default XDG paths and creates files only after approval.
HOME=$test_dir/fresh
export HOME
unset XDG_CONFIG_HOME
run_sync $'n\nn\nn\nn\nn\n'
[[ ! -e "$HOME" ]]
run_sync $'y\ny\ny\ny\ny\n'
cmp "$fixture/.vimrc" "$HOME/.vimrc"
cmp "$test_dir/expected-i3" "$HOME/.config/i3/config"
cmp "$fixture/.config/i3status/config" "$HOME/.config/i3status/config"
cmp "$fixture/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
cmp "$fixture/.config/dunst/dunstrc" "$HOME/.config/dunst/dunstrc"

# Existing symlinks keep pointing at the updated file.
mv "$HOME/.vimrc" "$HOME/vim-target"
ln -s vim-target "$HOME/.vimrc"
printf 'old linked vim\n' > "$HOME/vim-target"
run_sync $'y\n'
[[ -L "$HOME/.vimrc" ]]
cmp "$fixture/.vimrc" "$HOME/vim-target"

# Editing the file while its diff is open must abort rather than overwrite it.
reset_host
coproc REVIEW { PATH="$test_dir/bin" "$bash_bin" "$fixture/sync.sh" 2>&1; }
review_pid=$!
review_input=${REVIEW[1]}
review_output=${REVIEW[0]}
output=''
while IFS= read -r -n 1 -t 5 -u "$review_output" char; do
    output+=$char
    if [[ "$output" == *'[y/N/q] '* ]]; then break; fi
done
[[ "$output" == *'[y/N/q] '* ]]
printf 'edited during review\n' > "$HOME/.vimrc"
printf 'y\n' >& "$review_input"
if wait "$review_pid"; then
    printf 'Expected concurrent edit to abort.\n' >&2
    exit 1
fi
[[ $(cat "$HOME/.vimrc") == 'edited during review' ]]
cmp "$test_dir/i3-before" "$XDG_CONFIG_HOME/i3/config"
cmp "$test_dir/status-before" "$XDG_CONFIG_HOME/i3status/config"

# Reverse sync uses the same prompts without requiring desktop programs.
reset_host
for dependency in 'kitty' 'i3' 'i3status' 'setxkbmap' 'pactl' 'killall' 'dunst' 'dmenu' 'xdg-open' 'flameshot' 'paplay'; do
    mv "$test_dir/bin/$dependency" "$test_dir/bin/$dependency.unavailable"
done
cp "$fixture/.vimrc" "$test_dir/repo-vim-before"
cp "$fixture/.config/i3/config" "$test_dir/repo-i3-before"
cp "$fixture/.config/i3status/config" "$test_dir/repo-status-before"
cp "$fixture/.config/kitty/kitty.conf" "$test_dir/repo-kitty-before"
cp "$fixture/.config/dunst/dunstrc" "$test_dir/repo-dunst-before"
for input in $'n\nn\nn\nn\nn\n' $'q\n' ''; do
    run_sync "$input" '--from-host'
    cmp "$test_dir/repo-vim-before" "$fixture/.vimrc"
    cmp "$test_dir/repo-i3-before" "$fixture/.config/i3/config"
    cmp "$test_dir/repo-status-before" "$fixture/.config/i3status/config"
    cmp "$test_dir/repo-kitty-before" "$fixture/.config/kitty/kitty.conf"
    cmp "$test_dir/repo-dunst-before" "$fixture/.config/dunst/dunstrc"
    assert_unchanged
done
run_sync $'y\ny\ny\ny\ny\n' '--from-host'
grep -q $'\033\[' "$test_dir/output"
grep -Fq "$fixture/.config/i3/config (after)" "$test_dir/output"
if grep -Fq 'local-startup' "$test_dir/output"; then
    printf 'Local overrides leaked into the repo diff.\n' >&2
    exit 1
fi
cmp "$HOME/.vimrc" "$fixture/.vimrc"
printf 'old shared\n' > "$test_dir/expected-shared"
cmp "$test_dir/expected-shared" "$fixture/.config/i3/config"
cmp "$XDG_CONFIG_HOME/i3status/config" "$fixture/.config/i3status/config"
cmp "$XDG_CONFIG_HOME/kitty/kitty.conf" "$fixture/.config/kitty/kitty.conf"
cmp "$XDG_CONFIG_HOME/dunst/dunstrc" "$fixture/.config/dunst/dunstrc"
assert_unchanged
run_sync '' '--from-host'
[[ $(grep -c 'Already up to date:' "$test_dir/output") == 5 ]]
for dependency in 'kitty' 'i3' 'i3status' 'setxkbmap' 'pactl' 'killall' 'dunst' 'dmenu' 'xdg-open' 'flameshot' 'paplay'; do
    mv "$test_dir/bin/$dependency.unavailable" "$test_dir/bin/$dependency"
done
# Exporting and importing again must not accumulate blank lines.
run_sync ''
[[ $(grep -c 'Already up to date:' "$test_dir/output") == 5 ]]

# Without a marker the entire host i3 config is imported verbatim.
printf 'shared without marker' > "$XDG_CONFIG_HOME/i3/config"
run_sync $'y\n' '--from-host'
cmp "$XDG_CONFIG_HOME/i3/config" "$fixture/.config/i3/config"

# Forward sync keeps the marker separate when shared content lacks a newline.
run_sync $'y\n'
printf 'shared without marker\n%s\n' "$marker" > "$test_dir/expected-i3"
cmp "$test_dir/expected-i3" "$XDG_CONFIG_HOME/i3/config"

printf 'outdated\n%s\nlocal' "$marker" > "$XDG_CONFIG_HOME/i3/config"
run_sync $'y\n'
printf 'shared without marker\n%s\nlocal' "$marker" > "$test_dir/expected-i3"
cmp "$test_dir/expected-i3" "$XDG_CONFIG_HOME/i3/config"

# A marker at the first line imports an empty shared config.
printf '%s\nlocal only\n' "$marker" > "$XDG_CONFIG_HOME/i3/config"
run_sync $'y\n' '--from-host'
[[ ! -s "$fixture/.config/i3/config" ]]
run_sync ''
[[ $(grep -c 'Already up to date:' "$test_dir/output") == 5 ]]

# Missing sources and ambiguous markers must not overwrite repo files.
cp "$fixture/.vimrc" "$test_dir/repo-vim-before"
cp "$fixture/.config/i3/config" "$test_dir/repo-i3-before"
cp "$fixture/.config/i3status/config" "$test_dir/repo-status-before"
cp "$fixture/.config/kitty/kitty.conf" "$test_dir/repo-kitty-before"
cp "$fixture/.config/dunst/dunstrc" "$test_dir/repo-dunst-before"
printf '%s\nprivate\n%s\n' "$marker" "$marker" > "$XDG_CONFIG_HOME/i3/config"
if run_sync $'y\n' '--from-host'; then
    printf 'Expected duplicate markers to fail on reverse sync.\n' >&2
    exit 1
fi
cmp "$test_dir/repo-i3-before" "$fixture/.config/i3/config"
mv "$HOME/.vimrc" "$test_dir/host-vim-saved"
if run_sync $'y\ny\ny\n' '--from-host'; then
    printf 'Expected missing host source to fail.\n' >&2
    exit 1
fi
cmp "$test_dir/repo-vim-before" "$fixture/.vimrc"
cmp "$test_dir/repo-i3-before" "$fixture/.config/i3/config"
cmp "$test_dir/repo-status-before" "$fixture/.config/i3status/config"
cmp "$test_dir/repo-kitty-before" "$fixture/.config/kitty/kitty.conf"
cmp "$test_dir/repo-dunst-before" "$fixture/.config/dunst/dunstrc"
grep -q 'Missing or non-regular source file:' "$test_dir/output"

if run_sync '' '--unknown'; then exit 1; fi
grep -q 'Usage:' "$test_dir/output"
if run_sync '' '--from-host' '--from-host'; then exit 1; fi
grep -q 'Usage:' "$test_dir/output"

printf 'All sync checks passed.\n'
