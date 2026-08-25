-- Patch for nvim-treesitter master + Neovim 0.12 compatibility
-- Neovim 0.12 changed vim.treesitter.query handlers to receive
-- match as table<integer, TSNode[]> (array) instead of table<integer, TSNode> (single).
-- The archived master branch of nvim-treesitter still expects single nodes,
-- which causes: `attempt to call method 'range' (a nil value)` in vim.treesitter.get_range.
-- This module re-registers the affected predicates/directives with a compatibility shim.

local ok, query = pcall(require, "vim.treesitter.query")
if not ok then
  return
end

local html_script_type_languages = {
  ["importmap"] = "json",
  ["module"] = "javascript",
  ["application/ecmascript"] = "javascript",
  ["text/ecmascript"] = "javascript",
}

local non_filetype_match_injection_language_aliases = {
  ex = "elixir",
  pl = "perl",
  sh = "bash",
  uxn = "uxntal",
  ts = "typescript",
}

local function get_parser_from_markdown_info_string(injection_alias)
  local match = vim.filetype.match { filename = "a." .. injection_alias }
  return match or non_filetype_match_injection_language_aliases[injection_alias] or injection_alias
end

-- Helper to handle both old (single TSNode) and new (TSNode[]) API
local function get_match_node(match, id)
  local node_or_nodes = match[id]
  if not node_or_nodes then
    return nil
  end
  if type(node_or_nodes) == "table" then
    return node_or_nodes[1]
  end
  return node_or_nodes
end

local opts = { force = true, all = false }
-- For Neovim <0.10 compatibility the old code used `true` as opts
if vim.fn.has("nvim-0.10") == 0 then
  opts = true
end

-- Re-register predicates/directives only if nvim-treesitter is the provider
-- (main branch no longer has query_predicates.lua, so this is a no-op there)
local function patch()
  -- nth?
  pcall(query.add_predicate, "nth?", function(match, _pattern, _bufnr, pred)
    local node = get_match_node(match, pred[2])
    local n = tonumber(pred[3])
    if node and node:parent() and node:parent():named_child_count() > n then
      return node:parent():named_child(n) == node
    end
    return false
  end, opts)

  pcall(query.add_predicate, "is?", function(match, _pattern, bufnr, pred)
    local locals_ok, locals = pcall(require, "nvim-treesitter.locals")
    if not locals_ok then
      return true
    end
    local node = get_match_node(match, pred[2])
    local types = { unpack(pred, 3) }
    if not node then
      return true
    end
    local _, _, kind = locals.find_definition(node, bufnr)
    return vim.tbl_contains(types, kind)
  end, opts)

  pcall(query.add_predicate, "kind-eq?", function(match, _pattern, _bufnr, pred)
    local node = get_match_node(match, pred[2])
    local types = { unpack(pred, 3) }
    if not node then
      return true
    end
    return vim.tbl_contains(types, node:type())
  end, opts)

  pcall(query.add_directive, "set-lang-from-mimetype!", function(match, _, bufnr, pred, metadata)
    local capture_id = pred[2]
    local node = get_match_node(match, capture_id)
    if not node then
      return
    end
    local type_attr_value = vim.treesitter.get_node_text(node, bufnr)
    local configured = html_script_type_languages[type_attr_value]
    if configured then
      metadata["injection.language"] = configured
    else
      local parts = vim.split(type_attr_value, "/", {})
      metadata["injection.language"] = parts[#parts]
    end
  end, opts)

  pcall(query.add_directive, "set-lang-from-info-string!", function(match, _, bufnr, pred, metadata)
    local capture_id = pred[2]
    local node = get_match_node(match, capture_id)
    if not node then
      return
    end
    local injection_alias = vim.treesitter.get_node_text(node, bufnr):lower()
    metadata["injection.language"] = get_parser_from_markdown_info_string(injection_alias)
  end, opts)

  pcall(query.add_directive, "downcase!", function(match, _, bufnr, pred, metadata)
    local id = pred[2]
    local node = get_match_node(match, id)
    if not node then
      return
    end
    local text = vim.treesitter.get_node_text(node, bufnr, { metadata = metadata[id] }) or ""
    if not metadata[id] then
      metadata[id] = {}
    end
    metadata[id].text = string.lower(text)
  end, opts)
end

-- Apply immediately (covers case where nvim-treesitter already loaded)
patch()

-- Also re-apply after nvim-treesitter loads (lazy loading)
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  callback = function(args)
    if args.data == "nvim-treesitter" then
      patch()
    end
  end,
})

return { patch = patch }
