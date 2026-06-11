
return {
  name = "autosave.nvim",
  dir = vim.fn.stdpath("config") .. "/lua/custom/plugins/autosave",
  config = function()
    local M = {}

    M.enabled = true

    local blocked_filetypes = {
      "NvimTree",
      "neo-tree",
      "lazy",
      "mason",
      "help",
      "qf",
      "terminal",
      "toggleterm",
      "alpha",
      "dashboard",
      "gitcommit",
      "fugitive",
      "oil",
      "diff",
    }

    local blocked_buftypes = {
      "nofile",
      "nowrite",
      "quickfix",
      "terminal",
      "prompt",
    }

    local function contains(list, v)
      for _, x in ipairs(list) do
        if x == v then return true end
      end
      return false
    end

    local function should_save(bufnr)
      if not M.enabled then return false end
      bufnr = bufnr or vim.api.nvim_get_current_buf()

      if not vim.api.nvim_buf_is_valid(bufnr) then return false end

      local name = vim.api.nvim_buf_get_name(bufnr)
      if name == nil or name == "" then return false end

      if not vim.bo[bufnr].modified then return false end

      if vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable then return false end

      if contains(blocked_buftypes, vim.bo[bufnr].buftype) then return false end
      if contains(blocked_filetypes, vim.bo[bufnr].filetype) then return false end

      if vim.bo[bufnr].modified and vim.bo[bufnr].buftype == "" then
        vim.cmd("silent! checktime " .. bufnr)
      end

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

    function M.enable()
      M.enabled = true
      vim.notify("AutoSave: enabled", vim.log.levels.INFO)
    end

    function M.disable()
      M.enabled = false
      vim.notify("AutoSave: disabled", vim.log.levels.INFO)
    end

    function M.toggle()
      M.enabled = not M.enabled
      vim.notify("AutoSave: " .. (M.enabled and "enabled" or "disabled"), vim.log.levels.INFO)
    end

    local augroup = vim.api.nvim_create_augroup("AutoSave", { clear = true })

    vim.api.nvim_create_autocmd({
      "InsertLeave",
      "TextChanged",
      "TextChangedI",
      "FocusLost",
    }, {
      group = augroup,
      callback = function(args)
        save(args.buf)
      end,
    })

    vim.api.nvim_create_user_command("AutoSaveEnable", M.enable, {})
    vim.api.nvim_create_user_command("AutoSaveDisable", M.disable, {})
    vim.api.nvim_create_user_command("AutoSaveToggle", M.toggle, {})

    vim.keymap.set("n", "<leader>as", M.toggle, { desc = "Toggle AutoSave" })
  end,
}
