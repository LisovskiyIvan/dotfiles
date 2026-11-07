-- Rex keybindings migrated from herdr/config.toml.
-- Physical keys in brackets work in any keyboard layout (RU/EN).
-- Prefix: Ctrl+A (herdr prefix).

local P = "ctrl+[KeyA]>"

-- Direct (no prefix)
rex.bind("alt+[KeyJ]", "client.tab.next")
rex.bind("alt+[KeyK]", "client.tab.previous")
rex.bind("alt+[KeyH]", "pane.focus.left")
rex.bind("alt+[KeyL]", "pane.focus.right")

-- Sessions / workspaces
rex.bind(P .. "shift+[KeyN]", "session.new")
rex.bind(P .. "[KeyW]", "session.new")
rex.bind(P .. "[KeyU]", "session.switch")
rex.bind(P .. "shift+[KeyW]", "session.rename")
rex.bind(P .. "shift+[KeyD]", "session.close")

-- Tabs
rex.bind(P .. "[KeyC]", "client.tab.new")
rex.bind(P .. "[KeyT]", "client.tab.new")
rex.bind(P .. "[KeyP]", "client.tab.previous")
rex.bind(P .. "[KeyN]", "client.tab.next")
rex.bind(P .. "shift+[KeyT]", "client.tab.rename")
rex.bind(P .. "shift+[KeyX]", "client.tab.close")
for i = 1, 9 do
  rex.bind(P .. tostring(i), "client.tab.goto", { index = i })
end

-- Panes
rex.bind(P .. "[KeyH]", "pane.focus.left")
rex.bind(P .. "[KeyJ]", "pane.focus.down")
rex.bind(P .. "[KeyK]", "pane.focus.up")
rex.bind(P .. "[KeyL]", "pane.focus.right")
rex.bind(P .. "tab", "pane.focus_next")
rex.bind(P .. "shift+tab", "pane.focus_previous")
rex.bind(P .. "[KeyV]", "pane.split.right")
rex.bind(P .. "-", "pane.split.down")
rex.bind(P .. "[KeyX]", "pane.close")
rex.bind(P .. "[KeyZ]", "pane.zoom")
rex.bind(P .. "[KeyF]", "pane.float")
rex.bind(P .. "[KeyM]", "pane.minimize_floating")
rex.bind(P .. "shift+[KeyM]", "pane.minimize_all_floating")

-- Resize mode
rex.bind(P .. "[KeyR]", "client.mode.enter", { name = "resize" })
rex.bind("resize/[KeyH]", "pane.resize", { direction = "left" })
rex.bind("resize/[KeyJ]", "pane.resize", { direction = "down" })
rex.bind("resize/[KeyK]", "pane.resize", { direction = "up" })
rex.bind("resize/[KeyL]", "pane.resize", { direction = "right" })
rex.bind("resize/left", "pane.resize", { direction = "left" })
rex.bind("resize/down", "pane.resize", { direction = "down" })
rex.bind("resize/up", "pane.resize", { direction = "up" })
rex.bind("resize/right", "pane.resize", { direction = "right" })

-- Other
rex.bind(P .. "[KeyB]", "client.sidebar.toggle")
rex.bind(P .. "shift+[KeyR]", "client.config.reload")
rex.bind(P .. "[KeyS]", "client.settings")
