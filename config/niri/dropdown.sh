#! /usr/bin/env bash

readonly SCRATCH_WORKSPACE_NAME=scratch
readonly SCRATCH_WIN_NAME=dropdown

# Cache niri state once per invocation
_win_data=""
_ws_data=""

win_data() {
  if [[ -z "$_win_data" ]]; then
    _win_data=$(niri msg -j windows)
  fi
  echo "$_win_data"
}

ws_data() {
  if [[ -z "$_ws_data" ]]; then
    _ws_data=$(niri msg -j workspaces)
  fi
  echo "$_ws_data"
}

# Matched by title rather than app_id: under native Wayland every wezterm window
# reports app_id org.wezfurlong.wezterm, so wezterm/dropdown.lua pins the title
# instead. niri/config.kdl matches the same way.
app_window() {
  win_data | jq ".[] | select(.title == \"${SCRATCH_WIN_NAME}\")"
}

focused_workspace() {
  ws_data | jq '.[] | select(.is_focused == true)'
}

is_running() { [[ -n $(app_window) ]]; }
is_focused() { [[ $(app_window | jq .is_focused) == "true" ]]; }
on_current_workspace() { [[ $(focused_workspace | jq -r .id) == $(app_window | jq -r .workspace_id) ]]; }

workspace_reference() {
  focused_workspace |
    jq -r 'if .name == null then (.idx | tostring) else .name end'
}

window_id() {
  app_window | jq .id
}

run_quake() {
  # --always-new-process is required: without it wezterm attaches to the running
  # instance through its per-class GUI socket and the window would be spawned
  # there, under the main config, ignoring --config-file.
  niri msg action spawn-sh -- "wezterm --config-file ~/.config/wezterm/dropdown.lua start --always-new-process"
  # Poll until window appears (max 2s)
  for _ in {1..20}; do
    _win_data="" # invalidate cache
    is_running && return
    sleep 0.1
  done
}

# Window rules that act when the window is mapped never match: niri evaluates
# them before wezterm sets the title. open-on-workspace and open-focused do not
# matter because bringToFocus places the window anyway, but the floating
# placement and the size have to be applied by hand.
#
# This runs on every show rather than once at spawn. Applying it right after the
# window is mapped is too early, niri settles its own layout afterwards and wins,
# and a size set once would not survive niri relaying the window out later.
# All three actions set a state instead of toggling one, so repeating them is
# harmless, and the percentages resolve against the output the window is on,
# which is why this has to come after the move.
applyGeometry() {
  local id=$1

  niri msg action move-window-to-floating --id "$id"
  niri msg action set-window-width --id "$id" "100%"
  niri msg action set-window-height --id "$id" "100%"
  # Resizing a floating window keeps its old top-left corner, which leaves a
  # full-width window hanging off the right edge. Centering has to come last,
  # once the size is known, and it derives the offsets from the working area, so
  # the waybar strut and the gaps are accounted for without hardcoding them.
  niri msg action center-window --id "$id"
}

moveToScratchpad() {
  niri msg action move-window-to-workspace \
    --window-id "$(window_id)" \
    "$SCRATCH_WORKSPACE_NAME" \
    --focus=false
}

bringToFocus() {
  local id
  id=$(window_id)
  niri msg action move-window-to-workspace --window-id "$id" "$(workspace_reference)"
  niri msg action focus-window --id "$id"
  applyGeometry "$id"
}

main() {
  if is_running; then
    if is_focused || on_current_workspace; then
      moveToScratchpad
    else
      bringToFocus
    fi
  else
    run_quake
    bringToFocus
  fi
}

main "$@"
