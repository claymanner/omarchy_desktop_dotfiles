# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
# /etc/omarchy.conf is written by omarchy-dev-link. When absent, force the
# package default instead of preserving a stale inherited dev-link value before
# we decide which rc file to source.
if [[ -f /etc/omarchy.conf ]]; then
  source /etc/omarchy.conf
  export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
else
  export OMARCHY_PATH=/usr/share/omarchy
fi
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'
# PATH order matters here: mise's shims dir must stay AHEAD of ~/.local/bin.
# omarchy generates the wrappers in ~/.local/bin (omarchy-mise-install) so they
# exec the bare tool name, and `mise x` substitutes the tool's install dir at the
# position of the *shims* dir -- so with a wrapper dir in front, `claude` finds its
# own wrapper again and re-execs forever. See Orca.md in the vault (2026-08-20).
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

_tmux_ssh_target() {
    local arg skip_next=""

    for arg in "$@"; do
        if [ -n "$skip_next" ]; then
            skip_next=""
            continue
        fi

        case "$arg" in
            --)
                continue
                ;;
            -[bBcDEeFIiJLlmOopQRSWw])
                skip_next=1
                continue
                ;;
            -b*|-c*|-D*|-E*|-e*|-F*|-I*|-i*|-J*|-L*|-l*|-m*|-O*|-o*|-p*|-Q*|-R*|-S*|-W*|-w*)
                continue
                ;;
            -*)
                continue
                ;;
            *)
                printf '%s\n' "${arg##*@}"
                return 0
                ;;
        esac
    done
}

_tmux_set_title() {
    [ -n "$TMUX" ] || return 0
    tmux select-pane -T "$1" >/dev/null 2>&1 || true
}

ssh() {
    local ssh_target="" old_title="" ssh_status

    ssh_target="$(_tmux_ssh_target "$@")"

    if [ -n "$TMUX" ] && [ -n "$ssh_target" ]; then
        old_title="$(tmux display-message -p -t "${TMUX_PANE:-}" "#{pane_title}" 2>/dev/null)"
        _tmux_set_title "$ssh_target"
    fi

    command ssh "$@"
    ssh_status=$?

    if [ -n "$TMUX" ]; then
        tmux select-pane -T "${old_title:-${PWD##*/}}" >/dev/null 2>&1 || true
    fi

    return "$ssh_status"
}

codex() {
    local old_title="" codex_status

    if [ -n "$TMUX" ]; then
        old_title="$(tmux display-message -p -t "${TMUX_PANE:-}" "#{pane_title}" 2>/dev/null)"
        _tmux_set_title "codex"
    fi

    command codex "$@"
    codex_status=$?

    if [ -n "$TMUX" ]; then
        _tmux_set_title "${old_title:-${PWD##*/}}"
    fi

    return "$codex_status"
}

[ -n "$TMUX" ] && return
[ -n "$VSCODE_PID" ] && return
[ "$EUID" -eq 0 ] && return

# Route `herdr` through the env-scrubbing wrapper: the herdr server freezes its
# launch environment into every pane it ever spawns. See ~/.local/bin/herdr-clean.
if [ -x "$HOME/.local/bin/herdr-clean" ]; then
    herdr() { "$HOME/.local/bin/herdr-clean" "$@"; }
fi

# Herdr and Orca are themselves multiplexers -- never autostart tmux inside their panes.
# Orca also installs OSC 133 agent-lifecycle hooks into THIS shell (see
# ~/.config/orca/shell-ready/bash/rcfile); letting tmux take over strands those hooks in
# the outer shell and makes every Orca pane a client of the one shared `main` session,
# so the panes all mirror each other. Guard on TERM_PROGRAM, which Orca sets to "Orca".
# Note: this is a targeted skip, NOT an early `return` like VSCODE_PID above -- Orca panes
# still need the rest of this file (PATH, mise/uv env) for the agents they run.
if [ -z "$HERDR_ENV" ] && [ "$TERM_PROGRAM" != "Orca" ] && command -v tmux >/dev/null; then
    tmux attach -t main 2>/dev/null || tmux new -s main
fi

# Deliberately NOT sourcing uv's "$HOME/.local/share/../bin/env" here: it only
# prepends ~/.local/bin (spelled $HOME/.local/share/../bin), which is already in
# PATH above -- and that spelling defeats both its own idempotence check and the
# shims-first ordering, which is what made `claude` recurse in Orca panes.
