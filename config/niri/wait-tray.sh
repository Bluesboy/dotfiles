#! /usr/bin/env bash
# Launch a tray application only after the StatusNotifierWatcher (tray host)
# owns its D-Bus name. Electron apps (Slack, Element) register their SNI tray
# item exactly once at startup and never retry, so if they start before Noctalia
# has registered the watcher their tray icon is lost for the whole session.
#
# `gdbus wait` blocks until the name appears and returns immediately if it is
# already owned, making this deterministic instead of relying on a fixed sleep.
# After --timeout it returns non-zero; we launch the app anyway (better running
# without an icon than not running at all).

gdbus wait --session --timeout 30 org.kde.StatusNotifierWatcher
exec "$@"
