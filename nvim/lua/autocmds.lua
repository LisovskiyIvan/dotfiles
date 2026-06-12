require "nvchad.autocmds"

vim.filetype.add {
  extension = {
    gd = "gdscript",
    gdshader = "gdshader",
    tscn = "godot_scene",
    tres = "godot_resource",
    luau = "luau",
  },
}

local autosave = { enabled = true }

local blocked_filetypes = {
  "NvimTree", "neo-tree", "lazy", "mason", "help", "qf",
  "terminal", "toggleterm", "alpha", "dashboard", "gitcommit",
  "fugitive", "oil", "diff",
}

local blocked_buftypes = {
  "nofile", "nowrite", "quickfix", "terminal", "prompt",
}

local function contains(list, v)
  for _, x in ipairs(list) do
    if x == v then return true end
  end
  return false
end

local function should_save(bufnr)
  if not autosave.enabled then return false end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return false end
  if vim.api.nvim_buf_get_name(bufnr) == "" then return false end
  if not vim.bo[bufnr].modified then return false end
  if vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable then return false end
  if contains(blocked_buftypes, vim.bo[bufnr].buftype) then return false end
  if contains(blocked_filetypes, vim.bo[bufnr].filetype) then return false end
  return true
end

local pending = false
local function save(bufnr)
  if pending then return end
  pending = true
  vim.schedule(function()
    pending = false
    if not should_save(bufnr) then return end
    vim.cmd("silent! keepjumps keepalt update")
  end)
end

local augroup = vim.api.nvim_create_augroup("AutoSave", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "TextChangedI", "FocusLost" }, {
  group = augroup,
  callback = function(args) save(args.buf) end,
})

vim.api.nvim_create_user_command("AutoSaveToggle", function()
  autosave.enabled = not autosave.enabled
  vim.notify("AutoSave: " .. (autosave.enabled and "enabled" or "disabled"))
end, {})

vim.keymap.set("n", "<leader>as", function()
  autosave.enabled = not autosave.enabled
  vim.notify("AutoSave: " .. (autosave.enabled and "enabled" or "disabled"))
end, { desc = "Toggle AutoSave" })

local rojo_sourcemap_timers = {}

local function rojo_sourcemap_root(bufnr)
  return vim.fs.root(bufnr or 0, "default.project.json")
end

local function rojo_sourcemap_cmd(root)
  local rojo = vim.fn.exepath "rojo"
  if rojo == "" then
    rojo = "/usr/local/bin/rojo"
  end

  return {
    rojo,
    "sourcemap",
    "default.project.json",
    "--output",
    "sourcemap.json",
  }, { cwd = root }
end

local function file_contents(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local contents = file:read "*a"
  file:close()
  return contents
end

local function generate_rojo_sourcemap(bufnr, notify_success)
  local root = rojo_sourcemap_root(bufnr)
  if not root then
    if notify_success then
      vim.notify("Rojo sourcemap: default.project.json not found", vim.log.levels.WARN)
    end
    return
  end

  if rojo_sourcemap_timers[root] then
    rojo_sourcemap_timers[root]:stop()
    rojo_sourcemap_timers[root]:close()
  end

  local timer = vim.uv.new_timer()
  rojo_sourcemap_timers[root] = timer
  timer:start(500, 0, function()
    rojo_sourcemap_timers[root] = nil
    timer:close()

    local sourcemap = root .. "/sourcemap.json"
    local before = file_contents(sourcemap)
    local cmd, opts = rojo_sourcemap_cmd(root)
    vim.system(cmd, opts, function(result)
      if result.code ~= 0 then
        vim.schedule(function()
          vim.notify("Rojo sourcemap failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
        end)
      else
        local after = file_contents(sourcemap)
        vim.schedule(function()
          if before ~= after then
            vim.cmd "silent! lsp restart luau_lsp"
          end

          if notify_success then
            vim.notify "Rojo sourcemap generated"
          end
        end)
      end
    end)
  end)
end

vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("RojoSourcemap", { clear = true }),
  pattern = { "*.luau", "default.project.json" },
  callback = function(args)
    generate_rojo_sourcemap(args.buf, false)
  end,
})

vim.api.nvim_create_user_command("RojoSourcemap", function()
  generate_rojo_sourcemap(0, true)
end, {})

vim.api.nvim_create_user_command("RojoRestart", function()
  vim.cmd "silent! lsp restart luau_lsp"
end, {})
