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

# Route `herdr` through the env-scrubbing wrapper: the herdr server freezes its
# launch environment into every pane it ever spawns. See ~/.local/bin/herdr-clean.
if [ -x "$HOME/.local/bin/herdr-clean" ]; then
    herdr() { "$HOME/.local/bin/herdr-clean" "$@"; }
fi

# Herdr and Orca are themselves multiplexers -- never autostart tmux inside their panes.
# See the matching guard in bashrc for why Orca must not be wrapped in tmux.
if [ -z "$TMUX" ] && [ -z "$HERDR_ENV" ] && [ "$TERM_PROGRAM" != "Orca" ]; then tmux; fi

. "$HOME/.local/share/../bin/env"
