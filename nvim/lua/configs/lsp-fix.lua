-- Workaround for Neovim 0.12 bug: "Invalid cursor line: out of range"
-- in vim.lsp.buf definition/declaration/type_definition/implementation handlers.
-- Fixed upstream in Neovim 0.13 (nightly). Remove this file once upgraded.
--
-- The bug: when an LSP returns a location whose line number exceeds the
-- buffer's line count (e.g., file changed since the request), the default
-- handler calls nvim_win_set_cursor with an out-of-range line, causing an error.
--
-- This workaround overrides the affected functions with safe versions that
-- validate the line number before jumping, and fall back to the quickfix list.

local api = vim.api

--- Validate that lnum is within buffer range, clamp if not.
local function safe_position(item)
  if not item then
    return nil
  end

  local bufnr = item.bufnr
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local line_count = api.nvim_buf_line_count(bufnr)
  local lnum = item.lnum or 1
  local col = (item.col or 1) - 1

  -- Clamp to valid range
  if lnum < 1 then
    lnum = 1
  end
  if lnum > line_count then
    lnum = line_count
  end
  if col < 0 then
    col = 0
  end

  return bufnr, lnum, col
end

--- Build a safe on_list handler that validates positions before jumping.
--- Captures from/tagname at call time (not response time) matching original behavior.
local function make_safe_on_list(method, from, tagname, user_opts)
  local user_on_list = user_opts and user_opts.on_list
  local loclist = user_opts and user_opts.loclist

  return function(what)
    if user_on_list then
      -- User provided their own handler; use it as-is.
      user_on_list(what)
      return
    end

    local items = what.items or {}

    if #items == 1
      and method ~= "textDocument/implementation"
      and method ~= "textDocument/references"
    then
      local item = items[1]
      local bufnr, lnum, col = safe_position(item)

      if bufnr then
        -- Valid position: jump directly (same behavior as default, but safe).
        local win = api.nvim_get_current_win()

        -- Save position in jumplist
        vim.cmd("normal! m'")

        -- Push tagstack (using captured from/tagname from call time)
        local tagstack = { { tagname = tagname, from = from } }
        vim.fn.settagstack(vim.fn.win_getid(win), { items = tagstack }, "t")

        -- Show buffer and set cursor
        vim.bo[bufnr].buflisted = true

        local w = win
        if api.nvim_win_get_buf(w) ~= bufnr then
          w = vim.fn.bufwinid(bufnr)
          w = w >= 0 and w or vim.fn.win_findbuf(bufnr)[1] or win
          if w ~= win then
            api.nvim_set_current_win(w)
          end
        end
        api.nvim_win_set_buf(w, bufnr)
        api.nvim_win_set_cursor(w, { lnum, col })
        vim._with({ win = w }, function()
          vim.cmd("normal! zv")
        end)
        return
      end
    end

    -- Fall back to quickfix / location list
    if loclist then
      vim.fn.setloclist(0, {}, " ", what)
      if #items == 1 then
        vim.cmd("lfirst")
      else
        vim.cmd("lopen")
      end
    else
      vim.fn.setqflist({}, " ", what)
      if #items == 1 then
        vim.cmd("cfirst")
      else
        vim.cmd("botright copen")
      end
    end
  end
end

-- Wrap the original functions to inject a safe on_list handler.
-- Captures from/tagname at call time, before the LSP request goes out.
local function wrap_with_safe_handler(method, orig_fn)
  return function(opts)
    opts = vim.deepcopy(opts or {})

    -- Capture position info at call time (matches original behavior)
    local from = vim.fn.getpos(".")
    from[1] = api.nvim_get_current_buf()
    local tagname = vim.fn.expand("<cword>")

    opts.on_list = make_safe_on_list(method, from, tagname, opts)
    orig_fn(opts)
  end
end

-- Apply the fix
local buf = vim.lsp.buf
buf.definition = wrap_with_safe_handler("textDocument/definition", buf.definition)
buf.declaration = wrap_with_safe_handler("textDocument/declaration", buf.declaration)
buf.type_definition = wrap_with_safe_handler("textDocument/typeDefinition", buf.type_definition)
buf.implementation = wrap_with_safe_handler("textDocument/implementation", buf.implementation)
