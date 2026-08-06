#!/usr/bin/env sh
# Directional pane movement for the tmux layer, aware of the wezterm panes
# around it. Called from the tmux key bindings once tmux itself has run out of
# panes in the requested direction.
#
#   1. a wezterm pane lies that way              -> move into it
#   2. otherwise wezterm panes lie the other way -> wrap onto the furthest one,
#      so the ring spans the whole stack instead of just the tmux panes
#   3. otherwise                                 -> let tmux wrap among its own
#
# nvim calls this too, through the smart-splits at_edge hook, so that the ring
# is defined in one place instead of being reimplemented in Lua. Exit code 3
# says nothing further out took the move and the caller should wrap within its
# own windows; the tmux bindings have no use for that and discard it.
#
# Usage: pane-nav.sh <Up|Down|Left|Right> [tmux-client-pid]

set -u

NOBODY_MOVED=3

direction=$1
client_pid=${2:-}

# nvim has no client pid to hand over, so look it up. The bindings still pass it
# explicitly: they know which client pressed the key, which matters once more
# than one client is attached to the session.
if [ -z "$client_pid" ] && [ -n "${TMUX:-}" ]; then
  client_pid=$(tmux display-message -p '#{client_pid}' 2>/dev/null) || client_pid=
fi

case $direction in
Up) opposite=Down tmux_flag=-U ;;
Down) opposite=Up tmux_flag=-D ;;
Left) opposite=Right tmux_flag=-L ;;
Right) opposite=Left tmux_flag=-R ;;
*)
  echo "pane-nav: unknown direction '$direction'" >&2
  exit 64
  ;;
esac

tmux_fallback() {
  _before=$(tmux display-message -p '#{pane_id}' 2>/dev/null)
  tmux select-pane "$tmux_flag" 2>/dev/null
  _after=$(tmux display-message -p '#{pane_id}' 2>/dev/null)

  # A single tmux pane has nowhere to wrap to, and that is the one case where
  # the move belongs back to whoever called.
  [ "$_before" != "$_after" ] && exit 0
  exit "$NOBODY_MOVED"
}

# The tmux server keeps the environment of whichever pane happened to start it,
# for its whole life. That pane's wezterm is usually long gone, so the inherited
# WEZTERM_UNIX_SOCKET names a socket that no longer exists and WEZTERM_PANE names
# a pane in a window that no longer exists. The tmux client, on the other hand,
# runs inside the wezterm pane the keypress came from, so its environment is the
# current one. The bindings pass its pid in.
client_env() {
  tr '\0' '\n' <"/proc/$client_pid/environ" 2>/dev/null | sed -n "s/^$1=//p" | head -n 1
}

if [ -n "$client_pid" ] && [ -r "/proc/$client_pid/environ" ]; then
  _pane=$(client_env WEZTERM_PANE)
  _sock=$(client_env WEZTERM_UNIX_SOCKET)

  case $_pane in
  '' | *[!0-9]*) ;;
  *) WEZTERM_PANE=$_pane ;;
  esac

  if [ -n "$_sock" ]; then
    WEZTERM_UNIX_SOCKET=$_sock
    export WEZTERM_UNIX_SOCKET
  fi
fi

# --no-auto-start matters as much as the socket itself: without it a stale socket
# makes wezterm cli daemonize a mux-server and sit there for seconds, which is
# what turns a missed keypress into a burst of late ones.
wez() {
  wezterm cli --no-auto-start "$@" 2>/dev/null
}

# Prints the neighbouring pane id, or fails when there is none. wezterm answers
# with the pane's own id rather than with nothing when the pane sits at the edge
# of an unzoomed tab, so the identity case has to count as "no neighbour" too --
# without it the walk below never terminates.
neighbour() {
  _n=$(wez get-pane-direction --pane-id "$1" "$2") || return 1
  [ -n "$_n" ] || return 1
  [ "$_n" != "$1" ] || return 1
  printf '%s\n' "$_n"
}

# No usable wezterm around this tmux session: no CLI, no pane to start from, or a
# socket whose GUI has died. Each check is cheap and keeps the fallback instant.
command -v wezterm >/dev/null 2>&1 || tmux_fallback
[ -n "${WEZTERM_PANE:-}" ] || tmux_fallback
[ -S "${WEZTERM_UNIX_SOCKET:-}" ] || tmux_fallback

if neighbour "$WEZTERM_PANE" "$direction" >/dev/null; then
  # activate-pane-direction is the one that lifts a zoom on its way, which is
  # wanted here because the move really happens.
  wez activate-pane-direction "$direction" || tmux_fallback
  exit 0
fi

# Walk to the far end the other way. get-pane-direction resolves its origin from
# --pane-id rather than from whichever pane is active, so the chain has to be
# followed by hand. The step cap only guards against a layout that somehow keeps
# reporting new neighbours; a real tab runs out long before it.
far=$WEZTERM_PANE
steps=0
while [ "$steps" -lt 64 ] && next=$(neighbour "$far" "$opposite"); do
  far=$next
  steps=$((steps + 1))
done

[ "$far" != "$WEZTERM_PANE" ] || tmux_fallback

# activate-pane cannot reveal a pane hidden under a zoom, so drop the zoom first.
wez zoom-pane --pane-id "$WEZTERM_PANE" --unzoom
wez activate-pane --pane-id "$far" || tmux_fallback
