# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'
export PATH="$HOME/.local/bin:$PATH"

[ -n "$TMUX" ] && return
[ -n "$VSCODE_PID" ] && return
[ "$EUID" -eq 0 ] && return

if command -v tmux >/dev/null; then
    tmux attach -t main 2>/dev/null || tmux new -s main
fi
