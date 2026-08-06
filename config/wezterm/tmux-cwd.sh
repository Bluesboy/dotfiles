#!/usr/bin/env sh
# Bridges a wezterm pane that runs tmux to the tmux pane inside it.
#
# wezterm learns a pane's directory from OSC 7, and tmux does not forward it on
# a plain cd, so for a pane running tmux wezterm keeps reporting the directory
# tmux was started in. Both halves of "open the toggle terminal where I am"
# break on that: the directory read out of the invoker is stale, and a cd sent
# to the terminal lands in tmux itself rather than in a shell.
#
# The tmux client living in a wezterm pane carries WEZTERM_PANE in its
# environment, which is what ties the two together -- the same handle
# tmux/pane-nav.sh uses in the other direction.
#
#   path <wezterm-pane-id>        prints the directory of that client's active pane,
#                                 exiting non-zero when there is no client
#   send <wezterm-pane-id> <dir>  cds that pane there, printing one of
#                                   sent     the cd went out
#                                   same     already there, pane left alone
#                                   busy     not a shell, nothing sent
#                                 and exiting non-zero when there is no client
#
# The caller has to tell "no tmux here, talk to the pane directly" apart from
# "tmux is here and declined", which is why send reports a word rather than
# leaning on the exit status alone.

set -u

usage() {
  echo "usage: tmux-cwd.sh path <wezterm-pane-id> | send <wezterm-pane-id> <dir>" >&2
  exit 64
}

[ $# -ge 2 ] || usage

action=$1
wezterm_pane=$2

case $wezterm_pane in
'' | *[!0-9]*) usage ;;
esac

# Every server is asked rather than just the default one: the socket this script
# runs under is whatever wezterm inherited, which need not be the server the
# pane is attached to.
sockets() {
  dir=${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)
  [ -d "$dir" ] || return 0

  for socket in "$dir"/*; do
    [ -S "$socket" ] && printf '%s\n' "$socket"
  done
}

# A pane id is only unique within one wezterm GUI process, and the dropdown
# terminal is a second one, so the same id exists twice and a client of the
# wrong instance would answer for the wrong pane. Walking up to the wezterm-gui
# that spawned this script gives the pid its socket is named after, which is
# what the clients carry. Returns nothing when there is no such ancestor, and
# the ownership check is then skipped rather than failing the lookup.
gui_socket() {
  _pid=${PPID:-1}

  while [ "${_pid:-0}" -gt 1 ]; do
    if [ "$(cat "/proc/$_pid/comm" 2>/dev/null)" = "wezterm-gui" ]; then
      printf '%s\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wezterm/gui-sock-$_pid"
      return 0
    fi

    _pid=$(ps -o ppid= -p "$_pid" 2>/dev/null | tr -d ' ')
  done

  return 1
}

want_socket=$(gui_socket) || want_socket=

# Prints "socket tty" for the client living in the pane. The tty is what
# identifies a client to tmux; the pid is only how its environment is reachable.
find_client() {
  for socket in $(sockets); do
    command tmux -S "$socket" list-clients -F '#{client_pid} #{client_tty}' 2>/dev/null | while read -r pid tty; do
      environ=$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null) || continue

      printf '%s\n' "$environ" | grep -qx "WEZTERM_PANE=$wezterm_pane" || continue

      if [ -n "$want_socket" ]; then
        printf '%s\n' "$environ" | grep -qx "WEZTERM_UNIX_SOCKET=$want_socket" || continue
      fi

      printf '%s %s\n' "$socket" "$tty"
      break
    done
  done | head -n 1
}

client=$(find_client)
[ -n "$client" ] || exit 1

socket=${client%% *}
tty=${client#* }

# Every lookup below has to reach the server the pane is attached to, which is
# not necessarily the one this script inherited.
tmux() {
  command tmux -S "$socket" "$@"
}

case $action in
path)
  path=$(tmux display-message -p -t "$tty" '#{pane_current_path}' 2>/dev/null) || exit 1
  [ -n "$path" ] || exit 1
  printf '%s\n' "$path"
  ;;
send)
  [ $# -ge 3 ] || usage
  dir=$3

  # Same guard as the wezterm side: C-u and a cd mean something else entirely to
  # an editor or a pager that happens to be in the foreground.
  case $(tmux display-message -p -t "$tty" '#{pane_current_command}' 2>/dev/null) in
  bash | dash | fish | ksh | sh | zsh) ;;
  *)
    echo busy
    exit 0
    ;;
  esac

  # Already there, so leave the pane and whatever is half-typed in it alone.
  if [ "$(tmux display-message -p -t "$tty" '#{pane_current_path}' 2>/dev/null)" = "$dir" ]; then
    echo same
    exit 0
  fi

  target=$(tmux display-message -p -t "$tty" '#{pane_id}' 2>/dev/null) || exit 1
  [ -n "$target" ] || exit 1

  # C-u leads the cd in the same call, so the two cannot arrive out of order.
  tmux send-keys -t "$target" C-u "cd '$(printf '%s' "$dir" | sed "s/'/'\\\\''/g")'" C-m
  echo sent
  ;;
*) usage ;;
esac
