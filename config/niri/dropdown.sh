#! /usr/bin/env bash

readonly SCRATCH_WORKSPACE_NAME=scratch
readonly SCRATCH_WIN_APP_ID=org.wezfurlong.wezterm.dropdown

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

# Matched by app-id, which wezterm takes from the --class it is started with.
# That is what lets niri's window rules fire as the window opens instead of
# after: the title wezterm pins in wezterm/dropdown.lua is only set once the
# window is mapped, so a rule keyed on it always arrived too late and the
# window was briefly tiled. niri/config.kdl matches the same app-id.
app_window() {
  win_data | jq ".[] | select(.app_id == \"${SCRATCH_WIN_APP_ID}\")"
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

# Both deliberately bypass win_data: they exist to watch niri change its mind
# while applyGeometry runs, which is exactly what the cache hides.
window_size() {
  niri msg -j windows | jq -c ".[] | select(.id == $1) | .layout.window_size"
}

window_is_floating() {
  niri msg -j windows | jq -r ".[] | select(.id == $1) | .is_floating"
}

run_quake() {
  # --always-new-process is required: without it wezterm attaches to the running
  # instance through its per-class GUI socket and the window would be spawned
  # there, under the main config, ignoring --config-file.
  niri msg action spawn-sh -- "wezterm --config-file ~/.config/wezterm/dropdown.lua start --always-new-process --class ${SCRATCH_WIN_APP_ID}"
  # Poll until window appears (max 2s)
  for _ in {1..20}; do
    _win_data="" # invalidate cache
    is_running && return
    sleep 0.1
  done
}

# The window rule in niri/config.kdl already opens this window floating and at
# full size, so on spawn there is usually nothing left to do here. This still
# runs on every show: the percentages resolve against the output the window is
# on, and a window shown on a different output than it was sized for has to be
# resized again, which is why this has to come after the move. All the actions
# set a state instead of toggling one, so repeating them is harmless.
applyGeometry() {
  local id=$1
  local floating
  local before

  floating=$(window_is_floating "$id")
  before=$(window_size "$id")

  niri msg action move-window-to-floating --id "$id"
  niri msg action set-window-width --id "$id" "100%"
  niri msg action set-window-height --id "$id" "100%"

  # center-window derives the position from the size the client has already
  # committed, so issuing it while the resize above is still in flight drops
  # that resize and the window keeps whatever size it was mapped with. A window
  # that is already floating is one niri has sized before, so nothing is pending
  # for it; only one that arrives tiled has to be waited for, and the wait ends
  # the moment the new size lands.
  if [[ $floating != "true" ]]; then
    for _ in {1..40}; do
      [[ $(window_size "$id") != "$before" ]] && break
      sleep 0.025
    done
  fi

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
