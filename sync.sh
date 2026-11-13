#!/usr/bin/env bash
set -euo pipefail

from_host=0
if (($#)); then
    if (($# != 1)) || [[ "$1" != '--from-host' ]]; then
        printf 'Usage: %s [--from-host]\n' "$0" >&2
        exit 2
    fi
    from_host=1
fi

dependencies=('awk' 'cat' 'chmod' 'cmp' 'cp' 'diff' 'dirname' 'head' 'mkdir' 'mktemp' 'mv' 'realpath' 'rm' 'tail')
if ((!from_host)); then
    dependencies+=('vim' 'i3' 'i3bar' 'i3-msg' 'i3-nagbar' 'i3status' 'kitty' 'dmenu_run' 'dex' 'xss-lock' 'i3lock' 'nm-applet')
    dependencies+=('setxkbmap' 'pactl' 'killall')
    dependencies+=('dunst' 'dmenu' 'xdg-open' 'flameshot' 'paplay')
fi
missing=()
for dependency in "${dependencies[@]}"; do
    command -v "$dependency" > '/dev/null' 2>&1 || missing+=("$dependency")
done
if ((${#missing[@]})); then
    printf 'Missing required commands:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    printf 'Install them and rerun; no configs were changed.\n' >&2
    exit 1
fi

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
marker='# === local overrides ==='
work_dir="$(mktemp -d)"
staged=''
trap 'rm -rf -- "$work_dir"; if [[ -n "$staged" ]]; then rm -f -- "$staged"; fi' 'EXIT'
trap 'exit 130' 'INT'
trap 'exit 143' 'TERM'

marker_line() {
    awk -v marker="$marker" '
        $0 == marker { line = NR; count++ }
        END { if (count > 1) exit 1; print line + 0 }
    ' "$1" || {
        printf 'Expected at most one host-local marker in %s:\n%s\n' "$1" "$marker" >&2
        exit 1
    }
}

sync_file() {
    local source="$1" destination="$2" target before candidate line answer diff_status existed=0
    if ((from_host)); then
        source="$2"
        destination="$1"
    fi
    if [[ ! -f "$source" ]]; then
        printf 'Missing or non-regular source file: %s\n' "$source" >&2
        exit 1
    fi
    # Resolve symlinks so an atomic replacement updates their target.
    target="$(realpath -m -- "$destination")"
    before="$work_dir/before"
    candidate="$work_dir/after"
    if [[ -e "$target" && ! -f "$target" ]]; then
        printf 'Not a regular file: %s\n' "$target" >&2
        exit 1
    fi
    if [[ -f "$target" ]]; then
        existed=1
        cp -- "$target" "$before"
    else
        : > "$before"
    fi
    cp -- "$source" "$candidate"
    if [[ "$1" == "$repo_dir/.config/i3/config" ]]; then
        line="$(marker_line "$candidate")"
        if ((from_host)); then
            if ((line)); then
                head -n "$((line - 1))" -- "$candidate" > "$work_dir/shared"
                mv -- "$work_dir/shared" "$candidate"
            fi
        else
            if ((line)); then
                printf 'Repo i3 config must not contain the host-local marker: %s\n' "$source" >&2
                exit 1
            fi
            line="$(marker_line "$before")"
            if ((line)); then
                # Add a newline only when needed to keep the marker on its own line.
                if [[ -s "$candidate" && -n "$(tail -c 1 -- "$candidate")" ]]; then
                    printf '\n' >> "$candidate"
                fi
                tail -n "+$line" -- "$before" >> "$candidate"
            fi
            if ! i3 -C -c "$candidate"; then
                printf 'Merged i3 config is invalid. Remove duplicate shared bindings from local overrides, or fix the reported errors, then rerun.\n' >&2
                exit 1
            fi
        fi
    fi

    diff_status=0
    diff --color='always' -u --label "$destination (before)" --label "$destination (after)" -- "$before" "$candidate" || diff_status=$?
    case "$diff_status" in
        0) printf 'Already up to date: %s\n' "$destination"; return ;;
        1) ;;
        *) exit "$diff_status" ;;
    esac

    while true; do
        printf 'Apply to %s? [y/N/q] ' "$destination"
        if ! IFS='' read -r answer; then exit 0; fi
        case "$answer" in
            'y'|'Y'|'yes'|'YES') break ;;
            ''|'n'|'N'|'no'|'NO') printf 'Skipped.\n'; return ;;
            'q'|'Q'|'quit') exit 0 ;;
            *) printf 'Enter y to apply, n to skip, or q to quit.\n' ;;
        esac
    done

    # Do not overwrite edits made while the diff was being reviewed.
    if { ((existed)) && ! cmp -s -- "$before" "$target"; } ||
        { ((!existed)) && [[ -e "$target" ]]; }; then
        printf 'File changed during review; rerun: %s\n' "$target" >&2
        exit 1
    fi
    mkdir -p -- "$(dirname -- "$target")"
    staged="$(mktemp "$(dirname -- "$target")/.config-sync.XXXXXX")"
    cat -- "$candidate" > "$staged"
    if [[ -f "$target" ]]; then chmod --reference="$target" "$staged"; fi
    mv -fT -- "$staged" "$target"
    staged=''
    printf 'Updated: %s\n' "$destination"
}

sync_file "$repo_dir/.vimrc" "$HOME/.vimrc"
sync_file "$repo_dir/.config/i3/config" "$config_dir/i3/config"
sync_file "$repo_dir/.config/i3status/config" "$config_dir/i3status/config"
sync_file "$repo_dir/.config/kitty/kitty.conf" "$config_dir/kitty/kitty.conf"
sync_file "$repo_dir/.config/dunst/dunstrc" "$config_dir/dunst/dunstrc"
