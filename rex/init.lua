-- Rex keybindings migrated from herdr/config.toml.
-- Physical keys in brackets work in any keyboard layout (RU/EN).
-- Prefix: Ctrl+A (herdr prefix).

local P = "ctrl+[KeyA]>"

-- Stable order: tiled blocks first, then floaters by position.
local function bounds_key(layer)
  local b = layer.bounds or {}
  if type(b) == "table" and #b >= 4 then
    return b[2], b[1]
  end
  if type(b) == "table" and b.y ~= nil then
    return b.y, b.x
  end
  return 0, 0
end

local function collect_layout_ids(node, out)
  if not node then return end
  if node.block_id then
    table.insert(out, node.block_id)
    return
  end
  if node.split then
    collect_layout_ids(node.split.before, out)
    collect_layout_ids(node.split.after, out)
  end
end

local function stable_pane_ids(window)
  local ids = {}

  for _, layer in ipairs(window.layers or {}) do
    if layer.kind == "tiled" then
      collect_layout_ids(layer.layout, ids)
    end
  end

  local floaters = {}
  for _, layer in ipairs(window.layers or {}) do
    if layer.kind == "floating" then
      local blocks = layer.blocks or {}
      if blocks[1] and blocks[1].block_id then
        local y, x = bounds_key(layer)
        table.insert(floaters, { id = blocks[1].block_id, y = y, x = x })
      end
    end
  end
  table.sort(floaters, function(a, b)
    if a.y ~= b.y then return a.y < b.y end
    if a.x ~= b.x then return a.x < b.x end
    return a.id < b.id
  end)
  for _, it in ipairs(floaters) do
    table.insert(ids, it.id)
  end

  return ids
end

-- Unified pane cycle: tiled + floaters, one stable order.
local last_pane = {}

local function pane_nav(dir)
  return function(ctx)
    if not ctx.session_id then return false end
    local view = rex.session.view{ session_id = ctx.session_id }
    if not view or not view.windows then return false end

    local win
    for _, w in ipairs(view.windows) do
      if w.window_id == view.active_window_id then win = w end
    end
    if not win then return false end

    local ids = stable_pane_ids(win)
    local n = #ids
    if n == 0 then return false end

    local focused = win.focused_block_id
    local pos
    for i, id in ipairs(ids) do
      if id == focused then pos = i end
    end

    local idx
    if dir == "left" then
      idx = pos and ((pos - 2) % n) + 1 or n
    else
      idx = pos and (pos % n) + 1 or 1
    end
    local next_id = ids[idx]

    -- Leaving a floating pane minimizes it.
    if focused and focused ~= next_id then
      for _, layer in ipairs(win.layers or {}) do
        if layer.kind == "floating" and layer.state ~= "minimized" then
          for _, b in ipairs(layer.blocks or {}) do
            if b.block_id == focused then
              rex.call("session.set_layer_state", { session_id = ctx.session_id, layer_id = layer.layer_id, state = "minimized" })
            end
          end
        end
      end
    end

    if next_id ~= focused then
      rex.call("session.focus_block", { session_id = ctx.session_id, block_id = next_id })
      last_pane[ctx.session_id] = next_id
    end
    return true
  end
end

rex.action{ name = "pane_nav_left", title = "Focus Pane Left", run = pane_nav("left") }
rex.action{ name = "pane_nav_right", title = "Focus Pane Right", run = pane_nav("right") }

-- Ctrl+A X: close pane; closing the last pane destroys the session.
rex.action{
  name = "close_pane",
  title = "Close Pane",
  run = function(ctx)
    if not ctx.session_id then return false end
    local view = rex.session.view{ session_id = ctx.session_id }
    if not view then return false end

    local count = 0
    for _, w in ipairs(view.windows or {}) do
      for _, layer in ipairs(w.layers or {}) do
        for _, b in ipairs(layer.blocks or {}) do
          count = count + 1
        end
      end
    end

    if count <= 1 then
      rex.call("session.destroy", { session_id = ctx.session_id })
      return true
    end

    local block_id = ctx.block_id
    if not block_id then
      for _, w in ipairs(view.windows or {}) do
        if w.window_id == view.active_window_id then
          block_id = w.focused_block_id
        end
      end
    end
    if not block_id then return false end

    rex.call("block.close", { session_id = ctx.session_id, block_id = block_id })
    return true
  end,
}

-- Direct (no prefix)
rex.bind("alt+[KeyJ]", "client.tab.next")
rex.bind("alt+[KeyK]", "client.tab.previous")
rex.bind("alt+[KeyH]", "pane_nav_left")
rex.bind("alt+[KeyL]", "pane_nav_right")
rex.bind("alt+[KeyZ]", "pane.zoom")

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
rex.bind(P .. "[KeyX]", "close_pane")
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
