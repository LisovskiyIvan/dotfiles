-- Worktree plugin: hotkey -> floating prompt -> git worktree + Rex session.
-- Delete from a terminal with: wt delete NAME

local WT = os.getenv("HOME") .. "/.local/bin/wt"

rex.action{
  name  = "worktree_new",
  title = "New Worktree",
  description = "Ask for a name, create a git worktree and open it as a tab",
  category = "Worktree",
  run = function(ctx)
    if not ctx.session_id then return false end

    -- Use the focused pane's directory as the base repo, nothing hardcoded.
    local cwd = os.getenv("HOME")
    if ctx.block_id then
      local proc = rex.call("com.superlogical.terminal.process", {
        session_id = ctx.session_id,
        block_id = ctx.block_id,
      })
      if proc ~= nil then
        cwd = (proc.foreground and proc.foreground.cwd)
          or (proc.ancestors and proc.ancestors[1] and proc.ancestors[1].cwd)
          or cwd
      end
    end

    local r, err = rex.session.new_layer{
      session_id = ctx.session_id,
      bounds = { 0.28, 0.30, 0.44, 0.34 },
      focus = true,
      layout = rex.layout.block{
        flavor = "com.superlogical.terminal.shell",
        label  = "worktree",
        options = {
          command = { WT, "prompt", cwd },
          cwd = cwd,
          size = { columns = 56, rows = 10 },
        },
      },
    }
    if r == nil then
      rex.log("error", "worktree_new: " .. tostring(err))
      return false
    end
    return true
  end,
}

-- Ctrl+A g
rex.bind("ctrl+[KeyA]>[KeyG]", "worktree_new")
